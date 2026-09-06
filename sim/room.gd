extends RefCounted
## Комната: границы и точки появления. Симуляция знает о ней только это —
## расстановка мебели не её дело (docs/PLAN.md).
##
## Планировки первого этажа — в room_map.gd.

var id: String = ""

var bounds: Rect2 = Rect2(-320, -180, 640, 360)

## Косяки остаются твёрдыми и после открытия прохода.
var blockers: Array[Rect2] = []

var player_spawns: Array[Vector2] = []
var enemy_spawns: Array[Vector2] = []


## Размер задан спрайтом, а не наоборот: персонаж нарисован высотой 156
## пикселей, и ужать его нельзя — на этом размере разваливается лицо.
## Границы и косяки сняты с art/room_start.png, см. art/README.md.
static func dev_room():
	var room := new()
	room.bounds = Rect2(-593, -302, 1186, 430)
	room.blockers = [
		Rect2(-593, -267, 40, 395),
		Rect2(546, -267, 47, 395),
	]
	room.player_spawns = [
		Vector2(-70, 0), Vector2(70, 0), Vector2(-70, 70), Vector2(70, 70),
	]
	room.enemy_spawns = [
		Vector2(-380, -180), Vector2(380, -180), Vector2(-380, 20), Vector2(380, 20),
	]
	return room


func player_spawn(index: int) -> Vector2:
	if player_spawns.is_empty():
		return Vector2.ZERO
	return player_spawns[index % player_spawns.size()]


func enemy_spawn(index: int) -> Vector2:
	if enemy_spawns.is_empty():
		return Vector2.ZERO
	return enemy_spawns[index % enemy_spawns.size()]


func clamp_body(position: Vector2, radius: float) -> Vector2:
	var limits := bounds.grow(-radius)
	var at := Vector2(
		clampf(position.x, limits.position.x, limits.end.x),
		clampf(position.y, limits.position.y, limits.end.y))
	for blocker in blockers:
		at = _push_out(at, blocker, radius, limits)
	return at


## Выход выбирается ближайший из четырёх, но только тот, что остаётся
## в комнате: косяк упирается в стену, и наружу выталкивать некуда.
static func _push_out(at: Vector2, blocker: Rect2, radius: float, limits: Rect2) -> Vector2:
	var grown := blocker.grow(radius)
	if not grown.has_point(at):
		return at

	var best := at
	var shortest := INF
	for exit in [Vector2(grown.position.x, at.y), Vector2(grown.end.x, at.y),
			Vector2(at.x, grown.position.y), Vector2(at.x, grown.end.y)]:
		var point: Vector2 = exit
		if point.x < limits.position.x or point.x > limits.end.x:
			continue
		if point.y < limits.position.y or point.y > limits.end.y:
			continue
		var distance := at.distance_squared_to(point)
		if distance < shortest:
			shortest = distance
			best = point
	return best


func contains(position: Vector2) -> bool:
	return bounds.has_point(position)


func to_dict() -> Dictionary:
	return {
		"blockers": blockers,
		"id": id,
		"bounds": bounds,
		"enemy_spawns": enemy_spawns,
		"player_spawns": player_spawns,
	}


static func from_dict(data: Dictionary):
	var room := new()
	room.id = data.get("id", "")
	room.bounds = data.get("bounds", Rect2())
	var walls: Array[Rect2] = []
	for rect in data.get("blockers", []):
		walls.append(rect)
	room.blockers = walls
	var enemies: Array[Vector2] = []
	for point in data.get("enemy_spawns", []):
		enemies.append(point)
	room.enemy_spawns = enemies
	var players: Array[Vector2] = []
	for point in data.get("player_spawns", []):
		players.append(point)
	room.player_spawns = players
	return room
