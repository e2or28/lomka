extends Node2D
## Всё состояние забега на экране: комната, тела, снаряды.
##
## Один узел с одним _draw вместо пула узлов на каждое тело: снаряды рождаются
## и гаснут каждую секунду десятками, и держать под них живые узлы значило бы
## писать пул ради картинки, которую всё равно перерисовывают целиком.
##
## Знает о симуляции только то, где что стоит. Обратной связи нет (правила
## 1 и 2 из CLAUDE.md). Удаляется целиком без последствий.

const RoomMap = preload("res://sim/room_map.gd")
const RoomArt = preload("res://game/room_art.gd")
const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")
const Pickup = preload("res://sim/pickup.gd")
const RunState = preload("res://sim/run_state.gd")
const CharacterPose = preload("res://game/character_pose.gd")
const ProjectilePose = preload("res://game/projectile_pose.gd")
const Organs = preload("res://sim/organs.gd")
const Harvest = preload("res://sim/harvest.gd")
const Miniboss = preload("res://sim/miniboss.gd")
const Arsenal = preload("res://sim/arsenal.gd")

const BODY := Vector2(32, 40)
const PROJECTILE := Vector2(18, 14)
const PROJECTILE_SHADOW_RADIUS := 10.0

## Якорь кадров — character_root из art/player_layers.json, точка под
## ногами, а не центр холста.
const PLAYER_ROOT := Vector2(64, 174)

## Общий холст кадров — нужен, чтобы отразить точку кисти вместе
## с отражённым кадром.
const PLAYER_CANVAS := Vector2(128, 192)

## Рост фигуры на кадре: значение по умолчанию у tools/import_frames.py,
## под которое приведён весь набор.
const PLAYER_HEIGHT := 156.0

# PNG танка 1334×742; опора в центре гусениц, ствол выступает влево.
const TANK_SIZE := Vector2(440, 245)
const TANK_ROOT := Vector2(288, 220)

## Снаряд вылетает из кисти, а не из-под ног: симуляция считает всё на полу,
## высота живёт только здесь. Тень остаётся внизу и показывает её.
const PROJECTILE_FLIGHT := PLAYER_ROOT.y - CharacterPose.HAND_SIDE.y

## Печатает tools/import_room.py при импорте комнаты; менять руками нельзя —
## только вместе с картинкой.
const ROOM_INSET := Vector2(91, 210)

const SLOT_COLORS: Array[Color] = [
	Color(0.45, 0.85, 0.55),
	Color(0.95, 0.65, 0.35),
	Color(0.55, 0.7, 0.98),
	Color(0.9, 0.55, 0.8),
]
const ENEMY_COLOR := Color(0.85, 0.35, 0.4)
const PAPER_COLOR := Color(0.93, 0.88, 0.72)

var state: RunState = null
var origin := Vector2.ZERO
var textures: Dictionary = {}

## В представлении, а не в состоянии забега: попадание считается по
## положению тела, а не по нарисованной руке, и гонять фазу шага по сети
## незачем.
var stride_phase: Dictionary = {}
var facing: Dictionary = {}

## Отдельно от facing: на ходу персонаж в профиль в любом случае, а анфас
## решается только для стойки. Одним значением это не выразить — при
## развороте к зрителю пришлось бы забыть, каким боком он шёл.
var standing_front: Dictionary = {}

## Ставится стендом: симуляция про представление не знает.
var firing: Dictionary = {}
var show_hitboxes := false
var inspected_slot := 0
var projectile_age: Dictionary = {}
var breath := 0.0

var _animation_state: RunState = null


## Здесь, а не в _draw: _draw может вызываться чаще или реже кадра.
func advance(delta: float) -> void:
	breath += delta
	if state != _animation_state:
		_animation_state = state
		stride_phase.clear()
		facing.clear()
		standing_front.clear()
		projectile_age.clear()
	if state == null:
		return

	for actor in state.actors:
		if actor.kind != Actor.Kind.PLAYER or not actor.alive:
			continue
		stride_phase[actor.id] = CharacterPose.advance_stride(
			stride_phase.get(actor.id, 0.0), actor.velocity.length(), delta)
		var shooting := bool(firing.get(actor.id, false))
		facing[actor.id] = CharacterPose.aiming_facing(
			actor.aim, actor.velocity, shooting, facing.get(actor.id, 1))
		standing_front[actor.id] = CharacterPose.stand_front(
			actor.aim, actor.velocity, shooting,
			bool(standing_front.get(actor.id, false)))

	var live_projectiles := {}
	for projectile in state.projectiles:
		live_projectiles[projectile.id] = true
		projectile_age[projectile.id] = float(projectile_age.get(projectile.id, 0.0)) + delta

	for id in projectile_age.keys():
		if live_projectiles.has(id):
			continue
		projectile_age.erase(id)


func _draw() -> void:
	if state == null:
		return
	draw_rect(get_viewport_rect(), Color(0.035, 0.04, 0.045))
	_draw_room()
	for pickup in state.pickups:
		_draw_pickup(pickup)
	var actors := state.actors.duplicate()
	actors.sort_custom(func(a, b): return a.position.y < b.position.y)
	for actor in actors:
		if not actor.alive:
			_draw_actor(actor)
	for actor in actors:
		if not actor.alive:
			continue
		if actor.behaviour == "tank" and actor.attack_ticks > 0:
			_draw_tank_warning(actor)
		_draw_actor(actor)
	for projectile in state.projectiles:
		_draw_projectile(projectile)


## Картинка комнаты выше игровой зоны сверху, чем снизу: по центру окна
## ставится она, а не зона, иначе верх стены с лампами уезжает за экран.
func centering_origin(viewport: Vector2) -> Vector2:
	if state != null and state.room.id != "":
		return _map_origin(viewport)
	var background: Texture2D = textures.get("room_start")
	if state == null or background == null:
		return viewport * 0.5
	return (viewport - background.get_size()) * 0.5 + ROOM_INSET - state.room.bounds.position


func _draw_room() -> void:
	if state.room.id != "":
		var texture: Texture2D = textures.get("room_" + state.room.id)
		if texture != null:
			RoomArt.draw(self, state.room, texture, origin)
			_draw_doors()
			return
	var rect := Rect2(origin + state.room.bounds.position, state.room.bounds.size)

	var background: Texture2D = textures.get("room_start")
	if background != null:
		draw_texture(background, rect.position - ROOM_INSET)
		return

	draw_rect(rect, Color(0.11, 0.10, 0.12), true)
	draw_rect(rect, Color(0.35, 0.33, 0.38), false, 2.0)


## Лежит на полу, поэтому рисуется до тел: подошедший накрывает его собой.
## Напольный спрайт крупнее оружия в руке, чтобы лут читался на пёстром полу.
func _draw_pickup(pickup: Pickup) -> void:
	var at := origin + pickup.position
	var ground: Texture2D = textures.get(pickup.content_id + "_ground")
	draw_set_transform(at, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 28.0 if ground != null else pickup.radius * 0.7,
		Color(0.0, 0.0, 0.0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var sprite: Texture2D = ground if ground != null else textures.get(pickup.content_id + "_top")
	if pickup.kind == Pickup.KIND_ORGAN:
		draw_circle(at, 12, Color(0.27, 0.07, 0.1))
		draw_arc(at, 12, 0, TAU, 24, Color(1, 0.5, 0.4), 2)
		var record := Organs.organ(pickup.content_id)
		var mark := "С" if record.get("slot", "") == "heart" else "П"
		draw_string(ThemeDB.fallback_font, at + Vector2(-5, 5), mark,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.8, 0.65))
	elif sprite != null:
		var size := sprite.get_size()
		if ground != null:
			size *= 54.0 / size.x
		draw_texture_rect(sprite, Rect2(at - size * 0.5, size), false)
	else:
		draw_rect(Rect2(at - Vector2(9, 4), Vector2(18, 8)), PAPER_COLOR, true)

	if not _within_reach(pickup):
		return
	draw_arc(at, pickup.radius, 0, TAU, 28, Color(1, 1, 1, 0.35), 1.5)
	var key := "E" if inspected_slot == 0 else "A"
	var caption := key
	if pickup.kind == Pickup.KIND_WEAPON:
		caption += " · " + Arsenal.weapon(pickup.content_id).get("name", pickup.content_id)
	var width := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var label_at := at + Vector2(-width * 0.5, -pickup.radius - 6)
	draw_rect(Rect2(label_at + Vector2(-5, -14), Vector2(width + 10, 19)), Color(0.04, 0.04, 0.04, 0.8))
	draw_string(ThemeDB.fallback_font, label_at,
		caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.89, 0.65))


func _within_reach(pickup: Pickup) -> bool:
	var actor := state.actor_of_slot(inspected_slot)
	if actor == null or not actor.alive or state.slots[inspected_slot].downed:
		return false
	var reach: float = pickup.radius + actor.radius
	return pickup.position.distance_squared_to(actor.position) <= reach * reach


func _draw_projectile(projectile: Projectile) -> void:
	var ground_at := origin + projectile.position
	var age := float(projectile_age.get(projectile.id, 0.0))

	var tumble := projectile.tumble_progress()
	_draw_projectile_shadow(ground_at, tumble)

	var at := ground_at - Vector2(0.0, PROJECTILE_FLIGHT + ProjectilePose.hop(tumble))
	var turn_direction := -1.0 if projectile.velocity.x < 0.0 else 1.0

	# Вращается то, что бросают. Пуля не крутится, а летит носом вперёд:
	# спрайт нарисован смотрящим вправо, поэтому доворачивается по скорости.
	var angle := projectile.velocity.angle()
	if projectile.tumble_range > 0.0:
		angle = ProjectilePose.rotation(age, tumble) * turn_direction
	draw_set_transform(at, angle, Vector2.ONE)

	var paper: Texture2D = textures.get(projectile.kind)
	if projectile.kind == "tank_shell":
		draw_line(Vector2(-22, 0), Vector2.ZERO, Color(1, 0.35, 0.08, 0.45), 8)
		draw_circle(Vector2.ZERO, 11, Color(0.15, 0.12, 0.07))
		draw_circle(Vector2(3, 0), 7, Color(1, 0.6, 0.22))
	elif paper != null:
		var size := paper.get_size()
		draw_texture(paper, -size * 0.5)
	else:
		var body := Rect2(-PROJECTILE * 0.5, PROJECTILE)
		draw_rect(body, PAPER_COLOR, true)
		draw_rect(body, PAPER_COLOR.darkened(0.5), false, 1.0)
		draw_line(Vector2(-4, -2), Vector2(4, -2), PAPER_COLOR.darkened(0.4), 1.0)
		draw_line(Vector2(-4, 1), Vector2(2, 1), PAPER_COLOR.darkened(0.4), 1.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_projectile_shadow(at: Vector2, tumble: float) -> void:
	var scale := ProjectilePose.shadow_scale(tumble)
	var alpha := ProjectilePose.shadow_alpha(tumble)
	draw_set_transform(at, 0.0, Vector2(scale, scale * 0.32))
	draw_circle(Vector2.ZERO, PROJECTILE_SHADOW_RADIUS, Color(0.0, 0.0, 0.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_actor(actor: Actor) -> void:
	var at := origin + actor.position
	var is_player := actor.kind == Actor.Kind.PLAYER
	var downed: bool = is_player and actor.slot >= 0 and state.slots[actor.slot].downed

	var color: Color = SLOT_COLORS[actor.slot % SLOT_COLORS.size()] if is_player else ENEMY_COLOR
	if not actor.alive:
		color = color.darkened(0.7)
	elif downed:
		color = color.darkened(0.5)

	var tint := Color.WHITE if not downed else Color(0.55, 0.55, 0.6)
	if not _draw_sprite(actor, at, tint):
		var box := Rect2(at - BODY * 0.5, BODY)
		draw_rect(box, color, true)
		draw_rect(box, color.lightened(0.35), false, 1.0)

	if not actor.alive:
		# Труп остаётся на экране: над ним делается харвест органов.
		draw_line(at + Vector2(-10, -8), at + Vector2(10, 8), color.lightened(0.3), 2.0)
		draw_line(at + Vector2(-10, 8), at + Vector2(10, -8), color.lightened(0.3), 2.0)
		if actor.organ_id != "" and not actor.harvested:
			draw_arc(at, actor.radius + 8, 0, TAU, 40, Color(0.95, 0.54, 0.36, 0.7), 2)
			var player := state.actor_of_slot(inspected_slot)
			if player != null and Harvest.nearest(state, player) == actor:
				var key := "F" if inspected_slot == 0 else "X"
				draw_string(ThemeDB.fallback_font, at + Vector2(-50, 24), key + " · ИЗВЛЕЧЬ",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.8, 0.55))
		return

	_draw_health(actor, at, color)

	if actor.aim != Vector2.ZERO and not downed:
		var from := at - Vector2(0, _sprite_height(actor) * 0.45)
		draw_line(from, from + actor.aim.normalized() * 40.0, Color(1, 1, 1, 0.4), 2.0)

	if actor.invulnerable > 0.0:
		draw_arc(at, actor.radius + 10.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)

	# Круг попаданий не совпадает с силуэтом намеренно, и на глаз это не
	# проверить: подбирать радиусы можно только видя их. Заливка нужна,
	# чтобы круг читался пятном на полу, а не обручем перед телом — он и
	# есть след на полу, тело стоит НАД ним.
	if show_hitboxes:
		draw_circle(at, actor.radius, Color(1, 0.3, 0.3, 0.16))
		draw_arc(at, actor.radius, 0, TAU, 32, Color(1, 0.35, 0.35, 0.9), 1.5)

	if is_player:
		draw_string(ThemeDB.fallback_font, at + Vector2(-6, -_sprite_height(actor) - 16.0),
			"p%d" % (actor.slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))


func _draw_sprite(actor: Actor, at: Vector2, tint: Color) -> bool:
	if actor.kind == Actor.Kind.PLAYER:
		return _draw_player(actor, at, tint)

	var sprite: Texture2D = textures.get(actor.archetype, textures.get("monster"))
	if sprite == null:
		return false
	if actor.behaviour == "tank":
		var side := -1.0 if actor.aim.x > 0.0 else 1.0
		draw_set_transform(at, 0.0, Vector2(side, 1.0))
		var color := tint if actor.alive else Color(0.45, 0.39, 0.35, 0.75)
		draw_texture_rect(sprite, Rect2(-TANK_ROOT, TANK_SIZE), false, color)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return true
	var size := sprite.get_size()
	if not actor.alive:
		draw_texture_rect(sprite, Rect2(at - Vector2(size.x * 0.5, size.y * 0.2),
			Vector2(size.x, size.y * 0.3)), false, Color(0.4, 0.35, 0.35, 0.7))
	else:
		draw_texture(sprite, at - Vector2(size.x * 0.5, size.y), tint)
	return true


func _draw_tank_warning(actor: Actor) -> void:
	var at := origin + actor.position
	var strength := 1.0 - float(actor.attack_ticks) / Miniboss.WINDUP_TICKS
	var direction := actor.attack_aim
	var from := at + direction * (actor.radius + 12)
	var reach := float(actor.stack.compute().get("range", 1200.0)) + actor.radius + 12
	var bounds := state.room.bounds
	if absf(direction.x) > 0.0001:
		var edge := bounds.end.x if direction.x > 0 else bounds.position.x
		reach = minf(reach, (edge - actor.position.x) / direction.x)
	if absf(direction.y) > 0.0001:
		var edge := bounds.end.y if direction.y > 0 else bounds.position.y
		reach = minf(reach, (edge - actor.position.y) / direction.y)
	var to := at + direction * reach
	draw_line(from, to, Color(1, 0.25, 0.15, 0.14 + strength * 0.15), 24)
	draw_dashed_line(from, to, Color(1, 0.5, 0.22, 0.7), 2, 10)
	draw_arc(at, actor.radius + 5, -PI / 2, -PI / 2 + TAU * strength,
		40, Color(1, 0.45, 0.18), 4)


func _draw_player(actor: Actor, at: Vector2, tint: Color) -> bool:
	var speed := actor.velocity.length()
	var phase: float = stride_phase.get(actor.id, 0.0)

	var front := bool(standing_front.get(actor.id, false))
	var names := CharacterPose.stand_names(actor.weapon_id)
	if CharacterPose.use_walk_frames(speed):
		names = CharacterPose.walk_frame_names(actor.weapon_id, CharacterPose.walk_frame(phase))
		front = false
	elif front:
		names = CharacterPose.front_stand_names(actor.weapon_id)
	var chosen := _first_name(names)
	if chosen == "":
		return false

	# Ноль — анфас: кадр не отражается и кисть берётся анфасная.
	var side := 0 if front else int(facing.get(actor.id, 1))
	var canvas := at - PLAYER_ROOT + CharacterPose.idle_bob(speed, breath)
	_draw_facing(textures[chosen], canvas, side, tint)
	_draw_weapon(actor, canvas, phase, speed, side, tint,
		actor.weapon_id != "" and chosen.contains("_%s_" % actor.weapon_id))
	return true


func _first_name(names: PackedStringArray) -> String:
	for name in names:
		if textures.get(name) != null:
			return name
	return ""


## Спрайт берётся по идентификатору оружия — здесь нет ни одного
## разветвления по видам. Нет спрайта — ничего не рисуется, это правильнее
## заглушки: чужой прямоугольник приняли бы за настоящее оружие.
func _draw_weapon(actor: Actor, canvas: Vector2, phase: float, speed: float,
		side: int, tint: Color, aimed: bool) -> void:
	if actor.weapon_id == "":
		return
	var texture: Texture2D = textures.get(actor.weapon_id)
	if texture == null:
		return

	var stats := actor.stack.compute()
	var hand := CharacterPose.hand_position(phase, speed,
		CharacterPose.throw_progress(actor.cooldown, stats.get("fire_rate", 0.0)),
		side, aimed, actor.weapon_id)
	if side > 0:
		hand.x = PLAYER_CANVAS.x - hand.x

	# Оружие отражается вместе с персонажем: иначе кольт у идущего влево
	# смотрел бы стволом назад.
	var size := texture.get_size()
	var mirrored := side < 0
	var offset := CharacterPose.weapon_offset(actor.weapon_id, size, mirrored)
	if mirrored:
		draw_set_transform(canvas + hand - Vector2(size.x - offset.x, offset.y)
			+ Vector2(size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture(texture, Vector2.ZERO, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_texture(texture, canvas + hand - offset, tint)


## Профильные кадры нарисованы лицом вправо, поэтому отражается движение
## влево. Проверено тестом «направление взгляда».
func _draw_facing(texture: Texture2D, canvas: Vector2, side: int, tint: Color) -> void:
	if side >= 0:
		draw_texture(texture, canvas, tint)
		return
	var width := texture.get_size().x
	draw_set_transform(canvas + Vector2(width, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture(texture, Vector2.ZERO, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_health(actor: Actor, at: Vector2, color: Color) -> void:
	var maximum: float = actor.max_health()
	if maximum <= 0.0:
		return
	var width := 34.0
	var top := at + Vector2(-width * 0.5, -_sprite_height(actor) - 10.0)
	draw_rect(Rect2(top, Vector2(width, 3)), Color(0, 0, 0, 0.6), true)
	var share := clampf(actor.health / maximum, 0.0, 1.0)
	draw_rect(Rect2(top, Vector2(width * share, 3)), color.lightened(0.2), true)


func _sprite_height(actor: Actor) -> float:
	if actor.kind == Actor.Kind.PLAYER:
		return PLAYER_HEIGHT
	if actor.behaviour == "tank":
		return TANK_ROOT.y
	var sprite: Texture2D = textures.get("monster")
	return sprite.get_size().y if sprite != null else BODY.y


func _map_origin(viewport: Vector2) -> Vector2:
	var texture: Texture2D = textures.get("room_" + state.room.id)
	if texture == null: return viewport * 0.5
	var image_rect := RoomArt.image_rect(state.room, texture.get_size())
	var player := state.actor_of_slot(inspected_slot)
	var target := player.position if player != null else Vector2.ZERO
	# Место под тело HUD: ноги у нижней стены должны оставаться видны.
	var usable := viewport - Vector2(0, 120)
	var result := usable * 0.5 - target
	for axis in 2:
		if image_rect.size[axis] <= usable[axis]:
			result[axis] = usable[axis] * 0.5 - image_rect.get_center()[axis]
		else:
			result[axis] = clampf(result[axis], usable[axis] - image_rect.end[axis], -image_rect.position[axis])
	return result


func _draw_doors() -> void:
	var opened := state.room_cleared()
	var color := Color(0.63, 0.86, 0.65) if opened else Color(0.9, 0.32, 0.25)
	for direction in RoomMap.exits(state.room):
		var normal: Vector2 = RoomMap.DIRECTIONS[direction]
		var tangent := Vector2(-normal.y, normal.x)
		var at := origin + RoomMap.door(state.room, direction) - normal * 5
		var width := RoomMap.half_width(direction)
		draw_line(at - tangent * width, at + tangent * width, color.darkened(0.5), 10)
		draw_line(at - tangent * width, at + tangent * width, color, 3)
		if opened:
			var tip := at - normal * 22
			draw_line(tip - normal * 12 - tangent * 9, tip, color, 3)
			draw_line(tip - normal * 12 + tangent * 9, tip, color, 3)
		else:
			for step in [-1, 0, 1]:
				var bar: Vector2 = at + tangent * step * 22
				draw_line(bar - normal * 10, bar + normal * 10, color, 4)
