extends RefCounted
## Снаряд. У офисного работника это папка, вылетающая из чемодана.
##
## Снаряд — список поведений, а не набор флагов: правило 4 требует, чтобы
## синергии складывались композицией. Пока поведение одно — пробитие, — но
## наведение, яд и расщепление лягут сюда же списком, а не ветвлением
## «если предмет A и предмет B».
##
## Два заимствования из Isaac, оба про ощущение боя:
##
## Первое — снаряд наследует часть скорости бросающего. Бежишь вправо и
## кидаешь вверх, папка уходит вверх-вправо. Отсюда разница между стрельбой
## стоя и на бегу, упреждение и осмысленное отступление с отстрелом.
##
## Второе — дальность это падение, а не таймер. Папка летит по дуге и
## шлёпается на пол. Так игроку видно, почему далёкий враг не получил урона,
## а не «снаряд исчез в воздухе».

## Ускорение падения, пикселей в секунду за секунду. Не стат: дуга задаёт
## характер оружия целиком, и крутить её предметом значило бы ломать
## читаемость боя.
const GRAVITY := 900.0

## С какой высоты вылетает снаряд — примерно уровень руки.
const START_HEIGHT := 46.0

var id: int = 0

## Кто бросил. Снаряд не бьёт своего владельца и своих по типу.
var owner_id: int = 0
var owner_kind: int = 0

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var radius: float = 6.0

## Высота над полом и вертикальная скорость. Пол — это ноль; коснувшись
## его, снаряд гаснет. Заменяет прежний таймер жизни.
var height: float = START_HEIGHT
var height_speed: float = 0.0

## Сколько тел ещё может пробить. Ноль — гаснет на первом попадании.
var pierce: int = 0

## Кого уже задел: без этого пробивающий снаряд бьёт одно тело каждый тик.
var hit_ids: Array[int] = []


## Вертикальная скорость, при которой снаряд коснётся пола ровно через
## flight_time секунд. Так дальность остаётся тем, что задано статом, а дуга
## получается сама: z(t) = h + v*t - g*t^2/2 = 0.
static func launch_speed(flight_time: float) -> float:
	if flight_time <= 0.0:
		return 0.0
	return (GRAVITY * flight_time * flight_time * 0.5 - START_HEIGHT) / flight_time


static func spawn(p_id: int, owner, direction: Vector2, stats: Dictionary):
	var projectile := new()
	projectile.id = p_id
	projectile.owner_id = owner.id
	projectile.owner_kind = int(owner.kind)
	projectile.position = owner.position
	projectile.damage = float(stats.get("damage", 0.0))

	var speed := float(stats.get("projectile_speed", 0.0))
	var aim := direction if direction != Vector2.ZERO else Vector2.RIGHT
	projectile.velocity = aim.normalized() * speed

	# Часть скорости бросающего переходит снаряду
	var momentum := float(stats.get("shot_momentum", 0.0))
	if momentum != 0.0:
		projectile.velocity += owner.velocity * momentum

	var range_units := float(stats.get("range", 0.0))
	var flight := range_units / speed if speed > 0.0 else 0.0
	projectile.height = START_HEIGHT
	projectile.height_speed = launch_speed(flight)
	return projectile


## Шаг полёта. Возвращает false, когда снаряд коснулся пола.
func advance(delta: float) -> bool:
	position += velocity * delta
	height_speed -= GRAVITY * delta
	height += height_speed * delta
	if height <= 0.0:
		height = 0.0
		return false
	return true


func expired() -> bool:
	return height <= 0.0


func can_hit(actor) -> bool:
	return actor.alive and int(actor.kind) != owner_kind and not hit_ids.has(actor.id)


func to_dict() -> Dictionary:
	return {
		"damage": damage,
		"height": height,
		"height_speed": height_speed,
		"hit_ids": hit_ids,
		"id": id,
		"owner_id": owner_id,
		"owner_kind": owner_kind,
		"pierce": pierce,
		"position": position,
		"radius": radius,
		"velocity": velocity,
	}


static func from_dict(data: Dictionary):
	var projectile := new()
	projectile.damage = float(data.get("damage", 0.0))
	projectile.height = float(data.get("height", 0.0))
	projectile.height_speed = float(data.get("height_speed", 0.0))
	var ids: Array[int] = []
	for value in data.get("hit_ids", []):
		ids.append(int(value))
	projectile.hit_ids = ids
	projectile.id = int(data.get("id", 0))
	projectile.owner_id = int(data.get("owner_id", 0))
	projectile.owner_kind = int(data.get("owner_kind", 0))
	projectile.pierce = int(data.get("pierce", 0))
	projectile.position = data.get("position", Vector2.ZERO)
	projectile.radius = float(data.get("radius", 6.0))
	projectile.velocity = data.get("velocity", Vector2.ZERO)
	return projectile
