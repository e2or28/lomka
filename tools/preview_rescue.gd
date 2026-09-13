extends SceneTree
const Arena = preload("res://tests/framework/arena.gd")
const Library = preload("res://game/art_library.gd")
const Sandbox = preload("res://game/dev_sandbox.gd")
class Gallery extends "res://game/world_view.gd":
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1000, 350), Color(0.14, 0.13, 0.12))
		breath = 0.6
		for i in 4:
			var actor = state.actor_of_slot(i)
			actor.position = Vector2(120 + i * 250, 245)
			actor.facing = 1
			state.slots[i].downed = i == 0
			state.slots[i].revive_target = state.actor_of_slot(0).id if i == 1 else -1
			state.slots[i].revive_ticks = 150 if i == 1 else 0
			if i >= 2: rescue.rising[actor.id] = 0.23 if i == 2 else 0.49
			draw_line(actor.position + Vector2(-95, 0), actor.position + Vector2(95, 0), Color(0.65, 0.6, 0.5), 1)
			_draw_actor(actor)
			draw_string(ThemeDB.fallback_font, Vector2(i * 250 + 30, 300), ["DOWNED", "HELPING", "KNEEL", "GETTING UP"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
var gallery
func _initialize() -> void:
	gallery = Gallery.new()
	gallery.state = Arena.room("rescue-preview", 4, 0)
	var library := Library.new()
	for name in Sandbox.SPRITES:
		var texture = library.get_texture(name)
		if texture != null: gallery.textures[name] = texture
	root.add_child(gallery)
	capture.call_deferred()
func capture() -> void:
	root.size = Vector2i(1000, 350)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/rescue-preview.png")
	print("RESCUE PREVIEW OK")
	quit()
