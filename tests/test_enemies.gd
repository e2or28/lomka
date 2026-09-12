extends "res://tests/framework/test_case.gd"
## Три типа врагов и их повадки.
##
## Класс: поведение, кроме последней пробы — она инвариант: повадка входит
## в состояние и обязана пережить сейв. Проверяется различие поведения,
## а не числа расстояний и сроков — те подобраны на глаз и будут двигаться.

const Arena = preload("res://tests/framework/arena.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Schemas = preload("res://sim/data/schemas.gd")

const SEED := "враги"


func title() -> String:
	return "враги"


func _test_bestiary_matches_schema() -> bool:
	no_errors(Bestiary.validate_all(), "записи бестиария не прошли схему")
	for id in ["test_monster", "runner", "heavy", "tandem", "oil_baron", "soldier", "soldier_dark", "ice_agent"]:
		check(Bestiary.ENEMIES.has(id), "потерян враг " + id)
	return true


func _test_every_enemy_declares_a_known_behaviour() -> bool:
	var wrong := PackedStringArray()
	for id in Bestiary.ENEMIES:
		var behaviour: String = Bestiary.ENEMIES[id].get("behaviour", "")
		if not Schemas.BEHAVIOURS.has(behaviour):
			wrong.append("%s: '%s'" % [id, behaviour])
	check(wrong.is_empty(), "неизвестные повадки: " + ", ".join(wrong))
	return true


func _test_behaviours_actually_differ() -> bool:
	var tracks := {}
	# Здесь различаются траектории преследователей; стрелки могут стоять
	# на месте, их предупреждение и попадания проверяет test_oil_baron.gd.
	for id in ["test_monster", "runner", "heavy"]:
		var state := Arena.duel(SEED, id, Vector2(260, 0))
		var enemy := Arena.enemies(state)[0]
		var path := PackedFloat32Array()
		for i in 180:
			Arena.coast(state, 1)
			path.append(snappedf(enemy.position.x, 0.5))
		tracks[id] = path

	var ids := tracks.keys()
	for a in ids.size():
		for b in range(a + 1, ids.size()):
			ne(tracks[ids[a]], tracks[ids[b]],
				"враги '%s' и '%s' движутся одинаково" % [ids[a], ids[b]])
	return true


func _test_everyone_can_reach_the_player() -> bool:
	for id in Bestiary.ENEMIES:
		# Обстановка не противник: бочка стоит и ждёт, пока в неё попадут.
		if Bestiary.ENEMIES[id].get("behaviour", "") == "prop":
			continue
		var state := Arena.duel(SEED, id, Vector2(320, 0))
		var player := state.actor_of_slot(0)
		var health := player.health
		Arena.coast(state, 600)
		check(player.health < health or state.slots[0].downed,
			"враг '%s' за десять секунд так и не достал игрока" % id)
	return true


func _test_harrier_backs_off() -> bool:
	var state := Arena.duel(SEED, "runner", Vector2(300, 0))
	var enemy := Arena.enemies(state)[0]

	var closest := INF
	var retreated := false
	var previous := enemy.position.x
	for i in 240:
		Arena.coast(state, 1)
		closest = minf(closest, absf(enemy.position.x))
		if enemy.position.x > previous + 0.5:
			retreated = true
		previous = enemy.position.x

	check(closest < 120.0, "курьер не подошёл близко ни разу")
	check(retreated, "курьер ни разу не отошёл — повадка не отличается от лобовой")
	return true


func _test_bruiser_never_retreats() -> bool:
	var state := Arena.duel(SEED, "heavy", Vector2(300, 0))
	var enemy := Arena.enemies(state)[0]

	var previous := enemy.position.x
	var backward := 0
	for i in 240:
		Arena.coast(state, 1)
		if enemy.position.x > previous + 1.0:
			backward += 1
		previous = enemy.position.x
	eq(backward, 0, "начальник пятился — повадка совпала с курьером")
	return true


func _test_room_mixes_the_roster() -> bool:
	var state := Arena.room(SEED, 1, 3)
	var kinds := {}
	for enemy in Arena.enemies(state):
		kinds[enemy.archetype] = true
	eq(kinds.size(), 3, "в комнате не все три типа врагов")
	return true


func _test_behaviour_survives_a_save() -> bool:
	var state := Arena.room(SEED, 1, 3)
	var loaded := Arena.after_save(state)
	check(loaded != null, "забег не загрузился")
	if loaded == null:
		return true
	var before := PackedStringArray()
	for enemy in Arena.enemies(state):
		before.append(enemy.behaviour)
	var after := PackedStringArray()
	for enemy in Arena.enemies(loaded):
		after.append(enemy.behaviour)
	eq(after, before, "повадки врагов не пережили сейв")
	return true
