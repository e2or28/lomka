extends RefCounted
## Поза персонажа: чистые функции от скорости, фазы шага и перезарядки —
## ни узлов, ни системных часов, поэтому проверяется тестом.
##
## Живёт в game/, а не в sim/: попадание считается по положению тела, а не
## по нарисованной руке, и гонять фазу шага по сети незачем.
##
## На ходу персонаж всегда в профиль: кадров ходьбы вверх и вниз в наборе
## нет. Разворачивается он на остановке — лицом к зрителю, если последним
## шёл по вертикали, и тем боком, которым шёл, если по горизонтали.

const STRIDE := 96.0

const IDLE_BREATH := 0.6
const IDLE_PERIOD := 2.6

## Короче времени перезарядки, иначе рука не успевает вернуться и персонаж
## машет непрерывно.
const THROW_TIME := 0.18

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


## На ходу дыхания нет: подъём корпуса уже нарисован в самих кадрах, и
## второй поверх них читается как дрожь.
static func idle_bob(speed: float, breath: float) -> Vector2:
	if speed >= WALK_THRESHOLD:
		return Vector2.ZERO
	return Vector2(0.0, -absf(sin(breath * TAU / IDLE_PERIOD)) * IDLE_BREATH)


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


## Безоружная анфасная стойка лежит в art/player.png: тот же файл идёт
## на иконку, поэтому имя у него общее, а не player_front_stand.
const FRONT_STAND := "player"


static func stand_names(weapon_id: String) -> PackedStringArray:
	if weapon_id == "colt":
		# Опорный кадр: обе ноги на полу и руки уже держат пистолет.
		return PackedStringArray(["player_colt_walk_4", "player_side_stand"])
	if weapon_id == "":
		return PackedStringArray(["player_side_stand"])
	return PackedStringArray(["player_%s_stand" % weapon_id, "player_side_stand"])


## Все имена здесь анфасные — представление по одному этому знает, что
## отражать кадр не надо и кисть брать анфасную.
static func front_stand_names(weapon_id: String) -> PackedStringArray:
	if weapon_id == "":
		return PackedStringArray([FRONT_STAND])
	return PackedStringArray(["player_%s_front" % weapon_id, FRONT_STAND])


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


## Лицом к зрителю персонаж встаёт после ходьбы по вертикали. Стрельба
## вбок разворачивает его в профиль, стрельба вверх и вниз — нет: как и
## взгляд, поза слушает прицел раньше движения.
static func stand_front(aim: Vector2, velocity: Vector2, firing: bool, previous: bool) -> bool:
	if firing and absf(aim.x) > 0.2:
		return false
	if velocity.length() < WALK_THRESHOLD:
		return previous
	return absf(velocity.y) > absf(velocity.x)


static func use_walk_frames(speed: float) -> bool:
	return speed >= WALK_THRESHOLD


## Точка на самом спрайте оружия, которой оно ложится в кисть. Без неё
## совмещение идёт центром картинки, и в ладони оказывается ствол.
const WEAPON_GRIP := {
	"colt": Vector2(4.0, 6.0),
	"suitcase": Vector2(13.0, 2.0),
}


static func weapon_offset(weapon_id: String, size: Vector2, mirrored: bool) -> Vector2:
	if not WEAPON_GRIP.has(weapon_id):
		return size * 0.5
	var grip: Vector2 = WEAPON_GRIP[weapon_id]
	return Vector2(size.x - grip.x, grip.y) if mirrored else grip
