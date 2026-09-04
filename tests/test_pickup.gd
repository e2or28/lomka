extends "res://tests/framework/test_case.gd"
## Класс: поведение. Обмен оружием на полу — правило игры, а не фундамент,
## и оно поменяется вместе с лутом на M3.

const Arena = preload("res://tests/framework/arena.gd")
const Encounter = preload("res://sim/encounter.gd")
const Command = preload("res://sim/input/command.gd")
const Pickup = preload("res://sim/pickup.gd")

const SEED := "подбор"


func title() -> String:
	return "подбор оружия"


func _armed_player(state) -> String:
	return Arena.players(state)[0].weapon_id


func _test_room_starts_with_a_weapon_on_the_floor() -> bool:
	var state := Arena.room(SEED, 1, 0)
	eq(state.pickups.size(), 1, "в комнате не оказалось оружия на полу")
	eq(state.pickups[0].kind, Pickup.KIND_WEAPON, "на полу лежит не оружие")
	eq(state.pickups[0].content_id, "colt", "на полу лежит не кольт")
	return true


func _test_standing_on_it_is_not_enough() -> bool:
	var state := Arena.room(SEED, 1, 0)
	var player := Arena.players(state)[0]
	player.position = state.pickups[0].position
	Arena.coast(state, 10)
	eq(_armed_player(state), "suitcase", "оружие подобралось без нажатия")
	return true


## Обмен, а не поглощение: прежнее оружие остаётся лежать, и за ним можно
## вернуться. Иначе одно нажатие стирало бы содержимое комнаты.
func _test_taking_leaves_the_old_weapon_behind() -> bool:
	var state := Arena.room(SEED, 1, 0)
	var player := Arena.players(state)[0]
	player.position = state.pickups[0].position

	Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	eq(_armed_player(state), "colt", "кольт не подобрался")
	eq(state.pickups.size(), 1, "предмет пропал с пола вместо обмена")
	eq(state.pickups[0].content_id, "suitcase", "на полу остался не чемодан")
	return true


## Зажатая кнопка меняла бы оружие местами каждый тик, и на экране это
## выглядело бы миганием.
func _test_holding_the_button_swaps_once() -> bool:
	var state := Arena.room(SEED, 1, 0)
	var player := Arena.players(state)[0]
	player.position = state.pickups[0].position

	Arena.hold(state, 30, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	eq(_armed_player(state), "colt", "удержание перевернуло обмен обратно")

	Arena.coast(state, 1)
	Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	eq(_armed_player(state), "suitcase", "второе нажатие не вернуло чемодан")
	return true


func _test_out_of_reach_does_nothing() -> bool:
	var state := Arena.room(SEED, 1, 0)
	var player := Arena.players(state)[0]
	var pickup: Pickup = state.pickups[0]
	player.position = pickup.position + Vector2(pickup.radius + player.radius + 8.0, 0.0)

	Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	eq(_armed_player(state), "suitcase", "оружие подобралось из-за предела круга")
	return true


func _test_unarmed_takes_it_for_good() -> bool:
	var state := Arena.room(SEED, 1, 0)
	var player := Arena.players(state)[0]
	player.position = state.pickups[0].position
	player.stack.remove_source("weapon:suitcase")
	player.weapon_id = ""

	Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	eq(_armed_player(state), "colt", "безоружный не подобрал оружие")
	eq(state.pickups.size(), 0, "на полу осталась пустая ячейка вместо ничего")
	return true


func _test_floor_survives_the_save() -> bool:
	var state := Arena.room(SEED, 1, 0)
	Encounter.add_pickup(state, "suitcase", Vector2(-200, -40))

	var loaded := Arena.after_save(state)
	check(loaded != null, "забег с предметами на полу не загрузился")
	if loaded == null:
		return true

	eq(loaded.pickups.size(), state.pickups.size(), "предметы на полу потеряны")
	for i in state.pickups.size():
		eq(loaded.pickups[i].to_dict(), state.pickups[i].to_dict(),
			"предмет %d прочитался не тем" % i)
	return true
