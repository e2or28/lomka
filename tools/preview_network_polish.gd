extends "res://tools/smoke_network.gd"
const Encounter = preload("res://sim/encounter.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Reinforcements = preload("res://sim/reinforcements.gd")
var aim := Vector2.ZERO
var evidence := {}

func _setup() -> void:
	super._setup()
	sandbox.set_process(true)
	root.title = "Ломка — " + role
	session.state_changed.connect(_art_evidence)

func _process(delta: float) -> bool:
	if session == null: return false
	var request_path := mailbox.path_join(role + ".request.json")
	if FileAccess.file_exists(request_path):
		var request = JSON.parse_string(FileAccess.get_file_as_string(request_path))
		if request is Dictionary and int(request.get("serial", -1)) > serial:
			serial = int(request.serial)
			_execute(request)
	if stepping and session != null and session.running:
		accumulated += delta
		if accumulated >= 1.0 / 60.0:
			accumulated = fmod(accumulated, 1.0 / 60.0)
			session.step(Command.from_axes(session.state.tick, move, aim, buttons))
			var actor = session.state.actor_of_slot(session.local_slot)
			if actor != null: sandbox._view.firing[actor.id] = buttons & Command.BTN_FIRE != 0
	return false

func _execute(request: Dictionary) -> void:
	if request.action == "stop":
		stepping = false
		move = Vector2.ZERO
		buttons = 0
	if request.action == "pump": aim = Vector2(float(request.get("aim_x", 0)), float(request.get("aim_y", 0)))
	if request.action == "capture":
		_capture.call_deferred(request)
		return
	if request.action == "fixture_polish":
		var player = session.state.actor_of_slot(0)
		player.position = Vector2(-180, 0)
		player.velocity = Vector2.ZERO
		Arsenal.equip(player, "colt")
		for i in range(1, 3):
			session.state.actor_of_slot(i).position = Vector2(180 + i * 60, 100)
		var corpse = Encounter.add_enemy(session.state, "runner", Vector2(-130, 0))
		corpse.take_damage(10000)
	elif request.action == "fixture_help":
		for slot in session.state.slots:
			if not slot.occupied: continue
			var actor = session.state.actor_of_slot(slot.index)
			actor.position = Vector2(slot.index * 40, 0)
			actor.velocity = Vector2.ZERO
		session.state.slots[1].downed = true
		session.state.actor_of_slot(1).health = 0
	elif request.action == "fixture_blast":
		Reinforcements.land(session.state, Encounter, 150)
		Encounter.add_enemy(session.state, "barrel", Vector2(120, 80))
		var player = session.state.actor_of_slot(0)
		player.position = Vector2(-160, 80)
		player.velocity = Vector2.ZERO
	elif request.action == "crash":
		for actor in session.state.actors:
			if actor.behaviour == "gunship": actor.take_damage(10000)
	super._execute(request)

func _art_evidence(state, events) -> void:
	for event in events:
		var kind: String = event.get("type", "")
		evidence[kind] = int(evidence.get(kind, 0)) + 1
	for slot in state.slots:
		if slot.harvest_ticks > 0: evidence["harvest_seen"] = true
		if slot.revive_ticks > 0: evidence["helper_seen"] = true
	for actor in state.actors:
		if Reinforcements.riding(actor): evidence["rider_seen"] = true

func _status() -> Dictionary:
	var result := super._status()
	result["evidence"] = evidence.duplicate()
	result["art"] = {"rising": sandbox._view.rescue.rising.size(), "crashing": sandbox._view.helicopter.ages.size(), "blasts": sandbox._view.feedback.blasts.size()}
	return result

func _capture(request: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var path := mailbox.path_join(role + "-" + String(request.label) + ".png")
	root.get_texture().get_image().save_png(path)
	var response := _status()
	response.serial = int(request.serial)
	response.path = path
	_write(response)
