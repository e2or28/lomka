extends SceneTree
const View = preload("res://game/world_view.gd")
const Sandbox = preload("res://game/dev_sandbox.gd")
const Library = preload("res://game/art_library.gd")
const Encounter = preload("res://sim/encounter.gd")
const Map = preload("res://sim/room_map.gd")
const Director = preload("res://sim/encounter_director.gd")
var view
func _initialize() -> void: capture.call_deferred()
func capture() -> void:
	root.size = Vector2i(1536, 1100)
	view = View.new()
	view.state = Encounter.dev_room("atmosphere-preview", 1, 0, Map.make("oil_baron"))
	Director.begin(view.state)
	view.state.actor_of_slot(0).position = Vector2(200, 240)
	for actor in view.state.actors:
		if actor.behaviour == "oil_baron":
			actor.attack_ticks = 0
			actor.cooldown = 2.2
	var library := Library.new()
	for name in Sandbox.SPRITES:
		var texture = library.get_texture(name)
		if texture != null: view.textures[name] = texture
	root.add_child(view)
	view.advance(0.0)
	view.origin = Vector2(768, 585)
	for i in 2:
		view.breath = 4.0 if i == 0 else 5.035
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.cache/atmosphere-%d.png" % i)
	print("ATMOSPHERE PREVIEW OK")
	quit()
