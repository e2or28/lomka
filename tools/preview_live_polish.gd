extends SceneTree
## Воспроизводимый бой через SimTick и WorldView; кадры пригодны для видео.
const Arena = preload("res://tests/framework/arena.gd")
const Encounter = preload("res://sim/encounter.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Command = preload("res://sim/input/command.gd")
const Tick = preload("res://sim/tick.gd")
const Reinforcements = preload("res://sim/reinforcements.gd")
const Library = preload("res://game/art_library.gd")
const Sandbox = preload("res://game/dev_sandbox.gd")
const View = preload("res://game/world_view.gd")
class SoundTrack extends "res://game/sound_effects.gd":
	var time := 0.0
	var timeline := []
	var last := {}
	func play(key: String) -> void:
		if time - float(last.get(key, -1.0)) < 0.045: return
		last[key] = time
		timeline.append({"time": time, "sound": key})
var view
var p0
var p1
var corpse
var gunship
var max_harvest := 0
var max_revive := 0
var blasts := 0
var revived := false

func _initialize() -> void:
	root.size = Vector2i(1280, 860)
	view = View.new()
	view.state = Arena.room("live-polish", 3, 0)
	p0 = view.state.actor_of_slot(0)
	p1 = view.state.actor_of_slot(1)
	p0.position = Vector2(-220, 150)
	p1.position = Vector2(-100, 60)
	var decoy = view.state.actor_of_slot(2)
	decoy.position = Vector2(380, -180)
	decoy.invulnerable = 30.0
	Encounter.add_enemy(view.state, "soldier", Vector2(550, -180))
	Arsenal.equip(p0, "colt")
	var library := Library.new()
	for name in Sandbox.SPRITES:
		var texture = library.get_texture(name)
		if texture != null: view.textures[name] = texture
	root.add_child(view)
	capture.call_deferred()

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://.cache/live-polish")
	var sound := SoundTrack.new()
	var render := DisplayServer.get_name() != "headless"
	view.advance(0.0)
	for frame in 405:
		if frame == 90:
			p0.position = Vector2(-220, 100)
			p0.velocity = Vector2.ZERO
			corpse = Encounter.add_enemy(view.state, "runner", Vector2(-170, 100))
			corpse.take_damage(10000)
		if frame == 130:
			p0.position = Vector2(-160, 60)
			p0.velocity = Vector2.ZERO
			p1.position = Vector2(-100, 60)
			p1.velocity = Vector2.ZERO
			view.state.slots[1].downed = true
			p1.health = 0.0
		if frame == 310:
			Reinforcements.land(view.state, Encounter, 130)
			for actor in view.state.actors:
				if actor.behaviour == "gunship": gunship = actor
			Encounter.add_enemy(view.state, "barrel", Vector2(160, 110))
			p0.position = Vector2(-100, 110)
			p0.velocity = Vector2.ZERO
		if frame == 345 and gunship != null: gunship.take_damage(10000)
		for substep in 2:
			var move := Vector2.ZERO
			var aim := Vector2.ZERO
			var buttons := 0
			if frame < 90:
				move = Vector2.UP if frame % 45 < 23 else Vector2.DOWN
				aim = move
				buttons = Command.BTN_FIRE
			elif frame < 120: buttons = Command.BTN_HARVEST
			elif frame >= 130 and frame < 281: buttons = Command.BTN_INTERACT
			elif frame >= 310 and frame < 350:
				aim = Vector2.RIGHT
				buttons = Command.BTN_FIRE
			view.firing[p0.id] = buttons & Command.BTN_FIRE != 0
			var commands := {0: Command.from_axes(view.state.tick, move, aim, buttons)}
			var events := Tick.step(view.state, commands)
			sound.time = float(frame * 2 + substep) / 60.0
			sound.consume(view.state, events, 0)
			view.consume_events(events)
			view.advance(Tick.DELTA)
			max_harvest = maxi(max_harvest, view.state.slots[0].harvest_ticks)
			max_revive = maxi(max_revive, view.state.slots[0].revive_ticks)
			for event in events:
				if event.type == "explosion": blasts += 1
				if event.type == "revived": revived = true
		view.origin = Vector2(600, 430)
		view.queue_redraw()
		if render:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.cache/live-polish/%04d.png" % frame)
		if frame % 90 == 0: print("LIVE FRAME ", frame)
	var audio_file := FileAccess.open("res://.cache/live-polish/audio.json", FileAccess.WRITE)
	audio_file.store_string(JSON.stringify(sound.timeline))
	audio_file.close()
	sound.free()
	print("LIVE POLISH: harvest=", max_harvest, " installed=", corpse.harvested,
		" revive=", max_revive, " revived=", revived, " barrel explosions=", blasts)
	if max_harvest != 59 or not corpse.harvested or not revived or blasts < 1:
		push_error("Live scenario did not complete its actions")
		quit(1)
	else:
		quit()
