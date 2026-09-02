extends RefCounted
## Снаряд: чемодан, брошенный служащим.
##
## Летит по прямой, на своей высоте — падения нет. Долетев до заявленной
## дальности, не гаснет, а переворачивается через себя и проходит ещё
## отрезок: приём взят у Mr. P из Brawl Stars, где чемодан кувыркается и
## доезжает дальше точки броска.
##
## Что это даёт механически: у оружия появляется две дальности — надёжная,
## на которой снаряд летит ровно, и добавочная, куда он доберётся кувырком.
## Обе статы, поэтому предмет сможет крутить их по отдельности.
##
## Дуга с падением здесь была и убрана намеренно: снаряд, шлёпающийся на
## пол, обрывал атаку там, где игрок ждал продолжения.

const Fnv = preload("res://sim/core/fnv.gd")

var id: int = 0

## Чем стреляли: папка из чемодана, пуля из кольта. Приходит из записи
## оружия и дальше ни на что в бою не влияет — по нему представление
## выбирает, что нарисовать. Держится в снаряде, а не выводится из владельца:
## оружие в руках сменится, а уже летящая папка обязана остаться папкой.
var kind: String = ""

## Кто бросил. Снаряд не бьёт своего владельца и своих по типу.
var owner_id: int = 0
var owner_kind: int = 0

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var radius: float = 6.0

## Сколько уже пролетел и сколько ему отмерено.
var travelled: float = 0.0

## Дальность ровного полёта. Дальше начинается кувырок.
var straight_range: float = 0.0

## Сколько ещё проходит кувырком. Ноль — гаснет сразу по дальности.
var tumble_range: float = 0.0

## Сколько тел ещё может пробить. Ноль — гаснет на первом попадании.
var pierce: int = 0

## Кого уже задел: без этого пробивающий снаряд бьёт одно тело каждый тик.
var hit_ids: Array[int] = []


static func spawn(p_id: int, owner, direction: Vector2, stats: Dictionary,
		p_kind: String = ""):
	var projectile := new()
	projectile.id = p_id
	projectile.kind = p_kind
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

	projectile.straight_range = float(stats.get("range", 0.0))
	projectile.tumble_range = float(stats.get("tumble_range", 0.0))
	return projectile


func total_range() -> float:
	return straight_range + tumble_range


## Идёт ли сейчас кувырок. Представление рисует по этому вращение, а урон
## остаётся тем же: кувыркающийся чемодан бьёт не слабее.
func tumbling() -> bool:
	return travelled >= straight_range


## Насколько далеко зашёл кувырок, от 0 до 1. Вне кувырка — -1.
func tumble_progress() -> float:
	if not tumbling() or tumble_range <= 0.0:
		return -1.0
	return clampf((travelled - straight_range) / tumble_range, 0.0, 1.0)


## Шаг полёта. Возвращает false, когда снаряд выдохся.
func advance(delta: float) -> bool:
	var step := velocity * delta
	position += step
	travelled += step.length()
	return travelled < total_range()


func expired() -> bool:
	return travelled >= total_range()


func can_hit(actor) -> bool:
	return actor.alive and int(actor.kind) != owner_kind and not hit_ids.has(actor.id)


func to_dict() -> Dictionary:
	return {
		"damage": damage,
		"hit_ids": hit_ids,
		"id": id,
		"kind": kind,
		"owner_id": owner_id,
		"owner_kind": owner_kind,
		"pierce": pierce,
		"position": position,
		"radius": radius,
		"straight_range": straight_range,
		"travelled": travelled,
		"tumble_range": tumble_range,
		"velocity": velocity,
	}


static func from_dict(data: Dictionary):
	var projectile := new()
	projectile.damage = float(data.get("damage", 0.0))
	var ids: Array[int] = []
	for value in data.get("hit_ids", []):
		ids.append(int(value))
	projectile.hit_ids = ids
	projectile.id = int(data.get("id", 0))
	projectile.kind = data.get("kind", "")
	projectile.owner_id = int(data.get("owner_id", 0))
	projectile.owner_kind = int(data.get("owner_kind", 0))
	projectile.pierce = int(data.get("pierce", 0))
	projectile.position = data.get("position", Vector2.ZERO)
	projectile.radius = float(data.get("radius", 6.0))
	projectile.straight_range = float(data.get("straight_range", 0.0))
	projectile.travelled = float(data.get("travelled", 0.0))
	projectile.tumble_range = float(data.get("tumble_range", 0.0))
	projectile.velocity = data.get("velocity", Vector2.ZERO)
	return projectile
