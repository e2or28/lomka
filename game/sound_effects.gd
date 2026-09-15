extends Node

const NAMES := ["shot", "paper", "hit", "pickup", "harvest", "down", "revive", "wave", "door", "explosion"]
const SETTINGS := "user://settings.cfg"
var volume := 0.55
var streams := {}
var voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played := {}
var _room := ""
var _build := ""
var _heat := 0
var _initialized := false

func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS) == OK: volume = clampf(float(settings.get_value("audio", "effects", volume)), 0, 1)
	for key in NAMES:
		streams[key] = AudioStreamWAV.load_from_file("res://assets/audio/%s.wav" % key)
	for i in 12:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func set_volume(value: float) -> void:
	volume = clampf(value, 0, 1)
	for voice in voices: voice.volume_db = linear_to_db(volume * 0.55) if volume > 0 else -80
	var settings := ConfigFile.new()
	settings.load(SETTINGS)
	settings.set_value("audio", "effects", volume)
	settings.save(SETTINGS)

func play(key: String) -> void:
	if volume <= 0 or not streams.has(key) or voices.is_empty(): return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(key, -1000)) < 45: return
	_last_played[key] = now
	var voice := voices[_next_voice % voices.size()]
	_next_voice += 1
	voice.stream = streams[key]
	voice.volume_db = linear_to_db(volume * 0.55)
	voice.pitch_scale = 1.0 + float((_next_voice % 5) - 2) * 0.025
	voice.play()

func consume(state, events: Array, local_slot: int) -> void:
	if state == null: return
	for event in events:
		if event.get("room_id", state.room.id) != state.room.id: continue
		match event.get("type", ""):
			"shot": play("paper" if event.get("kind", "") == "folder" else "shot")
			"hit": play("down" if event.get("fallen", false) else "hit")
			"revived": play("revive")
			"explosion": play("explosion")
			"wave_warning": play("wave")
	var actor = state.actor_of_slot(local_slot)
	if actor == null: return
	var slot = state.slots[local_slot]
	var weapon: String = "suitcase" if slot.cover_ticks > 0 else actor.weapon_id
	var build := str([weapon, slot.items, slot.organs])
	if _initialized and _room == state.room.id and state.heat > _heat:
		play("harvest")
	elif _initialized and _room == state.room.id and build != _build:
		play("pickup")
	elif _initialized and _room != state.room.id:
		play("door")
	_build = build
	_heat = state.heat
	_room = state.room.id
	_initialized = true

func reset() -> void:
	_initialized = false
	for voice in voices: voice.stop()
