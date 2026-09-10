extends SceneTree
## Настоящая сцена: игровые спрайты, предупреждение, подъём и открытое лобби.
const Sandbox = preload("res://game/dev_sandbox.gd")
const Travel = preload("res://sim/room_travel.gd")
const Encounter = preload("res://sim/encounter.gd")
var game

func _initialize() -> void:
	preview.call_deferred()

func preview() -> void:
	game = Sandbox.new()
	root.add_child(game)
	game.set_physics_process(false)
	game._state = Travel.start("coop-preview", 4)
	game._view.state = game._state
	game._organ_hud.state = game._state
	var state = game._state
	for i in 4: state.actor_of_slot(i).position = Vector2(-180 + i * 100, 100)
	state.slots[1].downed = true
	state.actor_of_slot(1).health = 0
	state.actor_of_slot(0).position = state.actor_of_slot(1).position + Vector2(-60, 0)
	state.slots[0].revive_target = state.actor_of_slot(1).id
	state.slots[0].revive_ticks = 150
	for i in 3:
		var actor = Encounter.add_enemy(state, ["test_monster", "runner", "heavy"][i], Vector2(-260 + i * 250, -50))
		actor.facing = -1 if i == 2 else 1
	state.pending_spawns.append({"id": "runner", "position": Vector2(320, 140), "spawn_tick": 45})
	game._view.consume_events([{"type": "wave_warning", "room_id": state.room.id, "count": 1}])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/coop-preview.png")
	game._lobby.toggle()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/lobby-preview.png")
	print("COOP PREVIEW OK")
	quit()
