extends RefCounted

const Room = preload("res://sim/room.gd")
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
