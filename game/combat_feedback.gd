extends RefCounted

const HOLD_AIM := 0.24
const FALL_TIME := 0.32
const MAX_IMPACTS := 96

var shots := {}
var hits := {}
var falls := {}
var impacts: Array[Dictionary] = []


func clear() -> void:
	shots.clear()
	hits.clear()
	falls.clear()
	impacts.clear()


func shot(event: Dictionary, at: Vector2) -> void:
	var record := event.duplicate()
	record["age"] = 0.0
	record["at"] = at
	shots[event.actor_id] = record


func hit(event: Dictionary, at: Vector2) -> void:
	var record := event.duplicate()
	record["age"] = 0.0
	record["at"] = at
	hits[event.actor_id] = record.duplicate()
	if event.fallen:
		falls[event.actor_id] = {"age": 0.0, "direction": event.direction}
	impacts.append(record)
	if impacts.size() > MAX_IMPACTS:
		impacts.pop_front()


func advance(delta: float) -> void:
	for id in shots.keys():
		shots[id].age += delta
		if shots[id].age >= HOLD_AIM:
			shots.erase(id)
	for impact in impacts:
		impact.age += delta
	impacts = impacts.filter(func(e): return e.age < maxf(duration(e.kind), FALL_TIME))
	for fall in falls.values():
		fall.age = minf(FALL_TIME, fall.age + delta)
	for id in hits.keys():
		hits[id].age += delta
		if hits[id].age >= maxf(duration(hits[id].kind), FALL_TIME):
			hits.erase(id)


static func duration(kind: String) -> float:
	return 0.28 if kind == "folder" else (0.16 if kind == "bullet" else 0.23)


static func strength(kind: String, age: float) -> float:
	var progress := clampf(age / duration(kind), 0, 1)
	return sin(progress * PI) * pow(1.0 - progress, 0.6)


func offset(actor_id: int, weight: float = 1.0) -> Vector2:
	if not hits.has(actor_id):
		return Vector2.ZERO
	var h: Dictionary = hits[actor_id]
	var distance := 10.0 if h.kind == "folder" else (4.0 if h.kind == "bullet" else 7.0)
	var direction: Vector2 = h.direction
	if direction == Vector2.ZERO:
		direction = Vector2(0, -1)
	return direction * distance * strength(h.kind, h.age) * weight


func flash(actor_id: int) -> float:
	if not hits.has(actor_id):
		return 0.0
	return pow(maxf(0, 1.0 - float(hits[actor_id].age) / 0.09), 2)


func fall_progress(actor_id: int) -> float:
	if not falls.has(actor_id):
		return 1.0
	return smoothstep(0, FALL_TIME, falls[actor_id].age)


func draw_impacts(view: Node2D, origin: Vector2) -> void:
	for h in impacts:
		var progress := clampf(float(h.age) / duration(h.kind), 0, 1)
		if progress >= 1:
			continue
		var at: Vector2 = origin + h.at
		var color := Color(1, 0.81, 0.42, 1.0 - progress)
		if h.kind == "folder":
			color = Color(0.95, 0.87, 0.68, 1.0 - progress)
		elif h.kind != "bullet":
			color = Color(1, 0.35, 0.29, 1.0 - progress)
		for i in 6:
			var direction := Vector2.RIGHT.rotated(TAU * i / 6.0 + Vector2(h.direction).angle())
			var point := at + direction * (3 + progress * 15)
			if h.kind == "folder":
				view.draw_set_transform(point, progress * (i + 1))
				view.draw_rect(Rect2(-2, -1, 4, 2), color)
				view.draw_set_transform(Vector2.ZERO)
			else:
				view.draw_line(point, point + direction * (5 * (1 - progress)), color, 2)
