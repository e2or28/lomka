extends "res://tests/framework/test_case.gd"
## Поведение: подъём требует пяти непрерывных секунд и переживает сейв.
const Arena = preload("res://tests/framework/arena.gd")
const Command = preload("res://sim/input/command.gd")
const Tick = preload("res://sim/tick.gd")
const Save = preload("res://sim/save/save_game.gd")

func title() -> String:
	return "подъём товарища"

func _party():
	var state = Arena.room("revive", 3, 0)
	state.actor_of_slot(0).position = Vector2.ZERO
	state.actor_of_slot(1).position = Vector2(40, 0)
	state.actor_of_slot(2).position = Vector2(-40, 0)
	state.slots[1].downed = true
	state.actor_of_slot(1).health = 0
	return state

func _test_completion_and_save() -> bool:
	var state = _party()
	Arena.hold(state, 150, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	eq(state.slots[0].revive_ticks, 150, "нет прогресса подъёма")
	var restored = Arena.after_save(state)
	bytes_eq(Save.to_bytes(state), Save.to_bytes(restored), "прогресс потерян в сейве")
	Arena.hold(restored, 149, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	check(restored.slots[1].downed, "подняли раньше пяти секунд")
	Arena.hold(restored, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	check(not restored.slots[1].downed, "не подняли")
	almost_eq(restored.actor_of_slot(1).health, restored.actor_of_slot(1).max_health() * 0.3, "не 30% здоровья")
	check(restored.actor_of_slot(1).invulnerable > 0, "нет защиты после подъёма")
	return true

func _test_cancellation_and_exclusive_actions() -> bool:
	for reason in ["release", "move", "fire", "distance", "downed"]:
		var state = _party()
		Arena.hold(state, 12, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
		if reason == "distance": state.actor_of_slot(1).position = Vector2(200, 0)
		if reason == "downed": state.slots[0].downed = true
		Arena.hold(state, 1, Vector2.RIGHT if reason == "move" else Vector2.ZERO,
			Vector2.RIGHT, (0 if reason == "release" else Command.BTN_INTERACT) | (Command.BTN_FIRE if reason == "fire" else 0))
		eq(state.slots[0].revive_ticks, 0, "подъём не отменён: " + reason)
	var state = _party()
	state.pickups[0].position = Vector2.ZERO
	Arena.hold(state, 60, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT | Command.BTN_SKILL | Command.BTN_HARVEST)
	eq(state.actor_of_slot(0).weapon_id, "suitcase", "при подъёме подобрали оружие")
	eq(state.slots[0].cover_ticks, 0, "при подъёме включили навык")
	eq(state.slots[0].harvest_ticks, 0, "при подъёме идёт харвест")
	return true

func _test_helpers_do_not_double_speed() -> bool:
	var state = _party()
	state.actor_of_slot(2).position = Vector2(60, 0)
	for i in 150:
		Tick.step(state, {0: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT),
			2: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)})
	check(state.slots[1].downed, "два помощника ускорили подъём")
	eq(state.slots[0].revive_ticks, 150, "первый помощник не держит цель")
	eq(state.slots[2].revive_ticks, 0, "второй помощник копит параллельно")
	return true

func _test_damage_and_room_transition_cancel() -> bool:
	var state = _party()
	Arena.hold(state, 299, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	var encounter = preload("res://sim/encounter.gd")
	var enemy = encounter.add_enemy(state, "heavy", state.actor_of_slot(0).position)
	enemy.stack.base["damage"] = 1000.0
	Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	check(state.slots[0].downed, "вражеский удар не уронил помощника")
	check(state.slots[1].downed, "упавший помощник завершил подъём")
	eq(state.slots[0].revive_ticks, 0, "урон не отменил подъём")
	var travel = preload("res://sim/room_travel.gd")
	var map = preload("res://sim/room_map.gd")
	state = travel.start("cancel at exit", 3)
	state.slots[1].downed = true
	state.actor_of_slot(1).health = 0
	state.actor_of_slot(1).position = state.actor_of_slot(0).position + Vector2(30, 0)
	Arena.hold(state, 12, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	state.actor_of_slot(2).position = map.door(state.room, "north") + Vector2(0, 18)
	travel.advance(state, {2: Command.from_axes(state.tick, Vector2.UP, Vector2.ZERO)})
	eq(state.room.id, "center", "третий игрок не перевёл группу")
	eq(state.slots[0].revive_target, -1, "переход сохранил старую цель")
	eq(state.slots[0].revive_ticks, 0, "переход сохранил прогресс")
	check(state.slots[1].downed, "переход поднял упавшего")
	return true

func _test_existing_helper_keeps_last_tick_when_earlier_slot_joins() -> bool:
	var state = _party()
	state.actor_of_slot(2).position = Vector2(60, 0)
	for i in 299:
		Tick.step(state, {2: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)})
	eq(state.slots[2].revive_ticks, 299, "поздний слот не начал подъём")
	state = Arena.after_save(state)
	var events = Tick.step(state, {
		0: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT),
		2: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)})
	check(not state.slots[1].downed, "новый помощник сбросил почти законченный подъём")
	var revived := events.filter(func(event): return event.type == "revived")
	eq(revived.size(), 1, "нет единственного события подъёма")
	if not revived.is_empty():
		eq(revived[0].helper_id, state.actor_of_slot(2).id, "подъём забрал новый помощник")
	return true
