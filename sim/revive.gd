extends RefCounted
## Подъём — непрерывное действие одного помощника. Цель и время входят в сейв.
const Command = preload("res://sim/input/command.gd")
const DURATION_TICKS := 300
const REACH := 75.0
const INVULNERABILITY := 1.5

static func nearest(state, player):
	var found = null
	var distance := REACH * REACH
	for slot in state.slots:
		if not slot.occupied or not slot.downed: continue
		var target = state.actor_of_slot(slot.index)
		if target == null or not target.alive or target.id == player.id: continue
		var squared: float = target.position.distance_squared_to(player.position)
		if squared <= distance:
			distance = squared
			found = target
	return found

static func cancel(slot) -> void:
	slot.revive_target = -1
	slot.revive_ticks = 0

## Фильтруем копии команд: журнал остаётся исходным. E у упавшего имеет
## приоритет над подбором, F и навыком даже у второго помощника.
static func prepare(state, commands: Dictionary) -> Dictionary:
	var filtered := commands.duplicate()
	var claimed := {}
	# Сначала сохраняем действующих помощников: номер слота новичка не
	# должен отнимать уже накопленные секунды у того, кто начал раньше.
	for slot in state.slots:
		if slot.revive_target < 0: continue
		var player = state.actor_of_slot(slot.index)
		var target = state.actor_by_id(slot.revive_target)
		if not _can_help(slot, player, commands.get(slot.index)) or not _valid_target(state, player, target) \
				or claimed.has(slot.revive_target):
			cancel(slot)
			continue
		claimed[slot.revive_target] = slot.index
	for slot in state.slots:
		var player = state.actor_of_slot(slot.index)
		var command = commands.get(slot.index)
		if not _can_help(slot, player, command):
			cancel(slot)
			continue
		var target = state.actor_by_id(slot.revive_target) if slot.revive_target >= 0 else nearest(state, player)
		if target == null:
			cancel(slot)
			continue
		var copy = Command.from_dict(command.to_dict())
		copy.buttons &= ~(Command.BTN_SKILL | Command.BTN_HARVEST)
		filtered[slot.index] = copy
		# Подбор проверяет фронт E; занятое действие этот фронт съедает.
		slot.interact_held = true
		slot.harvest_target = -1
		slot.harvest_ticks = 0
		slot.charge_ticks = 0
		player.velocity = Vector2.ZERO
		if claimed.has(target.id) and claimed[target.id] != slot.index:
			cancel(slot)
			continue
		claimed[target.id] = slot.index
		if slot.revive_target != target.id:
			cancel(slot)
			slot.revive_target = target.id
	return filtered

static func _can_help(slot, player, command) -> bool:
	return slot.occupied and not slot.downed and player != null and player.alive and command != null \
		and command.pressed(Command.BTN_INTERACT) and command.move_vector() == Vector2.ZERO \
		and not command.pressed(Command.BTN_FIRE)

static func _valid_target(state, player, target) -> bool:
	return player != null and target != null and target.alive and target.slot >= 0 \
		and state.slots[target.slot].occupied and state.slots[target.slot].downed \
		and player.position.distance_to(target.position) <= REACH

## После урона: упавший в этом тике помощник не успевает поднять товарища.
static func advance(state, events: Array[Dictionary]) -> void:
	for slot in state.slots:
		if slot.revive_target < 0: continue
		var player = state.actor_of_slot(slot.index)
		var target = state.actor_by_id(slot.revive_target)
		if slot.downed or player == null or not player.alive or target == null or not target.alive \
				or target.slot < 0 or not state.slots[target.slot].downed \
				or player.position.distance_to(target.position) > REACH:
			cancel(slot)
			continue
		slot.revive_ticks += 1
		if slot.revive_ticks < DURATION_TICKS: continue
		state.slots[target.slot].downed = false
		target.health = target.max_health() * 0.3
		target.invulnerable = INVULNERABILITY
		target.velocity = Vector2.ZERO
		events.append({"type": "revived", "actor_id": target.id, "helper_id": player.id,
			"position": target.position})
		cancel(slot)
