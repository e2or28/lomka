extends Node2D
## Стенд разработчика. Это не игра, а окно в симуляцию, чтобы её можно было
## щупать руками.
##
## Сейчас в нём комната разработчиков: служащий кидается папками с
## документами в манекенов. Логики боя здесь нет ни строки — она в sim/ и
## проверяется тестами без окна. Здесь только чтение ввода, отрисовка и
## ползунки.
##
## Правило 2 соблюдается буквально: снизу вверх связь есть, сверху вниз —
## только команды. Удалить каталог game/ целиком можно в любой момент,
## tools/test.sh останется зелёным.

const RunState = preload("res://sim/run_state.gd")
const SimTick = preload("res://sim/tick.gd")
const Motion = preload("res://sim/motion.gd")
const Command = preload("res://sim/input/command.gd")
const CommandLog = preload("res://sim/input/command_log.gd")
const Encounter = preload("res://sim/encounter.gd")
const Actor = preload("res://sim/actor.gd")
const InputReader = preload("res://game/input_reader.gd")
const InputMapDef = preload("res://tools/input_map.gd")
const WorldView = preload("res://game/world_view.gd")
const ArtLibrary = preload("res://game/art_library.gd")
const DebugOverlay = preload("res://game/debug_overlay.gd")
const ScaleReference = preload("res://game/scale_reference.gd")

## Спрайты, которые стенд ищет в art/. Нет файла — рисуется заглушка.
## Положи PNG с таким именем и нажми F5.
## Персонаж собран из слоёв — см. art/player_layers.json. Монстр и папка
## пока заглушки из tools/make_placeholder_art.py.
const SPRITES: Array[String] = [
	"player_body", "player_arm_left", "player_arm_right", "player_head",
	"player_side_stand",
	"player_side_walk_1", "player_side_walk_2", "player_side_walk_3",
	"player_side_walk_4", "player_side_walk_5", "player_side_walk_6",
	"monster", "folder", "suitcase",
]

const SEED := "стенд"
const MONSTERS := 3

var _state: RunState = null
var _journal: CommandLog = null
var _view: WorldView = null
var _art: ArtLibrary = null
var _overlay: DebugOverlay = null
var _scale_ref: ScaleReference = null

var _active_slots := 1
var _origin := Vector2.ZERO
var _art_note := ""
var _art_note_left := 0.0

## Куда тело едет само, когда ничего не нажато. Ноль — норма.
var _drift := Vector2.ZERO
var _idle_ticks := 0


func _ready() -> void:
	_art = ArtLibrary.new()

	_view = WorldView.new()
	add_child(_view)

	_scale_ref = ScaleReference.new()
	add_child(_scale_ref)

	_overlay = DebugOverlay.new()
	_overlay.stat_changed.connect(_on_stat_changed)
	add_child(_overlay)

	_reload_art()
	_reset()
	_overlay.sync_from_stats(_state.actor_of_slot(0).stack.compute())
	get_viewport().size_changed.connect(_recenter)
	_recenter()


func _reset() -> void:
	_state = Encounter.dev_room(SEED, _active_slots, MONSTERS)
	_journal = CommandLog.new()
	_view.state = _state


func _recenter() -> void:
	_origin = get_viewport_rect().size * 0.5
	_view.origin = _origin
	_scale_ref.queue_redraw()


## Симуляция идёт фиксированным шагом, представление — как получится.
func _physics_process(_delta: float) -> void:
	var commands := {}
	for i in _active_slots:
		var command: Command = InputReader.read(i, _state.tick, _mouse_aim(i))
		commands[i] = command
		_journal.record(i, command)
	SimTick.step(_state, commands)
	_watch_drift(commands)


## Мышью целится только первый слот и только пока правый стик отпущен.
func _mouse_aim(slot_index: int) -> Vector2:
	if slot_index != 0:
		return Vector2.ZERO
	var actor := _state.actor_of_slot(0)
	if actor == null:
		return Vector2.ZERO
	var to_cursor := get_viewport().get_mouse_position() - (_origin + actor.position)
	return to_cursor.normalized() if to_cursor.length() > 1.0 else Vector2.ZERO


## Тело, ползущее при отпущенном вводе, — почти всегда изношенный стик,
## а не ошибка в коде. Стенд обязан показать это прямо, а не заставлять гадать.
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
	_view.advance(delta)
	_view.queue_redraw()

	if _art_note_left > 0.0:
		_art_note_left -= delta
		if _art_note_left <= 0.0:
			_art_note = ""

	_overlay.set_text(_readout())


func _readout() -> String:
	var lines: Array[String] = []
	lines.append("СТЕНД · комната разработчиков · тик %d · %d кадр/с" % [
		_state.tick, Engine.get_frames_per_second()])
	lines.append("сид «%s» · отпечаток %d" % [_state.run_seed, _state.state_hash()])

	var alive := _state.living(Actor.Kind.ENEMY).size()
	lines.append("врагов живо %d из %d · снарядов в воздухе %d%s" % [
		alive, MONSTERS, _state.projectiles.size(),
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
	for actor in _state.actors:
		if actor.kind == Actor.Kind.PLAYER:
			actor.stack.base[stat] = value


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# По физической позиции, а не по символу: на кириллице keycode нулевой.
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match code:
		KEY_F1:
			_scale_ref.enabled = not _scale_ref.enabled
			_scale_ref.queue_redraw()
		KEY_F3:
			_overlay.visible = not _overlay.visible
		KEY_F5:
			_reload_art()
		KEY_TAB:
			_active_slots = _active_slots % RunState.MAX_PLAYERS + 1
			_reset()
		KEY_R:
			_reset()
		KEY_ESCAPE:
			get_tree().quit()


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
