extends RefCounted
## Поза персонажа: чистые функции от скорости, фазы шага и перезарядки —
## ни узлов, ни системных часов, поэтому проверяется тестом.
##
## Живёт в game/, а не в sim/: попадание считается по положению тела, а не
## по нарисованной руке, и гонять фазу шага по сети незачем.
##
## Слои и точки вращения — в art/player_layers.json. Пивот руки — плечо,
## поэтому поворот читается как мах, а не как отрыв конечности.

const STRIDE := 96.0

## Мал намеренно: на двадцати градусах кисть заезжает в корпус, на плече
## рвётся силуэт — проверено покадровой раскадровкой.
const ARM_SWING := 0.14

const ARM_LIFT := 1.8
const BODY_BOB := 1.6
const IDLE_BREATH := 0.6
const IDLE_PERIOD := 2.6

## Короче времени перезарядки, иначе рука не успевает вернуться и персонаж
## машет непрерывно.
const THROW_TIME := 0.18

const THROW_ANGLE := 0.75
const THROW_LIFT := 7.0
const WALK_THRESHOLD := 12.0
const WALK_FRAMES := 6


## Фаза считается от пройденного пути, а не от времени: тогда медленный шаг
## остаётся шагом, а не превращается в семенение на месте.
static func advance_stride(phase: float, speed: float, delta: float) -> float:
	if speed < WALK_THRESHOLD:
		return phase
	return fmod(phase + speed * delta / STRIDE * TAU, TAU)


static func throw_progress(cooldown: float, fire_rate: float) -> float:
	if fire_rate <= 0.0 or cooldown <= 0.0:
		return -1.0
	var period := 1.0 / fire_rate
	var elapsed := period - cooldown
	if elapsed < 0.0 or elapsed > THROW_TIME:
		return -1.0
	return clampf(elapsed / THROW_TIME, 0.0, 1.0)


static func body_offset(phase: float, speed: float, breath: float) -> Vector2:
	if speed < WALK_THRESHOLD:
		return Vector2(0.0, -absf(sin(breath * TAU / IDLE_PERIOD)) * IDLE_BREATH * 0.5)
	return Vector2(0.0, -absf(sin(phase)) * BODY_BOB)


static func head_offset(phase: float, speed: float, breath: float) -> Vector2:
	if speed < WALK_THRESHOLD:
		return Vector2(0.0, -absf(sin(breath * TAU / IDLE_PERIOD)) * IDLE_BREATH)
	return Vector2(0.0, -absf(sin(phase - 0.4)) * BODY_BOB * 0.6)


## На бегу руки идут в противофазе — иначе персонаж выглядит прыгающим на
## двух ногах. Бросок перебивает мах.
static func arm_angles(phase: float, speed: float, throw: float, throw_right: bool) -> Array:
	var left := 0.0
	var right := 0.0
	if speed >= WALK_THRESHOLD:
		left = sin(phase) * ARM_SWING
		right = -sin(phase) * ARM_SWING

	if throw >= 0.0:
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


static func walk_frame(phase: float) -> int:
	var wrapped := fposmod(phase, TAU)
	return clampi(int(wrapped / TAU * WALK_FRAMES), 0, WALK_FRAMES - 1)


## От предпочтительного к запасному: представление берёт первый файл,
## который нашёлся. Оружие без своего набора ходит базовым.
static func walk_frame_names(weapon_id: String, frame: int) -> PackedStringArray:
	var base := "player_side_walk_%d" % (frame + 1)
	if weapon_id == "":
		return PackedStringArray([base])
	return PackedStringArray(["player_%s_walk_%d" % [weapon_id, frame + 1], base])


static func stand_names(weapon_id: String) -> PackedStringArray:
	if weapon_id == "":
		return PackedStringArray(["player_side_stand"])
	return PackedStringArray(["player_%s_stand" % weapon_id, "player_side_stand"])


## Профильные кадры нарисованы лицом вправо — проверено по спрайту: кожа
## лица лежит правее волос затылка. Перепутано один раз, персонаж ходил
## спиной вперёд.
static func facing(velocity: Vector2, previous: int) -> int:
	if absf(velocity.x) < WALK_THRESHOLD:
		return previous
	return 1 if velocity.x > 0.0 else -1


## Голова не отдельный слой в профиле, поэтому по прицелу доворачивается
## всё тело, а не только голова, как в Isaac.
static func aiming_facing(aim: Vector2, velocity: Vector2, firing: bool, previous: int) -> int:
	if firing and absf(aim.x) > 0.2:
		return 1 if aim.x > 0.0 else -1
	return facing(velocity, previous)


static func snap_aim(aim: Vector2, directions: int) -> Vector2:
	if aim == Vector2.ZERO or directions <= 0:
		return aim
	var step := TAU / float(directions)
	var angle := roundf(aim.angle() / step) * step
	return Vector2.RIGHT.rotated(angle)


static func use_walk_frames(speed: float) -> bool:
	return speed >= WALK_THRESHOLD


## Найдены по самим спрайтам, холст 128x192.
const HAND_FRONT := Vector2(84.0, 121.0)
const HAND_SIDE := Vector2(49.0, 123.0)

## Для кадров, где оружие держат наизготовку двумя руками — другой рисунок,
## не поправка к прежней точке.
const HAND_SIDE_AIMED := Vector2(52.0, 95.0)

## Точка на самом спрайте оружия, которой оно ложится в кисть. Без нeё
## совмещение идёт центром картинки, и в ладони оказывается ствол.
const WEAPON_GRIP := {
	"colt": Vector2(4.0, 6.0),
}


static func weapon_offset(weapon_id: String, size: Vector2, mirrored: bool) -> Vector2:
	if not WEAPON_GRIP.has(weapon_id):
		return size * 0.5
	var grip: Vector2 = WEAPON_GRIP[weapon_id]
	return Vector2(size.x - grip.x, grip.y) if mirrored else grip


static func hand_position(phase: float, speed: float, profile: bool,
		throw: float, throw_right: bool, aimed: bool = false) -> Vector2:
	var hand := HAND_FRONT
	if profile:
		hand = HAND_SIDE_AIMED if aimed else HAND_SIDE
	if speed >= WALK_THRESHOLD:
		hand.y += sin(phase) * ARM_LIFT
		hand.x += cos(phase) * 1.2

	if throw >= 0.0 and not profile:
		var swing := _throw_swing(throw)
		hand.y -= THROW_LIFT * swing
		hand.x += (6.0 if throw_right else -6.0) * swing
	return hand
