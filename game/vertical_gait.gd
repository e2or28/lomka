extends RefCounted
## Две вертикальные походки используют собственный анфасный/задний силуэт.
## Стопа опорной ноги остаётся на полу; свободная нога сгибается в колене.
## Фаза приходит от пройденного пути. Модуль ничего не меняет в симуляции.

const CharacterPose = preload("res://game/character_pose.gd")
const ROOT := Vector2(64, 174)
const SIZE := Vector2(128, 192)
const FRONT := "player"
const BACK := "player_back_stand"
const WAIST := 110.0

var _points := PackedVector2Array()
var _uv := PackedVector2Array()
var _indices := PackedInt32Array()
var _meshes: Dictionary = {}


## Возвращает прежний разворот в покое, чтобы после шага вверх не прыгать
## обратно в анфас. Активная стрельба возвращает управление штатной позе:
## её хват и точка выпуска уже согласованы с баллистикой.
static func facing(velocity: Vector2, aim: Vector2, previous: String = "") -> String:
	if aim != Vector2.ZERO:
		return ""
	if velocity.length() < CharacterPose.WALK_THRESHOLD:
		return previous
	if absf(velocity.x) >= absf(velocity.y):
		return ""
	return BACK if velocity.y < 0 else FRONT


static func step_lift(phase: float, left: bool) -> float:
	var swing := sin(phase + (0.0 if left else PI))
	return pow(maxf(0.0, swing), 1.2) * 9.0


## Деформация непрерывна на поясе и плечах; ботинок двигается целиком,
## сгибание сосредоточено выше лодыжки. Разные ноги никогда не делят вершины.
static func point(source: Vector2, phase: float, moving: bool, back: bool) -> Vector2:
	if not moving:
		return source
	var p := source
	var sway := sin(phase) * 0.6
	var bob := -absf(sin(phase * 2.0)) * 1.4
	if source.y >= WAIST:
		var leg := smoothstep(WAIST, 161.0, source.y)
		var lift := step_lift(phase, source.x < ROOT.x)
		p.y += lerpf(bob, -lift, leg)
		p.x += sway * (1.0 - leg)
		# При подъёме колено чуть сходится внутрь, стопа не скользит вбок.
		p.x += sin(leg * PI) * lift * (0.13 if source.x < ROOT.x else -0.13)
	else:
		p += Vector2(sway, bob)
	# Руки идут против ног. У предплечья амплитуда больше, у плеча ноль.
	var arm := smoothstep(69.0, 99.0, source.y)
	var outer := smoothstep(15.0, 21.0, absf(source.x - ROOT.x))
	var end := 1.0 - smoothstep(119.0, 124.0, source.y)
	var side := 1.0 if source.x < ROOT.x else -1.0
	var swing := sin(phase) * side * (-1.0 if back else 1.0)
	p.y += swing * 3.5 * arm * outer * end
	p.x += absf(swing) * side * -0.9 * arm * outer * end
	return p


static func hand(phase: float, moving: bool, back: bool) -> Vector2:
	return point(Vector2(85, 113), phase, moving, back)


## at — точка пола, frame — FRONT/BACK. Оружие висит за настоящий хват.
## Для стрельбы вызывающий код использует прежнюю _player_pose/_draw_weapon.
func draw(view: Node2D, textures: Dictionary, actor_id: int, at: Vector2,
		tint: Color, frame: String, phase: float, moving: bool,
		weapon: String = "") -> bool:
	var texture: Texture2D = textures.get(frame)
	if texture == null or frame not in [FRONT, BACK]:
		return false
	_prepare()
	var vertices := PackedVector3Array()
	for source in _points:
		var p := point(source, phase, moving, frame == BACK)
		vertices.append(Vector3(p.x, p.y, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[actor_id] = mesh
	view.draw_set_transform(at - ROOT)
	view.draw_mesh(mesh, texture, Transform2D.IDENTITY, tint)
	var held: Texture2D = textures.get(weapon)
	if held != null:
		var grip := CharacterPose.weapon_offset(weapon, held.get_size(), false)
		var angle := PI * 0.5 if weapon == "colt" else 0.0
		var palm := hand(phase, moving, frame == BACK)
		view.draw_set_transform(at - ROOT + palm, angle)
		view.draw_texture(held, -grip, tint)
		# Пальцы остаются поверх ручки, а не прячутся за оружием.
		view.draw_set_transform(at - ROOT + palm - Vector2(85, 113))
		var fingers := Rect2(83, 113, 4, 4)
		view.draw_texture_rect_region(texture, fingers, fingers, tint)
	view.draw_set_transform(Vector2.ZERO)
	return true


func clear() -> void:
	_meshes.clear()


func _prepare() -> void:
	if not _points.is_empty():
		return
	# Два независимых полухолста: на пустом промежутке между ногами нет
	# растягивающегося треугольника от одной стопы к другой.
	for half in 2:
		var start := _points.size()
		var columns := 33
		var rows := 97
		for y in rows:
			for x in columns:
				var p := Vector2(half * 64 + x * 2, y * 2)
				_points.append(p)
				_uv.append(p / SIZE)
		for y in rows - 1:
			for x in columns - 1:
				var i := start + y * columns + x
				_indices.append_array(PackedInt32Array([i, i + 1, i + columns,
					i + 1, i + columns + 1, i + columns]))
