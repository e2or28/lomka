extends Node2D
## Стенд разработчика: окно в симуляцию, а не игра. Логики боя здесь нет ни
## строки — она в sim/ и проверяется тестами без окна.
##
## Правило 2 буквально: снизу вверх связь есть, сверху вниз — только
## команды. Удалить game/ целиком можно в любой момент, tools/test.sh
## останется зелёным.

const RunState = preload("res://sim/run_state.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const Encounter = preload("res://sim/encounter.gd")
const RoomTravel = preload("res://sim/room_travel.gd")
const Actor = preload("res://sim/actor.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const InputReader = preload("res://game/input_reader.gd")
const InputMapDef = preload("res://tools/input_map.gd")
const WorldView = preload("res://game/world_view.gd")
const Abilities = preload("res://sim/abilities.gd")
const ArtLibrary = preload("res://game/art_library.gd")
const DebugOverlay = preload("res://game/debug_overlay.gd")
const ScaleReference = preload("res://game/scale_reference.gd")
const OrganHud = preload("res://game/organ_hud.gd")
const NetworkSession = preload("res://game/network_session.gd")
const LobbyPanel = preload("res://game/lobby_panel.gd")
const SoundEffects = preload("res://game/sound_effects.gd")

## Нет файла в art/ — рисуется заглушка. Положи PNG с таким именем, нажми 4.
const SPRITES: Array[String] = [
	"player", "player_side_stand",
	"player_side_walk_1", "player_side_walk_2", "player_side_walk_3",
	"player_side_walk_4", "player_side_walk_5", "player_side_walk_6",
	"player_colt_stand", "player_colt_front",
	"player_colt_walk_1", "player_colt_walk_2", "player_colt_walk_3",
	"player_colt_walk_4", "player_colt_walk_5", "player_colt_walk_6",
	"monster", "test_monster", "runner", "heavy", "folder", "bullet", "suitcase", "colt", "colt_top", "colt_ground",
	"courier_heart", "armored_spine",
	"room_start", "room_center", "room_north", "room_south", "room_west", "room_east", "tandem",
]

const SEED := "стенд"

## Куда встаёт заказанный монстр: перед игроком, по направлению прицела.
const SPAWN_REACH := 240.0

var _state: RunState = null
var _view: WorldView = null
var _art: ArtLibrary = null
var _overlay: DebugOverlay = null
var _scale_ref: ScaleReference = null
var _organ_hud: OrganHud = null
var _network: NetworkSession
var _lobby: LobbyPanel
var _sounds: SoundEffects

var _active_slots := 1
var _origin := Vector2.ZERO
var _art_note := ""
var _art_note_left := 0.0

var _drift := Vector2.ZERO
var _idle_ticks := 0


func _ready() -> void:
	_art = ArtLibrary.new()

	_view = WorldView.new()
	add_child(_view)

	_scale_ref = ScaleReference.new()
	add_child(_scale_ref)

	_overlay = DebugOverlay.new()
	_overlay.visible = false
	_overlay.stat_changed.connect(_on_stat_changed)
	add_child(_overlay)
	_view.show_hitboxes = _overlay.visible
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	_organ_hud = OrganHud.new()
	hud_layer.add_child(_organ_hud)
	_sounds = SoundEffects.new()
	add_child(_sounds)
	_network = NetworkSession.new()
	_network.name = "NetworkSession"
	add_child(_network)
	_network.state_changed.connect(_accept_network_state)
	_network.ended.connect(func(): _active_slots = 1; _reset())
	_lobby = LobbyPanel.new()
	_lobby.session = _network
	add_child(_lobby)
	_lobby.volume.set_value_no_signal(_sounds.volume * 100)
	_lobby.volume_changed.connect(_sounds.set_volume)

	_reload_art()
	_reset()
	_overlay.sync_from_stats(_state.actor_of_slot(0).stack.compute())
	get_viewport().size_changed.connect(_recenter)
	_recenter()


func _reset() -> void:
	_state = RoomTravel.start("%s/%d" % [SEED, Time.get_ticks_usec()], _active_slots)
	_view.state = _state
	_view.inspected_slot = 0
	_view.keyboard_slot = 0
	_organ_hud.state = _state
	_organ_hud.player_index = 0
	_organ_hud.keyboard_slot = 0
	_organ_hud.network_mode = false
	_organ_hud.can_restart = true
	_sounds.reset()


func _accept_network_state(state: RunState, events: Array) -> void:
	_state = state
	_view.state = state
	_view.inspected_slot = _network.local_slot
	_view.keyboard_slot = _network.local_slot
	_organ_hud.state = state
	_organ_hud.player_index = _network.local_slot
	_organ_hud.keyboard_slot = _network.local_slot
	_organ_hud.network_mode = true
	_organ_hud.can_restart = _network.is_host()
	_view.consume_events(events)
	_sounds.consume(state, events, _network.local_slot)


func _recenter() -> void:
	_origin = _view.centering_origin(get_viewport_rect().size)
	_view.origin = _origin
	_scale_ref.queue_redraw()


func _physics_process(_delta: float) -> void:
	if _network.active:
		if _network.running:
			var command = InputReader.read(0, _state.tick)
			if _lobby.is_open(): command = Command.from_axes(_state.tick, Vector2.ZERO, Vector2.ZERO)
			_network.step(command)
			var actor := _state.actor_of_slot(_network.local_slot)
			if actor != null: _view.firing[actor.id] = command.pressed(Command.BTN_FIRE)
		return
	if _lobby.is_open(): return
	var commands := {}
	for i in _active_slots:
		var command: Command = InputReader.read(i, _state.tick)
		commands[i] = command
	var events := SimTick.step(_state, commands)
	_watch_drift(commands)

	for i in _active_slots:
		var slot := _state.slots[i]
		if commands.has(i) and slot.actor_id >= 0:
			_view.firing[slot.actor_id] = commands[i].pressed(Command.BTN_FIRE)
	_view.consume_events(events)
	_sounds.consume(_state, events, _organ_hud.player_index)



## Ползёт при отпущенном вводе почти всегда изношенный стик, а не ошибка
## в коде — стенд показывает это прямо, а не заставляет гадать.
func _watch_drift(commands: Dictionary) -> void:
	if not commands.has(0):
		return
	var move: Vector2 = commands[0].move_vector()
	if move == Vector2.ZERO:
		_idle_ticks += 1
		if _idle_ticks > 60:
			_drift = Vector2.ZERO
		return

	var keys_held := false
	for action in InputReader.MOVE_ACTIONS:
		if Input.is_action_pressed(InputMapDef.action_name(0, action)):
			keys_held = true
			break
	_idle_ticks = 0
	if not keys_held:
		_drift = move


func _process(delta: float) -> void:
	_recenter()
	_view.advance(delta)
	_view.queue_redraw()

	if _art_note_left > 0.0:
		_art_note_left -= delta
		if _art_note_left <= 0.0:
			_art_note = ""

	# Отпечаток сериализует весь мир: скрытая диагностика не должна
	# оплачивать эту работу на каждом кадре.
	if _overlay.visible:
		_overlay.set_text(_readout())


func _readout() -> String:
	var lines: Array[String] = []
	lines.append("СТЕНД · комната разработчиков · тик %d · %d кадр/с" % [
		_state.tick, Engine.get_frames_per_second()])
	lines.append("сид «%s» · отпечаток %d" % [_state.run_seed, _state.state_hash()])

	var alive := _state.living(Actor.Kind.ENEMY).size()
	lines.append("врагов живо %d из %d · снарядов в воздухе %d%s" % [
		alive, _state.actors.size() - _active_slots, _state.projectiles.size(),
		"  · КОМНАТА ЗАЧИЩЕНА" if _state.room_cleared() else ""])
	if _state.party_down():
		lines.append("ГРУППА ПАЛА — R для сброса")
	lines.append("")

	for i in _active_slots:
		var actor := _state.actor_of_slot(i)
		if actor == null:
			continue
		var stats := actor.stack.compute()
		lines.append("p%d  %3.0f/%3.0f хп   поз %6.1f %6.1f   |v| %5.1f%s" % [
			i + 1, actor.health, actor.max_health(),
			actor.position.x, actor.position.y, actor.velocity.length(),
			"   УПАЛ" if _state.slots[i].downed else ""])
		lines.append("    урон %.0f · темп %.1f/с · дальность %.0f · скорость %.0f" % [
			stats.get("damage", 0.0), stats.get("fire_rate", 0.0),
			stats.get("range", 0.0), stats.get("move_speed", 0.0)])

	lines.append("прицел: четыре направления, стрелками, как в Isaac")
	lines.append("")
	for line in InputReader.diagnostics(0):
		lines.append(line)

	lines.append("")
	var missing := PackedStringArray()
	for name in SPRITES:
		if not _art.has(name):
			missing.append(name + ".png")
	lines.append("art/: " + ("всё на месте" if missing.is_empty()
		else "нет " + ", ".join(missing) + " — рисую заглушки"))
	if _art_note != "":
		lines.append(_art_note)
	if _drift != Vector2.ZERO:
		lines.append("ДРЕЙФ: при отпущенном вводе тело едет (%+.3f %+.3f)" % [_drift.x, _drift.y])

	return "\n".join(lines)


func _on_stat_changed(stat: String, value: float) -> void:
	if _network.active: return
	for actor in _state.actors:
		if actor.kind == Actor.Kind.PLAYER:
			actor.stack.base[stat] = value


## Порядок нажатия стрелок нужен вводу, а _unhandled_input для этого не
## годится: событие, съеденное ползунками, сюда не дойдёт, и клавиша
## останется в стеке зажатой навсегда.
func _input(event: InputEvent) -> void:
	InputReader.feed(event)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# На кириллице event.keycode нулевой — см. «Ловушки» в CLAUDE.md.
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if _lobby.is_open():
		if code == KEY_ESCAPE: _lobby.panel.hide()
		return
	if _network.active:
		if code == KEY_ESCAPE:
			_lobby.toggle()
		elif code == KEY_R and _network.is_host():
			_network.restart()
		elif code == KEY_4:
			_reload_art()
		return

	# Цифры, а не F-клавиши: на ноутбуке те лежат под Fn, и одной рукой
	# на них не попасть. Спавн ушёл под Shift, чтобы освободить ряд.
	if code >= KEY_1 and code <= KEY_9 and event.shift_pressed:
		_spawn_enemy(code - KEY_1)
		return

	match code:
		KEY_1:
			_overlay.visible = not _overlay.visible
			_view.show_hitboxes = _overlay.visible
		KEY_2:
			_overlay.toggle_knobs()
		KEY_3:
			_scale_ref.enabled = not _scale_ref.enabled
			_scale_ref.queue_redraw()
		KEY_4:
			_reload_art()
		KEY_TAB:
			_active_slots = _active_slots % RunState.MAX_PLAYERS + 1
			_reset()
		KEY_Q:
			_next_weapon()
		KEY_V:
			_organ_hud.player_index = (_organ_hud.player_index + 1) % _active_slots
			_view.inspected_slot = _organ_hud.player_index
		KEY_0:
			_clear_enemies()
		KEY_R:
			_reset()
		KEY_ESCAPE:
			get_tree().quit()


## Тела рождаются вне тика намеренно: тик — чистая функция от состояния и
## команд, и спавн изнутри него сделал бы забег невоспроизводимым по
## журналу (sim/encounter.gd). Стенд журнал не проигрывает, ему можно.
func _spawn_enemy(index: int) -> void:
	var ids := Bestiary.ENEMIES.keys()
	ids.sort()
	if index >= ids.size():
		return

	var id: String = ids[index]
	var player := _state.actor_of_slot(0)
	var at := _state.room.bounds.get_center()
	if player != null:
		at = player.position + player.aim * SPAWN_REACH
	var enemy := Encounter.add_enemy(_state, id, at)
	enemy.position = _state.room.clamp_body(enemy.position, enemy.radius)

	_art_note = "спавн %d: %s · хитбокс %.0f" % [
		index + 1, Bestiary.enemy(id).get("name", id), enemy.radius]
	_art_note_left = 2.0


## Трупы уходят вместе с живыми: пустая комната нужна, чтобы смотреть на
## одного монстра, а R вернул бы стартовую тройку.
func _clear_enemies() -> void:
	var surviving: Array[Actor] = []
	for actor in _state.actors:
		if actor.kind != Actor.Kind.ENEMY:
			surviving.append(actor)
	_state.actors = surviving
	_art_note = "врагов убрано, комната пуста"
	_art_note_left = 2.0


## Порядок берётся из реестра: третий ствол должен появиться на стенде сам,
## не дожидаясь правки списком здесь.
func _next_weapon() -> void:
	var ids := Arsenal.WEAPONS.keys()
	ids.sort()
	if ids.is_empty():
		return

	var note := PackedStringArray()
	for actor in _state.living(Actor.Kind.PLAYER):
		# Иначе чемодан оказался бы разом и в руках, и укрытием на полу.
		Abilities.finish(_state, _state.slots[actor.slot])
		var index := ids.find(actor.weapon_id)
		var next: String = ids[(index + 1) % ids.size()]
		if Arsenal.equip(actor, next):
			note.append(Arsenal.weapon(next).get("name", next))
	if not note.is_empty():
		_art_note = "оружие: " + ", ".join(note)
		_art_note_left = 2.0


func _reload_art() -> void:
	_art.reload_all()
	var loaded := PackedStringArray()
	for name in SPRITES:
		var texture := _art.get_texture(name)
		_view.textures[name] = texture
		if texture != null:
			loaded.append(name)
	_art_note = "art/ перечитан: " + ("нет ни одного спрайта" if loaded.is_empty()
		else ", ".join(loaded))
	_art_note_left = 2.5
