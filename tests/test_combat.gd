extends "res://tests/framework/test_case.gd"
## Бой: стрельба, урон, падение, зачистка комнаты.
##
## Класс: поведение. Ощущение боя этим не измеряется: скорострельность,
## разлёт и вес попадания подбираются руками на стенде.

const Arena = preload("res://tests/framework/arena.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Encounter = preload("res://sim/encounter.gd")

const SEED := "бой"


func title() -> String:
	return "бой"


func _test_bestiary_matches_schema() -> bool:
	no_errors(Bestiary.validate_all(), "записи бестиария не прошли схему")
	return true


## Хитбокс — круг на позиции тела, радиус приходит из бестиария. Общий
## радиус на всех означал бы, что в Начальника попасть ровно так же
## трудно, как в Курьера, каких бы размеров их ни нарисовали.
func _test_hitbox_comes_from_the_bestiary() -> bool:
	var state := Arena.solo(SEED)
	var heavy := Encounter.add_enemy(state, "heavy", Vector2(300, 0))
	var runner := Encounter.add_enemy(state, "runner", Vector2(-300, 0))

	eq(heavy.radius, float(Bestiary.enemy("heavy")["radius"]),
		"радиус Начальника не приехал из записи")
	check(heavy.radius > runner.radius, "тяжёлый враг не крупнее лёгкого")
	check(Arena.players(state)[0].radius < runner.radius,
		"хитбокс игрока не самый узкий")
	return true


## Круг больше — попадание засчитывается дальше от центра. Это и есть вся
## система: снаряд против суммы двух радиусов. Тики считаны так, чтобы
## снаряд успел пройти мимо, а враг — не успел сойти с места.
func _test_bigger_body_is_hit_from_further() -> bool:
	var hit := PackedStringArray()
	for enemy_id in ["runner", "heavy"]:
		var state := Arena.duel(SEED, enemy_id, Vector2(34.0, 32.0))
		var enemy := Arena.enemies(state)[0]
		var before := enemy.health
		Arena.shoot(state, Vector2.RIGHT)
		Arena.coast(state, 4)
		if enemy.health < before:
			hit.append(enemy_id)

	eq(", ".join(hit), "heavy",
		"мимо на 32 пикселя задело не тех, кого надо: [%s]" % ", ".join(hit))
	return true


func _test_room_starts_populated() -> bool:
	var state := Arena.room(SEED, 1, 3)
	eq(Arena.players(state).size(), 1, "игрок не встал в комнату")
	eq(Arena.enemies(state).size(), 3, "враги не встали в комнату")
	check(not state.room_cleared(), "комната считается зачищенной, хотя враги живы")
	check(not state.party_down(), "группа считается павшей на старте")

	var ids := {}
	for actor in state.actors:
		check(not ids.has(actor.id), "два тела с одинаковым идентификатором")
		ids[actor.id] = true
	return true


func _test_firing_spawns_projectile_and_respects_rate() -> bool:
	var state := Arena.room(SEED, 1, 1)
	var shooter := state.actor_of_slot(0)
	var rate: float = shooter.stack.compute()["fire_rate"]

	Arena.hold(state, 1, Vector2.ZERO, Vector2.RIGHT, Arena.FIRE)
	eq(state.projectiles.size(), 1, "выстрел не породил снаряд")

	Arena.hold(state, int(30.0 / rate), Vector2.ZERO, Vector2.RIGHT, Arena.FIRE)
	eq(state.projectiles.size(), 1, "скорострельность не ограничивает стрельбу")
	return true


func _test_projectile_kills_enemy() -> bool:
	var state := Arena.room(SEED, 1, 1)
	var enemy := Arena.enemies(state)[0]
	var player := state.actor_of_slot(0)
	enemy.position = player.position + Vector2(80, 0)

	var before := enemy.health
	Arena.hold(state, 240, Vector2.ZERO, Vector2.RIGHT, Arena.FIRE)

	check(enemy.health < before, "враг не получил урона")
	check(not enemy.alive, "враг пережил четыре секунды обстрела в упор")
	check(state.room_cleared(), "комната не считается зачищенной после смерти врага")
	return true


func _test_corpse_stays() -> bool:
	var state := Arena.room(SEED, 1, 1)
	var enemy := Arena.enemies(state)[0]
	enemy.position = state.actor_of_slot(0).position + Vector2(80, 0)
	Arena.hold(state, 240, Vector2.ZERO, Vector2.RIGHT, Arena.FIRE)

	eq(state.actors.size(), 2, "труп исчез из мира — харвест органов станет невозможен")
	check(not state.actor_by_id(enemy.id).alive, "труп числится живым")
	return true


func _test_projectile_spares_the_shooter() -> bool:
	var state := Arena.room(SEED, 1, 1)
	var player := state.actor_of_slot(0)
	Arena.enemies(state)[0].position = Arena.FAR_AWAY
	var before := player.health

	Arena.hold(state, 120, Vector2.ZERO, Vector2.RIGHT, Arena.FIRE)
	almost_eq(player.health, before, "снаряд ранил того, кто его бросил", 1e-6)
	return true


func _test_projectile_expires() -> bool:
	var state := Arena.room(SEED, 1, 1)
	Arena.enemies(state)[0].position = Arena.FAR_AWAY
	var stats: Dictionary = state.actor_of_slot(0).stack.compute()
	var flight_ticks := int(stats["range"] / stats["projectile_speed"] * 60.0)

	Arena.hold(state, 1, Vector2.ZERO, Vector2.RIGHT, Arena.FIRE)
	eq(state.projectiles.size(), 1, "снаряд не появился")
	Arena.hold(state, flight_ticks + 5, Vector2.ZERO, Vector2.RIGHT)
	eq(state.projectiles.size(), 0, "снаряд не погас, пролетев свою дальность")
	return true


func _test_player_goes_down_not_dead() -> bool:
	var state := Arena.room(SEED, 1, 1)
	var player := state.actor_of_slot(0)
	var enemy := Arena.enemies(state)[0]
	enemy.position = player.position
	player.health = 1.0

	Arena.coast(state, 10)

	check(state.slots[0].downed, "игрок не упал, получив смертельный урон")
	check(player.alive, "игрок умер вместо падения")
	check(state.party_down(), "одиночное падение не закончило забег")
	return true


func _test_invulnerability_paces_touch_damage() -> bool:
	var state := Arena.room(SEED, 1, 1)
	var player := state.actor_of_slot(0)
	var enemy := Arena.enemies(state)[0]
	enemy.position = player.position
	var damage: float = enemy.stack.compute()["damage"]
	var before := player.health

	Arena.coast(state, 30)
	var taken := before - player.health
	check(taken <= damage * 2.0,
		"за полсекунды снято %.1f при уроне удара %.1f — неуязвимость не работает" % [taken, damage])
	check(taken > 0.0, "враг вплотную не нанёс урона вовсе")
	return true


func _test_enemies_ignore_the_downed() -> bool:
	var state := Arena.room(SEED, 2, 1)
	state.slots[0].downed = true
	var downed := state.actor_of_slot(0)
	var standing := state.actor_of_slot(1)
	var enemy := Arena.enemies(state)[0]
	downed.position = enemy.position + Vector2(30, 0)
	standing.position = enemy.position + Vector2(400, 0)

	Arena.coast(state, 60)

	check(enemy.position.x > downed.position.x,
		"враг пошёл к упавшему вместо стоящего")
	return true


func _test_bodies_stay_inside_the_room() -> bool:
	var state := Arena.room(SEED, 1, 1)
	Arena.hold(state, 600, Vector2(1, 1), Vector2.ZERO)
	var player := state.actor_of_slot(0)
	check(state.room.bounds.has_point(player.position),
		"тело вышло за стены комнаты: %s вне %s" % [player.position, state.room.bounds])
	return true
