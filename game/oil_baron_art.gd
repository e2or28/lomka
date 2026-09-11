extends RefCounted

const SpriteMesh = preload("res://game/sprite_mesh.gd")
const Attacks = preload("res://sim/guard_attacks.gd")
const PIVOT := Vector2(189, 104)
const SIZE := Vector2(382, 330)
## Станок весом в тонну не встаёт мгновенно: качание гаснет за это время,
## и только к концу кадр сменяется поверженным.
const STALL_TIME := 1.4
var surface := SpriteMesh.new()
var _death: Dictionary = {}
var _seen_alive: Dictionary = {}

static func pump_angle(time: float, windup: float, age: float, sway: float = 1.0) -> float:
	if windup >= 0.0: return lerpf(-0.035, 0.085, smoothstep(0.0, 0.85, windup)) * sway
	if age >= 0.0 and age < 0.65:
		if age < 0.12: return lerpf(0.085, -0.07, smoothstep(0.0, 0.12, age)) * sway
		return lerpf(-0.07, sin(time * TAU / 3.2) * 0.045, smoothstep(0.12, 0.65, age)) * sway
	return sin(time * TAU / 3.2) * 0.045 * sway

static func deform(p: Vector2, time: float, windup: float, age: float, sway: float = 1.0) -> Vector2:
	var angle := pump_angle(time, windup, age, sway)
	var beam := 1.0 - smoothstep(110.0, 157.0, p.y)
	var delta := (p - PIVOT).rotated(angle) - (p - PIVOT)
	var result := p + delta * beam
	var rod := smoothstep(338.0, 352.0, p.x) * smoothstep(142.0, 162.0, p.y)
	rod *= 1.0 - smoothstep(288.0, 323.0, p.y)
	result.y += sin(angle) * 170.0 * rod
	var linkage := (1.0 - smoothstep(82.0, 105.0, p.x)) * smoothstep(145.0, 175.0, p.y)
	linkage *= 1.0 - smoothstep(266.0, 292.0, p.y)
	result += Vector2(sin(time * TAU / 3.2) * 2.0 * sway, -sin(angle) * 70.0) * linkage
	return result

## Остановка играется только при переходе на глазах. Барон, уже лежавший,
## когда в комнату вернулись, так и остаётся лежать: иначе он умирал бы
## заново на каждом входе.
func death_progress(actor, time: float) -> float:
	if actor.alive:
		_seen_alive[actor.id] = true
		_death.erase(actor.id)
		return -1.0
	if not _death.has(actor.id):
		_death[actor.id] = time if bool(_seen_alive.get(actor.id, false)) else time - STALL_TIME
	return clampf((time - float(_death[actor.id])) / STALL_TIME, 0.0, 1.0)


func draw(view: Node2D, actor, texture: Texture2D, at: Vector2, tint: Color, time: float,
		hit: float = 0.0, fallen: Texture2D = null) -> void:
	var windup := -1.0
	if actor.attack_ticks > 0: windup = 1.0 - float(actor.attack_ticks) / float(Attacks.PROFILES.oil_baron.windup)
	var age := float(Attacks.PROFILES.oil_baron.recovery) - float(actor.cooldown) if actor.cooldown > 0 and windup < 0 else -1.0
	var death := death_progress(actor, time)
	var sway := 1.0 if death < 0.0 else 1.0 - smoothstep(0.0, 0.62, death)
	var swap := 0.0 if death < 0.0 else smoothstep(0.45, 1.0, death)
	var root := Vector2(texture.get_width() * 0.5, texture.get_height())
	if swap < 1.0 or fallen == null:
		surface.prepare(texture.get_size())
		var vertices := PackedVector2Array()
		for p in surface.points:
			vertices.append(deform(p, time, windup, age, sway) + detail_offset(p, time, hit, sway) - root)
		view.draw_set_transform(at)
		var alive_tint := tint if death < 0.0 else tint * Color(0.62, 0.56, 0.5, 1.0 - swap)
		surface.draw(view, texture, vertices, alive_tint)
		view.draw_set_transform(Vector2.ZERO)
	# Кадры совпадают рамкой пиксель в пиксель, поэтому подмена проходит
	# перетеканием на месте, а не рывком.
	if swap > 0.0 and fallen != null:
		view.draw_texture(fallen, at - Vector2(fallen.get_width() * 0.5, fallen.get_height()),
			Color(tint, tint.a * swap))


func clear() -> void:
	_death.clear()
	_seen_alive.clear()

static func detail_offset(p: Vector2, time: float, hit: float, sway: float = 1.0) -> Vector2:
	var torso := smoothstep(130.0, 151.0, p.x) * (1.0 - smoothstep(226.0, 246.0, p.x))
	torso *= smoothstep(158.0, 175.0, p.y) * (1.0 - smoothstep(266.0, 286.0, p.y))
	var offset := Vector2(hit * 4.0, -sin(time * TAU / 2.7) * 0.8 + hit * 2.0) * torso
	var flag := maxf(1.0 - absf(p.x - 132.0) / 22.0, 1.0 - absf(p.x - 250.0) / 22.0)
	flag = maxf(0.0, flag) * smoothstep(156.0, 179.0, p.y) * (1.0 - smoothstep(207.0, 224.0, p.y))
	offset.x += sin(time * 3.8 + p.y * 0.10) * 2.0 * flag
	offset.y += sin(time * 3.8 + p.x * 0.08) * 0.7 * flag
	var fingers := maxf(0.0, 1.0 - minf(absf(p.x - 148), absf(p.x - 230)) / 8.0)
	fingers *= maxf(0.0, 1.0 - absf(p.y - 231) / 6.0)
	offset.y -= pow(maxf(0.0, sin(time * 2.0)), 12.0) * 1.4 * fingers
	return offset * sway
