extends SceneTree

const Sandbox = preload("res://game/dev_sandbox.gd")
const Encounter = preload("res://sim/encounter.gd")
const Map = preload("res://sim/room_map.gd")
const Director = preload("res://sim/encounter_director.gd")
const Tick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
var game

func _initialize() -> void:
	preview.call_deferred()

func preview() -> void:
	game = Sandbox.new()
	root.add_child(game)
	game.set_physics_process(false)
	game._state = Encounter.dev_room("baron-preview", 1, 0, Map.make("oil_baron"))
	game._state.pickups.clear()
	game._state.actor_of_slot(0).position = Vector2(0, 280)
	Director.begin(game._state)
	game._view.state = game._state
	game._organ_hud.state = game._state
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/oil-baron-room.png")
	for i in 130:
		var events := Tick.step(game._state, {0: Command.from_axes(game._state.tick, Vector2.LEFT if i < 50 else Vector2.RIGHT, Vector2.UP, Command.BTN_FIRE)})
		game._view.consume_events(events)
		game._view.advance(1.0 / 60.0)
		game._view.queue_redraw()
		if i in [29, 79, 129]:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.cache/oil-baron-combat-%d.png" % i)
	print("OIL BARON PREVIEW OK")
	quit()
