extends RefCounted

# Смещения от опоры тела в плоскости видимого полёта. Хранятся в снаряде:
# поворот стрелка, смена оружия и загрузка не меняют уже выпущенную траекторию.
static func offset(kind: String, direction: Vector2, side: int, front: bool) -> Vector2:
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
