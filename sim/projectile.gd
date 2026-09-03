extends RefCounted
## Снаряд. Летит по прямой на своей высоте — падения нет. Долетев до
## заявленной дальности, не гаснет, а переворачивается через себя и
## проходит ещё отрезок (приём Mr. P из Brawl Stars) — дуга с падением
## здесь была и убрана: снаряд, шлёпающийся на пол, обрывал атаку там, где
## игрок ждал продолжения.

const Fnv = preload("res://sim/core/fnv.gd")

var id: int = 0

## Держится в снаряде, а не выводится из владельца оружия: оружие в руках
## сменится, а уже летящая папка обязана остаться папкой.
var kind: String = ""

var owner_id: int = 0
var owner_kind: int = 0

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var radius: float = 6.0
var travelled: float = 0.0
var straight_range: float = 0.0
var tumble_range: float = 0.0
var pierce: int = 0

## Без этого пробивающий снаряд бил бы одно тело каждый тик.
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

	var momentum := float(stats.get("shot_momentum", 0.0))
	if momentum != 0.0:
		projectile.velocity += owner.velocity * momentum

	projectile.straight_range = float(stats.get("range", 0.0))
	projectile.tumble_range = float(stats.get("tumble_range", 0.0))
	return projectile


func total_range() -> float:
	return straight_range + tumble_range


func tumbling() -> bool:
	return travelled >= straight_range


## Вне кувырка — -1.
func tumble_progress() -> float:
	if not tumbling() or tumble_range <= 0.0:
		return -1.0
	return clampf((travelled - straight_range) / tumble_range, 0.0, 1.0)


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
