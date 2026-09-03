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

## Свободный угол убран — docs/DECISIONS.md, 2 сентября 2026.
const AIM_DIRECTIONS := 8

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


static func read(player: int, tick: int):
	var move := apply_deadzone(raw_move(player))

	var aim := CharacterPose.snap_aim(
		apply_deadzone(Vector2(
			_axis(player, "aim_left", "aim_right"),
			_axis(player, "aim_up", "aim_down"))),
		AIM_DIRECTIONS)

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
