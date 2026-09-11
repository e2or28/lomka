extends RefCounted

const SpriteMesh = preload("res://game/sprite_mesh.gd")
const Attacks = preload("res://sim/guard_attacks.gd")
const PIVOT := Vector2(189, 104)
const SIZE := Vector2(382, 330)
var surface := SpriteMesh.new()

static func pump_angle(time: float, windup: float, age: float) -> float:
	if windup >= 0.0: return lerpf(-0.035, 0.085, smoothstep(0.0, 0.85, windup))
	if age >= 0.0 and age < 0.65:
		if age < 0.12: return lerpf(0.085, -0.07, smoothstep(0.0, 0.12, age))
		return lerpf(-0.07, sin(time * TAU / 3.2) * 0.045, smoothstep(0.12, 0.65, age))
	return sin(time * TAU / 3.2) * 0.045

static func deform(p: Vector2, time: float, windup: float, age: float) -> Vector2:
	var angle := pump_angle(time, windup, age)
	var beam := 1.0 - smoothstep(110.0, 157.0, p.y)
	var delta := (p - PIVOT).rotated(angle) - (p - PIVOT)
	var result := p + delta * beam
	var rod := smoothstep(338.0, 352.0, p.x) * smoothstep(142.0, 162.0, p.y)
	rod *= 1.0 - smoothstep(288.0, 323.0, p.y)
	result.y += sin(angle) * 170.0 * rod
	var linkage := (1.0 - smoothstep(82.0, 105.0, p.x)) * smoothstep(145.0, 175.0, p.y)
	linkage *= 1.0 - smoothstep(266.0, 292.0, p.y)
	result += Vector2(sin(time * TAU / 3.2) * 2.0, -sin(angle) * 70.0) * linkage
	return result

func draw(view: Node2D, actor, texture: Texture2D, at: Vector2, tint: Color, time: float, hit: float = 0.0) -> void:
	var windup := -1.0
	if actor.attack_ticks > 0: windup = 1.0 - float(actor.attack_ticks) / float(Attacks.PROFILES.oil_baron.windup)
	var age := float(Attacks.PROFILES.oil_baron.recovery) - float(actor.cooldown) if actor.cooldown > 0 and windup < 0 else -1.0
	surface.prepare(texture.get_size())
	var vertices := PackedVector2Array()
	var root := Vector2(texture.get_width() * 0.5, texture.get_height())
	for p in surface.points:
		vertices.append((deform(p, time, windup, age) + detail_offset(p, time, hit) if actor.alive else p) - root)
	view.draw_set_transform(at)
	surface.draw(view, texture, vertices, tint if actor.alive else tint * Color(0.48, 0.43, 0.39))
	view.draw_set_transform(Vector2.ZERO)

static func detail_offset(p: Vector2, time: float, hit: float) -> Vector2:
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
	return offset
