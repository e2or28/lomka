extends RefCounted

const Actor = preload("res://sim/actor.gd")

const LIFETIME_TICKS := 30 * 60
const FADE_TICKS := 3 * 60


static func advance(state) -> void:
	var kept: Array[Actor] = []
	for actor in state.actors:
		if actor.kind == Actor.Kind.ENEMY and not actor.alive:
			if actor.corpse_until_tick < 0:
				actor.corpse_until_tick = state.tick + LIFETIME_TICKS
			for slot in state.slots:
				if slot.harvest_target == actor.id and slot.harvest_ticks > 0:
					actor.corpse_until_tick = maxi(actor.corpse_until_tick, state.tick + FADE_TICKS)
			if state.tick >= actor.corpse_until_tick:
				continue
		kept.append(actor)
	state.actors = kept


static func opacity(actor, tick: int) -> float:
	if actor.alive or actor.corpse_until_tick < 0:
		return 1.0
	return clampf(float(actor.corpse_until_tick - tick) / FADE_TICKS, 0.0, 1.0)
