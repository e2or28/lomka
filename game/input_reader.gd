extends RefCounted
## Чтение ввода — представление, а не симуляция (правило 2).
##
## Здесь и только здесь движковый InputMap превращается в команду. Дальше
## идёт сериализуемая команда (правило 6), одинаковая локально и по сети:
## симуляция не знает, пришла она с клавиатуры, со стика или из журнала.

const Command = preload("res://sim/input/command.gd")
const InputMapDef = preload("res://tools/input_map.gd")
const CharacterPose = preload("res://game/character_pose.gd")

## Круговая, а не движковая поосевая: та даёт квадрат — по диагонали порог
## ниже, чем по прямой, и изношенный стик, тянущий в угол, проезжает фильтр.
## Считается по длине вектора, остаток растягивается на весь диапазон.
const STICK_DEADZONE := 0.22

## Свободный угол и диагональ убраны — docs/DECISIONS.md, 7 сентября 2026.
const AIM_DIRECTIONS := 4

const AIM_VECTORS := {
	"aim_up": Vector2.UP,
	"aim_down": Vector2.DOWN,
	"aim_left": Vector2.LEFT,
	"aim_right": Vector2.RIGHT,
}

## Порядок зажатых направлений прицела, на игрока: последнее нажатое в конце.
## Без него две зажатые стрелки давали бы вертикаль всегда — на ней округление
## половины, — и прицел залипал бы на повороте. В Isaac выигрывает последняя
## нажатая, и рука ждёт именно этого.
static var _aim_order: Dictionary = {}

## Движковая зона в карте ввода почти нулевая намеренно: круговую зону
## нельзя посчитать по уже обрезанным осям.
const MOVE_ACTIONS: Array[String] = ["move_up", "move_down", "move_left", "move_right"]


static func _axis(player: int, negative: String, positive: String) -> float:
	return Input.get_axis(
		InputMapDef.action_name(player, negative),
		InputMapDef.action_name(player, positive))


static func _held(player: int, action: String) -> bool:
	return Input.is_action_pressed(InputMapDef.action_name(player, action))


static func apply_deadzone(raw: Vector2) -> Vector2:
	var length := raw.length()
	if length <= STICK_DEADZONE:
		return Vector2.ZERO
	var direction := raw / length
	if length >= 1.0:
		return direction
	return direction * ((length - STICK_DEADZONE) / (1.0 - STICK_DEADZONE))


static func raw_move(player: int) -> Vector2:
	return Vector2(
		_axis(player, "move_left", "move_right"),
		_axis(player, "move_up", "move_down"))


## Стик сюда не попадает намеренно: у него честный угол, и приоритет по
## времени заедал бы — ось, заведённая раньше, держала бы прицел, пока
## игрок не отпустит стик полностью.
static func feed(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		return
	for player in InputMapDef.PLAYERS:
		var order: Array = _aim_order.get(player, [])
		for action: String in AIM_VECTORS:
			var name := InputMapDef.action_name(player, action)
			# Автоповтор — не нажатие и не отпускание: он бы вытолкнул
			# удерживаемую клавишу из стека или переставил её в конец.
			if event.is_action_pressed(name):
				order.erase(action)
				order.append(action)
			elif event.is_action_released(name):
				order.erase(action)
		_aim_order[player] = order


## Стек чистится событиями, но событие отпускания теряется при потере окном
## фокуса — отсюда сверка с настоящим состоянием клавиши.
static func aim_priority(player: int) -> Vector2:
	var order: Array = _aim_order.get(player, [])
	for i in range(order.size() - 1, -1, -1):
		var action: String = order[i]
		if _held(player, action):
			return AIM_VECTORS[action]
	return Vector2.ZERO


static func resolve_aim(axes: Vector2, priority: Vector2) -> Vector2:
	if priority != Vector2.ZERO and axes.x != 0.0 and axes.y != 0.0:
		return priority
	return CharacterPose.snap_aim(axes, AIM_DIRECTIONS)


static func read(player: int, tick: int):
	var move := apply_deadzone(raw_move(player))

	var aim := resolve_aim(
		apply_deadzone(Vector2(
			_axis(player, "aim_left", "aim_right"),
			_axis(player, "aim_up", "aim_down"))),
		aim_priority(player))

	var buttons := 0
	# Нажал направление — полетело, как в Isaac. Кнопка остаётся для
	# геймпада, где прицел на стике.
	if aim != Vector2.ZERO or _held(player, "fire"):
		buttons |= Command.BTN_FIRE
	if _held(player, "interact"):
		buttons |= Command.BTN_INTERACT
	if _held(player, "harvest"):
		buttons |= Command.BTN_HARVEST
	if _held(player, "skill"):
		buttons |= Command.BTN_SKILL

	return Command.from_axes(tick, move, aim, buttons)


static func diagnostics(player: int) -> PackedStringArray:
	var lines := PackedStringArray()

	var raw := raw_move(player)
	var clean := apply_deadzone(raw)
	lines.append("ввод p%d: сырой (%+.3f %+.3f) | после зоны (%+.3f %+.3f)" % [
		player + 1, raw.x, raw.y, clean.x, clean.y])

	var held := PackedStringArray()
	for action in MOVE_ACTIONS:
		var strength := Input.get_action_strength(InputMapDef.action_name(player, action))
		if strength > 0.0:
			held.append("%s %.2f" % [action, strength])
	lines.append("  активно: " + (", ".join(held) if not held.is_empty() else "ничего"))

	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		lines.append("  геймпадов нет")
	else:
		for device in pads:
			lines.append("  геймпад %d «%s» стик (%+.3f %+.3f)" % [
				device, Input.get_joy_name(device),
				Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
				Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)])
	return lines
