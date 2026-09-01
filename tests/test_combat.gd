extends "res://tests/framework/test_case.gd"
## Бой: стрельба, урон, падение, зачистка комнаты.
##
## Всё здесь — симуляция без единого узла, поэтому проверяется без окна.
## Ощущение боя этим не измеряется и измеряться не может: скорострельность,
## разлёт и вес попадания подбираются руками на стенде. Тесты стерегут
## правила, а не вкус.

const Encounter = preload("res://sim/encounter.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const Actor = preload("res://sim/actor.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const RunState = preload("res://sim/run_state.gd")

const SEED := "бой"


func title() -> String:
	return "бой"


func _hold(state: RunState, ticks: int, move: Vector2, aim: Vector2, buttons: int = 0) -> void:
	for i in ticks:
		SimTick.step(state, {0: Command.from_axes(state.tick, move, aim, buttons)})


## Данные врагов и персонажей идут через тот же валидатор, что и остальной
## контент. Опечатка в имени стата иначе всплывёт пустым уроном в бою.
func _test_bestiary_matches_schema() -> bool:
	no_errors(Bestiary.validate_all(), "записи бестиария не прошли схему")
	return true


func _test_room_starts_populated() -> bool:
	var state := Encounter.dev_room(SEED, 1, 3)
	eq(state.living(Actor.Kind.PLAYER).size(), 1, "игрок не встал в комнату")
	eq(state.living(Actor.Kind.ENEMY).size(), 3, "враги не встали в комнату")
	check(not state.room_cleared(), "комната считается зачищенной, хотя враги живы")
	check(not state.party_down(), "группа считается павшей на старте")

	var ids := {}
	for actor in state.actors:
		check(not ids.has(actor.id), "два тела с одинаковым идентификатором")
		ids[actor.id] = true
	return true


func _test_firing_spawns_projectile_and_respects_rate() -> bool:
	var state := Encounter.dev_room(SEED, 1, 1)
	var shooter := state.actor_of_slot(0)
	var rate: float = shooter.stack.compute()["fire_rate"]

	_hold(state, 1, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
	eq(state.projectiles.size(), 1, "выстрел не породил снаряд")

	# Ещё половина периода перезарядки — второго снаряда быть не должно
	_hold(state, int(30.0 / rate), Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
	eq(state.projectiles.size(), 1, "скорострельность не ограничивает стрельбу")
	return true


func _test_projectile_kills_enemy() -> bool:
	var state := Encounter.dev_room(SEED, 1, 1)
	var enemy := state.living(Actor.Kind.ENEMY)[0]
	var player := state.actor_of_slot(0)
	# Поставить врага прямо перед стволом, чтобы не гоняться за ним
	enemy.position = player.position + Vector2(80, 0)

	var before := enemy.health
	_hold(state, 240, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)

	check(enemy.health < before, "враг не получил урона")
	check(not enemy.alive, "враг пережил четыре секунды обстрела в упор")
	check(state.room_cleared(), "комната не считается зачищенной после смерти врага")
	return true


## Труп остаётся в мире: над ним делается харвест органов, это записано
## в docs/DECISIONS.md. Убирать тела нельзя.
func _test_corpse_stays() -> bool:
	var state := Encounter.dev_room(SEED, 1, 1)
	var enemy := state.living(Actor.Kind.ENEMY)[0]
	enemy.position = state.actor_of_slot(0).position + Vector2(80, 0)
	_hold(state, 240, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)

	eq(state.actors.size(), 2, "труп исчез из мира — харвест органов станет невозможен")
	check(not state.actor_by_id(enemy.id).alive, "труп числится живым")
	return true


func _test_projectile_spares_the_shooter() -> bool:
	var state := Encounter.dev_room(SEED, 1, 1)
	var player := state.actor_of_slot(0)
	state.living(Actor.Kind.ENEMY)[0].position = Vector2(9999, 9999)
	var before := player.health

	_hold(state, 120, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
	almost_eq(player.health, before, "снаряд ранил того, кто его бросил", 1e-6)
	return true


## Снаряд не летит вечно: дальность считается из range и скорости, поэтому
## предмет на дальность будет работать сам.
func _test_projectile_expires() -> bool:
	var state := Encounter.dev_room(SEED, 1, 1)
	state.living(Actor.Kind.ENEMY)[0].position = Vector2(9999, 9999)
	var stats: Dictionary = state.actor_of_slot(0).stack.compute()
	var flight_ticks := int(stats["range"] / stats["projectile_speed"] * 60.0)

	_hold(state, 1, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)
	eq(state.projectiles.size(), 1, "снаряд не появился")
	_hold(state, flight_ticks + 5, Vector2.ZERO, Vector2.RIGHT)
	eq(state.projectiles.size(), 0, "снаряд не погас, пролетев свою дальность")
	return true


## Игрок не умирает, а падает — модель Soul Knight из docs/DECISIONS.md.
func _test_player_goes_down_not_dead() -> bool:
	var state := Encounter.dev_room(SEED, 1, 1)
	var player := state.actor_of_slot(0)
	var enemy := state.living(Actor.Kind.ENEMY)[0]
	enemy.position = player.position
	player.health = 1.0

	_hold(state, 10, Vector2.ZERO, Vector2.ZERO)

	check(state.slots[0].downed, "игрок не упал, получив смертельный урон")
	check(player.alive, "игрок умер вместо падения")
	check(state.party_down(), "одиночное падение не закончило забег")
	return true


## Кадры неуязвимости задают темп ударов. Без них враг вплотную снимает
## урон каждый тик и убивает за треть секунды.
func _test_invulnerability_paces_touch_damage() -> bool:
	var state := Encounter.dev_room(SEED, 1, 1)
	var player := state.actor_of_slot(0)
	var enemy := state.living(Actor.Kind.ENEMY)[0]
	enemy.position = player.position
	var damage: float = enemy.stack.compute()["damage"]
	var before := player.health

	_hold(state, 30, Vector2.ZERO, Vector2.ZERO)
	var taken := before - player.health
	check(taken <= damage * 2.0,
		"за полсекунды снято %.1f при уроне удара %.1f — неуязвимость не работает" % [taken, damage])
	check(taken > 0.0, "враг вплотную не нанёс урона вовсе")
	return true


## Враги не добивают упавшего: его поднимают товарищи, и добивание сделало
## бы подъём невозможным.
func _test_enemies_ignore_the_downed() -> bool:
	var state := Encounter.dev_room(SEED, 2, 1)
	state.slots[0].downed = true
	var downed := state.actor_of_slot(0)
	var standing := state.actor_of_slot(1)
	var enemy := state.living(Actor.Kind.ENEMY)[0]
	downed.position = enemy.position + Vector2(30, 0)
	standing.position = enemy.position + Vector2(400, 0)

	_hold(state, 60, Vector2.ZERO, Vector2.ZERO)

	check(enemy.position.x > downed.position.x,
		"враг пошёл к упавшему вместо стоящего")
	return true


func _test_bodies_stay_inside_the_room() -> bool:
	var state := Encounter.dev_room(SEED, 1, 1)
	_hold(state, 600, Vector2(1, 1), Vector2.ZERO)
	var player := state.actor_of_slot(0)
	check(state.room.bounds.has_point(player.position),
		"тело вышло за стены комнаты: %s вне %s" % [player.position, state.room.bounds])
	return true
