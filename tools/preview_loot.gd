extends SceneTree
const Arena = preload("res://tests/framework/arena.gd")
const Library = preload("res://game/art_library.gd")
const Sandbox = preload("res://game/dev_sandbox.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Pickup = preload("res://sim/pickup.gd")
class Gallery extends "res://game/world_view.gd":
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1000, 330), Color(0.14, 0.13, 0.12))
		for i in 4:
			var actor = state.actor_of_slot(i)
			actor.position = Vector2(120 + i * 250, 240)
			actor.facing = 1
			if i >= 2:
				loot_feedback.switches[actor.id] = {"age": 0.08 if i == 2 else 0.18, "from": "suitcase"}
			_draw_actor(actor)
			var pickup = Pickup.weapon(100 + i, "colt", actor.position + Vector2(60, 0))
			if i == 0:
				loot_feedback.births[pickup.id] = 0.14
				loot_feedback.draw_pickup(self, textures, pickup, pickup.position, false, "E")
			if i == 1:
				loot_feedback.takes = [{"pickup": pickup, "actor": actor.id, "age": 0.13}]
				loot_feedback.draw_takes(self, textures, state, origin)
			draw_string(ThemeDB.fallback_font, Vector2(i * 250 + 30, 290), ["DROP", "PICK UP", "PUT AWAY", "DRAW WEAPON"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
var gallery
func _initialize() -> void:
	gallery = Gallery.new()
	gallery.state = Arena.room("loot-preview", 4, 0)
	for i in [2, 3]: Arsenal.equip(gallery.state.actor_of_slot(i), "colt")
	var library := Library.new()
	for name in Sandbox.SPRITES:
		var texture = library.get_texture(name)
		if texture != null: gallery.textures[name] = texture
	root.add_child(gallery)
	capture.call_deferred()
func capture() -> void:
	root.size = Vector2i(1000, 330)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/loot-preview.png")
	print("LOOT PREVIEW OK")
	quit()
