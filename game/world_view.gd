extends Node2D
## Всё состояние забега на экране: комната, тела, снаряды.
##
## Один узел с одним _draw вместо пула узлов на каждое тело. Причина —
## снаряды: их десятки, они рождаются и гаснут каждую секунду, и держать
## под них живые узлы значит писать пул с переиспользованием ради картинки,
## которую всё равно перерисовывают целиком.
##
## Знает о симуляции ровно одно: где что стоит. Обратной связи нет,
## решений не принимает (правила 1 и 2). Удаляется целиком без последствий.

const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")
const RunState = preload("res://sim/run_state.gd")
const CharacterPose = preload("res://game/character_pose.gd")

const BODY := Vector2(32, 40)
const PROJECTILE := Vector2(18, 14)

## Персонаж собирается из слоёв: корпус, руки, голова. Порядок от заднего
## к переднему задан в art/player_layers.json и менять его нельзя — руки
## обязаны лежать поверх корпуса, но под головой.
##
## Слои нарисованы на общем холсте 128x192 с общей системой координат,
## поэтому кладутся друг на друга без подгонки. Якорь — character_root
## оттуда же: это точка под ногами, а не центр холста. Совмещать надо её
## с положением тела в симуляции, иначе персонаж будет плавать над полом.
## Руки взяты отдельными слоями, а не общим: махать ими на бегу можно только
## поодиночке. Проверено, что arm_left и arm_right складываются в прежний
## общий слой пиксель-в-пиксель, а вся сборка совпадает с мастером.
const PLAYER_ROOT := Vector2(64, 174)

## Плечи из art/player_layers.json, набор godot_128. Вокруг них вращаются
## руки: пивот в плече читается как мах, пивот в центре холста — как отрыв
## конечности.
const LEFT_SHOULDER := Vector2(45, 63)
const RIGHT_SHOULDER := Vector2(83, 63)

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

## Фаза шага на каждое тело и общий счётчик для дыхания.
##
## Живут в представлении, а не в состоянии забега: от них ничего не зависит,
## попадание считается по положению тела, а не по нарисованной руке. Класть
## их в симуляцию значило бы гонять по сети данные, которые ни на что не
## влияют, и раздувать сейв.
var stride_phase: Dictionary = {}
var breath := 0.0


## Двигать фазы. Вызывается стендом каждый кадр — здесь, а не в _draw,
## потому что _draw может вызываться чаще или реже кадра.
func advance(delta: float) -> void:
	breath += delta
	if state == null:
		return
	for actor in state.actors:
		if actor.kind != Actor.Kind.PLAYER or not actor.alive:
			continue
		stride_phase[actor.id] = CharacterPose.advance_stride(
			stride_phase.get(actor.id, 0.0), actor.velocity.length(), delta)


func _draw() -> void:
	if state == null:
		return
	_draw_room()
	for projectile in state.projectiles:
		_draw_projectile(projectile)
	for actor in state.actors:
		_draw_actor(actor)


func _draw_room() -> void:
	var rect := Rect2(origin + state.room.bounds.position, state.room.bounds.size)
	draw_rect(rect, Color(0.11, 0.10, 0.12), true)
	draw_rect(rect, Color(0.35, 0.33, 0.38), false, 2.0)


## Папка с документами: летит, не вращаясь — вращение это уже ощущение,
## а его подбирает человек, а не формула.
func _draw_projectile(projectile: Projectile) -> void:
	var at := origin + projectile.position
	var body := Rect2(at - PROJECTILE * 0.5, PROJECTILE)
	var paper: Texture2D = textures.get("folder")
	if paper != null:
		var size := paper.get_size()
		draw_texture_rect(paper, Rect2(at - size * 0.5, size), false)
		return
	draw_rect(body, PAPER_COLOR, true)
	draw_rect(body, PAPER_COLOR.darkened(0.5), false, 1.0)
	draw_line(at + Vector2(-4, -2), at + Vector2(4, -2), PAPER_COLOR.darkened(0.4), 1.0)
	draw_line(at + Vector2(-4, 1), at + Vector2(2, 1), PAPER_COLOR.darkened(0.4), 1.0)


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
		# Труп остаётся: над ним делается харвест органов
		draw_line(at + Vector2(-10, -8), at + Vector2(10, 8), color.lightened(0.3), 2.0)
		draw_line(at + Vector2(-10, 8), at + Vector2(10, -8), color.lightened(0.3), 2.0)
		return

	_draw_health(actor, at, color)

	if actor.aim != Vector2.ZERO and not downed:
		var from := at - Vector2(0, _sprite_height(actor) * 0.45)
		draw_line(from, from + actor.aim.normalized() * 40.0, Color(1, 1, 1, 0.4), 2.0)

	if actor.invulnerable > 0.0:
		draw_arc(at, 26.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)

	if is_player:
		draw_string(ThemeDB.fallback_font, at + Vector2(-6, -_sprite_height(actor) - 16.0),
			"p%d" % (actor.slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))


## Спрайт тела. Возвращает false, если рисовать нечем — тогда вызывающий
## код кладёт заглушку.
func _draw_sprite(actor: Actor, at: Vector2, tint: Color) -> bool:
	if not actor.alive:
		return false

	if actor.kind == Actor.Kind.PLAYER:
		return _draw_player(actor, at, tint)

	var sprite: Texture2D = textures.get("monster")
	if sprite == null:
		return false
	# Враг тоже стоит на полу: якорь по низу спрайта, а не по центру
	var size := sprite.get_size()
	draw_texture(sprite, at - Vector2(size.x * 0.5, size.y), tint)
	return true


## Персонаж послойно, с позой. Порядок от заднего к переднему задан
## в art/player_layers.json и менять его нельзя: руки обязаны лежать поверх
## корпуса, но под головой.
func _draw_player(actor: Actor, at: Vector2, tint: Color) -> bool:
	var body: Texture2D = textures.get("player_body")
	if body == null:
		return false

	var canvas := at - PLAYER_ROOT
	var speed := actor.velocity.length()
	var phase: float = stride_phase.get(actor.id, 0.0)
	var stats := actor.stack.compute()
	var throw := CharacterPose.throw_progress(actor.cooldown, stats.get("fire_rate", 0.0))
	var throw_right := actor.aim.x >= 0.0
	var angles := CharacterPose.arm_angles(phase, speed, throw, throw_right)
	var lifts := CharacterPose.arm_lift(phase, speed, throw, throw_right)

	draw_texture(body, canvas + CharacterPose.body_offset(phase, speed, breath), tint)
	_draw_arm("player_arm_left", canvas, LEFT_SHOULDER, angles[0], lifts[0], tint)
	_draw_arm("player_arm_right", canvas, RIGHT_SHOULDER, angles[1], lifts[1], tint)

	var head: Texture2D = textures.get("player_head")
	if head != null:
		draw_texture(head, canvas + CharacterPose.head_offset(phase, speed, breath), tint)
	return true


## Рука поворачивается вокруг плеча. Холст у всех слоёв общий, поэтому
## смещать текстуру не нужно — достаточно поставить начало координат в
## плечо и нарисовать слой со сдвигом на минус плечо.
func _draw_arm(layer: String, canvas: Vector2, shoulder: Vector2,
		angle: float, lift: float, tint: Color) -> void:
	var texture: Texture2D = textures.get(layer)
	if texture == null:
		return
	var at := canvas + Vector2(0.0, lift)
	if is_zero_approx(angle):
		draw_texture(texture, at, tint)
		return
	draw_set_transform(at + shoulder, angle, Vector2.ONE)
	draw_texture(texture, -shoulder, tint)
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


## Высота спрайта над полом — по ней ставятся полоска здоровья и подпись.
## Заглушка ниже настоящего тела, и без этого подписи прыгали бы, стоит
## положить в art/ новый файл.
func _sprite_height(actor: Actor) -> float:
	if actor.kind == Actor.Kind.PLAYER:
		var head: Texture2D = textures.get("player_body")
		if head != null:
			return PLAYER_ROOT.y - 15.0
	else:
		var sprite: Texture2D = textures.get("monster")
		if sprite != null:
			return sprite.get_size().y
	return BODY.y
