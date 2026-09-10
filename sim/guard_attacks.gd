extends RefCounted

const Motion = preload("res://sim/motion.gd")
const Projectile = preload("res://sim/projectile.gd")
const PROFILES := {
	"oil_baron": {"windup": 75, "recovery": 2.4, "distance": 1200.0,
		"kind": "oil_drop", "angles": [-0.44, -0.22, 0.0, 0.22, 0.44]},
	"rifleman": {"windup": 36, "recovery": 1.4, "distance": 360.0,
		"kind": "rifle_bullet", "angles": [0.0]},
	"baton": {"windup": 36, "recovery": 1.1, "distance": 76.0},
}
const MELEE_REACH := 90.0
const MELEE_HALF_ANGLE := PI / 3.0


static func drive(state, actor, target, delta: float) -> bool:
	var profile: Dictionary = PROFILES[actor.behaviour]
	if target == null:
		actor.attack_ticks = 0
		actor.velocity = Vector2.ZERO
		return false
	if actor.attack_ticks > 0:
		actor.velocity = Vector2.ZERO
		actor.attack_ticks -= 1
		if actor.attack_ticks > 0: return false
		actor.cooldown = profile.recovery
		if actor.behaviour == "baton": return true
		for angle in profile.angles:
			var direction: Vector2 = actor.attack_aim.rotated(angle)
			var shot: Projectile = Projectile.spawn(state.take_id(), actor,
				direction, actor.stack.compute(), profile.kind)
			shot.radius = 11.0 if actor.behaviour == "oil_baron" else 5.0
			state.projectiles.append(shot)
		return false
	var offset: Vector2 = target.position - actor.position
	if offset != Vector2.ZERO:
		actor.aim = offset.normalized()
		if actor.behaviour != "oil_baron":
			if absf(offset.x) > 0.001: actor.facing = 1 if offset.x > 0 else -1
			actor.standing_front = absf(offset.y) > absf(offset.x)
	if actor.cooldown <= 0 and offset.length() <= float(profile.distance):
		actor.attack_aim = actor.aim
		actor.attack_ticks = profile.windup
		actor.velocity = Vector2.ZERO
		return false
	var move := Vector2.ZERO
	if actor.behaviour == "rifleman":
		if offset.length() > 340: move = actor.aim
		elif offset.length() < 210: move = -actor.aim
	elif actor.behaviour == "baton" and actor.cooldown <= 0:
		move = actor.aim
	actor.velocity = Motion.step_velocity(actor.velocity, move, actor.stack.compute(), delta)
	return false


static func in_swing(actor, target) -> bool:
	var offset: Vector2 = target.position - actor.position
	return offset.length() <= MELEE_REACH + target.radius \
		and (offset.is_zero_approx() or offset.normalized().dot(actor.attack_aim) >= cos(MELEE_HALF_ANGLE))
