extends RefCounted
## Комната: границы и точки появления.
##
## Планировка комнат остаётся человеку — это записано в docs/PLAN.md и здесь
## не меняется. Симуляция знает о комнате ровно две вещи: где стены и где
## встают тела. Всё остальное — расстановка мебели и вопрос «интересно ли
## тут находиться» — не её дело.
##
## Пока комната одна и задаётся кодом. На M3 придут зоны из data/, и тогда
## сюда добавится идентификатор и таблица спавна.

var bounds: Rect2 = Rect2(-320, -180, 640, 360)

## Откуда игроки и враги начинают. Индекс по порядку.
var player_spawns: Array[Vector2] = []
var enemy_spawns: Array[Vector2] = []


static func dev_room():
	## Комната разработчиков: тестовый полигон на M1.
	##
	## Размер задан спрайтом, а не наоборот. Персонаж нарисован высотой около
	## 127 пикселей, и ужать его до привычных сорока нельзя — на этом размере
	## лицо разваливается. Значит масштаб мира подгоняется под рисунок: тело
	## занимает около пятой части высоты комнаты, как в исааковском референсе.
	var room := new()
	room.bounds = Rect2(-580, -320, 1160, 640)
	room.player_spawns = [
		Vector2(-70, 150), Vector2(70, 150), Vector2(-70, 240), Vector2(70, 240),
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


## Удержать тело внутри стен. Радиус — половина ширины тела.
func clamp_body(position: Vector2, radius: float) -> Vector2:
	return Vector2(
		clampf(position.x, bounds.position.x + radius, bounds.end.x - radius),
		clampf(position.y, bounds.position.y + radius, bounds.end.y - radius))


func contains(position: Vector2) -> bool:
	return bounds.has_point(position)


func to_dict() -> Dictionary:
	return {
		"bounds": bounds,
		"enemy_spawns": enemy_spawns,
		"player_spawns": player_spawns,
	}


static func from_dict(data: Dictionary):
	var room := new()
	room.bounds = data.get("bounds", Rect2())
	var enemies: Array[Vector2] = []
	for point in data.get("enemy_spawns", []):
		enemies.append(point)
	room.enemy_spawns = enemies
	var players: Array[Vector2] = []
	for point in data.get("player_spawns", []):
		players.append(point)
	room.player_spawns = players
	return room
