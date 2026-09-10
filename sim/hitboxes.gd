extends RefCounted

static func rectangles(actor) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for source in actor.hurtboxes:
		var rect: Rect2 = source
		if (actor.behaviour == "tank" and actor.aim.x > 0.0) or (actor.behaviour != "tank" and actor.facing < 0):
			rect.position.x = -rect.end.x
		rect.position += actor.position
		result.append(rect)
	return result


static func segment_fraction(from: Vector2, to: Vector2, rect: Rect2) -> float:
	var enter := 0.0
	var leave := 1.0
	var step := to - from
	for axis in 2:
		if is_zero_approx(step[axis]):
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return INF
			continue
		var first: float = (rect.position[axis] - from[axis]) / step[axis]
		var last: float = (rect.end[axis] - from[axis]) / step[axis]
		enter = maxf(enter, minf(first, last))
		leave = minf(leave, maxf(first, last))
		if enter > leave:
			return INF
	return enter


static func hit_fraction(projectile, from: Vector2, to: Vector2, actor) -> float:
	var nearest := INF
	for rect in rectangles(actor):
		nearest = minf(nearest, segment_fraction(from + projectile.flight_offset(),
			to + projectile.flight_offset(), rect.grow(projectile.radius)))
	return nearest
