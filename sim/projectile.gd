extends RefCounted
## Снаряд. У офисного работника это брошенная папка с документами.
##
## Снаряд — список поведений, а не набор флагов: правило 4 требует, чтобы
## синергии складывались композицией. Пока поведение одно — пробитие, — но
## наведение, яд и расщепление лягут сюда же списком, а не ветвлением
## «если предмет A и предмет B».

const Fnv = preload("res://sim/core/fnv.gd")

var id: int = 0

## Кто бросил. Снаряд не бьёт своего владельца и своих по типу.
var owner_id: int = 0
var owner_kind: int = 0

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var radius: float = 6.0

## Сколько секунд снаряду осталось лететь. Считается из дальности и
## скорости, а не задаётся отдельно: иначе предмет на дальность не работал бы.
var life: float = 0.0

## Сколько тел ещё может пробить. Ноль — гаснет на первом попадании.
var pierce: int = 0

## Кого уже задел: без этого пробивающий снаряд бьёт одно тело каждый тик.
var hit_ids: Array[int] = []


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

	var range_units := float(stats.get("range", 0.0))
	projectile.life = range_units / speed if speed > 0.0 else 0.0
	return projectile


func expired() -> bool:
	return life <= 0.0


func can_hit(actor) -> bool:
	return actor.alive and int(actor.kind) != owner_kind and not hit_ids.has(actor.id)


func to_dict() -> Dictionary:
	return {
		"damage": damage,
		"hit_ids": hit_ids,
		"id": id,
		"life": life,
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
	var ids: Array[int] = []
	for value in data.get("hit_ids", []):
		ids.append(int(value))
	projectile.hit_ids = ids
	projectile.id = int(data.get("id", 0))
	projectile.life = float(data.get("life", 0.0))
	projectile.owner_id = int(data.get("owner_id", 0))
	projectile.owner_kind = int(data.get("owner_kind", 0))
	projectile.pierce = int(data.get("pierce", 0))
	projectile.position = data.get("position", Vector2.ZERO)
	projectile.radius = float(data.get("radius", 6.0))
	projectile.velocity = data.get("velocity", Vector2.ZERO)
	return projectile
