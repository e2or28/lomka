extends RefCounted

# Координаты на исходных холстах 128×192: плечо, локоть, центр хвата.
# Стойка colt нарисована с опущенной рукой; её нельзя путать с walk_1.
const SIDE := [
	[Vector2(50, 72), Vector2(49, 98), Vector2(50, 116)],
	[Vector2(51, 68), Vector2(49, 94), Vector2(52, 108)],
	[Vector2(50, 70), Vector2(49, 97), Vector2(51, 114)],
	[Vector2(50, 72), Vector2(49, 98), Vector2(51, 115)],
	[Vector2(48, 76), Vector2(45, 102), Vector2(45, 121)],
	[Vector2(50, 73), Vector2(49, 99), Vector2(51, 117)],
	[Vector2(49, 73), Vector2(46, 99), Vector2(45, 114)],
]
const COLT := [
	[Vector2(43, 69), Vector2(47, 88), Vector2(75, 90)],
	[Vector2(44, 68), Vector2(48, 86), Vector2(75, 88)],
	[Vector2(43, 69), Vector2(48, 88), Vector2(76, 90)],
	[Vector2(42, 71), Vector2(47, 90), Vector2(75, 92)],
	[Vector2(44, 68), Vector2(48, 85), Vector2(76, 87)],
	[Vector2(44, 68), Vector2(48, 85), Vector2(77, 86)],
]
const FRONT := [Vector2(83, 73), Vector2(84, 98), Vector2(85, 112)]
const COLT_FRONT := [Vector2(78, 74), Vector2(78, 98), Vector2(78, 110)]


static func joints(frame: String) -> Array:
	if frame.begins_with("player_colt_walk_"):
		return COLT[clampi(frame.get_slice("_", 3).to_int() - 1, 0, 5)]
	if frame.begins_with("player_side_walk_"):
		return SIDE[clampi(frame.get_slice("_", 3).to_int(), 1, 6)]
	if frame == "player_colt_front":
		return COLT_FRONT
	if frame == "player":
		return FRONT
	return SIDE[0]


static func is_raised(frame: String) -> bool:
	return frame.begins_with("player_colt_walk_")


static func pulse(progress: float) -> float:
	if progress < 0.0 or progress >= 1.0:
		return 0.0
	# Быстрый удар, более медленное возвращение; обе границы без скачка.
	if progress < 0.18:
		return smoothstep(0.0, 0.18, progress)
	return 1.0 - smoothstep(0.18, 1.0, progress)


static func motion(frame: String, weapon: String, phase: float, speed: float,
		progress: float) -> Transform2D:
	var shoulder: Vector2 = joints(frame)[0]
	var moving := smoothstep(0.0, 100.0, speed)
	var action := pulse(progress)
	var angle := sin(phase) * 0.025 * moving
	var offset := Vector2.ZERO
	if weapon == "colt":
		angle *= 0.3
		angle -= action * 0.065
		offset = Vector2(-2.0, 0.4) * action
		if not is_raised(frame):
			angle = 0.0
			offset = Vector2(0, -3) * action
	elif frame in ["player", "player_colt_front"]:
		angle = 0.0
		offset = Vector2(0, -6) * action
	else:
		angle -= action * 0.28
	return Transform2D(angle, shoulder - shoulder.rotated(angle) + offset)


static func hand(frame: String, transform: Transform2D) -> Vector2:
	return transform * Vector2(joints(frame)[2])


static func arm_weight(point: Vector2, frame: String) -> float:
	return smoothstep(4.0, 22.0, point.distance_to(joints(frame)[0]))


static func weapon_transform(frame: String, transform: Transform2D,
		grip: Vector2, side: int, weapon: String) -> Transform2D:
	var angle := transform.get_rotation()
	if weapon == "colt" and not is_raised(frame):
		angle += PI * 0.5
	var result := Transform2D(angle, hand(frame, transform))
	result.origin -= result.basis_xform(grip)
	if side < 0:
		return Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(128, 0)) * result
	return result
