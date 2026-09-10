extends RefCounted

const Attacks = preload("res://sim/guard_attacks.gd")
const ShotGeometry = preload("res://sim/shot_geometry.gd")
const ROOT := Vector2(80, 194)
const HEIGHT := 156.0
const SPRITES := ["oil_baron", "soldier", "soldier_front", "soldier_dark", "soldier_dark_front",
	"ice_agent", "ice_agent_front", "ice_agent_windup", "ice_agent_windup_front"]


static func handles(actor) -> bool:
	return Attacks.PROFILES.has(actor.behaviour)


static func frame(actor) -> String:
	var name: String = actor.archetype
	if actor.behaviour == "oil_baron": return name
	if actor.alive and actor.behaviour == "baton" and (actor.attack_ticks > 0 or actor.cooldown > 0.98):
		name += "_windup"
	if actor.standing_front: name += "_front"
	return name


static func root_for(actor, size: Vector2) -> Vector2:
	return Vector2(size.x * 0.5, size.y) if actor.behaviour == "oil_baron" else ROOT


static func draw(view: Node2D, textures: Dictionary, actor, at: Vector2, tint: Color) -> bool:
	var sprite: Texture2D = textures.get(frame(actor))
	if sprite == null: return false
	var side: float = 1.0 if actor.standing_front or actor.behaviour == "oil_baron" else float(actor.facing)
	if not actor.alive: tint *= Color(0.48, 0.43, 0.39)
	view.draw_set_transform(at, 0.0, Vector2(side, 1))
	view.draw_texture(sprite, -root_for(actor, sprite.get_size()), tint)
	view.draw_set_transform(Vector2.ZERO)
	return true


static func warning(view: Node2D, actor, origin: Vector2) -> void:
	if actor.attack_ticks <= 0: return
	var profile: Dictionary = Attacks.PROFILES[actor.behaviour]
	var strength := 1.0 - float(actor.attack_ticks) / float(profile.windup)
	var at: Vector2 = origin + actor.position
	var color := Color(1.0, 0.58, 0.19, 0.35 + strength * 0.5)
	if actor.behaviour == "baton":
		var center: float = actor.attack_aim.angle()
		var points := PackedVector2Array([at])
		for i in 21:
			points.append(at + Vector2.RIGHT.rotated(center - Attacks.MELEE_HALF_ANGLE \
				+ 2 * Attacks.MELEE_HALF_ANGLE * i / 20.0) * Attacks.MELEE_REACH)
		view.draw_colored_polygon(points, Color(color, 0.10 + strength * 0.10))
		view.draw_arc(at, Attacks.MELEE_REACH, center - Attacks.MELEE_HALF_ANGLE,
			center + Attacks.MELEE_HALF_ANGLE, 24, color, 2)
	else:
		var reach := float(actor.stack.compute().get("range", 850.0))
		var from := at + ShotGeometry.offset(profile.kind, actor.attack_aim, actor.facing, actor.standing_front)
		for angle in profile.angles:
			var direction: Vector2 = actor.attack_aim.rotated(angle)
			view.draw_dashed_line(from, from + direction * reach, color, 1.5, 13)
	view.draw_arc(at, actor.radius + 7, -PI / 2, -PI / 2 + TAU * strength, 32, color, 3)
