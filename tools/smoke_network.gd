extends SceneTree
## Четыре экземпляра этого стенда общаются настоящими RPC. Временный
## почтовый ящик управляет только тестом и не переносит состояние игры.
const Sandbox = preload("res://game/dev_sandbox.gd")
const Session = preload("res://game/network_session.gd")
const RoomMap = preload("res://sim/room_map.gd")
const Actor = preload("res://sim/actor.gd")
const Command = preload("res://sim/input/command.gd")
var session: Session
var sandbox: Sandbox
var mailbox := ""
var role := ""
var serial := -1
var stepping := false
var move := Vector2.ZERO
var buttons := 0
var accumulated := 0.0
var history := {}
var notices: Array[String] = []
var ended_count := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: -- <mailbox-directory> <role>")
		quit(2)
		return
	mailbox = args[0]
	role = args[1]
	call_deferred("_setup")

func _setup() -> void:
	sandbox = Sandbox.new()
	sandbox.name = "Sandbox"
	root.add_child(sandbox)
	sandbox.set_physics_process(false)
	sandbox.set_process(false)
	session = sandbox._network
	session.state_changed.connect(_observe)
	session.notice.connect(func(message): notices.append(message))
	session.ended.connect(func(): ended_count += 1)
	_write({"serial": -1, "booted": true})

func _observe(state, _events) -> void:
	if session.is_host():
		if state.tick % Session.SNAPSHOT_EVERY == 0:
			history["%d:%d" % [session.generation, state.tick]] = str(state.state_hash())
	elif session.last_server_tick >= 0:
		history["%d:%d" % [session.generation, session.last_server_tick]] = str(session.authoritative_hash)

func _process(delta: float) -> bool:
	if session == null: return false
	var request_path := mailbox.path_join(role + ".request.json")
	if FileAccess.file_exists(request_path):
		var request = JSON.parse_string(FileAccess.get_file_as_string(request_path))
		if request is Dictionary and int(request.get("serial", -1)) > serial:
			serial = int(request.serial)
			_execute(request)
	if stepping and session.running:
		accumulated += delta
		if accumulated >= 1.0 / 60.0:
			accumulated = fmod(accumulated, 1.0 / 60.0)
			session.step(Command.from_axes(session.state.tick, move, Vector2.ZERO, buttons))
	return false

func _execute(request: Dictionary) -> void:
	var result: Variant = null
	match request.action:
		"host": result = session.host(role, int(request.port))
		"join": result = session.join("127.0.0.1", role, int(request.port))
		"join_bad_protocol":
			session.multiplayer.connected_to_server.disconnect(session._connected)
			session.multiplayer.connected_to_server.connect(_bad_hello)
			result = session.join("127.0.0.1", role, int(request.port))
		"fixture_revive":
			assert(session.is_host() and session.running)
			for slot in session.state.slots:
				var actor = session.state.actor_of_slot(slot.index)
				actor.position = Vector2(slot.index * 40, 0)
				actor.velocity = Vector2.ZERO
			session.state.slots[1].downed = true
			session.state.actor_of_slot(1).health = 0.0
		"fixture_door":
			assert(session.is_host() and session.running and session.state.room.id == "south")
			for slot in session.state.slots:
				var actor = session.state.actor_of_slot(slot.index)
				actor.position = RoomMap.door(session.state.room, "north") + Vector2(0, actor.radius + 1 + slot.index * 38)
				actor.velocity = Vector2.ZERO
		"fixture_baron_door":
			assert(session.is_host() and session.running)
			session.state.room = RoomMap.make("center")
			session.state.actors = session.state.living(Actor.Kind.PLAYER)
			session.state.projectiles.clear()
			session.state.pickups.clear()
			session.state.pending_spawns.clear()
			session.state.encounter_waves.clear()
			for actor in session.state.actors:
				actor.position = RoomMap.door(session.state.room, "west") + Vector2(actor.radius + 1 + actor.slot * 38, 0)
				actor.velocity = Vector2.ZERO
		"ready": session.set_ready(bool(request.get("value", true)))
		"start": result = session.start("network-smoke")
		"restart": session.restart()
		"pump":
			move = Vector2(float(request.get("x", 0)), float(request.get("y", 0)))
			buttons = int(request.get("buttons", 0))
			stepping = true
		"stop": stepping = false
		"stale":
			session._submit_input.rpc_id(1, int(request.epoch), 1, 127, 0, 127, 0, Command.BTN_FIRE)
		"leave":
			stepping = false
			session.leave()
		"quit":
			session.leave(false)
			quit()
	var response := _status()
	response.serial = serial
	response.result = result
	_write(response)

func _bad_hello() -> void:
	session._hello.rpc_id(1, Session.PROTOCOL + 1, Session.SaveGame.FORMAT, role)

func _status() -> Dictionary:
	var response := {"active": session.active, "running": session.running,
		"slot": session.local_slot, "members": session.members, "generation": session.generation,
		"can_start": session.can_start(), "history": history.duplicate(),
		"last_server_tick": session.last_server_tick, "authoritative_hash": str(session.authoritative_hash),
		"ended_count": ended_count, "notices": notices.duplicate()}
	if session.state != null:
		response.tick = session.state.tick
		response.hash = str(session.state.state_hash())
		response.room = session.state.room.id
		response.enemies = session.state.living(Actor.Kind.ENEMY).size()
		response.waves = session.state.encounter_waves.size()
		response.pending = session.state.pending_spawns.size()
		response.projectiles = session.state.projectiles.size()
		response.enemy_types = []
		for enemy in session.state.living(Actor.Kind.ENEMY): response.enemy_types.append(enemy.archetype)
		response.projectile_types = []
		for shot in session.state.projectiles: response.projectile_types.append(shot.kind)
		response.slots = []
		for slot in session.state.slots:
			var actor = session.state.actor_of_slot(slot.index)
			response.slots.append({"index": slot.index, "occupied": slot.occupied, "actor_id": slot.actor_id, "downed": slot.downed,
				"revive_ticks": slot.revive_ticks, "health": actor.health if actor != null else 0.0,
				"x": actor.position.x if actor != null else 0.0, "y": actor.position.y if actor != null else 0.0})
		response.buffers = {}
		for id in session.buffers:
			var buffer = session.buffers[id]
			response.buffers[str(id)] = {"received": buffer.received, "acknowledged": buffer.acknowledged,
				"queued": buffer.queue.size()}
	return response

func _write(response: Dictionary) -> void:
	var path := mailbox.path_join(role + ".response.json")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	file.store_string(JSON.stringify(response))
	file.close()
	DirAccess.rename_absolute(temporary, path)
