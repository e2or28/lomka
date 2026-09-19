extends RefCounted

const Motion = preload("res://sim/motion.gd")
const Projectile = preload("res://sim/projectile.gd")
const Reinforcements = preload("res://sim/reinforcements.gd")
const ShotGeometry = preload("res://sim/shot_geometry.gd")
const PROFILES := {
	"oil_baron": {"windup": 75, "recovery": 2.4, "distance": 1200.0,
		"kind": "oil_drop", "angles": [-0.44, -0.22, 0.0, 0.22, 0.44]},
	"rifleman": {"windup": 36, "recovery": 1.4, "distance": 360.0,
		"kind": "rifle_bullet", "angles": [0.0]},
	"baton": {"windup": 36, "recovery": 1.1, "distance": 76.0},
	"gunship": {"windup": 54, "recovery": 2.8, "distance": 1000.0,
		"kind": "rocket", "angles": [0.0]},
}
const ROCKET_RADIUS := 12.0

## Вспышка догоревшей ракеты: меньше бочки, урона не наносит — топливо
## кончилось, а не сдетонировала боевая часть.
const ROCKET_BLAST := 90.0
const MELEE_REACH := 90.0
const MELEE_HALF_ANGLE := PI / 3.0

## Целятся в корпус и от дула, а не от опоры: ствол вынесен вбок, и линия
## огня без поправки уходила мимо цели на ширину тела.
const AIM_HEIGHT := 60.0


static func _lead(actor, target, kind: String) -> Vector2:
	var muzzle := ShotGeometry.offset(kind, actor.aim,
		ShotGeometry.side(actor.facing, actor.aim), actor.standing_front)
	var wanted: Vector2 = target.position + Vector2(0, -AIM_HEIGHT) - actor.position - muzzle
	return wanted.normalized() if wanted != Vector2.ZERO else actor.aim


static func drive(state, actor, target, delta: float) -> bool:
	var profile: Dictionary = PROFILES[actor.behaviour]
	# На канате не воюют, у пульта — тоже: и то и другое занимает целиком.
	if Reinforcements.pressing(actor):
		actor.attack_ticks = 0
		actor.velocity = Vector2.ZERO
		return false
	if Reinforcements.riding(actor):
		actor.velocity = Vector2.ZERO
		actor.attack_ticks = 0
		return false
	# Вертушка не бьёт, пока её же десант не спустился: ракета в этот
	# момент летела бы сквозь собственные канаты.
	if actor.behaviour == "gunship" and Reinforcements.summoning(state):
		actor.attack_ticks = 0
		actor.velocity = Motion.step_velocity(actor.velocity, Vector2.ZERO, actor.stack.compute(), delta)
		return false
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
			shot.radius = ROCKET_RADIUS if actor.behaviour == "gunship" \
				else (11.0 if actor.behaviour == "oil_baron" else 5.0)
			state.projectiles.append(shot)
		return false
	var offset: Vector2 = target.position - actor.position
	if offset != Vector2.ZERO:
		actor.aim = offset.normalized()
		if actor.behaviour == "gunship":
			# Вертушка разворачивается только по горизонтали: она смотрит
			# туда, куда летит, а не заваливается носом на цель.
			if absf(offset.x) > 40.0: actor.facing = 1 if offset.x > 0 else -1
		elif actor.behaviour != "oil_baron":
			if absf(offset.x) > 0.001: actor.facing = 1 if offset.x > 0 else -1
			actor.standing_front = absf(offset.y) > absf(offset.x)
	if actor.cooldown <= 0 and offset.length() <= float(profile.distance):
		# Дубинке поправка не нужна: сектор удара считается от опоры к опоре.
		actor.attack_aim = actor.aim if actor.behaviour == "baton" \
			else _lead(actor, target, profile.kind)
		actor.attack_ticks = profile.windup
		actor.velocity = Vector2.ZERO
		return false
	var move := Vector2.ZERO
	if actor.behaviour == "gunship":
		# Держится над целью и своей высоты не бросает: заходит по
		# горизонтали, а по вертикали возвращается к линии парения.
		move = Vector2(signf(offset.x) if absf(offset.x) > 120.0 else 0.0,
			signf(Reinforcements.HOVER_Y - actor.position.y) \
				if absf(Reinforcements.HOVER_Y - actor.position.y) > 12.0 else 0.0)
		if move != Vector2.ZERO: move = move.normalized()
	elif actor.behaviour == "rifleman":
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
