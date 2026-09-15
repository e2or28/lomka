extends RefCounted

const Guard = preload("res://game/guard_art.gd")
const Blast = preload("res://game/barrel_blast.gd")
const FALL_TIME := 0.72
const EFFECT_TIME := 2.1
const HUB := Vector2(280, 32)
var ages := {}
var _alive := {}
var _phases := {}
var _hover := {}

func clear() -> void:
	ages.clear()
	_alive.clear()
	_phases.clear()
	_hover.clear()

func advance(actors: Array, delta: float) -> void:
	var present := {}
	for actor in actors:
		if actor.behaviour != "gunship": continue
		present[actor.id] = true
		var age := float(ages.get(actor.id, 0.0))
		if actor.alive:
			ages.erase(actor.id)
			_hover[actor.id] = float(_hover.get(actor.id, 0.0)) + delta
		else:
			age = minf(EFFECT_TIME, age + delta) if ages.has(actor.id) else (0.0 if _alive.get(actor.id, false) else EFFECT_TIME)
			ages[actor.id] = age
		var speed := 35.0 if actor.alive else 35.0 * (1.0 - smoothstep(0.0, FALL_TIME, age))
		_phases[actor.id] = fposmod(float(_phases.get(actor.id, 0.0)) + delta * speed, TAU)
		_alive[actor.id] = actor.alive
	for id in _alive.keys():
		if not present.has(id):
			_alive.erase(id)
			ages.erase(id)
			_phases.erase(id)
			_hover.erase(id)

static func flight_offset(age: float, hover: float) -> Vector2:
	var progress := clampf(age / FALL_TIME, 0.0, 1.0)
	return Vector2(sin(progress * PI) * 13.0, sin(hover * 2.7) * 3.0 * (1.0 - progress) - (1.0 - progress * progress) * 36.0)

func draw(view: Node2D, textures: Dictionary, actor, at: Vector2, tint: Color, squad: int) -> bool:
	var texture: Texture2D = textures.get("helicopter")
	var wreck: Texture2D = textures.get("helicopter_wreck")
	if texture == null or wreck == null: return false
	var age := -1.0 if actor.alive else float(ages.get(actor.id, EFFECT_TIME))
	var phase := float(_phases.get(actor.id, 0.0))
	var side := float(actor.facing)
	var hover := float(_hover.get(actor.id, 0.0))
	if age < FALL_TIME:
		var offset := flight_offset(maxf(0.0, age), hover)
		var roll := smoothstep(0.0, FALL_TIME, age) * 0.18
		view.draw_set_transform(at + offset, roll * side, Vector2(side, 1))
		var root := Vector2(texture.get_width() * 0.5, texture.get_height())
		# Блик вращающегося диска отделён от корпуса; втулка остаётся на месте.
		var cut := 162.0 if age >= 0.24 else 0.0
		var body := Rect2(cut, 47, texture.get_width() - cut, texture.get_height() - 47)
		view.draw_texture_rect_region(texture, Rect2(body.position - root, body.size), body, tint)
		var tail := Rect2(0, 0, 72, 47)
		if age < 0.24: view.draw_texture_rect_region(texture, Rect2(tail.position - root, tail.size), tail, tint)
		var hub := Rect2(263, 29, 37, 18)
		view.draw_texture_rect_region(texture, Rect2(hub.position - root, hub.size), hub, tint)
		rotor(view, HUB - root, phase, Vector2(184, 22), tint)
		if age < 0.24: rotor(view, Vector2(31, 56) - root, phase * 1.7, Vector2(26, 31), tint)
		view.draw_set_transform(Vector2.ZERO)
		if actor.alive and squad > 0: Guard.cabin(view, textures, at + offset, side, tint, squad)
	else:
		var settle := (1.0 - smoothstep(FALL_TIME, FALL_TIME + 0.22, age)) * sin((age - FALL_TIME) * 35.0) * 3.0
		view.draw_set_transform(at + Vector2(0, settle), 0, Vector2(side, 1))
		view.draw_texture(wreck, -Vector2(wreck.get_width() * 0.5, wreck.get_height()), tint)
		view.draw_set_transform(Vector2.ZERO)
	if age >= 0.24 and age < EFFECT_TIME:
		fragments(view, texture, at, side, hover, age, tint)
	if age >= 0.0 and age < EFFECT_TIME:
		# Дым сопровождает падение, удар скрывает смену силуэта на обломки.
		if age >= FALL_TIME - 0.06:
			Blast.draw(view, at - Vector2(0, 28), age - FALL_TIME + 0.06, 92.0)
		else:
			for i in 5:
				var t := maxf(0.0, age - i * 0.055)
				view.draw_circle(at + Vector2(-i * 13 * side, -70 - t * 42), 6 + t * 17, Color(0.12, 0.11, 0.10, minf(0.55, t * 4) * tint.a))
	return true

static func rotor(view: Node2D, hub: Vector2, phase: float, size: Vector2, tint: Color) -> void:
	var disc := PackedVector2Array()
	for i in 48:
		var angle := TAU * i / 48.0
		disc.append(hub + Vector2(cos(angle), sin(angle)) * size)
	view.draw_colored_polygon(disc, Color(0.30, 0.29, 0.25, 0.10 * tint.a))
	for trail in 3:
		for blade in 4:
			var angle := phase + blade * PI * 0.5 - trail * 0.22
			var a := Vector2(cos(angle), sin(angle)) * size
			var b := Vector2(cos(angle + 0.085), sin(angle + 0.085)) * size
			view.draw_colored_polygon(PackedVector2Array([hub, hub + a, hub + b]), Color(0.30, 0.29, 0.25, (0.72 if trail == 0 else 0.16) * tint.a))
	view.draw_circle(hub, 4, Color(0.12, 0.11, 0.08, tint.a))

const PIECES := [Rect2(0, 18, 162, 143), Rect2(217, 56, 46, 38), Rect2(253, 104, 65, 25), Rect2(305, 137, 38, 22)]

static func fragment_motion(index: int, age: float) -> Vector3:
	var born := 0.24 if index == 0 else FALL_TIME - 0.04
	var t := maxf(0.0, age - born)
	var landed := minf(t, 0.65 if index == 0 else 0.85)
	var x := (-86.0 if index == 0 else (index - 1.5) * 95.0) * landed
	var y := -landed * (48 + index * 18) + landed * landed * 170
	var angle := landed * (-1.2 if index == 0 else (index - 2.0) * 5.2 + 2.1)
	return Vector3(x, y, angle)

static func fragments(view: Node2D, texture: Texture2D, at: Vector2, side: float, hover: float, age: float, tint: Color) -> void:
	var root := Vector2(texture.get_width() * 0.5, texture.get_height())
	for i in PIECES.size():
		var born := 0.24 if i == 0 else FALL_TIME - 0.04
		if age < born: continue
		var region: Rect2 = PIECES[i]
		var motion := fragment_motion(i, age)
		var launch := Transform2D(smoothstep(0, FALL_TIME, born) * 0.18 * side,
			Vector2(side, 1), 0, at + flight_offset(born, hover))
		var local := Transform2D(motion.z, region.get_center() - root + Vector2(motion.x, motion.y))
		var color := Color(tint, tint.a * (1.0 - smoothstep(1.5, EFFECT_TIME, age)))
		view.draw_set_transform_matrix(launch * local)
		if i == 0:
			# Над балкой хвоста в исходнике находится размытый основной винт.
			for part in [Rect2(0, 18, 72, 29), Rect2(0, 47, 162, 114)]:
				view.draw_texture_rect_region(texture, Rect2(part.position - region.get_center(), part.size), part, color)
		else:
			view.draw_texture_rect_region(texture, Rect2(-region.size * 0.5, region.size), region, color)
	view.draw_set_transform(Vector2.ZERO)
