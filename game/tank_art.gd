extends RefCounted

const Miniboss = preload("res://sim/miniboss.gd")
const SIZE := Vector2(440, 245)
const ROOT := Vector2(288, 220)
const MUZZLE := Vector2(8, 157)
const RECOIL_TIME := 0.5
const GRID := 10.0

var _points := PackedVector2Array()
var _uv := PackedVector2Array()
var _triangles := PackedInt32Array()
var _meshes := {}


static func recoil(age: float) -> float:
	if age < 0.0 or age >= RECOIL_TIME:
		return 0.0
	if age < 0.045:
		return smoothstep(0.0, 0.045, age)
	return 1.0 - smoothstep(0.045, RECOIL_TIME, age)


static func deform(point: Vector2, speed: float, time: float,
		windup: float, shot_age: float, alive: bool) -> Vector2:
	if not alive:
		return point
	var suspended := 1.0 - smoothstep(175.0, ROOT.y, point.y)
	var passengers := 1.0 - smoothstep(85.0, 120.0, point.y)
	var moving := smoothstep(0.0, 45.0, speed) if windup < 0.0 else 0.0
	var kick := recoil(shot_age)
	var brace := smoothstep(0.0, 1.0, maxf(0.0, windup))
	if shot_age >= 0.0:
		brace = 1.0 - smoothstep(0.0, RECOIL_TIME, shot_age)
	var offset := Vector2(2.0 * kick, 1.8 * kick + 1.2 * brace)
	var rumble := sin(time * 22.0) * 0.65 + sin(time * 37.0) * 0.25
	offset.y += rumble * moving
	offset *= suspended
	# Пассажиры запаздывают за подвеской; сетка сохраняет стык с башней.
	offset += passengers * Vector2(sin(time * 8.0 - 0.5) * moving * 1.4 + recoil(shot_age - 0.035) * 3.0,
		sin(time * 8.0 - 0.8) * moving * 0.7)
	var barrel := (1.0 - smoothstep(130.0, 185.0, point.x)) * smoothstep(115.0, 135.0, point.y)
	barrel *= 1.0 - smoothstep(167.0, 182.0, point.y)
	offset.x += barrel * kick * 14.0
	return point + offset


func draw(view: Node2D, actor, texture: Texture2D, tint: Color, time: float) -> void:
	if not actor.alive:
		view.draw_texture_rect(texture, Rect2(-ROOT, SIZE), false, tint)
		return
	if _points.is_empty():
		_build_grid()
	var windup := -1.0
	if actor.attack_ticks > 0:
		windup = 1.0 - float(actor.attack_ticks) / Miniboss.WINDUP_TICKS
	var age := Miniboss.RECOVERY - float(actor.cooldown) if actor.cooldown > 0 and windup < 0 else -1.0
	var vertices := PackedVector3Array()
	for point in _points:
		var p := deform(point, actor.velocity.length(), time, windup, age, true) - ROOT
		vertices.append(Vector3(p.x, p.y, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_INDEX] = _triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[actor.id] = mesh
	view.draw_mesh(mesh, texture, Transform2D.IDENTITY, tint)
	if age >= 0.0 and age < 0.09:
		var muzzle := deform(MUZZLE, actor.velocity.length(), time, windup, age, true) - ROOT
		var size := 1.0 - age / 0.09
		view.draw_colored_polygon(PackedVector2Array([muzzle + Vector2(2, -7) * size,
			muzzle + Vector2(-26, -12) * size, muzzle + Vector2(-18, 0) * size,
			muzzle + Vector2(-30, 7) * size, muzzle + Vector2(2, 7) * size]),
			Color(1.0, 0.68, 0.24, tint.a * size))


func clear() -> void:
	_meshes.clear()


func _build_grid() -> void:
	var columns := ceili(SIZE.x / GRID) + 1
	var rows := ceili(SIZE.y / GRID) + 1
	for y in rows:
		for x in columns:
			var point := Vector2(minf(x * GRID, SIZE.x), minf(y * GRID, SIZE.y))
			_points.append(point)
			_uv.append(point / SIZE)
	for y in rows - 1:
		for x in columns - 1:
			var i := y * columns + x
			_triangles.append_array(PackedInt32Array([i, i + 1, i + columns,
				i + 1, i + columns + 1, i + columns]))
