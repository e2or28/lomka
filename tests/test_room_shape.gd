extends "res://tests/framework/test_case.gd"
## Класс: инвариант. Комната — единственное, что держит тела внутри
## картинки: границы разъедутся с нарисованным полом, и персонаж упрётся
## в невидимую стену посреди ковра либо уйдёт за стену.

const Room = preload("res://sim/room.gd")
const WorldView = preload("res://game/world_view.gd")

const RADIUS := 16.0


func title() -> String:
	return "форма комнаты"


func _test_lower_wall_stops_feet_at_the_visible_floor() -> bool:
	var room = Room.dev_room()
	var feet: Vector2 = room.clamp_body(Vector2(-200, 1000), RADIUS)
	var pixel_y: float = feet.y - room.bounds.position.y + WorldView.ROOM_INSET.y
	check(pixel_y + RADIUS <= 640.0,
		"ноги заходят на нижнюю стену: пол кончается на y=640, круг тела доходит до %.0f" % (pixel_y + RADIUS))
	return true


func _test_bounds_sit_on_the_drawn_floor() -> bool:
	var image := Image.new()
	if image.load("res://art/room_start.png") != OK:
		fail("фон комнаты не загрузился")
		return true

	var room = Room.dev_room()
	var inset := WorldView.ROOM_INSET
	eq(Vector2(image.get_width(), image.get_height()),
		inset + room.bounds.size + Vector2(93.0, 240.0),
		"поля картинки вокруг игровой зоны разошлись с отступом")
	return true


func _test_body_stays_inside_the_room() -> bool:
	var room = Room.dev_room()
	var limits: Rect2 = room.bounds.grow(-RADIUS)
	var outside := 0
	for step in 64:
		var angle := TAU * step / 64.0
		var far := Vector2.RIGHT.rotated(angle) * 4000.0
		var at: Vector2 = room.clamp_body(far, RADIUS)
		if at.x < limits.position.x or at.x > limits.end.x:
			outside += 1
		if at.y < limits.position.y or at.y > limits.end.y:
			outside += 1
	eq(outside, 0, "тело вышло за комнату после выталкивания из косяка")
	return true


func _test_doorways_do_not_let_the_body_in() -> bool:
	var room = Room.dev_room()
	check(not room.blockers.is_empty(), "косяков нет — дверные проёмы стали проходимы")

	var inside := 0
	for blocker in room.blockers:
		for step in 25:
			var at: Vector2 = blocker.position + blocker.size * Vector2(
				float(step % 5) / 4.0, float(step / 5) / 4.0)
			if blocker.grow(-0.01).has_point(room.clamp_body(at, RADIUS)):
				inside += 1
	eq(inside, 0, "тело осталось внутри дверного косяка")
	return true


## Выталкивание идёт по кратчайшему выходу, а не по фиксированной оси:
## иначе тело, зашедшее в косяк сверху, вылетало бы через всю комнату.
func _test_push_out_takes_the_nearest_way() -> bool:
	var room = Room.dev_room()
	var blocker: Rect2 = room.blockers[1]

	var from_left: Vector2 = Vector2(blocker.position.x + 2.0, blocker.get_center().y)
	almost_eq(room.clamp_body(from_left, RADIUS).x, blocker.position.x - RADIUS,
		"вход сбоку вытолкнут не вбок", 0.01)

	var from_top: Vector2 = Vector2(blocker.get_center().x, blocker.position.y + 2.0)
	almost_eq(room.clamp_body(from_top, RADIUS).y, blocker.position.y - RADIUS,
		"вход сверху вытолкнут не вверх", 0.01)
	return true


func _test_spawns_land_on_free_floor() -> bool:
	var room = Room.dev_room()
	for i in room.player_spawns.size():
		var at: Vector2 = room.player_spawn(i)
		eq(room.clamp_body(at, RADIUS), at, "точка появления игрока %d в стене" % i)
	for i in room.enemy_spawns.size():
		var at: Vector2 = room.enemy_spawn(i)
		eq(room.clamp_body(at, RADIUS), at, "точка появления врага %d в стене" % i)
	return true
