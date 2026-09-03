extends RefCounted
## Команда игрока на один тик (правило 6): не дёргает узлы, ложится в
## журнал, воспроизводится из журнала.
##
## Оси квантуются в целые: float от драйвера к драйверу разный в последнем
## бите и по сети расходится на ровном месте. Точности -127..127 хватает —
## мёртвая зона стика всё равно крупнее.

const AXIS_SCALE := 127

const BTN_FIRE := 1
const BTN_INTERACT := 2
const BTN_HARVEST := 4
const BTN_SKILL := 8

var tick: int = 0
var move_x: int = 0
var move_y: int = 0
var aim_x: int = 0
var aim_y: int = 0
var buttons: int = 0


static func _quantize(value: float) -> int:
	return clampi(roundi(value * AXIS_SCALE), -AXIS_SCALE, AXIS_SCALE)


static func from_axes(p_tick: int, move: Vector2, aim: Vector2, p_buttons: int = 0):
	var cmd := new()
	cmd.tick = p_tick
	cmd.move_x = _quantize(move.x)
	cmd.move_y = _quantize(move.y)
	cmd.aim_x = _quantize(aim.x)
	cmd.aim_y = _quantize(aim.y)
	cmd.buttons = p_buttons
	return cmd


func move_vector() -> Vector2:
	return Vector2(move_x, move_y) / float(AXIS_SCALE)


func aim_vector() -> Vector2:
	return Vector2(aim_x, aim_y) / float(AXIS_SCALE)


func pressed(button: int) -> bool:
	return (buttons & button) != 0


func to_dict() -> Dictionary:
	return {
		"aim_x": aim_x,
		"aim_y": aim_y,
		"buttons": buttons,
		"move_x": move_x,
		"move_y": move_y,
		"tick": tick,
	}


static func from_dict(data: Dictionary):
	var cmd := new()
	cmd.aim_x = int(data.get("aim_x", 0))
	cmd.aim_y = int(data.get("aim_y", 0))
	cmd.buttons = int(data.get("buttons", 0))
	cmd.move_x = int(data.get("move_x", 0))
	cmd.move_y = int(data.get("move_y", 0))
	cmd.tick = int(data.get("tick", 0))
	return cmd
