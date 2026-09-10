extends "res://tests/framework/test_case.gd"
## Класс: поведение. Сборки и способность доступны через игровые команды и переходы.

const Arena = preload("res://tests/framework/arena.gd")
const Travel = preload("res://sim/room_travel.gd")
const Map = preload("res://sim/room_map.gd")
const Command = preload("res://sim/input/command.gd")
const Abilities = preload("res://sim/abilities.gd")
const Items = preload("res://sim/items.gd")
const Pickup = preload("res://sim/pickup.gd")
const Projectile = preload("res://sim/projectile.gd")
const Encounter = preload("res://sim/encounter.gd")

func title() -> String:
	return "игровой цикл сборок"

func _walk(state, direction: String) -> void:
	state.pending_spawns.clear()
	state.encounter_waves.clear()
	for enemy in Arena.enemies(state): enemy.take_damage(10000)
	var normal: Vector2 = Map.DIRECTIONS[direction]
	state.actor_of_slot(0).position = Map.door(state.room, direction) - normal * 16
	Travel.advance(state, {0: Command.from_axes(state.tick, normal, Vector2.ZERO)})

func _test_every_item_and_competing_eyes_reachable_without_debug_keys() -> bool:
	var state = Travel.start("лут", 1)
	var found := {}
	for direction in ["", "north", "west", "east", "east"]:
		if direction != "": _walk(state, direction)
		for pickup in state.pickups:
			if pickup.kind in ["item", "organ"]: found[pickup.content_id] = true
	for id in Items.RECORDS: check(found.has(id), "нет на карте предмета " + id)
	check(found.has("rear_eye") and found.has("notary_eye"), "нет двух вариантов глаза")
	return true

func _test_cover_returns_on_transition_without_resetting_cooldown() -> bool:
	var state = Travel.start("чемодан в проход", 1)
	check(Abilities.activate(state, state.slots[0]), "не поставлен чемодан")
	_walk(state, "north")
	eq(state.actor_of_slot(0).weapon_id, "suitcase", "чемодан потерян на переходе")
	eq(state.slots[0].cover_ticks, 0, "укрытие переехало в другую комнату")
	eq(state.slots[0].skill_cooldown_ticks, 600, "переход сбросил перезарядку")
	return true

func _test_deployed_cover_blocks_weapon_exchange_but_allows_items() -> bool:
	var state := Arena.solo("без оружия")
	var actor := state.actor_of_slot(0)
	state.pickups.clear()
	state.pickups.append(Pickup.weapon(state.take_id(), "colt", actor.position))
	Arena.hold(state, 1, Vector2.ZERO, Vector2.RIGHT, Command.BTN_SKILL | Command.BTN_FIRE | Command.BTN_INTERACT)
	eq(actor.weapon_id, "", "подбор оружия обошёл цену способности")
	eq(state.projectiles.size(), 0, "безоружный выстрелил")
	state.pickups.append(Pickup.item(state.take_id(), "red_folder", actor.position))
	Arena.coast(state, 1)
	Arena.hold(state, 1, Vector2.ZERO, Vector2.ZERO, Command.BTN_INTERACT)
	eq(state.slots[0].items.size(), 1, "укрытие запретило подобрать предмет")
	var loaded := Arena.after_save(state)
	Arena.coast(state, 250)
	Arena.coast(loaded, 250)
	eq(state.state_hash(), loaded.state_hash(), "возврат чемодана после сейва изменил сборку")
	almost_eq(actor.stack.compute()["damage"], 12 * 1.4, "возврат чемодана потерял предмет")
	return true

func _test_cover_intercepts_fast_shell_but_not_before_nearer_player() -> bool:
	for protected in [true, false]:
		var state := Arena.room("прикрытие", 2, 0)
		var owner := state.actor_of_slot(0)
		owner.position = Vector2.ZERO
		owner.aim = Vector2.RIGHT
		check(Abilities.activate(state, state.slots[0]), "укрытие не поставилось")
		var target := state.actor_of_slot(1)
		target.position = Vector2(0 if protected else 135, 0)
		var enemy := Encounter.add_enemy(state, "test_monster", Vector2(210, 0))
		enemy.stack.base["move_speed"] = 0.0
		var shot = Projectile.spawn(state.take_id(), enemy, Vector2.LEFT,
			{"damage": 18.0, "projectile_speed": 12000.0, "range": 1000.0}, "tank_shell")
		state.projectiles.append(shot)
		Arena.coast(state, 1)
		almost_eq(target.health, 100 if protected else 82, "нарушен порядок игрока и укрытия по пути снаряда")
	return true
