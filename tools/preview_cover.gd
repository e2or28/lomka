extends SceneTree
const Arena = preload("res://tests/framework/arena.gd")
const Library = preload("res://game/art_library.gd")
class Gallery extends "res://game/world_view.gd":
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1000, 300), Color(0.14, 0.13, 0.12))
		for i in 3:
			var slot = state.slots[i]
			slot.cover_ticks = 240
			slot.cover_health = 30 if i == 2 else 54
			slot.cover_position = Vector2(120 + 250 * i, 200)
			slot.cover_direction = Vector2.UP
			cover_art.covers[i] = {"age": [0.08, 0.27, 1.0][i], "from": slot.cover_position + Vector2(-65, -57), "hit": 0.03 if i == 2 else 1.0}
			_draw_cover(slot)
		cover_art.debris = [{"at": Vector2(870, 200), "age": 0.22}]
		cover_art.draw_debris(self, textures.suitcase, origin)
		for i in 4:
			draw_string(ThemeDB.fallback_font, Vector2(i * 250 + 30, 255), ["PLACE", "SETTLE", "HIT", "BREAK"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
var gallery
func _initialize() -> void:
	gallery = Gallery.new()
	gallery.state = Arena.room("cover-preview", 4, 0)
	gallery.textures.suitcase = Library.new().get_texture("suitcase")
	root.add_child(gallery)
	capture.call_deferred()
func capture() -> void:
	root.size = Vector2i(1000, 300)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/cover-preview.png")
	print("COVER PREVIEW OK")
	quit()
