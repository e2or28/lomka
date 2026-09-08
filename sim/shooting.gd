extends RefCounted

const Projectile = preload("res://sim/projectile.gd")
const Arsenal = preload("res://sim/arsenal.gd")

static func charge_duration(stats: Dictionary) -> int:
	return maxi(0, roundi(float(stats.get("charge_time", 0.0)) * 60.0))

static func advance(state, actor, slot, stats: Dictionary, firing: bool) -> void:
	var rate := float(stats.get("fire_rate", 0.0))
	if not firing or slot.downed or actor.weapon_id == "" or rate <= 0.0 \
			or float(stats.get("projectile_speed", 0.0)) <= 0.0 or float(stats.get("range", 0.0)) <= 0.0:
		slot.charge_ticks = 0
		return
	if actor.cooldown > 0.0:
		return
	var duration := charge_duration(stats)
	if duration > 0:
		slot.charge_ticks += 1
		if slot.charge_ticks < duration: return
	slot.charge_ticks = 0
	state.projectiles.append(Projectile.spawn(state.take_id(), actor, actor.aim, stats, Arsenal.projectile_of(actor)))
	if float(stats.get("rear_shots", 0.0)) > 0:
		state.projectiles.append(Projectile.spawn(state.take_id(), actor, -actor.aim, stats, Arsenal.projectile_of(actor)))
	actor.cooldown = 1.0 / rate
