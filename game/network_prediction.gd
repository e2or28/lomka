extends RefCounted

const Motion = preload("res://sim/motion.gd")
const Command = preload("res://sim/input/command.gd")
const BodyFacing = preload("res://sim/body_facing.gd")

var pending: Array = []
var room_id := ""

func push(sequence: int, command) -> void:
	pending.append({"sequence": sequence, "command": command})
	if pending.size() > 120: pending.pop_front()

func reconcile(state, slot: int, acknowledged: int, next_room: String) -> void:
	if room_id != next_room:
		pending.clear()
	room_id = next_room
	pending = pending.filter(func(entry): return int(entry.sequence) > acknowledged)
	for entry in pending:
		advance(state, slot, entry.command)

func advance(state, slot: int, command) -> void:
	var actor = state.actor_of_slot(slot)
	if actor == null or not actor.alive or state.slots[slot].downed:
		return
	var stats: Dictionary = actor.stack.compute()
	actor.velocity = Motion.step_velocity(actor.velocity, command.move_vector(), stats, 1.0 / 60.0)
	actor.position = state.room.clamp_body(Motion.step_position(actor.position, actor.velocity, 1.0 / 60.0), actor.radius)
	if command.aim_vector() != Vector2.ZERO:
		actor.aim = command.aim_vector().normalized()
	var firing: bool = command.pressed(Command.BTN_FIRE)
	actor.facing = BodyFacing.aiming_side(actor.aim, actor.velocity, firing, actor.facing)
	actor.standing_front = BodyFacing.front(actor.aim, actor.velocity, firing, actor.standing_front)
