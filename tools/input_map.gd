extends RefCounted
## Карта ввода как данные: 4 игрока × 12 действий — 48 действий и под сотню
## привязок, руками они разъедутся без диффа в гите.
##
## Клавиатура и мышь только у первого слота: p2–p4 нужны для геймпадов на
## одной машине и отладки нескольких локальных инстансов на M2.

const PLAYERS := 4

## Почти нулевая намеренно: настоящая круговая зона считается в
## game/input_reader.gd, а движковую нельзя посчитать по уже обрезанным осям.
const DEADZONE := 0.05

const ACTIONS: Array[String] = [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
	"aim_up",
	"aim_down",
	"aim_left",
	"aim_right",
	"fire",
	"interact",
	"harvest",
	"skill",
]

## Клавиатура — по физической позиции клавиши, не по символу.
const KEYS := {
	"move_up": [KEY_W],
	"move_down": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"aim_up": [KEY_UP],
	"aim_down": [KEY_DOWN],
	"aim_left": [KEY_LEFT],
	"aim_right": [KEY_RIGHT],
	"interact": [KEY_E],
	"harvest": [KEY_F],
	"skill": [KEY_SPACE],
}

## На кириллице macOS не сообщает physical_keycode — только метку, и
## привязка по позиции клавишу не ловит. Поэтому у каждой буквенной клавиши
## две привязки: по позиции и по метке (строчной и заглавной — с Shift
## приходит вторая). Раскладка ЙЦУКЕН. Проверено матрицей, tools/smoke.sh.
const RU_LABELS := {
	KEY_W: [0x0446, 0x0426],  # ц Ц
	KEY_A: [0x0444, 0x0424],  # ф Ф
	KEY_S: [0x044B, 0x042B],  # ы Ы
	KEY_D: [0x0432, 0x0412],  # в В
	KEY_E: [0x0443, 0x0423],  # у У
	KEY_F: [0x0430, 0x0410],  # а А
}

const MOUSE := {
	"fire": [MOUSE_BUTTON_LEFT],
	"skill": [MOUSE_BUTTON_RIGHT],
}

const PAD_BUTTONS := {
	"fire": [JOY_BUTTON_RIGHT_SHOULDER],
	"interact": [JOY_BUTTON_A],
	"harvest": [JOY_BUTTON_X],
	"skill": [JOY_BUTTON_LEFT_SHOULDER],
}

## У Godot ось Y растёт вниз, поэтому «вверх» — это -1.
const PAD_AXES := {
	"move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	"move_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"aim_up": [[JOY_AXIS_RIGHT_Y, -1.0]],
	"aim_down": [[JOY_AXIS_RIGHT_Y, 1.0]],
	"aim_left": [[JOY_AXIS_RIGHT_X, -1.0]],
	"aim_right": [[JOY_AXIS_RIGHT_X, 1.0]],
	"fire": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"skill": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
}


static func action_name(player: int, action: String) -> String:
	return "p%d_%s" % [player + 1, action]


static func events_for(player: int, action: String) -> Array:
	var events: Array = []

	if player == 0:
		for keycode in KEYS.get(action, []):
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			events.append(key)
			for label in RU_LABELS.get(keycode, []):
				var ru := InputEventKey.new()
				ru.key_label = label
				events.append(ru)
		for button in MOUSE.get(action, []):
			var mouse := InputEventMouseButton.new()
			mouse.button_index = button
			events.append(mouse)

	for button in PAD_BUTTONS.get(action, []):
		var pad := InputEventJoypadButton.new()
		pad.device = player
		pad.button_index = button
		events.append(pad)

	for pair in PAD_AXES.get(action, []):
		var motion := InputEventJoypadMotion.new()
		motion.device = player
		motion.axis = pair[0]
		motion.axis_value = pair[1]
		events.append(motion)

	return events


static func build() -> Dictionary:
	var actions := {}
	for player in PLAYERS:
		for action in ACTIONS:
			actions[action_name(player, action)] = {
				"deadzone": DEADZONE,
				"events": events_for(player, action),
			}
	return actions
