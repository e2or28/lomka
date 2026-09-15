extends "res://tests/framework/test_case.gd"
## Класс: поведение. Звуки отличают извлечение/подбор от временной смены оружия.
const Arena = preload("res://tests/framework/arena.gd")
const Abilities = preload("res://sim/abilities.gd")
const Arsenal = preload("res://sim/arsenal.gd")

class Recorder extends "res://game/sound_effects.gd":
	var played: Array[String] = []
	func play(key: String) -> void: played.append(key)

func title() -> String:
	return "звуки действий"

func _test_cover_does_not_sound_like_a_pickup() -> bool:
	var state := Arena.solo("sound-cover")
	var sounds := Recorder.new()
	Arsenal.equip(state.actor_of_slot(0), "suitcase")
	sounds.consume(state, [], 0)
	check(Abilities.activate(state, state.slots[0]), "укрытие не поставилось")
	sounds.consume(state, [], 0)
	Abilities.finish(state, state.slots[0])
	sounds.consume(state, [], 0)
	check(sounds.played.is_empty(), "укрытие звучит как подбор оружия")
	Arsenal.equip(state.actor_of_slot(0), "colt")
	sounds.consume(state, [], 0)
	eq(sounds.played, ["pickup"], "настоящая смена оружия осталась без звука")
	sounds.free()
	return true

func _test_repeated_harvest_and_network_events_make_sound() -> bool:
	var state := Arena.solo("sound-harvest")
	var sounds := Recorder.new()
	sounds.consume(state, [], 0)
	state.heat += 10
	sounds.consume(state, [], 0)
	sounds.consume(state, [], 0)
	eq(sounds.played, ["harvest"], "повторное извлечение молчит или дублируется")
	sounds.consume(state, [{"type": "revived", "room_id": ""},
		{"type": "wave_warning", "room_id": ""}, {"type": "shot", "room_id": "old-room"}], 0)
	eq(sounds.played, ["harvest", "revive", "wave"], "сетевые события потеряли звук или протекли между комнатами")
	sounds.free()
	return true

func _test_explosion_event_uses_its_own_sound_in_current_room() -> bool:
	var state := Arena.solo("explosion-audio")
	var sounds := Recorder.new()
	sounds.consume(state, [{"type": "explosion", "room_id": state.room.id}, {"type": "explosion", "room_id": "elsewhere"}], 0)
	eq(sounds.played, ["explosion"], "взрыв молчит или слышен из другой комнаты")
	var audio := AudioStreamWAV.load_from_file("res://assets/audio/explosion.wav")
	check(audio != null and audio.get_length() > 1.0, "нет хвоста звука взрыва")
	sounds.free()
	return true
