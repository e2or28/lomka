extends RefCounted
## Две вертикальные походки используют собственный анфасный/задний силуэт.
## Стопа опорной ноги остаётся на полу; свободная нога сгибается в колене.
## Фаза приходит от пройденного пути. Модуль ничего не меняет в симуляции.

const SpriteMesh = preload("res://game/sprite_mesh.gd")
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
var _shoot_parts := {}
var _shoot_arms := {}


static func facing(velocity: Vector2, aim: Vector2, previous: String = "") -> String:
	if aim != Vector2.ZERO:
		if absf(aim.y) <= absf(aim.x): return ""
		return BACK if aim.y < 0 else FRONT
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


func draw(view: Node2D, textures: Dictionary, actor_id: int, at: Vector2,
		tint: Color, frame: String, phase: float, moving: bool,
		weapon: String = "", aim_hand: Vector2 = Vector2.INF) -> bool:
	var texture: Texture2D = textures.get(frame)
	if texture == null or frame not in [FRONT, BACK]:
		return false
	_prepare()
	var shooting := aim_hand != Vector2.INF
	var mirrored := shooting and aim_hand.x < ROOT.x
	var body_texture := texture
	if shooting:
		var key := texture.get_instance_id()
		if not _shoot_parts.has(key): _shoot_parts[key] = shoot_layers(texture)
		body_texture = _shoot_parts[key].body
	var vertices := PackedVector3Array()
	for source in _points:
		var p := point(source, phase, moving, frame == BACK)
		if mirrored: p.x = SIZE.x - p.x
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
	view.draw_mesh(mesh, body_texture, Transform2D.IDENTITY, tint)
	if shooting:
		var key := texture.get_instance_id()
		if not _shoot_arms.has(actor_id): _shoot_arms[actor_id] = SpriteMesh.new()
		var surface = _shoot_arms[actor_id]
		surface.prepare(Vector2(20, 56), 2.0)
		var palm := Vector2(SIZE.x - aim_hand.x, aim_hand.y) if mirrored else aim_hand
		var shoulder := point(Vector2(83, 73), phase, moving, frame == BACK)
		var arm_vertices := PackedVector2Array()
		for p in surface.points:
			var moved := aimed_arm_point(p + Vector2(80, 69), shoulder, palm)
			if mirrored: moved.x = SIZE.x - moved.x
			arm_vertices.append(moved)
		surface.draw(view, _shoot_parts[key].arm, arm_vertices, tint)
	var held: Texture2D = null if shooting else textures.get(weapon)
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
	_shoot_parts.clear()
	_shoot_arms.clear()


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


static func aimed_arm_point(p: Vector2, shoulder: Vector2, palm: Vector2) -> Vector2:
	var delta := palm - shoulder
	var distance := maxf(0.01, delta.length())
	var direction := delta / distance
	var upper := 25.0
	var lower := 18.0
	var along := clampf((distance * distance + upper * upper - lower * lower) / (2 * distance), 0.0, upper)
	var elbow := shoulder + direction * along + direction.orthogonal() * (-1.0 if delta.y < 0.0 else 1.0) * sqrt(maxf(0.0, upper * upper - along * along))
	var upper_angle := (elbow - shoulder).angle() - Vector2(1, 25).angle()
	var lower_angle := (palm - elbow).angle() - Vector2(1, 14).angle()
	var first := shoulder + (p - Vector2(83, 73)).rotated(upper_angle)
	var second := palm + (p - Vector2(85, 112)).rotated(lower_angle)
	return first.lerp(second, smoothstep(91.0, 103.0, p.y))


static func shoot_layers(texture: Texture2D) -> Dictionary:
	var original := texture.get_image()
	var body := original.duplicate() as Image
	var arm := Image.create_empty(20, 56, false, Image.FORMAT_RGBA8)
	for y in range(69, 125):
		for x in range(80, 100):
			arm.set_pixel(x - 80, y - 69, original.get_pixel(x, y))
			body.set_pixel(x, y, Color.TRANSPARENT)
	return {"body": ImageTexture.create_from_image(body), "arm": ImageTexture.create_from_image(arm)}
