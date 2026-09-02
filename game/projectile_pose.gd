extends RefCounted
## Визуальная поза метательного портфеля.
##
## Высота, поворот и тень не участвуют в столкновениях и потому остаются
## в game/. Симуляция двигает снаряд по прямой, а представление показывает
## один прыжок и один полный переворот за то же время жизни.

const JUMP_HEIGHT := 22.0
const SHADOW_MIN_SCALE := 0.68
const SHADOW_GROUND_ALPHA := 0.30
const SHADOW_AIR_ALPHA := 0.14


static func progress(age: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(age / duration, 0.0, 1.0)


static func lift(value: float) -> float:
	return sin(clampf(value, 0.0, 1.0) * PI) * JUMP_HEIGHT


static func rotation(value: float) -> float:
	return clampf(value, 0.0, 1.0) * TAU


static func shadow_scale(value: float) -> float:
	return lerpf(1.0, SHADOW_MIN_SCALE, sin(clampf(value, 0.0, 1.0) * PI))


static func shadow_alpha(value: float) -> float:
	return lerpf(SHADOW_GROUND_ALPHA, SHADOW_AIR_ALPHA,
		sin(clampf(value, 0.0, 1.0) * PI))
