extends RefCounted

const Command = preload("res://sim/input/command.gd")
const LIMIT := 120
const RELEASE_AFTER := 12
const MAX_BACKLOG := 6

var acknowledged := 0
var received := 0
var queue: Array = []
var last = Command.new()
var idle_ticks := 0

func submit(sequence: int, mx: int, my: int, ax: int, ay: int, buttons: int) -> bool:
	if sequence <= received or sequence > 2147483647 or queue.size() >= LIMIT:
		return false
	if absi(mx) > 127 or absi(my) > 127 or absi(ax) > 127 or absi(ay) > 127 or buttons < 0 or buttons > 15:
		return false
	var command = Command.from_axes(sequence, Vector2(mx, my) / 127.0, Vector2(ax, ay) / 127.0, buttons)
	queue.append(command)
	received = sequence
	return true

func take(tick: int):
	# После сетевой паузы старые движения не должны задерживать новые
	# до конца забега. За тик всё равно применяется ровно одна команда.
	if queue.size() > MAX_BACKLOG:
		queue = queue.slice(queue.size() - 3)
	if not queue.is_empty():
		last = queue.pop_front()
		acknowledged = last.tick
		idle_ticks = 0
	else:
		idle_ticks += 1
	if idle_ticks > RELEASE_AFTER:
		return Command.from_axes(tick, Vector2.ZERO, Vector2.ZERO)
	return Command.from_axes(tick, last.move_vector(), last.aim_vector(), last.buttons)
