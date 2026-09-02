extends RefCounted
## Поза персонажа: во что превращается состояние тела на экране.
##
## Чистые функции от скорости, фазы шага и перезарядки — ни узлов, ни
## времени системных часов. Поэтому позу можно проверить тестом, а не
## разглядыванием: «на месте руки не машут», «на бегу машут в противофазе»,
## «после броска рука выброшена вперёд».
##
## Почему это в game/, а не в sim/. Анимация ни на что не влияет: попадание
## считается по положению тела, а не по нарисованной руке. Держать её в
## симуляции значило бы гонять по сети данные, от которых ничего не зависит,
## и раздувать сейв. Рассинхрон фазы шага между клиентами никому не мешает.
##
## Слои и точки вращения заданы в art/player_layers.json. Пивот руки — плечо,
## поэтому поворот вокруг него читается как мах, а не как отрыв конечности.

## Сколько пикселей пути приходится на полный цикл из двух шагов.
## Меньше — семенит, больше — скользит. Число подбирается глазами.
const STRIDE := 96.0

## Размах маха руками, в радианах.
##
## Мал намеренно. Персонаж нарисован строго спереди, руки висят вдоль тела:
## поворот вокруг плеча уводит их вбок, а не вперёд-назад. На двадцати
## градусах кисть заезжает в корпус, а на плече рвётся силуэт — проверено
## покадровой раскадровкой. Восемь градусов читаются как покачивание и
## ничего не ломают.
const ARM_SWING := 0.14

## Насколько рука ходит вверх-вниз на шаге. Для фронтального вида это
## читается лучше поворота: так двигается рука идущего человека, если
## смотреть на него в лоб.
const ARM_LIFT := 1.8

## Насколько корпус подбрасывает на шаге, в пикселях.
const BODY_BOB := 1.6

## Дыхание в покое: медленное и едва заметное. Полностью неподвижный
## персонаж выглядит сломанным, а не спокойным.
const IDLE_BREATH := 0.6
const IDLE_PERIOD := 2.6

## Сколько длится бросок. Короче времени перезарядки, иначе рука не
## успевает вернуться и персонаж машет непрерывно.
const THROW_TIME := 0.18

## Бросок. Угол меньше прямого по той же причине, что и мах: рука,
## вынесенная вбок горизонтально, читается как «показывает пальцем»,
## а не как замах. Основную работу делает подъём.
const THROW_ANGLE := 0.75
const THROW_LIFT := 7.0

## Ниже этой скорости считаем, что персонаж стоит.
const WALK_THRESHOLD := 12.0

## Кадров в цикле ходьбы. Профильные кадры нарисованы человеком: шесть
## положений на два шага.
const WALK_FRAMES := 6


## Насколько продвинулась фаза шага за кадр. Фаза считается от пройденного
## пути, а не от времени: тогда медленный шаг остаётся шагом, а не
## превращается в семенение на месте.
static func advance_stride(phase: float, speed: float, delta: float) -> float:
	if speed < WALK_THRESHOLD:
		return phase
	return fmod(phase + speed * delta / STRIDE * TAU, TAU)


## Прогресс броска от 0 до 1, или -1, если сейчас не бросок.
static func throw_progress(cooldown: float, fire_rate: float) -> float:
	if fire_rate <= 0.0 or cooldown <= 0.0:
		return -1.0
	var period := 1.0 / fire_rate
	var elapsed := period - cooldown
	if elapsed < 0.0 or elapsed > THROW_TIME:
		return -1.0
	return clampf(elapsed / THROW_TIME, 0.0, 1.0)


## Смещение корпуса. На бегу подбрасывает дважды за цикл — по разу на шаг.
static func body_offset(phase: float, speed: float, breath: float) -> Vector2:
	if speed < WALK_THRESHOLD:
		return Vector2(0.0, -absf(sin(breath * TAU / IDLE_PERIOD)) * IDLE_BREATH * 0.5)
	return Vector2(0.0, -absf(sin(phase)) * BODY_BOB)


## Голова качается слабее корпуса и с запозданием: она тяжелее и висит
## на шее, а не приколочена.
static func head_offset(phase: float, speed: float, breath: float) -> Vector2:
	if speed < WALK_THRESHOLD:
		return Vector2(0.0, -absf(sin(breath * TAU / IDLE_PERIOD)) * IDLE_BREATH)
	return Vector2(0.0, -absf(sin(phase - 0.4)) * BODY_BOB * 0.6)


## Углы рук. Возвращает [левая, правая].
##
## На бегу руки идут в противофазе — иначе персонаж выглядит прыгающим на
## двух ногах, а не бегущим. Бросок перебивает мах: рука, которая кидает,
## выносится вперёд, вторая отходит назад для равновесия.
static func arm_angles(phase: float, speed: float, throw: float, throw_right: bool) -> Array:
	var left := 0.0
	var right := 0.0
	if speed >= WALK_THRESHOLD:
		left = sin(phase) * ARM_SWING
		right = -sin(phase) * ARM_SWING

	if throw >= 0.0:
		# Замах и возврат: быстро вперёд, плавно обратно
		var swing := _throw_swing(throw)
		var forward := THROW_ANGLE * swing
		if throw_right:
			right = -forward
			left = lerpf(left, forward * 0.25, swing)
		else:
			left = forward
			right = lerpf(right, -forward * 0.25, swing)
	return [left, right]


static func _throw_swing(throw: float) -> float:
	return sin(throw * PI) if throw < 0.5 else (1.0 - throw) * 2.0


## Вертикальный ход рук. Возвращает [левая, правая], в пикселях вниз.
##
## Для фронтального вида это основная часть маха: поворотом руку не увести
## вперёд-назад, а поднять и опустить — можно, и человек так и выглядит,
## если смотреть на него в лоб.
static func arm_lift(phase: float, speed: float, throw: float, throw_right: bool) -> Array:
	var left := 0.0
	var right := 0.0
	if speed >= WALK_THRESHOLD:
		left = -sin(phase) * ARM_LIFT
		right = sin(phase) * ARM_LIFT

	if throw >= 0.0:
		var lift := -THROW_LIFT * _throw_swing(throw)
		if throw_right:
			right = lift
		else:
			left = lift
	return [left, right]


## Номер кадра ходьбы по фазе шага. Кадры нарисованы, а не собраны из слоёв,
## поэтому здесь только выбор — ни поворотов, ни смещений.
static func walk_frame(phase: float) -> int:
	var wrapped := fposmod(phase, TAU)
	return clampi(int(wrapped / TAU * WALK_FRAMES), 0, WALK_FRAMES - 1)


## Куда персонаж повёрнут: +1 вправо, -1 влево.
##
## Профильные кадры нарисованы лицом ВПРАВО — это проверено по спрайту, а не
## на глаз: в кадрах ходьбы кожа лица лежит правее волос затылка. Значит
## вправо персонаж идёт как нарисован, а влево — зеркалом. Сначала я прочитал
## картинку наоборот, и персонаж ходил спиной вперёд.
##
## При вертикальном движении и в покое направление сохраняется: иначе
## персонаж разворачивался бы на месте от любого дрожания стика.
static func facing(velocity: Vector2, previous: int) -> int:
	if absf(velocity.x) < WALK_THRESHOLD:
		return previous
	return 1 if velocity.x > 0.0 else -1


## Куда повёрнут стреляющий. Прицел важнее движения: служащий, кидающий
## папки влево на бегу вправо, читался как ошибка отрисовки.
##
## В Isaac эту работу делает голова — она отдельный слой и смотрит туда,
## куда летят слёзы, пока тело бежит своей дорогой. У нас голова отдельна
## только в анфасе, а профильные кадры целиком повёрнуты, поэтому по прицелу
## доворачивается всё тело. Настоящий исааковский приём потребует кадров
## головы на четыре стороны.
static func aiming_facing(aim: Vector2, velocity: Vector2, firing: bool, previous: int) -> int:
	if firing and absf(aim.x) > 0.2:
		return 1 if aim.x > 0.0 else -1
	return facing(velocity, previous)


## Прицел, притянутый к ближайшему из восьми направлений.
##
## Так стреляют в Isaac: четыре кнопки плюс диагонали при двух нажатых.
## Свободный угол у нас записан в решениях, поэтому это режим для пробы,
## а не замена — переключается в стенде.
static func snap_aim(aim: Vector2, directions: int) -> Vector2:
	if aim == Vector2.ZERO or directions <= 0:
		return aim
	var step := TAU / float(directions)
	var angle := roundf(aim.angle() / step) * step
	return Vector2.RIGHT.rotated(angle)



## Профиль или анфас. В движении персонаж идёт боком — под это нарисованы
## кадры. Стоя он смотрит на игрока: так читается лицо, и работают дыхание
## с замахом, которых в профильных кадрах нет.
static func use_walk_frames(speed: float) -> bool:
	return speed >= WALK_THRESHOLD


## Где кисть, в которой оружие. Координаты в холсте 128x192, найдены по
## самим спрайтам: у слоя правой руки кисть в (84, 121), у профильной
## стойки — в (49, 123). Пишу их сюда, а не подбираю на глаз, чтобы оружие
## не висело в воздухе рядом с рукой.
const HAND_FRONT := Vector2(84.0, 121.0)
const HAND_SIDE := Vector2(49.0, 123.0)


## Куда положить оружие. Возвращает точку в холсте.
##
## На бегу кисть ходит вместе с рукой, поэтому оружие качается в такт шагу:
## неподвижный чемодан у шагающего человека читается как приклеенный.
## На замахе оружие уходит вместе с бросающей рукой.
static func hand_position(phase: float, speed: float, profile: bool,
		throw: float, throw_right: bool) -> Vector2:
	var hand := HAND_SIDE if profile else HAND_FRONT
	if speed >= WALK_THRESHOLD:
		hand.y += sin(phase) * ARM_LIFT
		hand.x += cos(phase) * 1.2
	else:
		hand.y += -absf(sin(0.0)) * 0.0

	if throw >= 0.0 and not profile:
		var swing := _throw_swing(throw)
		hand.y -= THROW_LIFT * swing
		hand.x += (6.0 if throw_right else -6.0) * swing
	return hand
