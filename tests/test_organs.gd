extends "res://tests/framework/test_case.gd"
## Класс: поведение. Харвест требует отдельного действия; орган меняет сборку.

const Arena = preload("res://tests/framework/arena.gd")
const Command = preload("res://sim/input/command.gd")
const Organs = preload("res://sim/organs.gd")
const Pickup = preload("res://sim/pickup.gd")
const Encounter = preload("res://sim/encounter.gd")
const SimTick = preload("res://sim/tick.gd")
const Schemas = preload("res://sim/data/schemas.gd")


func title() -> String:
	return "органы и харвест"


func _test_courier_harvest_changes_speed() -> bool:
	var state := Arena.duel("органы", "runner", Vector2(20, 0))
	var corpse = Arena.enemies(state)[0]
	corpse.take_damage(1000.0)
	Arena.hold(state, 60, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	almost_eq(state.actor_of_slot(0).stack.compute()["move_speed"], 325.0,
		"сердце курьера не дало +25% скорости после извлечения")
	return true


func _corpse(state):
	var enemy := Encounter.add_enemy(state, "runner", state.actor_of_slot(0).position + Vector2(20, 0))
	enemy.take_damage(1000.0)
	return enemy


func _test_records_and_eight_slots() -> bool:
	no_errors(Organs.validate_all(), "неверные данные органов")
	var state := Arena.solo("слоты")
	eq(state.slots[0].organs.keys(), Schemas.ORGAN_SLOTS, "слоты тела не совпали")
	var bad := Organs.organ("courier_heart").duplicate(true)
	bad["slot"] = "third_hand"
	has_error(Schemas.validate("organ", bad), "не входит", "принят неизвестный слот")
	return true


func _test_kill_costs_nothing_harvest_exactly_once() -> bool:
	var state := Arena.solo("heat")
	var corpse = _corpse(state)
	Arena.coast(state, 1)
	eq(state.heat, 0, "убийство повысило Heat")
	Arena.hold(state, 59, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	eq(state.heat, 0, "неоконченное извлечение повысило Heat")
	Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	eq(state.heat, 10, "извлечение не стоит 10 Heat")
	check(corpse.harvested, "труп не помечен изъятым")
	Arena.hold(state, 180, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	Arena.coast(state, 1)
	Arena.hold(state, 60, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	eq(state.heat, 10, "повторное извлечение повысило Heat")
	return true


func _test_release_movement_fire_and_distance_cancel() -> bool:
	for reason in ["release", "move", "fire", "distance", "downed"]:
		var state := Arena.solo("отмена")
		_corpse(state)
		Arena.hold(state, 30, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
		match reason:
			"release": Arena.coast(state, 1)
			"move": Arena.hold(state, 1, Vector2.RIGHT, Vector2.ZERO, Command.BTN_HARVEST)
			"fire": Arena.hold(state, 1, Vector2.ZERO, Vector2.UP, Command.BTN_FIRE | Command.BTN_HARVEST)
			"distance":
				state.actor_of_slot(0).position += Vector2(300, 0)
				Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
			"downed":
				state.slots[0].downed = true
				Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
		eq(state.slots[0].harvest_ticks, 0, "не отменён харвест: " + reason)
		eq(state.heat, 0, "отмена дала Heat: " + reason)
	return true


func _test_living_or_empty_enemy_is_not_harvested() -> bool:
	var state := Arena.duel("живой", "runner", Vector2(30, 0))
	Arena.hold(state, 60, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	eq(state.heat, 0, "извлечён орган живого врага")
	state = Arena.duel("пустой", "test_monster", Vector2(30, 0))
	Arena.enemies(state)[0].take_damage(1000)
	Arena.hold(state, 60, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	eq(state.heat, 0, "пустой труп дал Heat")
	return true


func _test_two_players_cannot_duplicate_organ() -> bool:
	var state := Arena.room("двое", 2, 0)
	state.actor_of_slot(1).position = state.actor_of_slot(0).position
	_corpse(state)
	for i in 60:
		var cmd: Command = Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
		SimTick.step(state, {0: cmd, 1: cmd})
	eq(state.heat, 10, "двое заплатили за один труп дважды")
	eq(state.slots[0].organs["heart"], "courier_heart", "первый слот не выиграл ничью")
	eq(state.slots[1].organs["heart"], "", "один орган достался двоим")
	return true


func _test_heart_punishes_after_three_seconds_and_resets_on_motion() -> bool:
	var state := Arena.solo("сердце")
	var player := state.actor_of_slot(0)
	Organs.equip(player, state.slots[0], "courier_heart")
	Arena.coast(state, 180)
	almost_eq(player.health, 100.0, "штраф наступил до трёх секунд")
	Arena.coast(state, 1)
	almost_eq(player.health, 95.0, "нет штрафа после трёх секунд")
	Arena.coast(state, 60)
	almost_eq(player.health, 90.0, "штраф не повторился через секунду")
	Arena.hold(state, 1, Vector2.RIGHT)
	eq(state.slots[0].stationary_ticks, 0, "движение не сбросило таймер")
	return true


func _test_pushing_a_wall_counts_as_stopping_and_can_end_run() -> bool:
	var state := Arena.solo("стена")
	var player := state.actor_of_slot(0)
	Organs.equip(player, state.slots[0], "courier_heart")
	player.position = Vector2(0, state.room.bounds.end.y)
	player.health = 5.0
	Arena.hold(state, 181, Vector2.DOWN)
	check(state.party_down(), "упор в стену обошёл штраф или падение")
	return true


func _test_synergy_composes_and_disappears_without_touching_weapon() -> bool:
	var state := Arena.solo("сочетание")
	var player := state.actor_of_slot(0)
	var slot = state.slots[0]
	Organs.equip(player, slot, "armored_spine")
	Organs.equip(player, slot, "courier_heart")
	var stats := player.stack.compute()
	almost_eq(stats["damage"], 16.2, "позвоночник не повысил урон")
	almost_eq(stats["move_speed"], 276.25, "плюс и минус скорости не сложились")
	eq(Organs.active_synergies(slot), ["express_delivery"], "пара не включилась")
	var shot = Arena.shoot(state, Vector2.RIGHT)
	eq(shot.pierce, 1, "сочетание не пробивает вторую цель")
	almost_eq(shot.velocity.length(), 806.0, "сочетание не ускорило снаряд")
	Organs.unequip(player, slot, "heart")
	eq(Organs.active_synergies(slot).size(), 0, "сочетание осталось после снятия")
	almost_eq(player.stack.compute()["projectile_speed"], 620.0, "бонус сочетания остался в стеке")
	almost_eq(player.stack.compute()["damage"], 16.2, "снятие сердца затронуло позвоночник/оружие")
	return true


func _test_repeated_install_does_not_stack_and_replacement_is_left_on_floor() -> bool:
	var state := Arena.solo("замена")
	var player := state.actor_of_slot(0)
	Organs.equip(player, state.slots[0], "courier_heart")
	_corpse(state)
	Arena.hold(state, 60, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	almost_eq(player.stack.compute()["move_speed"], 325.0, "дубликат сердца удвоил бонус")
	var organs: Array = state.pickups.filter(func(p): return p.kind == Pickup.KIND_ORGAN)
	eq(organs.size(), 1, "заменённый орган потерян")
	if organs.is_empty():
		return true
	Organs.unequip(player, state.slots[0], "heart")
	player.position = organs[0].position
	Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	eq(state.slots[0].organs["heart"], "courier_heart", "орган с пола не установлен через E")
	eq(state.heat, 10, "подбор уже извлечённого органа повысил Heat")
	return true


func _test_save_mid_harvest_and_curse_replays_identically() -> bool:
	var state := Arena.solo("сейв органов")
	_corpse(state)
	Arena.hold(state, 30, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	var loaded := Arena.after_save(state)
	bytes_eq(var_to_bytes(state.to_dict()), var_to_bytes(loaded.to_dict()), "потерян прогресс харвеста")
	Arena.hold(state, 30, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	Arena.hold(loaded, 30, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	Arena.coast(state, 170)
	Arena.coast(loaded, 170)
	eq(state.state_hash(), loaded.state_hash(), "харвест разошёлся после сейва")
	loaded = Arena.after_save(state)
	Arena.coast(state, 100)
	Arena.coast(loaded, 100)
	eq(state.state_hash(), loaded.state_hash(), "таймер штрафа разошёлся после сейва")
	return true


func _test_synergy_projectile_hits_two_targets_but_not_three() -> bool:
	var state := Arena.shooting_range("пробитие")
	var player := state.actor_of_slot(0)
	Organs.equip(player, state.slots[0], "courier_heart")
	Organs.equip(player, state.slots[0], "armored_spine")
	var targets: Array = []
	for x in [-350, -250, -150]:
		var enemy := Encounter.add_enemy(state, "test_monster", Vector2(x, 0))
		enemy.stack.base["move_speed"] = 0.0
		targets.append(enemy)
	Arena.shoot(state, Vector2.RIGHT)
	Arena.coast(state, 50)
	almost_eq(targets[0].health, 23.8, "снаряд не повредил первую цель ровно один раз")
	almost_eq(targets[1].health, 23.8, "снаряд не пробил вторую цель")
	almost_eq(targets[2].health, 40.0, "снаряд ошибочно пробил третью цель")
	return true


func _test_holding_harvest_never_chains_into_another_corpse() -> bool:
	var state := Arena.solo("один орган за удержание")
	_corpse(state)
	_corpse(state)
	Arena.hold(state, 130, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	eq(state.heat, 10, "удержание автоматически извлекло соседний труп")
	Arena.coast(state, 1)
	Arena.hold(state, 60, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	eq(state.heat, 20, "новое удержание не извлекло второй труп")
	return true
