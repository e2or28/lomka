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

const FIXTURE_PATH := "res://tests/fixtures/save_format_1.bin"


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
	eq(loaded.slots[0].character_id, "khimik", "персонаж первого слота прочитался не тот")
	eq(loaded.slots[0].position, Vector2(128.5, -64.25), "позиция первого слота прочиталась не та")
	eq(loaded.slots[0].velocity, Vector2(-12.0, 3.5), "скорость первого слота прочиталась не та")
	eq(loaded.slots[0].stack.size(), 3, "модификаторы первого слота прочитались не все")
	eq(loaded.slots[1].downed, true, "признак падения прочитался не тот")
	return true


## Отпечаток эталона зафиксирован числом. Если он поехал, а байты совпали —
## значит поехал сам state_hash, и все сверки хоста с клиентом врут.
func _test_state_hash_is_stable() -> bool:
	eq(ReferenceRun.build().state_hash(), -2398982469003510750,
		"отпечаток эталонного состояния поехал — сверка хоста с клиентом сломана")
	return true


## Стек модификаторов из эталона обязан считаться так же, как считался.
## Порядок фаз — часть контракта не меньше, чем формат байтов.
func _test_computed_stats_are_stable() -> bool:
	var stats := ReferenceRun.build().slots[0].stack.compute()
	almost_eq(stats["move_speed"], 253.0, "скорость посчиталась иначе: (220) * 1.15")
	almost_eq(stats["health"], 66.0, "здоровье посчиталось иначе: SET должен победить")
	almost_eq(stats["damage"], 4.0, "урон посчитался иначе: стат вне базы начинается с нуля")
	return true
