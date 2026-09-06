extends RefCounted

const RunState = preload("res://sim/run_state.gd")
const Actor = preload("res://sim/actor.gd")
const Pickup = preload("res://sim/pickup.gd")
const Encounter = preload("res://sim/encounter.gd")
const RoomMap = preload("res://sim/room_map.gd")


static func start(seed_text: String, players: int) -> RunState:
	var state := Encounter.dev_room(seed_text, players, 0, RoomMap.make("south"))
	for actor in state.actors:
		actor.position.y -= 220
	state.pickups[0].position = Vector2(100, -100)
	return state


static func advance(state: RunState, commands: Dictionary) -> void:
	if not state.room_cleared() or state.party_down(): return
	for slot in state.slots:
		if not slot.occupied or slot.downed or not commands.has(slot.index): continue
		var actor := state.actor_of_slot(slot.index)
		if actor == null or not actor.alive: continue
		var move: Vector2 = commands[slot.index].move_vector()
		for direction in RoomMap.exits(state.room):
			var outward: Vector2 = RoomMap.DIRECTIONS[direction]
			if move.dot(outward) < 0.5: continue
			var offset: Vector2 = actor.position - RoomMap.door(state.room, direction)
			var across := absf(offset.cross(outward))
			if absf(offset.dot(outward)) <= actor.radius + 3.0 and across <= RoomMap.half_width(direction) - actor.radius:
				_enter(state, direction)
				return


static func _enter(state: RunState, direction: String) -> void:
	var next: String = RoomMap.exits(state.room)[direction]
	var enemies: Array = []
	var pickups: Array = []
	var party: Array[Actor] = []
	for actor in state.actors:
		if actor.kind == Actor.Kind.PLAYER: party.append(actor)
		else: enemies.append(actor.to_dict())
	for pickup in state.pickups: pickups.append(pickup.to_dict())
	state.room_states[state.room.id] = {"actors": enemies, "pickups": pickups}
	state.actors = party.duplicate()
	state.pickups.clear()
	state.projectiles.clear()
	state.room = RoomMap.make(next)
	if state.room_states.has(next):
		for record in state.room_states[next]["actors"]: state.actors.append(Actor.from_dict(record))
		for record in state.room_states[next]["pickups"]: state.pickups.append(Pickup.from_dict(record))
	else:
		var roster: Array = RoomMap.ROSTERS[next]
		for i in roster.size():
			Encounter.add_enemy(state, roster[i], state.room.enemy_spawn(i))
	var arrival: String = RoomMap.OPPOSITE[direction]
	var inward: Vector2 = -RoomMap.DIRECTIONS[arrival]
	var at := RoomMap.door(state.room, arrival)
	for i in party.size():
		var actor := party[i]
		# Вся локальная группа переходит вместе. Запас в глубину исключает обратный переход.
		actor.position = state.room.clamp_body(at + inward * (76 + i * 38), actor.radius)
		actor.velocity = Vector2.ZERO
		actor.attack_ticks = 0
		state.slots[actor.slot].harvest_target = -1
		state.slots[actor.slot].harvest_ticks = 0
