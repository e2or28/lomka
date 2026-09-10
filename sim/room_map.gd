extends RefCounted

const Room = preload("res://sim/room.gd")

const IDS := ["south", "center", "north", "west", "east", "oil_baron"]
const NAMES := {"south": "Приёмная", "center": "Главный зал", "north": "Тандем",
	"west": "Курьерская", "east": "Архив", "oil_baron": "Нефтяной барон"}
const LINKS := {
	"south": {"north": "center"},
	"center": {"south": "south", "north": "north", "west": "oil_baron", "east": "east"},
	"north": {"south": "center"}, "west": {"east": "oil_baron"}, "east": {"west": "center"},
	"oil_baron": {"east": "center", "west": "west"},
}
const DIRECTIONS := {"north": Vector2.UP, "south": Vector2.DOWN,
	"west": Vector2.LEFT, "east": Vector2.RIGHT}
const OPPOSITE := {"north": "south", "south": "north", "west": "east", "east": "west"}
const ROSTERS := {"south": [], "center": ["test_monster", "runner", "heavy"],
	"north": ["tandem"], "west": ["runner", "runner"], "east": ["heavy", "test_monster"],
	"oil_baron": ["oil_baron", "soldier", "soldier_dark", "ice_agent", "ice_agent"]}

## Постоянный лут первого этажа: раскладывается при первом входе в комнату
## и больше не создаётся. Генерации по сиду ещё нет — она придёт на M3.
const LOOT := {
	"south": [
		{"kind": "item", "id": "carbon_copy", "at": Vector2(-320, -40)},
		{"kind": "item", "id": "red_folder", "at": Vector2(320, -40)},
	],
	"center": [
		{"kind": "item", "id": "rubber_stamp", "at": Vector2(-360, 230)},
		{"kind": "item", "id": "spring", "at": Vector2(360, 230)},
	],
	"west": [
		{"kind": "item", "id": "runners", "at": Vector2(-200, 330)},
		{"kind": "item", "id": "hole_punch", "at": Vector2(60, 330)},
	],
	"east": [
		{"kind": "item", "id": "heavy_seal", "at": Vector2(-160, 330)},
		{"kind": "item", "id": "optical_ruler", "at": Vector2(140, 330)},
		{"kind": "organ", "id": "rear_eye", "at": Vector2(-160, -330)},
		{"kind": "organ", "id": "notary_eye", "at": Vector2(140, -330)},
	],
}


static func make(id: String) -> Room:
	var room := Room.new()
	room.id = id
	# Пол замерен в исходных PNG; координаты симуляции начинаются в его центре.
	# Низ упирается в чёрный контур над лицевой полосой: y=890/890/890/1386/1386.
	var size := Vector2(1344, 750)
	if id == "south": size.y = 680
	if id in ["west", "east"]: size = Vector2(832, 1246)
	room.bounds = Rect2(-size * 0.5, size)
	room.player_spawns = [Vector2(-70, 100), Vector2(70, 100), Vector2(-70, 170), Vector2(70, 170)]
	room.enemy_spawns = [Vector2(0, -100), Vector2(-240, -160), Vector2(240, -160)]
	if id == "north": room.enemy_spawns = [Vector2(0, 60)]
	# Выступы у боковых дверей: проём между двумя прямоугольниками остаётся свободен.
	if id in ["center", "oil_baron"]:
		room.blockers = [Rect2(-672, -150, 42, 100), Rect2(629, -150, 43, 100),
			Rect2(-672, 35, 42, 105), Rect2(629, 35, 43, 105)]
	elif id == "west":
		room.blockers = [Rect2(366, -375, 50, 140), Rect2(366, 145, 50, 130)]
	elif id == "east":
		room.blockers = [Rect2(-416, -375, 50, 140), Rect2(-416, 145, 50, 140)]
	return room


static func exits(room: Room) -> Dictionary:
	return LINKS.get(room.id, {})


static func door(room: Room, direction: String) -> Vector2:
	var at: Vector2 = room.bounds.get_center()
	match direction:
		"north": at.y = room.bounds.position.y
		"south": at.y = room.bounds.end.y
		"west": at = Vector2(room.bounds.position.x, -7 if room.id in ["center", "oil_baron"] else -15)
		"east": at = Vector2(room.bounds.end.x, -7 if room.id in ["center", "oil_baron"] else -15)
	return at


static func half_width(direction: String) -> float:
	return 70.0 if direction in ["north", "south"] else 40.0
