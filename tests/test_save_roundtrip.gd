extends "res://tests/framework/test_case.gd"
## Обязательный тест номер два: сохранить, загрузить, сравнить побайтово.
##
## Риск из docs/PLAN.md: ошибки сериализации не падают, а проявляются как
## «после загрузки что-то не так» — через неделю и не там, где сломалось.
## Побайтовое сравнение ловит их в момент появления.
##
## Проверяется три круга: память -> байты -> память -> байты, круг через
## файл, и смысловой круг — позиции потоков случайности обязаны продолжаться
## с того же места, а не начинаться заново.

const RunState = preload("res://sim/run_state.gd")
const Encounter = preload("res://sim/encounter.gd")
const Actor = preload("res://sim/actor.gd")
const SaveGame = preload("res://sim/save/save_game.gd")
const RngStreams = preload("res://sim/core/rng_streams.gd")
const Modifier = preload("res://sim/core/modifier.gd")

const SAVE_PATH := "user://test_save_roundtrip.sav"


func title() -> String:
	return "круговорот сейва"




## Забег в середине: слоты заняты, кто-то упал, предметы в стеках,
## потоки случайности вычерпаны по-разному.
func _make_state() -> RunState:
	var state := Encounter.dev_room("забег-сейв-7", 2, 2)
	state.zone_index = 2

	var first := state.actor_of_slot(0)
	first.stack.add(Modifier.make("damage", Modifier.Op.ADD, 4.0, "item:shprits", "m1"))
	first.stack.add(Modifier.make("damage", Modifier.Op.MUL, 1.5, "item:pechen", "m2"))
	first.stack.add(Modifier.make("health", Modifier.Op.ADD, 25.0, "organ:serdce", "m3"))

	state.slots[1].downed = true
	state.actor_of_slot(1).health = 0.0

	# Потоки вычерпаны неравномерно — как в живом забеге.
	for i in 37:
		state.rng.stream(RngStreams.LOOT_PLACEMENT).randi()
	for i in 11:
		state.rng.stream(RngStreams.ORGAN_DROP).randi()

	return state


func _test_empty_run_roundtrip() -> bool:
	var state := RunState.new("пустой")
	var bytes := SaveGame.to_bytes(state)
	var loaded = SaveGame.from_bytes(bytes)
	check(loaded != null, "пустой забег не загрузился")
	if loaded == null:
		return true
	bytes_eq(SaveGame.to_bytes(loaded), bytes, "пустой забег не совпал побайтово")
	eq(loaded.occupied_count(), 0, "в пустом забеге взялись занятые слоты")
	return true


func _test_played_run_roundtrip() -> bool:
	var state := _make_state()
	var bytes := SaveGame.to_bytes(state)

	var loaded = SaveGame.from_bytes(bytes)
	check(loaded != null, "забег не загрузился")
	if loaded == null:
		return true

	bytes_eq(SaveGame.to_bytes(loaded), bytes, "забег не совпал побайтово после круга через память")

	eq(loaded.run_seed, state.run_seed, "сид забега потерян")
	eq(loaded.zone_index, state.zone_index, "номер зоны потерян")
	eq(loaded.occupied_count(), 2, "состав слотов потерян")
	eq(loaded.slots[1].downed, true, "признак падения потерян")
	eq(loaded.slots[0].character_id, "clerk", "выбранный персонаж потерян")
	eq(loaded.actor_of_slot(0).stack.compute(), state.actor_of_slot(0).stack.compute(),
		"стек модификаторов посчитался иначе")
	eq(loaded.actor_of_slot(0).stack.size(), 9, "модификаторы потеряны")
	eq(loaded.actor_of_slot(0).weapon_id, "suitcase", "оружие в руках потеряно")
	eq(loaded.actors.size(), state.actors.size(), "тела потеряны")
	eq(loaded.living(Actor.Kind.ENEMY).size(), 2, "враги потеряны")
	eq(loaded.next_id, state.next_id, "счётчик идентификаторов поехал")
	return true


func _test_file_roundtrip() -> bool:
	var state := _make_state()
	var bytes := SaveGame.to_bytes(state)

	eq(SaveGame.save_to_file(state, SAVE_PATH), OK, "сейв не записался на диск")

	var from_disk = SaveGame.load_from_file(SAVE_PATH)
	check(from_disk != null, "сейв не прочитался с диска")
	if from_disk != null:
		bytes_eq(SaveGame.to_bytes(from_disk), bytes, "сейв не совпал побайтово после круга через файл")

	var raw := FileAccess.get_file_as_bytes(SAVE_PATH)
	bytes_eq(raw, bytes, "на диске лежат не те байты, что отдаёт to_bytes")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	return true


## Смысл сейва не в байтах, а в том, что забег продолжается тот же самый.
## Позиции потоков обязаны пережить загрузку: иначе после «продолжить»
## лут ляжет заново и забег превратится в другой.
func _test_rng_positions_survive() -> bool:
	var state := _make_state()
	var bytes := SaveGame.to_bytes(state)
	var loaded = SaveGame.from_bytes(bytes)
	if loaded == null:
		fail("забег не загрузился, позиции потоков не проверить")
		return true

	for name in RngStreams.DECLARED:
		var expected: Array = []
		var actual: Array = []
		for i in 5:
			expected.append(state.rng.stream(name).randi())
			actual.append(loaded.rng.stream(name).randi())
		eq(actual, expected, "поток '%s' после загрузки пошёл не с того места" % name)
	return true


func _test_rejects_foreign_bytes() -> bool:
	print("             (ниже два ожидаемых ERROR: так выглядит отбраковка чужого файла)")
	var junk := var_to_bytes({"magic": "NOT_LOMKA", "format": 1, "state": {}})
	eq(SaveGame.from_bytes(junk), null, "чужой файл принят за сейв")

	var future := var_to_bytes({"magic": SaveGame.MAGIC, "format": SaveGame.FORMAT + 1, "state": {}})
	eq(SaveGame.from_bytes(future), null, "сейв будущей версии принят как свой")
	return true
