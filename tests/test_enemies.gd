extends "res://tests/framework/test_case.gd"
## Три типа врагов и их повадки.
##
## Различаться врагам положено поведением, а не числами: одинаковые по
## повадкам противники в толпе не читаются, сколько бы у них ни было
## разного здоровья. Поэтому проверяется именно движение, а не статы.
##
## Повадки детерминированы от расстояния и номера тика — случайности в них
## нет намеренно: лишний бросок сдвинул бы поток AI_SPREAD и
## рассинхронизировал забег.

const Encounter = preload("res://sim/encounter.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const Actor = preload("res://sim/actor.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Schemas = preload("res://sim/data/schemas.gd")
const RunState = preload("res://sim/run_state.gd")

const SEED := "враги"


func title() -> String:
	return "враги"


func _idle(state: RunState, ticks: int) -> void:
	for i in ticks:
		SimTick.step(state, {0: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO)})


## Один враг заданного типа на известном расстоянии от неподвижного игрока.
func _duel(enemy_id: String, offset: Vector2) -> Array:
	var state := Encounter.dev_room(SEED, 1, 0)
	var player := state.actor_of_slot(0)
	player.position = Vector2.ZERO
	var enemy := Encounter.add_enemy(state, enemy_id, offset)
	return [state, player, enemy]


func _test_bestiary_matches_schema() -> bool:
	no_errors(Bestiary.validate_all(), "записи бестиария не прошли схему")
	eq(Bestiary.ENEMIES.size(), 3, "врагов не три — M1 требует три типа")
	return true


## Повадки закрыты списком: опечатка иначе даёт врага, молча стоящего
## на месте.
func _test_every_enemy_declares_a_known_behaviour() -> bool:
	var wrong := PackedStringArray()
	for id in Bestiary.ENEMIES:
		var behaviour: String = Bestiary.ENEMIES[id].get("behaviour", "")
		if not Schemas.BEHAVIOURS.has(behaviour):
			wrong.append("%s: '%s'" % [id, behaviour])
	check(wrong.is_empty(), "неизвестные повадки: " + ", ".join(wrong))
	return true


## Разные повадки — разное поведение. Если траектории совпадают, врагов
## по-прежнему один, просто с тремя именами.
func _test_behaviours_actually_differ() -> bool:
	var tracks := {}
	for id in Bestiary.ENEMIES:
		var duel := _duel(id, Vector2(260, 0))
		var state: RunState = duel[0]
		var enemy: Actor = duel[2]
		var path := PackedFloat32Array()
		for i in 180:
			_idle(state, 1)
			path.append(snappedf(enemy.position.x, 0.5))
		tracks[id] = path

	var ids := tracks.keys()
	for a in ids.size():
		for b in range(a + 1, ids.size()):
			ne(tracks[ids[a]], tracks[ids[b]],
				"враги '%s' и '%s' движутся одинаково" % [ids[a], ids[b]])
	return true


## Все трое обязаны доходить до игрока: враг, который не может ударить,
## не враг.
func _test_everyone_can_reach_the_player() -> bool:
	for id in Bestiary.ENEMIES:
		var duel := _duel(id, Vector2(320, 0))
		var state: RunState = duel[0]
		var player: Actor = duel[1]
		var enemy: Actor = duel[2]
		var health := player.health
		_idle(state, 600)
		check(player.health < health or state.slots[0].downed,
			"враг '%s' за десять секунд так и не достал игрока" % id)
	return true


## Курьер налетает и отходит — иначе от него можно отстреливаться стоя.
func _test_harrier_backs_off() -> bool:
	var duel := _duel("runner", Vector2(300, 0))
	var state: RunState = duel[0]
	var enemy: Actor = duel[2]

	var closest := INF
	var retreated := false
	var previous := enemy.position.x
	for i in 240:
		_idle(state, 1)
		closest = minf(closest, absf(enemy.position.x))
		if enemy.position.x > previous + 0.5:
			retreated = true
		previous = enemy.position.x

	check(closest < 120.0, "курьер не подошёл близко ни разу")
	check(retreated, "курьер ни разу не отошёл — повадка не отличается от лобовой")
	return true


## Начальник прёт напролом и не пятится.
func _test_bruiser_never_retreats() -> bool:
	var duel := _duel("heavy", Vector2(300, 0))
	var state: RunState = duel[0]
	var enemy: Actor = duel[2]

	var previous := enemy.position.x
	var backward := 0
	for i in 240:
		_idle(state, 1)
		if enemy.position.x > previous + 1.0:
			backward += 1
		previous = enemy.position.x
	eq(backward, 0, "начальник пятился — повадка совпала с курьером")
	return true


## Комната ставит всех троих: разница в повадках видна только вместе.
func _test_room_mixes_the_roster() -> bool:
	var state := Encounter.dev_room(SEED, 1, 3)
	var kinds := {}
	for enemy in state.living(Actor.Kind.ENEMY):
		kinds[enemy.archetype] = true
	eq(kinds.size(), 3, "в комнате не все три типа врагов")
	return true


func _test_behaviour_survives_a_save() -> bool:
	var SaveGame = preload("res://sim/save/save_game.gd")
	var state := Encounter.dev_room(SEED, 1, 3)
	var loaded = SaveGame.from_bytes(SaveGame.to_bytes(state))
	check(loaded != null, "забег не загрузился")
	if loaded == null:
		return true
	var before := PackedStringArray()
	for enemy in state.living(Actor.Kind.ENEMY):
		before.append(enemy.behaviour)
	var after := PackedStringArray()
	for enemy in loaded.living(Actor.Kind.ENEMY):
		after.append(enemy.behaviour)
	eq(after, before, "повадки врагов не пережили сейв")
	return true
