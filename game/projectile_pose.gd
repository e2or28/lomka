extends RefCounted
## Вид летящего чемодана: переворот и тень.
##
## Высота отсюда ушла дважды. Сначала она была декорацией поверх прямого
## полёта, потом стала настоящей — снаряд летел по дуге и падал. Падение
## убрали: чемодан, шлёпающийся на пол, обрывал атаку там, где игрок ждал
## продолжения.
##
## Теперь снаряд идёт ровно, а в конце дальности переворачивается и
## проходит ещё отрезок. Здесь — как это показать.

## За сколько секунд чемодан делает оборот в ровном полёте. Не от дальности:
## короткий бросок должен крутиться так же, как длинный, иначе оружие с
## малой дальностью выглядит вялым.
const SPIN_PERIOD := 0.55

## Во сколько раз быстрее он крутится на кувырке. Это единственное, по чему
## игрок видит, что чемодан вошёл в добавочный отрезок.
const TUMBLE_SPIN := 3.0

const SHADOW_MIN_SCALE := 0.72
const SHADOW_GROUND_ALPHA := 0.30
const SHADOW_TUMBLE_ALPHA := 0.20


## Угол переворота. tumble — доля кувырка от 0 до 1, или -1 в ровном полёте.
static func rotation(age: float, tumble: float) -> float:
	if SPIN_PERIOD <= 0.0:
		return 0.0
	var speed := 1.0 if tumble < 0.0 else TUMBLE_SPIN
	return fmod(age * speed / SPIN_PERIOD, 1.0) * TAU


## На кувырке чемодан подскакивает — не по-настоящему, а настолько, чтобы
## переворот читался как кувырок, а не как вращение на месте.
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
