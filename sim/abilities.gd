extends RefCounted

const Actor = preload("res://sim/actor.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Command = preload("res://sim/input/command.gd")

const DURATION_TICKS := 240
const COOLDOWN_TICKS := 600
const COVER_HEALTH := 54.0
const COVER_SIZE := Vector2(88, 28)
const COVER_DISTANCE := 72.0


static func advance(state, commands: Dictionary) -> void:
	for slot in state.slots:
		slot.skill_cooldown_ticks = maxi(0, slot.skill_cooldown_ticks - 1)
		var actor = state.actor_of_slot(slot.index)
		if slot.cover_ticks > 0:
			if slot.cover_ticks == 1 or slot.downed or actor == null or not actor.alive:
				finish(state, slot)
			else:
				slot.cover_ticks -= 1
		var command = commands.get(slot.index)
		var pressed: bool = command != null and command.pressed(Command.BTN_SKILL)
		if pressed and not slot.skill_held:
			if actor != null and command.aim_vector() != Vector2.ZERO:
				actor.aim = command.aim_vector().normalized()
			if Bestiary.character(slot.character_id).get("skill", "") == "lunch_break":
				activate(state, slot)
		slot.skill_held = pressed


static func activate(state, slot) -> bool:
	var actor = state.actor_of_slot(slot.index)
	if not slot.occupied or slot.downed or actor == null or not actor.alive:
		return false
	if slot.cover_ticks > 0 or slot.skill_cooldown_ticks > 0 or actor.weapon_id != "suitcase":
		return false
	var direction := Vector2.RIGHT
	if absf(actor.aim.x) >= absf(actor.aim.y):
		direction = Vector2.LEFT if actor.aim.x < 0.0 else Vector2.RIGHT
	else:
		direction = Vector2.UP if actor.aim.y < 0.0 else Vector2.DOWN
	var position: Vector2 = actor.position + direction * COVER_DISTANCE
	var area := _rectangle(position, direction)
	if not state.room.bounds.encloses(area):
		return false
	for blocker in state.room.blockers:
		if area.intersects(blocker):
			return false
	for enemy in state.living(Actor.Kind.ENEMY):
		if area.grow(enemy.radius).has_point(enemy.position):
			return false
	for other in state.slots:
		if other.cover_ticks > 0 and area.intersects(rect(other)):
			return false
	slot.cover_position = position
	slot.cover_direction = direction
	slot.cover_ticks = DURATION_TICKS
	slot.cover_health = COVER_HEALTH
	slot.skill_cooldown_ticks = COOLDOWN_TICKS
	slot.charge_ticks = 0
	Arsenal.unequip(actor)
	return true


static func finish(state, slot) -> void:
	if slot.cover_ticks <= 0:
		return
	slot.cover_ticks = 0
	slot.cover_health = 0.0
	var actor = state.actor_of_slot(slot.index)
	if actor != null:
		Arsenal.equip(actor, "suitcase")


static func rect(slot) -> Rect2:
	return _rectangle(slot.cover_position, slot.cover_direction)


static func _rectangle(position: Vector2, direction: Vector2) -> Rect2:
	var size := Vector2(COVER_SIZE.y, COVER_SIZE.x) if direction.x != 0.0 else COVER_SIZE
	return Rect2(position - size * 0.5, size)


static func blocks_shot(state, projectile, from: Vector2) -> bool:
	if projectile.owner_kind != Actor.Kind.ENEMY:
		return false
	var closest = null
	var earliest := INF
	for slot in state.slots:
		if slot.cover_ticks <= 0:
			continue
		var time := _segment_entry(rect(slot).grow(projectile.radius), from, projectile.position)
		if time < earliest:
			earliest = time
			closest = slot
	if closest == null:
		return false
	closest.cover_health -= maxf(0.0, projectile.damage)
	if closest.cover_health <= 0.0:
		finish(state, closest)
	return true


static func constrain_enemy(state, actor, before: Vector2) -> void:
	if actor.kind != Actor.Kind.ENEMY or not actor.alive:
		return
	var destination: Vector2 = actor.position
	var earliest := INF
	for slot in state.slots:
		if slot.cover_ticks <= 0:
			continue
		var area := rect(slot).grow(actor.radius)
		earliest = minf(earliest, _segment_entry(area, before, destination))
	if earliest != INF:
		destination = before.lerp(destination, maxf(0.0, earliest - 0.0001))
		actor.velocity = Vector2.ZERO
	actor.position = destination


static func _segment_entry(area: Rect2, from: Vector2, to: Vector2) -> float:
	var delta := to - from
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if is_zero_approx(delta[axis]):
			if from[axis] < area.position[axis] or from[axis] > area.end[axis]:
				return INF
			continue
		var first: float = (area.position[axis] - from[axis]) / delta[axis]
		var last: float = (area.end[axis] - from[axis]) / delta[axis]
		enter = maxf(enter, minf(first, last))
		leave = minf(leave, maxf(first, last))
		if enter > leave:
			return INF
	return enter if leave > 0.0 else INF
