extends RefCounted
const RoomArt = preload("res://game/room_art.gd")
const Attacks = preload("res://sim/guard_attacks.gd")

static func lamp_dim(time: float) -> float:
	var phase := fposmod(time + 6.0, 11.0)
	if phase < 0.075: return 0.65 * sin(phase / 0.075 * PI)
	if phase > 0.16 and phase < 0.23: return 0.4 * sin((phase - 0.16) / 0.07 * PI)
	return 0.0

static func draw_lamp(view: Node2D, room, size: Vector2, origin: Vector2, time: float) -> void:
	if room.id != "oil_baron": return
	# Светящаяся область в room_oil_baron: x=316..352, y=52..58;
	# верхняя стена растягивается с 140 до 210 пикселей.
	var corner := RoomArt.image_rect(room, size).position + origin
	var dim := lamp_dim(time)
	var rect := Rect2(corner + Vector2(315, 76.5), Vector2(39, 13.5))
	if dim > 0.0: view.draw_rect(rect, Color(0.10, 0.075, 0.025, dim))
	var glow := 1.0 - dim
	for i in 3:
		view.draw_rect(rect.grow(1 + i * 2), Color(1.0, 0.75, 0.3, glow * 0.012))

static func dust_age(actor) -> float:
	if not actor.alive or actor.behaviour != "oil_baron" or actor.attack_ticks > 0 or actor.cooldown <= 0.0:
		return -1.0
	var age := float(Attacks.PROFILES.oil_baron.recovery) - float(actor.cooldown)
	return age if age >= 0.0 and age < 0.65 else -1.0

static func draw_dust(view: Node2D, actor, at: Vector2) -> void:
	var age := dust_age(actor)
	if age < 0.0: return
	var progress := age / 0.65
	var fade := sin(progress * PI) * 0.28
	for side in [-1, 1]:
		var foot := at + Vector2(side * 176, -4)
		for i in 5:
			var p := foot + Vector2(side * (i * 5 + progress * 18), -sin(progress * PI) * (4 + i * 2))
			view.draw_circle(p, 2.0 + progress * (2 + i), Color(0.66, 0.53, 0.32, fade * (1.0 - i * 0.12)))
