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
var _travel := {}
# Координаты измерены на исходном рисунке в холсте SIZE. Колёса скрыты
# бронёй сверху, поэтому вращаем только внутренний диск, сохраняя обод.
const WHEELS := [Vector3(83, 218, 10), Vector3(119, 220, 10),
	Vector3(206, 222, 12), Vector3(239, 222, 12), Vector3(269, 221, 12),
	Vector3(298, 220, 12), Vector3(328, 218, 12), Vector3(358, 217, 12),
	Vector3(386, 214, 11), Vector3(414, 198, 9)]
const TRACK := [Vector2(125, 197), Vector2(128, 211), Vector2(145, 226),
	Vector2(188, 240), Vector2(370, 234), Vector2(409, 222), Vector2(426, 201)]
const FAR_TRACK := [Vector2(26, 195), Vector2(31, 208), Vector2(45, 222),
	Vector2(69, 232), Vector2(133, 232)]


func advance(actors: Array) -> void:
	var present := {}
	for actor in actors:
		if actor.behaviour != "tank": continue
		present[actor.id] = true
		var old: Dictionary = _travel.get(actor.id, {"position": actor.position, "distance": 0.0})
		var displacement: Vector2 = actor.position - old.position
		var distance: float = old.distance
		if actor.alive and displacement.length() < 180.0:
			var side := -1.0 if actor.aim.x > 0.0 else 1.0
			var direction := -signf(displacement.x * side) if absf(displacement.x) > 0.001 else 1.0
			distance += displacement.length() * direction
		_travel[actor.id] = {"position": actor.position, "distance": distance}
	for id in _travel.keys():
		if not present.has(id):
			_travel.erase(id)
			_meshes.erase(id)


func track_distance(id: int) -> float:
	return float(_travel.get(id, {}).get("distance", 0.0))


static func wheel_uv(point: Vector2, center: Vector2, distance: float) -> Vector2:
	return center + (point - center).rotated(-distance / 12.0)


func _draw_tracks(view: Node2D, actor, texture: Texture2D, tint: Color) -> void:
	var distance := track_distance(actor.id)
	for wheel in WHEELS:
		var center := Vector2(wheel.x, wheel.y)
		var points := PackedVector2Array()
		var uv := PackedVector2Array()
		for i in 24:
			var p: Vector2 = center + Vector2.RIGHT.rotated(TAU * i / 24.0) * wheel.z
			points.append(p - ROOT)
			uv.append(wheel_uv(p, center, distance) / SIZE)
		view.draw_polygon(points, PackedColorArray([tint]), uv, texture)
	_draw_belt(view, FAR_TRACK, distance, tint, 3.0)
	_draw_belt(view, TRACK, distance, tint, 3.6)


func _draw_belt(view: Node2D, path: Array, distance: float, tint: Color, width: float) -> void:
	var length := 0.0
	var line := PackedVector2Array()
	for point in path: line.append(point - ROOT)
	view.draw_polyline(line, Color(0.105, 0.105, 0.08, tint.a) * Color(tint, 1.0), width + 1.0)
	for segment in path.size() - 1:
		var a: Vector2 = path[segment]
		var b: Vector2 = path[segment + 1]
		var span := a.distance_to(b)
		var along := fposmod(distance - length, 5.0)
		var normal := (b - a).normalized().orthogonal() * width * 0.5
		while along < span:
			var at := a.lerp(b, along / span) - ROOT
			view.draw_line(at - normal, at + normal, Color(0.29, 0.28, 0.20, tint.a) * Color(tint, 1.0), 1.5)
			along += 5.0
		length += span


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
	_draw_tracks(view, actor, texture, tint)
	if age >= 0.0 and age < 0.09:
		var muzzle := deform(MUZZLE, actor.velocity.length(), time, windup, age, true) - ROOT
		var size := 1.0 - age / 0.09
		view.draw_colored_polygon(PackedVector2Array([muzzle + Vector2(2, -7) * size,
			muzzle + Vector2(-26, -12) * size, muzzle + Vector2(-18, 0) * size,
			muzzle + Vector2(-30, 7) * size, muzzle + Vector2(2, 7) * size]),
			Color(1.0, 0.68, 0.24, tint.a * size))


func clear() -> void:
	_meshes.clear()
	_travel.clear()


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
