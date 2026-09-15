extends RefCounted

const Blob = preload("res://game/oil_drop_art.gd")
const DURATION := 1.65

static func debris(index: int, age: float, radius: float) -> Vector2:
	var angle := index * 2.39996
	var speed := radius * (0.8 + (index % 4) * 0.22)
	var travel := 0.80 * (1.0 - exp(-age * 4.0))
	return Vector2(cos(angle), sin(angle) * 0.5) * speed * travel + Vector2(0, -age * (85 + index % 3 * 30) + age * age * 155)

static func draw(view: Node2D, at: Vector2, age: float, radius: float) -> void:
	if age < 0.0 or age >= DURATION: return
	var fade := 1.0 - smoothstep(0.8, DURATION, age)
	var shock := 1.0 - smoothstep(0.08, 0.38, age)
	var spread := 1.0 - exp(-age * 13.0)
	Blob.blob(view, at + Vector2(0, 6), radius * 0.51, Vector2(1, 0.33), Color(0.055, 0.04, 0.025, fade * 0.5))
	if shock > 0:
		var ring := PackedVector2Array()
		for i in 49:
			var angle := TAU * i / 48.0
			ring.append(at + Vector2(cos(angle), sin(angle) * 0.52) * radius * spread)
		view.draw_polyline(ring, Color(1, 0.76, 0.39, shock * 0.65), 2.5)
	# Разные сроки рождения дают клубам объём; дым поднимается после огня.
	for i in 7:
		var born := i % 3 * 0.018
		var t := maxf(0.0, age - born)
		var angle := i * 2.39996
		var center := at + Vector2(cos(angle) * radius * 0.28 * spread,
			sin(angle) * radius * 0.16 * spread - t * (24 + i % 3 * 12))
		var size := radius * (0.14 + i % 4 * 0.019) * (0.35 + spread * 0.85 + t * 0.35)
		var smoke := smoothstep(0.16, 0.62, t)
		var color := Color(0.96, 0.27, 0.045).lerp(Color(0.27, 0.25, 0.22), smoke)
		lobe(view, center, size, Vector2(1, 1.2 + i % 2 * 0.25), Color(color, fade * 0.88), i, age)
		var fire := 1.0 - smoothstep(0.13, 0.47, t)
		if fire > 0:
			lobe(view, center + Vector2(-size * 0.1, size * 0.2), size * 0.64, Vector2(0.8, 1.12), Color(1, 0.64, 0.12, fire), i + 11, age)
	var flash := 1.0 - smoothstep(0.035, 0.14, age)
	if flash > 0:
		lobe(view, at - Vector2(0, 12), radius * (0.12 + spread * 0.24), Vector2(1, 0.85), Color(1, 0.94, 0.67, flash), 24, age)
	for i in 18:
		var life := age - i % 3 * 0.014
		if life < 0 or life > 0.8: continue
		var point := at + debris(i, life, radius)
		var previous := at + debris(i, maxf(0, life - 0.025), radius)
		var alpha := 1.0 - smoothstep(0.45, 0.8, life)
		if i % 3 == 0:
			view.draw_set_transform(point, life * (8 + i))
			view.draw_rect(Rect2(-3, -2, 6, 4), Color(0.27, 0.20, 0.12, alpha))
			view.draw_set_transform(Vector2.ZERO)
		else:
			view.draw_line(previous, point, Color(1, 0.51 + i % 2 * 0.3, 0.12, alpha), 2)

static func lobe(view: Node2D, center: Vector2, radius: float, stretch: Vector2, color: Color, seed: int, age: float) -> void:
	var points := PackedVector2Array()
	for i in 28:
		var angle := TAU * i / 28.0
		var edge := 0.83 + sin(i * 2.37 + seed * 1.73) * 0.13 + sin(angle * 5 + age * 7 + seed) * 0.08
		var point := center + Vector2(cos(angle), sin(angle)) * stretch * radius * edge
		points.append(Vector2(roundf(point.x / 2) * 2, roundf(point.y / 2) * 2))
	view.draw_colored_polygon(points, color)
