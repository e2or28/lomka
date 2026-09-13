extends RefCounted

const Abilities = preload("res://sim/abilities.gd")
var covers := {}
var debris: Array[Dictionary] = []
var _seen := {}

func clear() -> void:
	covers.clear()
	debris.clear()
	_seen.clear()

func advance(state, delta: float) -> void:
	for piece in debris: piece.age += delta
	debris = debris.filter(func(p): return p.age < 0.8)
	var present := {}
	for slot in state.slots:
		present[slot.index] = true
		var actor = state.actor_of_slot(slot.index)
		var old: Dictionary = covers.get(slot.index, {})
		if slot.cover_ticks > 0:
			if old.is_empty():
				covers[slot.index] = {"age": 0.0 if _seen.has(slot.index) else 1.0,
					"from": actor.position + Vector2(actor.facing * 6, -57) if actor != null else slot.cover_position,
					"at": slot.cover_position, "hit": 1.0, "health": slot.cover_health, "ticks": slot.cover_ticks}
			else:
				old.age += delta
				old.hit = 0.0 if slot.cover_health < old.health else old.hit + delta
				old.health = slot.cover_health
				old.ticks = slot.cover_ticks
		elif not old.is_empty():
			if old.ticks > 6 and not slot.downed and actor != null and actor.alive:
				debris.append({"at": old.at, "age": 0.0})
			covers.erase(slot.index)
		_seen[slot.index] = true
	for id in _seen.keys():
		if not present.has(id):
			_seen.erase(id)
			covers.erase(id)

static func placement(from: Vector2, to: Vector2, age: float) -> Vector2:
	var p := clampf(age / 0.22, 0.0, 1.0)
	var at := from.lerp(to, smoothstep(0.0, 1.0, p))
	at.y -= sin(p * PI) * 20.0
	return at

func draw(view: Node2D, texture: Texture2D, slot, origin: Vector2) -> void:
	var area := Abilities.rect(slot)
	var record: Dictionary = covers.get(slot.index, {"age": 1.0, "from": slot.cover_position, "hit": 1.0})
	var ground: Vector2 = origin + slot.cover_position
	var size := Vector2(maxf(32, area.size.x), maxf(38, area.size.y * 0.6 + 22))
	var at := origin + placement(record.from, slot.cover_position, record.age)
	var kick := sin(float(record.hit) * 48.0) * exp(-float(record.hit) * 22.0)
	var settle := sin(maxf(0.0, float(record.age) - 0.22) * 36.0) * exp(-maxf(0.0, float(record.age) - 0.22) * 16.0)
	if record.age < 0.22: settle = 0.0
	view.draw_set_transform(ground, 0, Vector2(1, area.size.y / maxf(1, area.size.x)))
	view.draw_circle(Vector2.ZERO, area.size.x * 0.55, Color(0, 0, 0, 0.3))
	view.draw_set_transform(at + Vector2(kick * 3, 0), kick * 0.05 + settle * 0.025)
	if texture != null:
		view.draw_texture_rect(texture, Rect2(-size.x * 0.5, -size.y, size.x, size.y), false)
	else:
		view.draw_rect(Rect2(-size.x * 0.5, -size.y, size.x, size.y), Color(0.3, 0.2, 0.12))
	view.draw_set_transform(Vector2.ZERO)
	var health := clampf(slot.cover_health / Abilities.COVER_HEALTH, 0, 1)
	view.draw_rect(Rect2(ground + Vector2(-size.x * 0.5, -size.y - 9), Vector2(size.x, 3)), Color(0.12, 0.1, 0.08))
	view.draw_rect(Rect2(ground + Vector2(-size.x * 0.5, -size.y - 9), Vector2(size.x * health, 3)), Color(0.83, 0.62, 0.35))

func draw_debris(view: Node2D, texture: Texture2D, origin: Vector2) -> void:
	for event in debris:
		var age: float = event.age
		var progress := age / 0.8
		var fade := 1.0 - smoothstep(0.3, 1.0, progress)
		var at: Vector2 = origin + event.at
		for side in [-1, 1]:
			var offset := Vector2(side * progress * 40, -sin(progress * PI) * 27)
			view.draw_set_transform(at + offset, side * progress * 0.9)
			if texture != null:
				var part := Rect2(0 if side < 0 else texture.get_width() * 0.5, 0, texture.get_width() * 0.5, texture.get_height())
				view.draw_texture_rect_region(texture, Rect2(-20, -30, 40, 30), part, Color(1, 1, 1, fade))
		for i in 9:
			var piece := at + Vector2((i - 4) * progress * 15, -sin(progress * PI) * (22 + (i % 3) * 12))
			view.draw_set_transform(piece, progress * (i - 4))
			view.draw_rect(Rect2(-3, -2, 6, 4), Color(0.9, 0.85, 0.7, fade))
		view.draw_set_transform(Vector2.ZERO)
