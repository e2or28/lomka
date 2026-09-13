extends SceneTree
const Arena = preload("res://tests/framework/arena.gd")
const Library = preload("res://game/art_library.gd")
const Sandbox = preload("res://game/dev_sandbox.gd")
class Gallery extends "res://game/world_view.gd":
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1120, 350), Color(0.14, 0.13, 0.12))
		for i in 4:
			var actor = state.actor_of_slot(i)
			var slot = state.slots[i]
			actor.position = Vector2(135 + i * 280, 245)
			actor.facing = -1 if i == 2 else 1
			slot.harvest_ticks = [1, 30, 55, 0][i]
			actions.installs.clear()
			if i == 3:
				actions.installs[actor.id] = {"age": 0.33, "organ": "courier_heart", "socket": "heart", "from": actor.position + Vector2(50, 10)}
			draw_line(actor.position + Vector2(-85, 0), actor.position + Vector2(100, 0), Color(0.65, 0.6, 0.5), 1)
			_draw_actor(actor)
			draw_string(ThemeDB.fallback_font, Vector2(i * 280 + 30, 300), ["REACH", "EXTRACT", "MIRRORED", "INSTALL"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
var gallery
func _initialize() -> void:
	root.size = Vector2i(1120, 350)
	gallery = Gallery.new()
	gallery.state = Arena.room("action-preview", 4, 0)
	var library := Library.new()
	for name in Sandbox.SPRITES:
		var texture = library.get_texture(name)
		if texture != null: gallery.textures[name] = texture
	root.add_child(gallery)
	capture.call_deferred()
func capture() -> void:
	root.size = Vector2i(1120, 350)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/actions-preview.png")
	print("ACTIONS PREVIEW OK")
	quit()
