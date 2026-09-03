extends "res://tests/framework/test_case.gd"
## Класс: поведение. Третье и четвёртое оружие перепишут половину ожиданий —
## это обычная работа, а не поломка.
##
## Оружие: выдать, сменить, снять. Смысл теста — не в чемодане, а в том, что
## второе оружие не потребует ни строчки нового кода в бою.

const Arsenal = preload("res://sim/arsenal.gd")
const Encounter = preload("res://sim/encounter.gd")
const Actor = preload("res://sim/actor.gd")
const Modifier = preload("res://sim/core/modifier.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")

const CROWBAR := {
	"id": "crowbar",
	"name": "Монтировка",
	"projectile": "folder",
	"modifiers": [
		{"stat": "damage", "op": "add", "value": 40.0},
		{"stat": "fire_rate", "op": "add", "value": 1.0},
		{"stat": "projectile_speed", "op": "add", "value": 300.0},
		{"stat": "range", "op": "add", "value": 200.0},
	],
}


func title() -> String:
	return "оружие"


func _equip_raw(actor, record: Dictionary) -> void:
	if actor.weapon_id != "":
		actor.stack.remove_source(Arsenal.source_of(actor.weapon_id))
	for entry in record["modifiers"]:
		actor.stack.add(Modifier.make(entry["stat"], Modifier.Op.ADD,
			entry["value"], Arsenal.source_of(record["id"])))
	actor.weapon_id = record["id"]


func _test_weapons_match_schema() -> bool:
	no_errors(Arsenal.validate_all(), "записи оружия не прошли схему")
	return true


func _test_unarmed_cannot_shoot() -> bool:
	var state := Encounter.dev_room("оружие", 1, 1)
	var actor := state.actor_of_slot(0)
	Arsenal.unequip(actor)

	var stats := actor.stack.compute()
	almost_eq(stats.get("fire_rate", 0.0), 0.0, "у безоружного осталась скорострельность")
	almost_eq(stats.get("damage", 0.0), 0.0, "у безоружного остался урон")

	for i in 120:
		SimTick.step(state, {0: Command.from_axes(state.tick, Vector2.ZERO, Vector2.RIGHT,
			Command.BTN_FIRE)})
	eq(state.projectiles.size(), 0, "безоружный кидается снарядами")

	check(actor.alive, "снятие оружия убило персонажа")
	check(actor.stack.compute()["move_speed"] > 0.0, "безоружный разучился ходить")
	return true


func _test_default_weapon_is_the_suitcase() -> bool:
	var state := Encounter.dev_room("оружие", 1, 1)
	var actor := state.actor_of_slot(0)
	eq(actor.weapon_id, Arsenal.DEFAULT_WEAPON, "стартовое оружие не то")
	eq(Arsenal.projectile_of(actor), "folder", "чемодан кидается не папками")

	var stats := actor.stack.compute()
	almost_eq(stats["damage"], 12.0, "урон чемодана не тот")
	almost_eq(stats["fire_rate"], 3.5, "темп чемодана не тот")
	return true


func _test_swapping_replaces_the_stats() -> bool:
	var state := Encounter.dev_room("оружие", 1, 1)
	var actor := state.actor_of_slot(0)
	var before := actor.stack.compute()

	_equip_raw(actor, CROWBAR)
	var after := actor.stack.compute()

	eq(actor.weapon_id, "crowbar", "оружие не сменилось")
	almost_eq(after["damage"], 40.0, "урон не стал уроном нового оружия")
	almost_eq(after["fire_rate"], 1.0, "темп не стал темпом нового оружия")
	check(after["damage"] != before["damage"], "статы не изменились вовсе")
	eq(actor.stack.size(), 4, "в стеке остались модификаторы от прежнего оружия")
	return true


func _test_swapping_keeps_items_and_organs() -> bool:
	var state := Encounter.dev_room("оружие", 1, 1)
	var actor := state.actor_of_slot(0)
	actor.stack.add(Modifier.make("damage", Modifier.Op.ADD, 5.0, "item:shprits"))
	actor.stack.add(Modifier.make("health", Modifier.Op.ADD, 25.0, "organ:serdce"))
	actor.stack.add(Modifier.make("move_speed", Modifier.Op.MUL, 1.2, "item:krossovki"))

	_equip_raw(actor, CROWBAR)
	var stats := actor.stack.compute()

	almost_eq(stats["damage"], 45.0, "прибавка предмета к урону потерялась при смене оружия")
	almost_eq(stats["health"], 125.0, "орган потерялся при смене оружия")
	almost_eq(stats["move_speed"], 312.0, "предмет на скорость потерялся при смене оружия")
	return true


func _test_unequip_removes_only_the_weapon() -> bool:
	var state := Encounter.dev_room("оружие", 1, 1)
	var actor := state.actor_of_slot(0)
	actor.stack.add(Modifier.make("damage", Modifier.Op.ADD, 5.0, "item:shprits"))

	Arsenal.unequip(actor)
	eq(actor.weapon_id, "", "оружие осталось в руках после снятия")
	almost_eq(actor.stack.compute()["damage"], 5.0, "снятие оружия унесло прибавку предмета")

	Arsenal.equip(actor, Arsenal.DEFAULT_WEAPON)
	almost_eq(actor.stack.compute()["damage"], 17.0, "возврат оружия не восстановил урон")
	return true


func _test_equipping_twice_does_not_stack() -> bool:
	var state := Encounter.dev_room("оружие", 1, 1)
	var actor := state.actor_of_slot(0)
	var once: float = actor.stack.compute()["damage"]

	Arsenal.equip(actor, Arsenal.DEFAULT_WEAPON)
	Arsenal.equip(actor, Arsenal.DEFAULT_WEAPON)
	almost_eq(actor.stack.compute()["damage"], once, "повторная выдача сложила урон дважды")
	eq(actor.stack.size(), 6, "повторная выдача наплодила модификаторов")
	return true


func _test_unknown_weapon_is_refused() -> bool:
	var state := Encounter.dev_room("оружие", 1, 1)
	var actor := state.actor_of_slot(0)
	var before: float = actor.stack.compute()["damage"]

	print("             (ниже ожидаемый ERROR: так выглядит отказ выдать несуществующее)")
	check(not Arsenal.equip(actor, "plazmomet"), "несуществующее оружие выдалось")
	eq(actor.weapon_id, Arsenal.DEFAULT_WEAPON, "неудачная выдача сменила оружие в руках")
	almost_eq(actor.stack.compute()["damage"], before, "неудачная выдача изменила статы")
	return true


## Проверяется не баланс, а то, что кольт отличается от чемодана по всем
## осям, по которым оружие вообще может отличаться.
func _test_colt_is_a_different_weapon_entirely() -> bool:
	var state := Encounter.dev_room("оружие", 1, 1)
	var actor := state.actor_of_slot(0)
	var suitcase := actor.stack.compute()

	check(Arsenal.equip(actor, "colt"), "кольт не выдался")
	var colt := actor.stack.compute()

	eq(Arsenal.projectile_of(actor), "bullet", "из кольта летят не пули")
	check(colt["damage"] > suitcase["damage"], "кольт бьёт не сильнее чемодана")
	check(colt["fire_rate"] < suitcase["fire_rate"], "кольт стреляет не реже чемодана")
	check(colt["projectile_speed"] > suitcase["projectile_speed"],
		"пуля летит не быстрее папки")
	check(colt["shot_momentum"] < suitcase["shot_momentum"],
		"пуля наследует скорость стрелка наравне с папкой")
	return true


func _test_swapping_to_the_colt_leaves_no_tumble() -> bool:
	var state := Encounter.dev_room("оружие", 1, 1)
	var actor := state.actor_of_slot(0)
	almost_eq(actor.stack.compute().get("tumble_range", 0.0), 220.0,
		"у чемодана пропал кувырок")

	check(Arsenal.equip(actor, "colt"), "кольт не выдался")
	almost_eq(actor.stack.compute().get("tumble_range", 0.0), 0.0,
		"после смены на кольт остался кувырок чемодана")
	return true
