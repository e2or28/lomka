extends RefCounted
## Визуальная поза летящей папки.
##
## Раньше здесь была и высота: симуляция двигала снаряд по прямой, а
## представление подрисовывало прыжок. Теперь дуга настоящая — снаряд
## поднимается и падает в симуляции, и от высоты зависит, попадёт он или
## пройдёт над головой. Рисовать вторую, декоративную дугу поверх настоящей
## значило бы показывать игроку не то, что считается.
##
## Здесь осталось то, что действительно ни на что не влияет: переворот папки
## в полёте и вид тени.

## За сколько секунд папка делает полный оборот. Не от дальности: короткий
## бросок должен крутиться так же, как длинный, иначе оружие с малой
## дальностью выглядит вялым.
const SPIN_PERIOD := 0.55

## Высота, выше которой тень уже не уменьшается. Примерно вершина дуги.
const SHADOW_FULL_HEIGHT := 90.0

const SHADOW_MIN_SCALE := 0.68
const SHADOW_GROUND_ALPHA := 0.30
const SHADOW_AIR_ALPHA := 0.14


## Угол переворота по возрасту снаряда.
static func rotation(age: float) -> float:
	if SPIN_PERIOD <= 0.0:
		return 0.0
	return fmod(age / SPIN_PERIOD, 1.0) * TAU


## Насколько тень меньше и бледнее. Считается от настоящей высоты, поэтому
## по тени видно ровно то, что учитывает попадание.
static func shadow_lift(height: float) -> float:
	return clampf(height / SHADOW_FULL_HEIGHT, 0.0, 1.0)


static func shadow_scale(height: float) -> float:
	return lerpf(1.0, SHADOW_MIN_SCALE, shadow_lift(height))


static func shadow_alpha(height: float) -> float:
	return lerpf(SHADOW_GROUND_ALPHA, SHADOW_AIR_ALPHA, shadow_lift(height))
