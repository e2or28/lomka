extends "res://tests/framework/test_case.gd"
## Класс: поведение. Смена органа меняет стиль игры, предметы сочетаются в залпе.

const Arena = preload("res://tests/framework/arena.gd")
const Organs = preload("res://sim/organs.gd")
const Command = preload("res://sim/input/command.gd")
const Pickup = preload("res://sim/pickup.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Encounter = preload("res://sim/encounter.gd")
const SimTick = preload("res://sim/tick.gd")

func title() -> String:
	return "сборки и эффекты предметов"

func _items():
	if not check(ResourceLoader.exists("res://sim/items.gd"), "нет реестра восьми предметов"):
		return null
	return load("res://sim/items.gd")

func _test_alternative_heart_replaces_synergy_and_reacts_to_danger() -> bool:
	var state := Arena.duel("сердце труса", "test_monster", Vector2(200, 0))
	var player := state.actor_of_slot(0)
	var slot = state.slots[0]
	Organs.equip(player, slot, "courier_heart")
	Organs.equip(player, slot, "armored_spine")
	if not check(Organs.equip(player, slot, "coward_heart"), "сердце труса отсутствует"):
		return true
	Arena.coast(state, 1)
	almost_eq(player.stack.compute()["move_speed"], 260 * 0.85 * 1.35, "нет ускорения возле врага")
	eq(Organs.active_synergies(slot).size(), 0, "осталась синергия снятого сердца")
	Arena.enemies(state)[0].take_damage(1000)
	Arena.coast(state, 190)
	almost_eq(player.stack.compute()["move_speed"], 260 * 0.85 * 0.85, "мёртвый враг пугает сердце")
	almost_eq(player.health, 100, "снятое сердце курьера продолжает штрафовать")
	Organs.unequip(player, slot, "heart")
	almost_eq(player.stack.compute()["move_speed"], 260 * 0.85, "динамический штраф остался после снятия")
	return true

func _test_eight_items_pickup_stacks_only_for_recipient() -> bool:
	var items = _items()
	if items == null: return true
	no_errors(items.validate_all(), "невалидные предметы")
	eq(items.RECORDS.size(), 8, "нужно восемь предметов")
	var state := Arena.room("предметы", 2, 0)
	var player := state.actor_of_slot(0)
	state.pickups.clear()
	for i in 2:
		var pickup = Pickup.weapon(state.take_id(), "red_folder", player.position)
		pickup.kind = "item"
		state.pickups.append(pickup)
		Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
		Arena.coast(state, 1)
	almost_eq(player.stack.compute()["damage"], 12 * 1.4 * 1.4, "повторные предметы не сложились")
	almost_eq(state.actor_of_slot(1).stack.compute()["damage"], 12, "предмет попал в чужой стек")
	eq(state.pickups.size(), 0, "подобранный предмет остался на полу")
	eq(state.slots[0].items.size(), 2, "инвентарь не сохранил два экземпляра")
	var loaded := Arena.after_save(state)
	eq(state.state_hash(), loaded.state_hash(), "инвентарь изменился после сейва")
	return true

func _test_charge_rear_bounce_and_pierce_compose_on_both_weapons() -> bool:
	var items = _items()
	if items == null: return true
	for weapon in ["suitcase", "colt"]:
		var state := Arena.solo("залп")
		var player := state.actor_of_slot(0)
		player.position = Vector2.ZERO
		Arsenal.equip(player, weapon)
		for id in ["carbon_copy", "rubber_stamp", "heavy_seal", "hole_punch"]:
			check(items.equip(player, state.slots[0], id), "не установлен " + id)
		Arena.hold(state, 35, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
		eq(state.projectiles.size(), 0, "заряд выстрелил раньше времени")
		var loaded := Arena.after_save(state)
		Arena.hold(state, 1, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
		Arena.hold(loaded, 1, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
		eq(state.state_hash(), loaded.state_hash(), "заряд разошёлся после сейва")
		if not eq(state.projectiles.size(), 2, "нет залпа вперёд и назад"): continue
		check(state.projectiles[0].velocity.x > 0 and state.projectiles[1].velocity.x < 0, "обе пули летят в одну сторону")
		for shot in state.projectiles:
			eq(shot.pierce, 1, "пробитие не наследуется залпом")
			eq(shot.bounces, 1, "рикошет не наследуется залпом")
			almost_eq(shot.damage, (12 if weapon == "suitcase" else 24) * 0.75 * 0.85 * 2.5, "урон эффектов не скомбинирован")
	return true

func _test_release_cancels_charge_and_eye_replacement_removes_rear_shot() -> bool:
	var state := Arena.solo("глаза")
	var player := state.actor_of_slot(0)
	if not check(Organs.equip(player, state.slots[0], "rear_eye"), "нет глаза затылочника"): return true
	Arena.shoot(state, Vector2.RIGHT)
	eq(state.projectiles.size(), 2, "глаз не стреляет назад")
	state.projectiles.clear()
	player.cooldown = 0
	check(Organs.equip(player, state.slots[0], "notary_eye"), "нет глаза нотариуса")
	Arena.hold(state, 20, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
	Arena.coast(state, 1)
	Arena.hold(state, 20, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
	eq(state.projectiles.size(), 0, "отпускание не сбросило заряд")
	Arena.hold(state, 16, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
	eq(state.projectiles.size(), 1, "снятый глаз продолжает стрелять назад")
	return true

func _test_ricochet_preserves_distance_and_stops_after_budget() -> bool:
	var items = _items()
	if items == null: return true
	var state := Arena.solo("рикошет")
	var player := state.actor_of_slot(0)
	player.position = Vector2(0, 0)
	items.equip(player, state.slots[0], "rubber_stamp")
	var shot = Arena.shoot(state, Vector2.RIGHT)
	shot.position = Vector2(state.room.bounds.end.x - 2, 0)
	var distance: float = shot.travelled
	Arena.coast(state, 1)
	check(state.projectiles.has(shot), "снаряд исчез вместо рикошета")
	check(shot.velocity.x < 0, "рикошет не развернул снаряд")
	check(shot.travelled > distance, "рикошет сбросил дальность")
	shot.position = Vector2(state.room.bounds.position.x + 2, 0)
	Arena.coast(state, 1)
	check(not state.projectiles.has(shot), "снаряд отскочил лишний раз")
	return true
