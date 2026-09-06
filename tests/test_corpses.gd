extends "res://tests/framework/test_case.gd"
## Класс: поведение. Труп исчезает по времени забега, не прерывая харвест.

const Arena = preload("res://tests/framework/arena.gd")
const Command = preload("res://sim/input/command.gd")
const SaveGame = preload("res://sim/save/save_game.gd")
const Pickup = preload("res://sim/pickup.gd")
const Harvest = preload("res://sim/harvest.gd")
const RoomTravel = preload("res://sim/room_travel.gd")
const Encounter = preload("res://sim/encounter.gd")
const Corpses = preload("res://sim/corpses.gd")


func title() -> String:
	return "исчезновение трупов"


func _test_expiry_keeps_players_and_loot() -> bool:
	for enemy_id in ["test_monster", "runner", "tandem"]:
		var state := Arena.duel("исчезновение", enemy_id, Vector2(20, 0))
		var corpse = Arena.enemies(state)[0]
		corpse.take_damage(1000)
		state.pickups.append(Pickup.organ(state.take_id(), "courier_heart", Vector2.ZERO))
		Arena.coast(state, 1799)
		check(state.actor_by_id(corpse.id) != null, "труп исчез раньше 30 секунд: " + enemy_id)
		Arena.coast(state, 2)
		check(state.actor_by_id(corpse.id) == null, "труп не исчез: " + enemy_id)
		check(state.actor_of_slot(0) != null, "удалён игрок")
		eq(state.pickups.size(), 2, "исчез орган или оружие на полу")
		eq(state.heat, 0, "исчезновение стало харвестом")
	return true


func _test_harvest_started_before_expiry_finishes() -> bool:
	var state := Arena.duel("успел", "runner", Vector2(20, 0))
	var corpse = Arena.enemies(state)[0]
	corpse.take_damage(1000)
	Arena.coast(state, 1790)
	Arena.hold(state, 60, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	eq(state.slots[0].organs["heart"], "courier_heart", "исчезновение оборвало операцию")
	eq(state.heat, 10, "стоимость харвеста потерялась")
	Arena.coast(state, 181)
	check(state.actor_by_id(corpse.id) == null, "извлечённое тело осталось навсегда")
	return true


func _test_save_does_not_restart_decay() -> bool:
	var state := Arena.duel("сейв", "runner", Vector2(20, 0))
	var corpse = Arena.enemies(state)[0]
	corpse.take_damage(1000)
	Arena.coast(state, 1500)
	var loaded = SaveGame.from_bytes(SaveGame.to_bytes(state))
	Arena.coast(loaded, 301)
	check(loaded.actor_by_id(corpse.id) == null, "загрузка обнулила время трупа")
	check(Harvest.nearest(loaded, loaded.actor_of_slot(0)) == null, "можно извлечь невидимый труп")
	return true


func _test_return_to_room_does_not_revive_corpse() -> bool:
	var state := RoomTravel.start("комнаты", 1)
	var corpse := Encounter.add_enemy(state, "runner", Vector2(20, 0))
	corpse.take_damage(1000)
	Arena.coast(state, 1)
	RoomTravel._enter(state, "north")
	state.tick += 1801
	RoomTravel._enter(state, "south")
	check(state.actor_by_id(corpse.id) == null, "возвращение восстановило истёкший труп")
	return true


func _test_fade_and_downed_player() -> bool:
	var state := Arena.duel("затухание", "tandem", Vector2(20, 0))
	var corpse = Arena.enemies(state)[0]
	corpse.take_damage(1000)
	Arena.coast(state, 1)
	almost_eq(Corpses.opacity(corpse, 1620), 1.0, "тело тускнеет раньше 27 секунд")
	almost_eq(Corpses.opacity(corpse, 1710), 0.5, "неравномерное затухание")
	almost_eq(Corpses.opacity(corpse, 1800), 0.0, "тело видно после 30 секунд")
	state.slots[0].downed = true
	state.actor_of_slot(0).health = 0
	Arena.coast(state, 1801)
	check(state.actor_of_slot(0) != null, "исчез упавший товарищ")
	check(state.slots[0].downed, "таймер поднял игрока")
	return true
