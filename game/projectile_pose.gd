extends RefCounted
## Вид летящего снаряда: переворот и тень. Падение по дуге отсюда убрано —
## снаряд, шлёпающийся на пол, обрывал атаку там, где игрок ждал продолжения.

## Не от дальности: короткий бросок крутится так же, как длинный, иначе
## оружие с малой дальностью выглядит вялым.
const SPIN_PERIOD := 0.55

## Единственное, по чему видно, что снаряд вошёл в добавочный отрезок.
const TUMBLE_SPIN := 3.0

const SHADOW_MIN_SCALE := 0.72
const SHADOW_GROUND_ALPHA := 0.30
const SHADOW_TUMBLE_ALPHA := 0.20


## tumble — доля кувырка от 0 до 1, или -1 в ровном полёте.
static func rotation(age: float, tumble: float) -> float:
	if SPIN_PERIOD <= 0.0:
		return 0.0
	var speed := 1.0 if tumble < 0.0 else TUMBLE_SPIN
	return fmod(age * speed / SPIN_PERIOD, 1.0) * TAU


static func hop(tumble: float) -> float:
	if tumble < 0.0:
		return 0.0
	return sin(clampf(tumble, 0.0, 1.0) * PI) * 7.0


static func shadow_scale(tumble: float) -> float:
	if tumble < 0.0:
		return 1.0
	return lerpf(1.0, SHADOW_MIN_SCALE, sin(clampf(tumble, 0.0, 1.0) * PI))


static func shadow_alpha(tumble: float) -> float:
	if tumble < 0.0:
		return SHADOW_GROUND_ALPHA
	return lerpf(SHADOW_GROUND_ALPHA, SHADOW_TUMBLE_ALPHA,
		sin(clampf(tumble, 0.0, 1.0) * PI))
