extends Node2D
## Стенд разработчика. Это не игра и не прототип геймплея — это окно
## в симуляцию, чтобы её можно было щупать руками.
##
## Что здесь есть: тела слотов, ходящие от настоящей карты ввода через
## настоящий поток команд и настоящий тик симуляции. Что здесь появится
## дальше: первые спрайты художественного теста. Чего здесь не будет:
## игровой логики — она живёт в sim/ и проверяется тестами без окна.
##
## Правило 2 соблюдается буквально: снизу вверх связь есть, сверху вниз —
## только команды. Удалить каталог game/ целиком можно в любой момент,
## tools/test.sh останется зелёным.

const RunState = preload("res://sim/run_state.gd")
const SimTick = preload("res://sim/tick.gd")
const Motion = preload("res://sim/motion.gd")
const Command = preload("res://sim/input/command.gd")
const CommandLog = preload("res://sim/input/command_log.gd")
const InputReader = preload("res://game/input_reader.gd")
const InputMapDef = preload("res://tools/input_map.gd")
const ActorView = preload("res://game/actor_view.gd")
const ArtLibrary = preload("res://game/art_library.gd")
const DebugOverlay = preload("res://game/debug_overlay.gd")
const ScaleReference = preload("res://game/scale_reference.gd")

## Имя файла в art/, которым стенд рисует тело игрока. Положи туда PNG —
## и он появится по F5, без импорта и без редактора.
const PLAYER_SPRITE := "player"

const SEED := "стенд"

var _state: RunState = null
var _journal: CommandLog = null
var _views: Array[ActorView] = []
var _art: ArtLibrary = null
var _overlay: DebugOverlay = null
var _scale_ref: ScaleReference = null

var _active_slots := 1
var _origin := Vector2.ZERO
var _art_note := ""
var _art_note_left := 0.0

## Куда тело едет само, когда ничего не нажато. Ноль — норма; всё остальное
## означает, что устройство ввода отдаёт ненулевое значение в покое.
var _drift := Vector2.ZERO
var _idle_ticks := 0


func _ready() -> void:
	_art = ArtLibrary.new()
	_art.get_texture(PLAYER_SPRITE)

	_scale_ref = ScaleReference.new()
	add_child(_scale_ref)

	_overlay = DebugOverlay.new()
	_overlay.stat_changed.connect(_on_stat_changed)
	add_child(_overlay)

	_reset()
	_overlay.sync_from_stats(Motion.PLACEHOLDER_STATS)
	get_viewport().size_changed.connect(_recenter)
	_recenter()


func _reset() -> void:
	_state = RunState.new(SEED)
	_journal = CommandLog.new()

	for view in _views:
		view.queue_free()
	_views.clear()

	for i in RunState.MAX_PLAYERS:
		var slot := _state.slots[i]
		slot.occupied = i < _active_slots
		slot.character_id = "sandbox"
		slot.stack.base = Motion.PLACEHOLDER_STATS.duplicate()

		var view := ActorView.new()
		view.slot_index = i
		view.visible = slot.occupied
		view.texture = _art.get_texture(PLAYER_SPRITE)
		add_child(view)
		_views.append(view)


func _recenter() -> void:
	_origin = get_viewport_rect().size * 0.5
	if _scale_ref != null:
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


## Тело, ползущее при отпущенном вводе, — самая частая причина жалобы
## «двигается само в одну сторону», и почти всегда это изношенный стик,
## а не ошибка в коде. Стенд обязан показать это прямо, а не заставлять
## гадать: замер идёт по клавиатуре, отпущенной дольше секунды.
func _watch_drift(commands: Dictionary) -> void:
	if not commands.has(0):
		return
	var move: Vector2 = commands[0].move_vector()
	if move == Vector2.ZERO:
		_idle_ticks += 1
		if _idle_ticks > 60:
			_drift = Vector2.ZERO
		return

	# Ввод есть, но клавиш никто не держит — значит его даёт устройство само
	var keys_held := false
	for action in InputReader.MOVE_ACTIONS:
		if Input.is_action_pressed(InputMapDef.action_name(0, action)):
			keys_held = true
			break
	_idle_ticks = 0
	if not keys_held:
		_drift = move


## Мышью целится только первый слот и только пока правый стик отпущен.
func _mouse_aim(slot_index: int) -> Vector2:
	if slot_index != 0:
		return Vector2.ZERO
	var body := _origin + _state.slots[0].position
	var to_cursor := get_viewport().get_mouse_position() - body
	return to_cursor.normalized() if to_cursor.length() > 1.0 else Vector2.ZERO


func _process(delta: float) -> void:
	for i in _views.size():
		var slot := _state.slots[i]
		var view := _views[i]
		view.visible = slot.occupied
		if not slot.occupied:
			continue
		view.position = _origin + slot.position
		view.downed = slot.downed
		var frame := _journal.frame(maxi(_state.tick - 1, 0))
		if frame.has(i):
			var command: Command = frame[i]
			view.aim = command.aim_vector()
			view.firing = command.pressed(Command.BTN_FIRE)
		view.queue_redraw()

	if _art_note_left > 0.0:
		_art_note_left -= delta
		if _art_note_left <= 0.0:
			_art_note = ""

	_overlay.set_text(_readout())


func _readout() -> String:
	var lines: Array[String] = []
	lines.append("СТЕНД · сид «%s» · тик %d · %d кадр/с" % [
		_state.run_seed, _state.tick, Engine.get_frames_per_second()])
	lines.append("отпечаток состояния  %d" % _state.state_hash())
	lines.append("")

	for i in _active_slots:
		var slot := _state.slots[i]
		var stats := slot.stack.compute()
		lines.append("p%d  поз %6.1f %6.1f   скор %6.1f %6.1f   |v| %5.1f%s" % [
			i + 1, slot.position.x, slot.position.y,
			slot.velocity.x, slot.velocity.y, slot.velocity.length(),
			"   УПАЛ" if slot.downed else ""])
		lines.append("    скорость %.0f · разгон %.0f · торможение %.0f" % [
			stats.get("move_speed", 0.0), stats.get("acceleration", 0.0),
			stats.get("friction", 0.0)])

	lines.append("")
	for line in InputReader.diagnostics(0):
		lines.append(line)

	lines.append("")
	lines.append("потоки случайности:")
	for name in _state.rng.names():
		lines.append("    %-18s %d" % [name, _state.rng.stream(name).state])

	lines.append("")
	var sprite_state := "art/%s.png" % PLAYER_SPRITE if _art.has(PLAYER_SPRITE) else "art/%s.png — нет файла, рисую заглушку" % PLAYER_SPRITE
	lines.append("спрайт: " + sprite_state)

	if _drift != Vector2.ZERO:
		lines.append("ДРЕЙФ: при отпущенном вводе тело едет (%+.3f %+.3f) — изношенный стик" % [
			_drift.x, _drift.y])
	if _art_note != "":
		lines.append(_art_note)

	return "\n".join(lines)


func _on_stat_changed(stat: String, value: float) -> void:
	for slot in _state.slots:
		slot.stack.base[stat] = value


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# По физической позиции, а не по символу: на кириллице keycode нулевой,
	# и сброс по R перестал бы работать ровно так же, как перестало движение.
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
	var texture := _art.get_texture(PLAYER_SPRITE)
	for view in _views:
		view.texture = texture
		view.queue_redraw()
	_art_note = "art/ перечитан: %s" % ("спрайт на месте" if texture != null else "файла нет")
	_art_note_left = 2.5
