extends Node2D
## Всё состояние забега на экране: комната, тела, снаряды.
##
## Один узел с одним _draw вместо пула узлов на каждое тело: снаряды рождаются
## и гаснут каждую секунду десятками, и держать под них живые узлы значило бы
## писать пул ради картинки, которую всё равно перерисовывают целиком.
##
## Знает о симуляции только то, где что стоит. Обратной связи нет (правила
## 1 и 2 из CLAUDE.md). Удаляется целиком без последствий.

const RoomArt = preload("res://game/room_art.gd")
const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")
const Pickup = preload("res://sim/pickup.gd")
const RunState = preload("res://sim/run_state.gd")
const CharacterPose = preload("res://game/character_pose.gd")
const CombatFeedback = preload("res://game/combat_feedback.gd")
const ArmPose = preload("res://game/arm_pose.gd")
const CharacterArms = preload("res://game/character_arms.gd")
const ProjectilePose = preload("res://game/projectile_pose.gd")
const Organs = preload("res://sim/organs.gd")
const Harvest = preload("res://sim/harvest.gd")
const Miniboss = preload("res://sim/miniboss.gd")
const TankArt = preload("res://game/tank_art.gd")
const GuardArt = preload("res://game/guard_art.gd")
const Hitboxes = preload("res://sim/hitboxes.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const OrganArt = preload("res://game/organ_art.gd")
const LootArt = preload("res://game/loot_art.gd")
const Corpses = preload("res://sim/corpses.gd")
const Items = preload("res://sim/items.gd")
const Abilities = preload("res://sim/abilities.gd")
const Shooting = preload("res://sim/shooting.gd")

const BODY := Vector2(32, 40)
const BAR := Vector2(34, 3)
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
const TANK_ROOT := TankArt.ROOT

## Запасная высота для снарядов без известной точки выпуска (например, танка).
## У игрока смещение фиксируется по кисти/дулу в момент выстрела.
const PROJECTILE_FLIGHT := 51.0

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

var state: RunState = null
var origin := Vector2.ZERO
var textures: Dictionary = {}

## Фаза шага косметическая; сторону тела представление читает из актора.
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
var keyboard_slot := 0
var projectile_age: Dictionary = {}
var breath := 0.0

var _animation_state: RunState = null
var _arms := CharacterArms.new()
var _tank_art := TankArt.new()
var feedback := CombatFeedback.new()
var _animation_room := ""


## Здесь, а не в _draw: _draw может вызываться чаще или реже кадра.
func advance(delta: float) -> void:
	breath += delta
	_sync_animation_state()
	if state == null:
		return
	feedback.advance(delta)
	for id in feedback.falls.keys():
		if state.actor_by_id(id) == null:
			feedback.falls.erase(id)

	for actor in state.actors:
		if actor.kind != Actor.Kind.PLAYER or not actor.alive:
			continue
		stride_phase[actor.id] = CharacterPose.advance_stride(
			stride_phase.get(actor.id, 0.0), actor.velocity.length(), delta)
		facing[actor.id] = actor.facing
		standing_front[actor.id] = actor.standing_front

	var live_projectiles := {}
	for projectile in state.projectiles:
		live_projectiles[projectile.id] = true
		projectile_age[projectile.id] = float(projectile_age.get(projectile.id, 0.0)) + delta

	for id in projectile_age.keys():
		if live_projectiles.has(id):
			continue
		projectile_age.erase(id)


func _sync_animation_state() -> void:
	var room_id := state.room.id if state != null else ""
	if state != null and _animation_state != null and state.run_seed == _animation_state.run_seed \
			and state.tick >= _animation_state.tick and room_id == _animation_room:
		_animation_state = state
		return
	_animation_state = state
	_animation_room = room_id
	stride_phase.clear()
	facing.clear()
	standing_front.clear()
	projectile_age.clear()
	_arms.clear()
	_tank_art.clear()
	feedback.clear()


func consume_events(events: Array) -> void:
	_sync_animation_state()
	if state == null:
		return
	for event in events:
		if event.room_id != state.room.id:
			continue
		if event.type != "shot" and event.type != "hit": continue
		var actor := state.actor_by_id(event.actor_id)
		if actor == null:
			continue
		if event.type == "shot":
			var at: Vector2 = event.position - Vector2(0, PROJECTILE_FLIGHT)
			if actor.kind == Actor.Kind.PLAYER:
				var pose := _player_pose(actor, event.aim, event.weapon, 0.0)
				if not pose.is_empty():
					var grip := CharacterPose.weapon_offset(event.weapon, Vector2.ZERO, false)
					at = event.position - PLAYER_ROOT + CharacterPose.idle_bob(actor.velocity.length(), breath) + ArmPose.emission(
						pose.frame, pose.motion, event.weapon, grip, pose.side, event.aim)
			if event.has("projection_offset"):
				at = event.position + event.projection_offset
			feedback.shot(event, at)
		elif event.type == "hit":
			var at: Vector2 = event.position - Vector2(0, _sprite_height(actor) * 0.55)
			at = event.get("impact_position", at)
			feedback.hit(event, at)


func _draw() -> void:
	if state == null:
		return
	draw_rect(get_viewport_rect(), Color(0.035, 0.04, 0.045))
	_draw_room()
	_draw_spawn_markers()
	var actors := state.actors.duplicate()
	actors.sort_custom(func(a, b): return a.position.y < b.position.y)
	for actor in actors:
		if not actor.alive:
			_draw_actor(actor)
	var reachable = _reachable_pickup()
	var key := "E" if inspected_slot == keyboard_slot else "A"
	for pickup in state.pickups:
		LootArt.draw(self, textures, pickup, origin + pickup.position, pickup == reachable, key)
	for slot in state.slots:
		if slot.cover_ticks > 0:
			_draw_cover(slot)
	for actor in actors:
		if not actor.alive:
			continue
		if actor.behaviour == "tank" and actor.attack_ticks > 0:
			_draw_tank_warning(actor)
		if GuardArt.handles(actor): GuardArt.warning(self, actor, origin)
		_draw_actor(actor)
	for projectile in state.projectiles:
		_draw_projectile(projectile)
	feedback.draw_impacts(self, origin)
	var inspected := state.actor_of_slot(inspected_slot)
	if inspected != null:
		var alpha := feedback.flash(inspected.id) * 0.28
		if alpha > 0:
			draw_rect(get_viewport_rect().grow(-5), Color(0.85, 0.16, 0.13, alpha), false, 10)


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
			RoomArt.draw_doors(self, state.room, state.room_cleared(), origin)
			return
	var rect := Rect2(origin + state.room.bounds.position, state.room.bounds.size)

	var background: Texture2D = textures.get("room_start")
	if background != null:
		draw_texture(background, rect.position - ROOM_INSET)
		return

	draw_rect(rect, Color(0.11, 0.10, 0.12), true)
	draw_rect(rect, Color(0.35, 0.33, 0.38), false, 2.0)


## Подсказка горит у одного лута — того, который и возьмётся. Правило,
## по которому он выбран, живёт в симуляции.
func _reachable_pickup():
	var actor := state.actor_of_slot(inspected_slot)
	if actor == null or not actor.alive or state.slots[inspected_slot].downed:
		return null
	return Pickup.nearest(state, actor)


func _projectile_at(projectile: Projectile) -> Vector2:
	return origin + projectile.position + projectile.flight_offset()


func _draw_projectile(projectile: Projectile) -> void:
	var ground_at := origin + projectile.position
	var age := float(projectile_age.get(projectile.id, 0.0))

	var tumble := projectile.tumble_progress()
	_draw_projectile_shadow(ground_at + Vector2(projectile.projection_offset.x, 0), tumble)

	var at := _projectile_at(projectile)
	var turn_direction := -1.0 if projectile.velocity.x < 0.0 else 1.0

	# Вращается то, что бросают. Пуля не крутится, а летит носом вперёд:
	# спрайт нарисован смотрящим вправо, поэтому доворачивается по скорости.
	var angle := projectile.velocity.angle()
	if projectile.tumble_range > 0.0:
		angle = ProjectilePose.rotation(age, tumble) * turn_direction
	draw_set_transform(at, angle, Vector2.ONE)

	var paper: Texture2D = textures.get("bullet" if projectile.kind == "rifle_bullet" else projectile.kind)
	if projectile.kind == "oil_drop":
		draw_line(Vector2(-19, 0), Vector2.ZERO, Color(0.18, 0.12, 0.05, 0.65), 12)
		draw_circle(Vector2.ZERO, 11, Color(0.82, 0.51, 0.19))
		draw_circle(Vector2.ZERO, 8, Color(0.06, 0.045, 0.04))
		draw_circle(Vector2(2, -3), 2.5, Color(0.58, 0.43, 0.24))
	elif projectile.kind == "tank_shell":
		draw_line(Vector2(-22, 0), Vector2.ZERO, Color(1, 0.35, 0.08, 0.45), 8)
		draw_circle(Vector2.ZERO, 11, Color(0.15, 0.12, 0.07))
		draw_circle(Vector2(3, 0), 7, Color(1, 0.6, 0.22))
	elif paper != null:
		var size := paper.get_size()
		draw_texture(paper, -size * 0.5)
	else:
		var body := Rect2(-PROJECTILE * 0.5, PROJECTILE)
		draw_rect(body, LootArt.PAPER, true)
		draw_rect(body, LootArt.PAPER.darkened(0.5), false, 1.0)
		draw_line(Vector2(-4, -2), Vector2(4, -2), LootArt.PAPER.darkened(0.4), 1.0)
		draw_line(Vector2(-4, 1), Vector2(2, 1), LootArt.PAPER.darkened(0.4), 1.0)

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
	if not actor.alive:
		tint.a = Corpses.opacity(actor, state.tick)
		color.a = tint.a
		if tint.a <= 0.0:
			return
	var flash := feedback.flash(actor.id)
	tint *= Color(1 + flash * 1.8, 1 + flash * 1.2, 1 + flash * 0.7)
	var visual_at := at + feedback.offset(actor.id, 0.25 if actor.behaviour == "tank" else 1.0)
	var drawn := _draw_fallen(actor, visual_at, tint) if not actor.alive or downed else _draw_sprite(actor, visual_at, tint)
	if not drawn:
		var box := Rect2(at - BODY * 0.5, BODY)
		draw_rect(box, color, true)
		draw_rect(box, color.lightened(0.35), false, 1.0)

	if not actor.alive:
		if actor.organ_id != "" and not actor.harvested:
			var player := state.actor_of_slot(inspected_slot)
			if player != null and player.alive and not state.slots[inspected_slot].downed \
					and Harvest.nearest(state, player) == actor:
				var key := "F" if inspected_slot == keyboard_slot else "X"
				var caption := key + " · ИЗВЛЕЧЬ"
				if actor.corpse_until_tick >= 0:
					caption += " · %d с" % ceili(float(actor.corpse_until_tick - state.tick) / 60.0)
				var width := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				draw_string(ThemeDB.fallback_font, at + Vector2(-width * 0.5, 24), caption,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.8, 0.55))
		return

	if downed:
		draw_string(ThemeDB.fallback_font, at + Vector2(-18, -24), "УПАЛ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.75, 0.65))
		return
	_draw_health(actor, at, color)
	if is_player and actor.slot >= 0:
		_draw_charge(actor, at)

	if actor.invulnerable > 0.0:
		draw_arc(at, actor.radius + 10.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)

	# Напольный круг отвечает за движение и касание. Зоны урона врага
	# рисуются из тех же данных, по которым симуляция проверяет снаряд.
	if show_hitboxes:
		draw_circle(at, actor.radius, Color(1, 0.3, 0.3, 0.16))
		draw_arc(at, actor.radius, 0, TAU, 32, Color(1, 0.35, 0.35, 0.9), 1.5)
		for rect in Hitboxes.rectangles(actor):
			rect.position += origin
			draw_rect(rect, Color(1, 0.7, 0.2, 0.12))
			draw_rect(rect, Color(1, 0.7, 0.2, 0.9), false, 1.0)

	if is_player:
		draw_string(ThemeDB.fallback_font, at + Vector2(-6, -_sprite_height(actor) - 24.0),
			"p%d" % (actor.slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))


func _draw_sprite(actor: Actor, at: Vector2, tint: Color) -> bool:
	if actor.kind == Actor.Kind.PLAYER:
		return _draw_player(actor, at, tint)
	if GuardArt.handles(actor):
		return GuardArt.draw(self, textures, actor, at, tint)

	var sprite: Texture2D = textures.get(actor.archetype, textures.get("monster"))
	if sprite == null:
		return false
	if actor.behaviour == "tank":
		var side := -1.0 if actor.aim.x > 0.0 else 1.0
		draw_set_transform(at, 0.0, Vector2(side, 1.0))
		var color := tint if actor.alive else Color(0.45, 0.39, 0.35, 0.75 * tint.a)
		_tank_art.draw(self, actor, sprite, color, breath)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return true
	var size := sprite.get_size()
	draw_set_transform(at, 0.0, Vector2(actor.facing, 1.0))
	draw_texture(sprite, -Vector2(size.x * 0.5, size.y), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _draw_spawn_markers() -> void:
	for pending in state.pending_spawns:
		var at: Vector2 = origin + pending.position
		var remaining := maxf(0.0, float(pending.spawn_tick - state.tick) / 90.0)
		var color := Color(0.96, 0.40, 0.18, 0.75)
		draw_circle(at, 30.0, Color(0.8, 0.16, 0.05, 0.14))
		draw_arc(at, 30.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - remaining), 40, color, 3.0)
		draw_line(at + Vector2(-10, -10), at + Vector2(10, 10), color, 2.0)
		draw_line(at + Vector2(-10, 10), at + Vector2(10, -10), color, 2.0)
		draw_string(ThemeDB.fallback_font, at + Vector2(-34, -39), "ПОДКРЕПЛЕНИЕ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


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


func _player_pose(actor: Actor, aim: Vector2 = Vector2.ZERO, weapon: String = "",
		progress_override: float = -2.0) -> Dictionary:
	if weapon == "":
		weapon = actor.weapon_id
	var recent: Dictionary = feedback.shots.get(actor.id, {})
	var matching_shot: bool = not recent.is_empty() and recent.get("weapon", "") == weapon
	if aim == Vector2.ZERO and (bool(firing.get(actor.id, false)) or matching_shot):
		aim = actor.aim
	var speed := actor.velocity.length()
	var phase: float = stride_phase.get(actor.id, 0.0)
	var front := bool(standing_front.get(actor.id, actor.standing_front))
	if aim != Vector2.ZERO and (weapon == "colt" or absf(aim.x) > 0.2):
		front = false
	var names := CharacterPose.stand_names(weapon)
	var gait := ""
	if CharacterPose.use_walk_frames(speed):
		gait = _first_name(CharacterPose.walk_frame_names(weapon, CharacterPose.walk_frame(phase)))
		front = false
	elif front:
		names = CharacterPose.front_stand_names(weapon)
	var chosen := _first_name(names)
	if chosen == "":
		chosen = gait
		gait = ""
	if chosen == "":
		return {}
	var side := 0 if front else CharacterPose.aiming_facing(aim, actor.velocity,
		aim != Vector2.ZERO, int(facing.get(actor.id, actor.facing)))
	var progress := -1.0
	if matching_shot:
		progress = float(recent.age) / CharacterPose.THROW_TIME
	if progress_override > -2.0:
		progress = progress_override
	var motion := ArmPose.aimed_motion(chosen, weapon, phase, speed, progress, aim, side)
	return {"frame": chosen, "gait": gait, "side": side, "motion": motion, "aim": aim, "weapon": weapon, "actor_id": actor.id}


func _draw_player(actor: Actor, at: Vector2, tint: Color) -> bool:
	var pose := _player_pose(actor)
	if pose.is_empty():
		return false
	var side: int = pose.side
	var canvas := at - PLAYER_ROOT + CharacterPose.idle_bob(actor.velocity.length(), breath)
	var organs: Dictionary = state.slots[actor.slot].organs if actor.slot >= 0 else {}
	OrganArt.draw_body(self, textures, organs, canvas, side, tint, breath, true)
	var body_transform := Transform2D(0.0, canvas)
	if side < 0:
		body_transform = Transform2D(Vector2(-1, 0), Vector2(0, 1), canvas + Vector2(PLAYER_CANVAS.x, 0))
	draw_set_transform_matrix(body_transform)
	_arms.draw(self, actor.id, textures[pose.frame], pose.frame, pose.motion, tint,
		textures.get("player_side_stand"), textures.get(pose.gait), pose.gait)
	draw_set_transform(Vector2.ZERO)
	OrganArt.draw_body(self, textures, organs, canvas, side, tint, breath, false)
	_draw_weapon(canvas, tint, pose, body_transform)
	return true


func _draw_fallen(actor: Actor, at: Vector2, tint: Color) -> bool:
	if actor.behaviour in ["tank", "oil_baron"]:
		return _draw_sprite(actor, at, tint)
	var texture: Texture2D = textures.get("player_side_stand") if actor.kind == Actor.Kind.PLAYER else textures.get(actor.archetype, textures.get("monster"))
	if GuardArt.handles(actor): texture = textures.get(GuardArt.frame(actor))
	if texture == null:
		return false
	var progress := feedback.fall_progress(actor.id)
	if actor.kind == Actor.Kind.ENEMY:
		tint *= Color.WHITE.lerp(Color(0.6, 0.55, 0.52), progress)
	var size := texture.get_size()
	var root := PLAYER_ROOT if actor.kind == Actor.Kind.PLAYER else Vector2(size.x * 0.5, size.y)
	if GuardArt.handles(actor): root = GuardArt.ROOT
	var center := Vector2(0, -root.y * 0.5 * (1.0 - progress))
	var direction := 1.0
	if feedback.falls.has(actor.id) and Vector2(feedback.falls[actor.id].direction).x < 0:
		direction = -1.0
	draw_set_transform(at + center, direction * progress * PI * 0.5, Vector2(1, lerpf(1, 0.65, progress)))
	draw_texture(texture, Vector2(-root.x, -root.y * 0.5), tint)
	draw_set_transform(Vector2.ZERO)
	return true


func _first_name(names: PackedStringArray) -> String:
	for name in names:
		if textures.get(name) != null:
			return name
	return ""


func _draw_weapon(canvas: Vector2, tint: Color, pose: Dictionary,
		body_transform: Transform2D) -> void:
	var texture: Texture2D = textures.get(pose.weapon)
	if texture == null:
		return
	var grip := CharacterPose.weapon_offset(pose.weapon, texture.get_size(), false)
	var attachment := ArmPose.weapon_transform(pose.frame, pose.motion, grip, pose.side, pose.weapon, pose.aim)
	attachment.origin += canvas
	draw_set_transform_matrix(attachment)
	draw_texture(texture, Vector2.ZERO, tint)
	var shot: Dictionary = feedback.shots.get(pose.actor_id, {})
	if pose.weapon == "colt" and shot.get("weapon", "") == "colt" and shot.age < 0.055:
		var muzzle := Vector2(19, 3)
		var reach := 11.0 * (1 - float(shot.age) / 0.055)
		draw_colored_polygon(PackedVector2Array([muzzle, muzzle + Vector2(4, -3),
			muzzle + Vector2(reach, 0), muzzle + Vector2(4, 3)]), Color(1, 0.84, 0.4, 0.9))
	var palm: Vector2 = ArmPose.joints(pose.frame)[2]
	var fingers := Rect2(palm + Vector2(-2, 0), Vector2(4, 4))
	draw_set_transform_matrix(body_transform * Transform2D(pose.motion))
	draw_texture_rect_region(textures[pose.frame], fingers, fingers, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_health(actor: Actor, at: Vector2, color: Color) -> void:
	var maximum: float = actor.max_health()
	if maximum <= 0.0:
		return
	if actor.behaviour == "oil_baron":
		return
	_draw_bar(at + Vector2(-BAR.x * 0.5, -_sprite_height(actor) - 10.0), BAR,
		actor.health / maximum, color.lightened(0.2))


## Чемодан-укрытие: пока он стоит, его нет в руках владельца.
func _draw_cover(slot) -> void:
	var area := Abilities.rect(slot)
	var rect := Rect2(origin + area.position, area.size)
	draw_set_transform(rect.get_center() + Vector2(0, rect.size.y * 0.4), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, rect.size.x * 0.5, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(rect, Color(0.24, 0.16, 0.11), true)
	draw_rect(rect, Color(0.08, 0.06, 0.05), false, 2.0)
	var handle := Rect2(rect.get_center() - Vector2(rect.size.x * 0.18, rect.size.y * 0.5 + 6),
		Vector2(rect.size.x * 0.36, 6))
	draw_rect(handle, Color(0.14, 0.1, 0.08), true)
	_draw_bar(rect.position + Vector2(0, -12), Vector2(rect.size.x, 4),
		slot.cover_health / Abilities.COVER_HEALTH, Color(0.83, 0.62, 0.35))


func _draw_charge(actor: Actor, at: Vector2) -> void:
	var slot = state.slots[actor.slot]
	if slot.charge_ticks <= 0:
		return
	var duration := Shooting.charge_duration(actor.stack.compute())
	if duration <= 0:
		return
	_draw_bar(at + Vector2(-BAR.x * 0.5, -_sprite_height(actor) - 18.0), BAR,
		float(slot.charge_ticks) / duration, Color(1.0, 0.82, 0.35))


func _draw_bar(top: Vector2, size: Vector2, share: float, color: Color) -> void:
	draw_rect(Rect2(top, size), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(top, Vector2(size.x * clampf(share, 0.0, 1.0), size.y)), color, true)


func _sprite_height(actor: Actor) -> float:
	if actor.kind == Actor.Kind.PLAYER:
		return PLAYER_HEIGHT
	if actor.behaviour == "tank":
		return TANK_ROOT.y
	if GuardArt.handles(actor): return 330.0 if actor.behaviour == "oil_baron" else GuardArt.HEIGHT
	var sprite: Texture2D = textures.get(actor.archetype, textures.get("monster"))
	return sprite.get_size().y if sprite != null else BODY.y


func _map_origin(viewport: Vector2) -> Vector2:
	var texture: Texture2D = textures.get("room_" + state.room.id)
	if texture == null: return viewport * 0.5
	var image_rect := RoomArt.image_rect(state.room, texture.get_size())
	var player := state.actor_of_slot(inspected_slot)
	var target := player.position if player != null else Vector2.ZERO
	# Качалка выше обычного врага. У входа камера держит её целиком,
	# но продолжает следить за игроком у верхней и нижней границ.
	if state.room.id == "oil_baron": target.y = clampf(-30.0, target.y - 310.0, target.y + 200.0)
	# Место под тело HUD: ноги у нижней стены должны оставаться видны.
	var usable := viewport - Vector2(0, 120)
	var result := usable * 0.5 - target
	for axis in 2:
		if image_rect.size[axis] <= usable[axis]:
			result[axis] = usable[axis] * 0.5 - image_rect.get_center()[axis]
		else:
			result[axis] = clampf(result[axis], usable[axis] - image_rect.end[axis], -image_rect.position[axis])
	return result
