extends RefCounted
## Снаряд. Летит по прямой на своей высоте — падения нет. Долетев до
## заявленной дальности, не гаснет, а переворачивается через себя и
## проходит ещё отрезок (приём Mr. P из Brawl Stars) — дуга с падением
## здесь была и убрана: снаряд, шлёпающийся на пол, обрывал атаку там, где
## игрок ждал продолжения.


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
var bounces: int = 0

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
	projectile.pierce = maxi(0, int(stats.get("pierce", 0.0)))
	projectile.bounces = maxi(0, int(stats.get("bounces", 0.0)))

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


func fly(delta: float, room) -> Dictionary:
	var points: Array[Vector2] = [position]
	var remaining := minf(velocity.length() * delta, maxf(0, total_range() - travelled))
	while remaining > 0.00001:
		var direction := velocity.normalized()
		var step := direction * remaining
		var hit := _wall_hit(position, step, room)
		var fraction: float = hit.get("fraction", 1.0)
		position += step * fraction
		travelled += remaining * fraction
		points.append(position)
		remaining *= 1.0 - fraction
		if not hit.has("normal"): break
		if bounces <= 0:
			return {"points": points, "flying": false}
		bounces -= 1
		var normal: Vector2 = hit["normal"]
		velocity = velocity.bounce(normal)
		position += normal * 0.0001
	return {"points": points, "flying": not expired()}


static func _wall_hit(from: Vector2, step: Vector2, room) -> Dictionary:
	var hit := {}
	var nearest := 1.0
	for axis in 2:
		if is_zero_approx(step[axis]): continue
		var edge: float = room.bounds.end[axis] if step[axis] > 0 else room.bounds.position[axis]
		var fraction: float = (edge - from[axis]) / step[axis]
		if fraction >= 0 and fraction <= nearest:
			var normal := Vector2.ZERO
			normal[axis] = -signf(step[axis])
			hit = {"fraction": fraction, "normal": normal}
			nearest = fraction
	for blocker in room.blockers:
		var enter := -INF
		var leave := INF
		var normal := Vector2.ZERO
		var misses := false
		for axis in 2:
			if is_zero_approx(step[axis]):
				if from[axis] < blocker.position[axis] or from[axis] > blocker.end[axis]: misses = true
				continue
			var first: float = (blocker.position[axis] - from[axis]) / step[axis]
			var last: float = (blocker.end[axis] - from[axis]) / step[axis]
			if minf(first, last) > enter:
				enter = minf(first, last)
				normal = Vector2.ZERO
				normal[axis] = -signf(step[axis])
			leave = minf(leave, maxf(first, last))
		if not misses and enter >= 0 and enter <= leave and enter <= nearest:
			nearest = enter
			hit = {"fraction": enter, "normal": normal}
	return hit


static func hit_fraction(from: Vector2, to: Vector2, center: Vector2, reach: float) -> float:
	var offset := from - center
	if offset.length_squared() <= reach * reach: return 0.0
	var step := to - from
	var a := step.length_squared()
	if a <= 0.000001: return INF
	var b := offset.dot(step)
	var discriminant := b * b - a * (offset.length_squared() - reach * reach)
	if discriminant < 0: return INF
	var fraction := (-b - sqrt(discriminant)) / a
	return fraction if fraction >= 0 and fraction <= 1 else INF


func can_hit(actor) -> bool:
	return actor.alive and int(actor.kind) != owner_kind and not hit_ids.has(actor.id)


func to_dict() -> Dictionary:
	return {
		"bounces": bounces,
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
	projectile.bounces = int(data.get("bounces", 0))
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
