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

const BODY := Vector2(24, 28)
const PROJECTILE := Vector2(14, 11)

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

	var sprite: Texture2D = textures.get("player" if is_player else "monster")
	if sprite != null and actor.alive:
		var size := sprite.get_size()
		draw_texture_rect(sprite, Rect2(at - size * 0.5, size), false,
			Color.WHITE if not downed else Color(0.55, 0.55, 0.6))
	else:
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
		draw_line(at, at + actor.aim.normalized() * 26.0, Color(1, 1, 1, 0.4), 2.0)

	if actor.invulnerable > 0.0:
		draw_arc(at, 20.0, 0, TAU, 20, Color(1, 1, 1, 0.35), 1.5)

	if is_player:
		draw_string(ThemeDB.fallback_font, at + Vector2(-6, -BODY.y * 0.5 - 14),
			"p%d" % (actor.slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))


func _draw_health(actor: Actor, at: Vector2, color: Color) -> void:
	var maximum: float = actor.max_health()
	if maximum <= 0.0:
		return
	var width := 28.0
	var top := at + Vector2(-width * 0.5, -BODY.y * 0.5 - 8)
	draw_rect(Rect2(top, Vector2(width, 3)), Color(0, 0, 0, 0.6), true)
	var share := clampf(actor.health / maximum, 0.0, 1.0)
	draw_rect(Rect2(top, Vector2(width * share, 3)), color.lightened(0.2), true)
