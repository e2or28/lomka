extends SceneTree
## Сквозная проверка стенда: физическая клавиша -> действие -> команда ->
## симуляция -> положение тела на экране.
##
## Это то, чего не покрывают ни tools/test.sh (он не касается game/), ни
## обычный дымовой прогон (он поднимает сцену, но ничего не нажимает).
## Между «симуляция считает правильно» и «на экране едет правильно» лежит
## слой представления, и ошибка в нём выглядит как ошибка симуляции.
##
## _process здесь намеренно не переопределён: этим занят сам SceneTree, и
## перехват сломал бы обход дерева. Кадры ждутся корутиной через
## process_frame.

const SANDBOX := "res://game/dev_sandbox.tscn"

## Три формы события, как их отдаёт система на разных раскладках.
## «Кириллица без позиции» — та, на которой движение и ломалось: физическая
## позиция клавиши в событии не заполнена, есть только кириллическая метка.
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

## Сколько случаев реально дошло до конца. Ошибка скрипта гасит только свою
## функцию и молча возвращает управление — без этого счётчика проверка,
## упавшая на каждом случае, рапортовала бы «в порядке» с пустым списком
## падений. Так уже случилось при переезде тела из слота в актора.
var _completed := 0


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

	var expected := CASES.size() * LAYOUTS.size()
	if _completed != expected:
		_failures.append("до конца дошло %d проверок из %d — ищи ошибку скрипта выше" % [
			_completed, expected])

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


## Стрельба идёт от направления, без отдельной кнопки огня — так в Isaac,
## и так записано в docs/DECISIONS.md с 2 сентября 2026. Проверяется в живой
## сцене: путь от клавиши до снаряда в воздухе длиннее, чем кажется.
func _check_shooting(sandbox: Node) -> void:
	sandbox._reset()
	await process_frame

	var arrows := {KEY_RIGHT: "вправо", KEY_UP: "вверх", KEY_LEFT: "влево", KEY_DOWN: "вниз"}
	for key in arrows:
		sandbox._reset()
		await process_frame
		var before: int = sandbox._state.projectiles.size()

		var down := InputEventKey.new()
		down.physical_keycode = key
		down.pressed = true
		Input.parse_input_event(down)
		Input.flush_buffered_events()

		var until: int = sandbox._state.tick + 4
		while sandbox._state.tick < until:
			await process_frame

		var up := InputEventKey.new()
		up.physical_keycode = key
		up.pressed = false
		Input.parse_input_event(up)
		Input.flush_buffered_events()
		await process_frame

		var fired: int = sandbox._state.projectiles.size() - before
		print("    стрелка %-7s снарядов %d  %s" % [
			arrows[key], fired, "ok" if fired > 0 else "ПАДЕНИЕ"])
		if fired <= 0:
			_failures.append("стрелка %s не выстрелила — отдельной кнопки огня быть не должно" % arrows[key])


func _check(sandbox: Node, case: Dictionary, layout: Dictionary) -> void:
	sandbox._reset()
	await process_frame

	var before: Vector2 = sandbox._state.actor_of_slot(0).position
	_press(case, layout, true)
	# Считаются тики симуляции, а не кадры: сколько физических шагов уложится
	# в кадр отрисовки, зависит от нагрузки, и на этом тест бы дребезжал.
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
