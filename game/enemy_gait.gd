extends RefCounted
## Походки исходных трёх врагов. Фаза зависит от пути, а не от часов:
## при упоре в стену ноги останавливаются вместе с телом.

const SpriteMesh = preload("res://game/sprite_mesh.gd")
const TYPES := ["test_monster", "runner", "heavy"]
var _motion := {}
var _surfaces := {}
var _last_tick := -1
var _elapsed := 0.0

static func stride_length(kind: String) -> float:
	return 74.0 if kind == "runner" else (88.0 if kind == "heavy" else 64.0)

func advance(actors: Array, delta: float, tick: int = -1) -> void:
	_elapsed += delta
	# Экран может рисоваться чаще 60 Гц: между тиками поза не сбрасывается.
	if tick >= 0 and tick == _last_tick: return
	_last_tick = tick
	delta = _elapsed
	_elapsed = 0.0
	var present := {}
	for actor in actors:
		if actor.archetype not in TYPES: continue
		present[actor.id] = true
		var previous: Dictionary = _motion.get(actor.id, {"position": actor.position, "phase": 0.0})
		var distance: float = actor.position.distance_to(previous.position)
		# Смена комнаты сбрасывается WorldView; телепорт в отладке тоже не шаг.
		var moving: bool = actor.alive and distance > 0.001 and distance < 180.0 and delta > 0.0
		var next: float = previous.phase
		if moving: next = fposmod(next + distance / stride_length(actor.archetype) * TAU, TAU)
		_motion[actor.id] = {"position": actor.position, "phase": next,
			"amount": clampf(distance / maxf(delta, 0.0001) / 40.0, 0.0, 1.0) if moving else 0.0}
	for id in _motion.keys():
		if not present.has(id):
			_motion.erase(id)
			_surfaces.erase(id)

func phase(id: int) -> float:
	return float(_motion.get(id, {}).get("phase", 0.0))

func amount(id: int) -> float:
	return float(_motion.get(id, {}).get("amount", 0.0))

static func deform(p: Vector2, size: Vector2, kind: String, step: float, strength: float) -> Vector2:
	if strength <= 0.0: return p
	var runner := kind == "runner"
	var heavy := kind == "heavy"
	var waist := size.y * (0.67 if heavy else 0.57)
	var result := p
	var swing := sin(step + (0.0 if p.x < size.x * 0.52 else PI))
	if p.y >= waist:
		var leg := smoothstep(waist, size.y * 0.96, p.y)
		result.y -= pow(maxf(0.0, swing), 1.5) * (7.0 if runner else (2.5 if heavy else 3.6)) * leg * strength
		result.x += cos(step + (0.0 if p.x < size.x * 0.52 else PI)) * (4.0 if runner else 2.0) * leg * strength
	else:
		var upper := 1.0 - smoothstep(size.y * 0.2, waist, p.y)
		# Бегун подан вперёд, начальник переносит вес, служащий держит спину.
		result.x += (3.0 * upper if runner else sin(step) * (2.0 if heavy else 0.55)) * strength
		result.y -= absf(sin(step)) * (1.7 if runner else (0.7 if heavy else 0.6)) * strength
	return result

func draw(view: Node2D, actor, texture: Texture2D, tint: Color) -> void:
	var size := texture.get_size()
	var root := Vector2(size.x * 0.5, size.y)
	var strength := amount(actor.id) if actor.alive else 0.0
	if strength <= 0.0:
		view.draw_texture(texture, -root, tint)
		return
	var surface: SpriteMesh = _surfaces.get(actor.id)
	if surface == null:
		surface = SpriteMesh.new()
		_surfaces[actor.id] = surface
	surface.prepare(size, 3.0)
	var vertices := PackedVector2Array()
	for p in surface.points:
		vertices.append(deform(p, size, actor.archetype, phase(actor.id), strength) - root)
	surface.draw(view, texture, vertices, tint)

func clear() -> void:
	_last_tick = -1
	_elapsed = 0.0
	_motion.clear()
	_surfaces.clear()
