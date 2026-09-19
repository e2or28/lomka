extends RefCounted

# Смещения от опоры тела в плоскости видимого полёта. Хранятся в снаряде:
# поворот стрелка, смена оружия и загрузка не меняют уже выпущенную траекторию.

# Сторона выпуска: стрельба вбок идёт по направлению, вверх и вниз — по
# тому боку, которым тело уже стоит.
static func side(facing: int, direction: Vector2) -> int:
	if absf(direction.x) > 0.2:
		return 1 if direction.x > 0 else -1
	return facing



static func offset(kind: String, direction: Vector2, side: int, front: bool) -> Vector2:
	if kind == "oil_drop": return Vector2(0, -70)
	if kind == "rifle_bullet": return Vector2(30 * side, -62)
	if kind == "bullet":
		if absf(direction.x) > 0.2:
			return Vector2(26.0 * signf(direction.x), -85.0)
		# Плечо (-22,-103), хват (11,-82), локальное наведение руки на 60% угла.
		var angle := direction.angle() * 0.6
		var hand := Vector2(-22, -103) + Vector2(33, 21).rotated(angle)
		var muzzle := hand + Vector2(15, -3).rotated(direction.angle())
		muzzle.x *= side
		return muzzle
	if kind == "folder":
		return Vector2(21, -62) if front else Vector2(-14 * side, -58)
	if kind == "tank_shell":
		return Vector2(0, -51)
	return Vector2.ZERO
