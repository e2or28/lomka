extends SceneTree
## Сквозная проверка стенда: физическая клавиша -> действие -> команда ->
## симуляция -> положение тела на экране. Не покрыто ни отдельными тестами
## компонентов, ни обычным дымовым прогоном (ничего не нажимает).
##
## _process не переопределён: этим занят сам SceneTree, перехват сломал бы
## обход дерева. Кадры ждутся корутиной через process_frame.

const SANDBOX := "res://game/dev_sandbox.tscn"

## «Кириллица без позиции» — та, на которой движение и ломалось.
const LAYOUTS := [
	{"name": "латиница", "physical": true, "label": 0},
	{"name": "кириллица", "physical": true, "label": 1},
	{"name": "кириллица без позиции", "physical": false, "label": 1},
]

const CASES := [
	{"key": KEY_D, "ru": 0x0432, "label": "вправо", "axis": "x", "sign": 1},
	{"key": KEY_A, "ru": 0x0444, "label": "влево", "axis": "x", "sign": -1},
	{"key": KEY_S, "ru": 0x044B, "label": "вниз", "axis": "y", "sign": 1},
	{"key": KEY_W, "ru": 0x0446, "label": "вверх", "axis": "y", "sign": -1},
]

const HOLD_TICKS := 20

var _failures: PackedStringArray = []

## Без счётчика проверка, упавшая на каждом случае, рапортовала бы «в
## порядке» с пустым списком падений — ошибка скрипта гасит только свою
## функцию. Так уже случилось при переезде тела из слота в актора.
var _completed := 0

## Тот же сторож для проверок стрельбы: они идут вне общего счётчика.
var _extras_done := 0


func _initialize() -> void:
	_run()


func _press(case: Dictionary, layout: Dictionary, down: bool) -> void:
	var event := InputEventKey.new()
	if layout["physical"]:
		event.physical_keycode = case["key"]
	if layout["label"] == 1:
		event.key_label = case["ru"]
	else:
		event.keycode = case["key"]
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _run() -> void:
	var scene: PackedScene = load(SANDBOX)
	if scene == null:
		print("сцена стенда не загрузилась: %s" % SANDBOX)
		quit(1)
		return

	var sandbox: Node = scene.instantiate()
	root.add_child(sandbox)
	await process_frame
	await process_frame

	print("Сквозная проверка ввода стенда")
	for layout in LAYOUTS:
		print("  раскладка: %s" % layout["name"])
		for case in CASES:
			await _check(sandbox, case, layout)

	await _check_shooting(sandbox)
	await _check_last_pressed_wins(sandbox)

	var expected := CASES.size() * LAYOUTS.size()
	if _completed != expected:
		_failures.append("до конца дошло %d проверок из %d — ищи ошибку скрипта выше" % [
			_completed, expected])
	if _extras_done != 2:
		_failures.append("проверки стрельбы оборвались: дошло %d из 2" % _extras_done)

	sandbox.queue_free()
	await process_frame

	print("")
	if _failures.is_empty():
		print("ВВОД СТЕНДА В ПОРЯДКЕ: %d направлений на %d раскладках" % [
			CASES.size(), LAYOUTS.size()])
		quit(0)
		return

	for failure in _failures:
		print("  " + failure)
	print("ВВОД СТЕНДА СЛОМАН: %d из %d проверок" % [
		_failures.size(), CASES.size() * LAYOUTS.size()])
	quit(1)


func _arrow(key: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _ticks(sandbox: Node, count: int) -> void:
	var until: int = sandbox._state.tick + count
	while sandbox._state.tick < until:
		await process_frame


func _check_shooting(sandbox: Node) -> void:
	var arrows := {KEY_RIGHT: "вправо", KEY_UP: "вверх", KEY_LEFT: "влево", KEY_DOWN: "вниз"}
	for key in arrows:
		sandbox._reset()
		await process_frame
		var before: int = sandbox._state.projectiles.size()

		_arrow(key, true)
		await _ticks(sandbox, 4)
		_arrow(key, false)
		await process_frame

		var fired: int = sandbox._state.projectiles.size() - before
		print("    стрелка %-7s снарядов %d  %s" % [
			arrows[key], fired, "ok" if fired > 0 else "ПАДЕНИЕ"])
		if fired <= 0:
			_failures.append("стрелка %s не выстрелила — отдельной кнопки огня быть не должно" % arrows[key])
	_extras_done += 1


## Порядок нажатий собирается из событий, а не опросом состояния клавиш, —
## проверить его можно только в живой сцене.
func _check_last_pressed_wins(sandbox: Node) -> void:
	sandbox._reset()
	await process_frame

	_arrow(KEY_UP, true)
	await _ticks(sandbox, 2)
	_arrow(KEY_RIGHT, true)
	await _ticks(sandbox, 2)
	var later: Vector2 = sandbox._state.actor_of_slot(0).aim

	_arrow(KEY_RIGHT, false)
	await _ticks(sandbox, 2)
	var back: Vector2 = sandbox._state.actor_of_slot(0).aim

	_arrow(KEY_UP, false)
	await process_frame

	var ok := later.is_equal_approx(Vector2.RIGHT) and back.is_equal_approx(Vector2.UP)
	print("    вверх, затем вправо  прицел %s, после отпускания %s  %s" % [
		later, back, "ok" if ok else "ПАДЕНИЕ"])
	if not later.is_equal_approx(Vector2.RIGHT):
		_failures.append("вправо нажато позже вверх, а прицел смотрит %s" % later)
	elif not back.is_equal_approx(Vector2.UP):
		_failures.append("вправо отпущено, прицел не вернулся вверх, а смотрит %s" % back)
	_extras_done += 1


func _check(sandbox: Node, case: Dictionary, layout: Dictionary) -> void:
	sandbox._reset()
	await process_frame

	var before: Vector2 = sandbox._state.actor_of_slot(0).position
	_press(case, layout, true)
	# Тики симуляции, а не кадры: сколько шагов уложится в кадр, зависит
	# от нагрузки, и на этом тест бы дребезжал.
	var until: int = sandbox._state.tick + HOLD_TICKS
	while sandbox._state.tick < until:
		await process_frame
	_press(case, layout, false)

	var after: Vector2 = sandbox._state.actor_of_slot(0).position
	var moved := after - before
	var along: float = moved.x if case["axis"] == "x" else moved.y
	var across: float = moved.y if case["axis"] == "x" else moved.x
	var want: int = case["sign"]

	var ok := signf(along) == float(want) and absf(along) > 1.0
	var clean := absf(across) < 0.001

	print("    %-8s сдвиг (%7.2f, %7.2f)  %s" % [
		case["label"], moved.x, moved.y,
		"ok" if ok and clean else "ПАДЕНИЕ"])

	_completed += 1
	if not ok:
		_failures.append("%s / %s: тело не поехало (сдвиг по оси %.2f, ожидался знак %d)" % [
			layout["name"], case["label"], along, want])
	elif not clean:
		_failures.append("%s / %s: тело уехало вбок на %.2f" % [
			layout["name"], case["label"], across])
