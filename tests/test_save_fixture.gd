extends "res://tests/framework/test_case.gd"
## Эталонный сейв с диска. Ловит то, чего не ловит круговорот в памяти:
## изменение формата.
##
## Круговорот проверяет, что сегодняшний код читает сегодняшний сейв. Он
## останется зелёным, даже если поменять формат целиком — просто обе стороны
## поменяются вместе. А забег игрока, начатый на прошлой неделе, после этого
## не откроется, и узнается это из отзыва в Steam.
##
## Фикстура лежит в гите и не меняется. Покраснел тест — либо чинить код,
## либо поднимать SaveGame.FORMAT и писать миграцию, либо (осознанно)
## пересобирать эталон через tools/gen_fixture.sh. Молча третий путь
## выбирать нельзя.

const SaveGame = preload("res://sim/save/save_game.gd")
const ReferenceRun = preload("res://tests/framework/reference_run.gd")
const RngStreams = preload("res://sim/core/rng_streams.gd")
const Actor = preload("res://sim/actor.gd")

const FIXTURE_PATH := "res://tests/fixtures/save_format_5.bin"


func title() -> String:
	return "эталонный сейв"


func _test_fixture_exists() -> bool:
	check(FileAccess.file_exists(FIXTURE_PATH),
		"нет эталонного сейва %s — собери tools/gen_fixture.sh" % FIXTURE_PATH)
	return true


func _test_format_did_not_drift() -> bool:
	if not FileAccess.file_exists(FIXTURE_PATH):
		fail("нет эталонного сейва, сверять не с чем")
		return true

	var on_disk := FileAccess.get_file_as_bytes(FIXTURE_PATH)
	var today := SaveGame.to_bytes(ReferenceRun.build())
	bytes_eq(today, on_disk,
		"формат сейва разошёлся с эталоном — поднимай SaveGame.FORMAT и пиши миграцию, либо чини код")
	return true


func _test_fixture_loads_and_makes_sense() -> bool:
	if not FileAccess.file_exists(FIXTURE_PATH):
		fail("нет эталонного сейва, загружать нечего")
		return true

	var loaded = SaveGame.load_from_file(FIXTURE_PATH)
	check(loaded != null, "эталонный сейв не загрузился")
	if loaded == null:
		return true

	eq(loaded.run_seed, ReferenceRun.SEED, "сид забега прочитался не тот")
	eq(loaded.zone_index, 2, "номер зоны прочитался не тот")
	eq(loaded.tick, 4321, "номер тика прочитался не тот")
	eq(loaded.occupied_count(), 2, "состав слотов прочитался не тот")
	eq(loaded.slots[0].character_id, "clerk", "персонаж первого слота прочитался не тот")
	eq(loaded.actor_of_slot(0).position, Vector2(128.5, -64.25), "позиция тела прочиталась не та")
	eq(loaded.actor_of_slot(0).velocity, Vector2(-12.0, 3.5), "скорость тела прочиталась не та")
	# Три от предметов плюс четыре от чемодана
	eq(loaded.actor_of_slot(0).stack.size(), 9, "модификаторы прочитались не все")
	eq(loaded.actor_of_slot(0).weapon_id, "suitcase", "оружие в руках прочиталось не то")
	eq(loaded.slots[1].downed, true, "признак падения прочитался не тот")
	eq(loaded.living(Actor.Kind.ENEMY).size(), 2, "враги прочитались не все")
	eq(loaded.projectiles.size(), 1, "снаряд в полёте потерян")
	return true


## Отпечаток эталона зафиксирован числом. Если он поехал, а байты совпали —
## значит поехал сам state_hash, и все сверки хоста с клиентом врут.
func _test_state_hash_is_stable() -> bool:
	eq(ReferenceRun.build().state_hash(), 3425943865796113033,
		"отпечаток эталонного состояния поехал — сверка хоста с клиентом сломана")
	return true


## Стек модификаторов из эталона обязан считаться так же, как считался.
## Порядок фаз — часть контракта не меньше, чем формат байтов.
func _test_computed_stats_are_stable() -> bool:
	var stats: Dictionary = ReferenceRun.build().actor_of_slot(0).stack.compute()
	almost_eq(stats["move_speed"], 299.0, "скорость посчиталась иначе: 260 * 1.15")
	almost_eq(stats["health"], 66.0, "здоровье посчиталось иначе: SET должен победить")
	almost_eq(stats["damage"], 16.0, "урон посчитался иначе: 12 базовых плюс 4")
	return true
