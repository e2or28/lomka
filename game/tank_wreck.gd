extends RefCounted
const SpriteMesh = preload("res://game/sprite_mesh.gd")
const SIZE := Vector2(440, 245)
const ROOT := Vector2(288, 220)
const COLLAPSE_TIME := 1.1
var ages := {}
var _alive := {}
var _surfaces := {}

func clear() -> void:
	ages.clear()
	_alive.clear()
	_surfaces.clear()

func advance(actors: Array, delta: float) -> void:
	var present := {}
	for actor in actors:
		if actor.behaviour != "tank": continue
		present[actor.id] = true
		if actor.alive:
			ages.erase(actor.id)
		else:
			if not ages.has(actor.id): ages[actor.id] = 0.0 if bool(_alive.get(actor.id, false)) else 3.0
			else: ages[actor.id] = minf(3.0, float(ages[actor.id]) + delta)
		_alive[actor.id] = actor.alive
	for id in _alive.keys():
		if not present.has(id):
			_alive.erase(id)
			ages.erase(id)
			_surfaces.erase(id)

static func deform(p: Vector2, progress: float) -> Vector2:
	var settle := smoothstep(0.0, 1.0, progress)
	var suspended := 1.0 - smoothstep(173.0, 220.0, p.y)
	var point := p + Vector2(sin(progress * TAU * 2.0) * (1.0 - progress) * 3.0, settle * 8.0) * suspended
	var riders := 1.0 - smoothstep(85.0, 115.0, p.y)
	point += Vector2(-8.0, 11.0) * riders * settle
	var barrel := (1.0 - smoothstep(95.0, 145.0, p.x)) * smoothstep(135.0, 148.0, p.y) * (1.0 - smoothstep(168.0, 182.0, p.y))
	point.y += settle * barrel * 9.0
	return point

func draw(view: Node2D, actor, texture: Texture2D, tint: Color) -> void:
	if not _surfaces.has(actor.id): _surfaces[actor.id] = SpriteMesh.new()
	var surface = _surfaces[actor.id]
	surface.prepare(SIZE, 5.0)
	var age := float(ages.get(actor.id, 3.0))
	var progress := clampf(age / COLLAPSE_TIME, 0.0, 1.0)
	var vertices := PackedVector2Array()
	for p in surface.points: vertices.append(deform(p, progress) - ROOT)
	surface.draw(view, texture, vertices, tint)
	if age < 2.5:
		for i in 7:
			var life := maxf(0.0, age - i * 0.07)
			var fade := (1.0 - smoothstep(0.8, 2.5, age)) * smoothstep(0.0, 0.1, life)
			var at := Vector2(240 + (i % 3) * 22, 138) - ROOT + Vector2(sin(i * 2.2) * life * 10, -life * (19 + i * 2))
			view.draw_circle(at, 6 + life * 9, Color(0.12, 0.105, 0.085, fade * 0.4 * tint.a))
