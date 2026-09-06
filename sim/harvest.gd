extends RefCounted

const Actor = preload("res://sim/actor.gd")
const Command = preload("res://sim/input/command.gd")
const Organs = preload("res://sim/organs.gd")
const Pickup = preload("res://sim/pickup.gd")

const DURATION_TICKS := 60
const REACH := 40.0


static func nearest(state, player):
	var found = null
	var shortest := INF
	for corpse in state.actors:
		if corpse.kind != Actor.Kind.ENEMY or corpse.alive or corpse.harvested:
			continue
		if corpse.corpse_until_tick >= 0 and state.tick >= corpse.corpse_until_tick:
			continue
		if Organs.organ(corpse.organ_id).is_empty():
			continue
		var reach: float = corpse.radius + player.radius + REACH
		var distance: float = corpse.position.distance_squared_to(player.position)
		if distance <= reach * reach and distance < shortest:
			found = corpse
			shortest = distance
	return found


static func advance(state, commands: Dictionary) -> void:
	for slot in state.slots:
		var command = commands.get(slot.index)
		var held: bool = command != null and command.pressed(Command.BTN_HARVEST)
		if not held:
			slot.harvest_spent = false
		var player = state.actor_of_slot(slot.index)
		if not slot.occupied or slot.downed or player == null or not player.alive \
				or not held or slot.harvest_spent:
			cancel(slot)
			continue
		if command.move_vector() != Vector2.ZERO or command.pressed(Command.BTN_FIRE):
			cancel(slot)
			continue
		var corpse = nearest(state, player)
		if corpse == null:
			cancel(slot)
			continue
		if slot.harvest_target != corpse.id:
			slot.harvest_ticks = 0
			slot.harvest_target = corpse.id
		slot.harvest_ticks += 1
		if slot.harvest_ticks < DURATION_TICKS:
			continue
		var record := Organs.organ(corpse.organ_id)
		var previous: String = slot.organs[record["slot"]]
		if Organs.equip(player, slot, corpse.organ_id):
			corpse.harvested = true
			state.heat += int(record["heat"])
			if previous != "":
				state.pickups.append(Pickup.organ(state.take_id(), previous, player.position))
			slot.harvest_spent = true
		cancel(slot)


static func cancel(slot) -> void:
	slot.harvest_target = -1
	slot.harvest_ticks = 0
