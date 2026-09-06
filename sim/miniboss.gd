extends RefCounted

const Motion = preload("res://sim/motion.gd")
const Projectile = preload("res://sim/projectile.gd")

const WINDUP_TICKS := 54
const RECOVERY := 1.8
const STANDOFF := 320.0


static func drive(state, tank, target, delta: float) -> void:
	if target == null:
		tank.attack_ticks = 0
		tank.velocity = Vector2.ZERO
		return
	if tank.attack_ticks > 0:
		tank.velocity = Vector2.ZERO
		tank.attack_ticks -= 1
		if tank.attack_ticks == 0:
			var shot: Projectile = Projectile.spawn(state.take_id(), tank,
				tank.attack_aim, tank.stack.compute(), "tank_shell")
			shot.radius = 12.0
			shot.position += tank.attack_aim * (tank.radius + 12.0)
			state.projectiles.append(shot)
			tank.cooldown = RECOVERY
		return
	var offset: Vector2 = target.position - tank.position
	if offset != Vector2.ZERO:
		tank.aim = offset.normalized()
	if tank.cooldown <= 0.0:
		tank.attack_aim = tank.aim
		tank.attack_ticks = WINDUP_TICKS
		tank.velocity = Vector2.ZERO
		return
	var move := Vector2.ZERO
	if offset.length() > STANDOFF:
		move = offset.normalized()
	tank.velocity = Motion.step_velocity(tank.velocity, move, tank.stack.compute(), delta)
