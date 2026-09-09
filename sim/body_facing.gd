extends RefCounted

const MOVE_THRESHOLD := 12.0

static func side(velocity: Vector2, previous: int) -> int:
	if absf(velocity.x) < MOVE_THRESHOLD:
		return previous
	return 1 if velocity.x > 0.0 else -1


static func aiming_side(aim: Vector2, velocity: Vector2, firing: bool, previous: int) -> int:
	if firing and absf(aim.x) > 0.2:
		return 1 if aim.x > 0.0 else -1
	return side(velocity, previous)


static func front(aim: Vector2, velocity: Vector2, firing: bool, previous: bool) -> bool:
	if firing and absf(aim.x) > 0.2:
		return false
	if velocity.length() < MOVE_THRESHOLD:
		return previous
	return absf(velocity.y) > absf(velocity.x)
