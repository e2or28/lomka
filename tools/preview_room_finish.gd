extends SceneTree
const Arena = preload("res://tests/framework/arena.gd")
const Library = preload("res://game/art_library.gd")
const Map = preload("res://sim/room_map.gd")
const RoomArt = preload("res://game/room_art.gd")
class Gallery extends "res://game/world_view.gd":
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1400, 610), Color(0.14, 0.13, 0.12))
		var tank = state.actors[-1]
		for i in 3:
			tank.id = 900 + i
			tank.alive = false
			tank.aim = Vector2.LEFT
			tank_wreck.ages[tank.id] = [0.0, 0.55, 2.8][i]
			_draw_sprite(tank, Vector2(290 + i * 455, 270), Color.WHITE)
			draw_string(ThemeDB.fallback_font, Vector2(i * 455 + 70, 320), ["HIT", "COLLAPSE", "WRECK"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var room = Map.make("north")
		for i in 3:
			var at := Vector2(180 + i * 455, 500) - Map.door(room, "south")
			RoomArt.draw_doors(self, room, true, at, [0.0, 0.5, 1.0][i])
			draw_string(ThemeDB.fallback_font, Vector2(i * 455 + 70, 565), ["LOCKED", "OPENING", "OPEN"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
var gallery
func _initialize() -> void:
	gallery = Gallery.new()
	gallery.state = Arena.duel("finish-preview", "tandem", Vector2(200, 0))
	gallery.textures.tandem = Library.new().get_texture("tandem")
	root.add_child(gallery)
	capture.call_deferred()
func capture() -> void:
	root.size = Vector2i(1400, 610)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/room-finish-preview.png")
	print("ROOM FINISH PREVIEW OK")
	quit()
