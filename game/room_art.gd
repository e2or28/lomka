extends RefCounted

const Room = preload("res://sim/room.gd")
const RoomMap = preload("res://sim/room_map.gd")
const WALL_HEIGHT := 210.0


static func floor_inset(id: String) -> Vector2:
	return Vector2(96, 210 if id == "south" else 140)


static func image_rect(room: Room, texture_size: Vector2) -> Rect2:
	var inset := floor_inset(room.id)
	return Rect2(room.bounds.position - Vector2(inset.x, WALL_HEIGHT),
		texture_size + Vector2(0, WALL_HEIGHT - inset.y))


static func draw(view: Node2D, room: Room, texture: Texture2D, origin: Vector2) -> void:
	var source_size := texture.get_size()
	var inset := floor_inset(room.id)
	var at := origin + room.bounds.position - Vector2(inset.x, WALL_HEIGHT)
	# Верхняя стена выше персонажа; пол остаётся в исходном масштабе 1:1.
	view.draw_texture_rect_region(texture, Rect2(at, Vector2(source_size.x, WALL_HEIGHT)),
		Rect2(Vector2.ZERO, Vector2(source_size.x, inset.y)))
	view.draw_texture_rect_region(texture,
		Rect2(at + Vector2(0, WALL_HEIGHT), Vector2(source_size.x, source_size.y - inset.y)),
		Rect2(Vector2(0, inset.y), Vector2(source_size.x, source_size.y - inset.y)))


## Проём открыт — зелёная стрелка наружу, закрыт — красная решётка.
static func draw_doors(view: Node2D, room: Room, opened: bool, origin: Vector2, progress: float = 1.0) -> void:
	var slide := smoothstep(0.0, 1.0, progress) if opened else 0.0
	var color := Color(0.63, 0.86, 0.65) if opened else Color(0.9, 0.32, 0.25)
	for direction in RoomMap.exits(room):
		var normal: Vector2 = RoomMap.DIRECTIONS[direction]
		var tangent := Vector2(-normal.y, normal.x)
		var at := origin + RoomMap.door(room, direction) - normal * 5
		var width := RoomMap.half_width(direction)
		view.draw_line(at - tangent * width, at + tangent * width, Color(color, 0.22), 2)
		if slide < 1.0:
			for side in [-1, 1]:
				view.draw_line(at + tangent * width * side * slide, at + tangent * width * side, color.darkened(0.5), 10)
				view.draw_line(at + tangent * width * side * slide, at + tangent * width * side, color, 3)
		if opened:
			color.a = slide
			var tip := at - normal * (14 + slide * 8)
			view.draw_line(tip - normal * 12 - tangent * 9, tip, color, 3)
			view.draw_line(tip - normal * 12 + tangent * 9, tip, color, 3)
		else:
			for step in [-1, 0, 1]:
				var bar: Vector2 = at + tangent * step * 22
				view.draw_line(bar - normal * 10, bar + normal * 10, color, 4)
