extends "res://tests/framework/test_case.gd"
## Поведение: воспроизводимые безопасные конечные волны, без дублирования.
const Travel = preload("res://sim/room_travel.gd")
const Map = preload("res://sim/room_map.gd")
const Arena = preload("res://tests/framework/arena.gd")
const Tick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")

func title() -> String:
	return "режиссёр столкновений"

func _enter(seed_text: String, players: int = 1):
	var state = Travel.start(seed_text, players)
	state.actor_of_slot(0).position = Map.door(state.room, "north") + Vector2(0, 18)
	Travel.advance(state, {0: Command.from_axes(0, Vector2.UP, Vector2.ZERO)})
	return state

func _test_seed_and_safety() -> bool:
	var a = _enter("same", 4)
	var b = _enter("same", 4)
	eq(a.state_hash(), b.state_hash(), "один сид даёт разные столкновения")
	var c = _enter("different", 4)
	check(Arena.enemies(a)[0].position != Arena.enemies(c)[0].position, "сид не меняет расстановку")
	for enemy in Arena.enemies(a):
		for player in Arena.players(a):
			check(enemy.position.distance_to(player.position) >= 220, "спавн у игрока")
		eq(a.room.clamp_body(enemy.position, enemy.radius), enemy.position, "спавн в стене")
	return true

func _test_finite_telegraphed_wave_and_save() -> bool:
	var state = _enter("waves")
	for enemy in Arena.enemies(state): enemy.alive = false
	Tick.step(state, {})
	check(not state.room_cleared(), "двери открылись до подкрепления")
	check(not state.pending_spawns.is_empty(), "нет предупреждения")
	var expected: int = state.pending_spawns.size()
	var until: int = state.pending_spawns[0].spawn_tick
	check(until - state.tick >= 72, "предупреждение короче 1,2 с")
	var restored = Arena.after_save(state)
	eq(restored.state_hash(), state.state_hash(), "волна потеряна в сейве")
	Arena.coast(restored, until - restored.tick)
	eq(Arena.enemies(restored).size(), 0, "волна пришла до предупреждения")
	Tick.step(restored, {})
	eq(Arena.enemies(restored).size(), expected, "волна не пришла")
	for enemy in Arena.enemies(restored): enemy.alive = false
	Arena.coast(restored, 400)
	check(restored.room_cleared(), "подкрепления бесконечны")
	var last_id: int = restored.next_id
	Arena.coast(restored, 400)
	eq(restored.next_id, last_id, "повторный спавн")
	restored.actor_of_slot(0).position = Map.door(restored.room, "south") + Vector2(0, -18)
	Travel.advance(restored, {0: Command.from_axes(restored.tick, Vector2.DOWN, Vector2.ZERO)})
	eq(restored.room.id, "south", "после последней волны не вышли")
	restored = Arena.after_save(restored)
	restored.actor_of_slot(0).position = Map.door(restored.room, "north") + Vector2(0, 18)
	Travel.advance(restored, {0: Command.from_axes(restored.tick, Vector2.UP, Vector2.ZERO)})
	eq(restored.room.id, "center", "не вернулись")
	check(restored.room_cleared(), "возвращение создало новую волну")
	eq(restored.next_id, last_id, "возвращение продублировало врагов")
	return true

func _test_room_roles_scaling_and_rng_isolation() -> bool:
	var director = preload("res://sim/encounter_director.gd")
	var encounter = preload("res://sim/encounter.gd")
	for id in Map.IDS:
		for count in [1, 4]:
			var state = encounter.dev_room("roles", count, 0, Map.make(id))
			var before: Dictionary = state.rng.to_dict()
			director.begin(state)
			eq(state.rng.to_dict(), before, "расстановка сдвинула посторонний поток")
			var enemies = Arena.enemies(state)
			if id == "south":
				check(state.room_cleared(), "приёмная небезопасна")
			elif id == "north":
				eq(enemies.size(), 1, "Тандем перестал быть один")
				eq(enemies[0].archetype, "tandem", "в северной комнате не Тандем")
			elif id == "west":
				check(enemies.filter(func(e): return e.archetype == "runner").size() >= 2, "курьерская без бегунов")
			elif id == "east":
				eq(enemies[0].archetype, "heavy", "архив без тяжёлого врага")
			check(enemies.size() <= 4, "масштабирование создаёт толпу")
			for enemy in enemies:
				for player in Arena.players(state):
					check(enemy.position.distance_to(player.position) >= director.SAFE_DISTANCE, "небезопасный спавн " + id)
				eq(state.room.clamp_body(enemy.position, enemy.radius), enemy.position, "спавн в косяке " + id)
	return true

func _test_occupied_warning_relocates_with_full_new_telegraph() -> bool:
	var director = preload("res://sim/encounter_director.gd")
	var state = _enter("occupied warning", 2)
	for enemy in Arena.enemies(state): enemy.alive = false
	Tick.step(state, {})
	var warned: Vector2 = state.pending_spawns[0].position
	var deadline: int = state.pending_spawns[0].spawn_tick
	state.actor_of_slot(1).position = warned
	Arena.coast(state, deadline - state.tick)
	var events = Tick.step(state, {})
	eq(Arena.enemies(state).size(), 0, "враг появился на игроке у предупреждения")
	eq(state.pending_spawns.size(), 1, "занятая точка потеряла подкрепление")
	if state.pending_spawns.is_empty(): return true
	var moved: Dictionary = state.pending_spawns[0]
	check(moved.position != warned, "не выбрана новая безопасная точка")
	eq(moved.spawn_tick, deadline + director.TELEGRAPH_TICKS, "новая точка без полного предупреждения")
	for player in Arena.players(state):
		check(player.position.distance_to(moved.position) >= director.SAFE_DISTANCE, "новая точка у игрока")
	check(events.any(func(event): return event.type == "wave_warning"), "перенос не предупредил игроков")
	var restored = Arena.after_save(state)
	eq(restored.state_hash(), state.state_hash(), "перенос не пережил сейв")
	Arena.coast(restored, moved.spawn_tick - restored.tick)
	eq(Arena.enemies(restored).size(), 0, "враг появился до нового предупреждения")
	Tick.step(restored, {})
	eq(Arena.enemies(restored).size(), 1, "перенесённый враг не появился")
	return true
