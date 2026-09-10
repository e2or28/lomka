extends Node

const RunState = preload("res://sim/run_state.gd")
const Travel = preload("res://sim/room_travel.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const SaveGame = preload("res://sim/save/save_game.gd")
const Buffer = preload("res://game/network_input.gd")
const Prediction = preload("res://game/network_prediction.gd")
const Abilities = preload("res://sim/abilities.gd")
const PROTOCOL := 1
const PORT := 27841
const SNAPSHOT_EVERY := 3

signal lobby_changed
signal state_changed(state, events)
signal notice(message: String)
signal ended

var active := false
var running := false
var local_slot := 0
var members: Dictionary = {}
var state: RunState
var last_server_tick := -1
var authoritative_hash := 0
var local_sequence := 0
var generation := 0
var prediction := Prediction.new()
var buffers: Dictionary = {}
var _events: Array[Dictionary] = []
var _name := "Игрок"
var _connecting_since := 0
var _last_snapshot_ms := 0
var _waiting: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_lost_host)

func is_host() -> bool:
	return active and multiplayer.is_server()

func host(player_name: String, port: int = PORT) -> Error:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 3, 3)
	if error != OK:
		notice.emit("Не удалось создать комнату. Возможно, этот порт уже занят.")
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	_name = clean_name(player_name)
	members = {1: {"name": _name, "slot": 0, "ready": true}}
	buffers[1] = Buffer.new()
	lobby_changed.emit()
	notice.emit("Комната создана. Передай другу адрес и дождись готовности.")
	return OK

func join(address: String, player_name: String, port: int = PORT) -> Error:
	leave(false)
	address = address.strip_edges()
	if address.is_empty() or address.length() > 253 or port < 1 or port > 65535:
		notice.emit("Укажи адрес компьютера, который создал комнату.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port, 3)
	if error != OK:
		notice.emit("Не удалось подключиться по этому адресу.")
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	_name = clean_name(player_name)
	_connecting_since = Time.get_ticks_msec()
	lobby_changed.emit()
	notice.emit("Подключаемся…")
	return OK

static func clean_name(value: String) -> String:
	value = value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").left(24)
	return "Игрок" if value.is_empty() else value

func leave(announce: bool = true) -> void:
	var was_running := running
	if active: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	running = false
	members.clear()
	buffers.clear()
	_waiting.clear()
	_events.clear()
	state = null
	local_slot = 0
	local_sequence = 0
	last_server_tick = -1
	_connecting_since = 0
	_last_snapshot_ms = 0
	prediction = Prediction.new()
	lobby_changed.emit()
	if was_running: ended.emit()
	if announce: notice.emit("Ты вышел из сетевой комнаты.")

func set_ready(value: bool) -> void:
	if not active or running: return
	if is_host():
		members[1].ready = value
		_broadcast_lobby()
	elif members.has(multiplayer.get_unique_id()):
		_ready_request.rpc_id(1, value)

func can_start() -> bool:
	if not is_host() or running or members.is_empty(): return false
	for member in members.values():
		if not bool(member.ready): return false
	return true

func start(seed_text: String = "") -> bool:
	if not can_start(): return false
	var ids := members.keys()
	ids.sort()
	for i in ids.size(): members[ids[i]].slot = i
	_broadcast_lobby()
	state = Travel.start(seed_text if not seed_text.is_empty() else str(Time.get_unix_time_from_system()), members.size())
	running = true
	local_sequence = 0
	for id in members: buffers[id] = Buffer.new()
	local_slot = 0
	_events.clear()
	generation += 1
	_begin.rpc(generation, state.to_dict())
	state_changed.emit(state, [])
	lobby_changed.emit()
	return true

func restart() -> void:
	if not is_host() or not running: return
	running = false
	start()

func step(local_command) -> void:
	if not active or not running or state == null: return
	if is_host():
		var commands := {0: local_command}
		for id in members:
			if int(id) == 1: continue
			commands[int(members[id].slot)] = buffers[id].take(state.tick)
		var events := SimTick.step(state, commands)
		_events.append_array(events)
		state_changed.emit(state, events)
		if state.tick % SNAPSHOT_EVERY == 0:
			var acknowledgements := {}
			for id in members: acknowledgements[id] = buffers[id].acknowledged
			_snapshot.rpc(generation, state.to_dict(), acknowledgements, _events)
			_events.clear()
	else:
		local_sequence += 1
		_submit_input.rpc_id(1, generation, local_sequence, local_command.move_x, local_command.move_y,
			local_command.aim_x, local_command.aim_y, local_command.buttons)
		prediction.push(local_sequence, local_command)
		prediction.advance(state, local_slot, local_command)
		state_changed.emit(state, [])

func _process(_delta: float) -> void:
	if not active: return
	var now := Time.get_ticks_msec()
	if _connecting_since > 0 and now - _connecting_since > 8000:
		leave(false)
		notice.emit("Комната не ответила. Проверь адрес, сеть и что друг создал лобби.")
	elif running and not is_host() and _last_snapshot_ms > 0 and now - _last_snapshot_ms > 8000:
		_lost_host()
	if is_host():
		for id in _waiting.keys():
			if now - int(_waiting[id]) > 8000:
				multiplayer.multiplayer_peer.disconnect_peer(id)
				_waiting.erase(id)

func _peer_connected(id: int) -> void:
	if is_host(): _waiting[id] = Time.get_ticks_msec()

func _connected() -> void:
	_hello.rpc_id(1, PROTOCOL, SaveGame.FORMAT, _name)

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(protocol: int, format: int, player_name: String) -> void:
	if not is_host(): return
	var id := multiplayer.get_remote_sender_id()
	if members.has(id): return
	if protocol != PROTOCOL or format != SaveGame.FORMAT:
		_reject.rpc_id(id, "Версии игры отличаются. Обновите игру на обоих компьютерах.")
		return
	if running or members.size() >= RunState.MAX_PLAYERS:
		_reject.rpc_id(id, "Забег уже начат." if running else "В комнате уже четыре игрока.")
		return
	members[id] = {"name": clean_name(player_name), "slot": members.size(), "ready": false}
	buffers[id] = Buffer.new()
	_waiting.erase(id)
	_broadcast_lobby()

@rpc("authority", "call_remote", "reliable", 0)
func _reject(message: String) -> void:
	leave(false)
	notice.emit(message)

@rpc("any_peer", "call_remote", "reliable", 0)
func _ready_request(value: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or running or not members.has(id): return
	members[id].ready = value
	_broadcast_lobby()

func _broadcast_lobby() -> void:
	_lobby.rpc(members)
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable", 0)
func _lobby(roster: Dictionary) -> void:
	members = roster.duplicate(true)
	var id := multiplayer.get_unique_id()
	if members.has(id):
		local_slot = int(members[id].slot)
		_connecting_since = 0
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable", 0)
func _begin(epoch: int, data: Dictionary) -> void:
	generation = epoch
	state = RunState.from_dict(data)
	running = true
	last_server_tick = state.tick - 1
	local_sequence = 0
	prediction = Prediction.new()
	prediction.room_id = state.room.id
	_last_snapshot_ms = Time.get_ticks_msec()
	state_changed.emit(state, [])
	lobby_changed.emit()

@rpc("any_peer", "call_remote", "reliable", 1)
func _submit_input(epoch: int, sequence: int, mx: int, my: int, ax: int, ay: int, buttons: int) -> void:
	if not is_host() or not running or epoch != generation: return
	var id := multiplayer.get_remote_sender_id()
	if not members.has(id) or int(id) == 1: return
	buffers[id].submit(sequence, mx, my, ax, ay, buttons)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _snapshot(epoch: int, data: Dictionary, acknowledgements: Dictionary, events: Array) -> void:
	if not running or epoch != generation or int(data.get("tick", -1)) <= last_server_tick: return
	state = RunState.from_dict(data)
	last_server_tick = state.tick
	authoritative_hash = state.state_hash()
	_last_snapshot_ms = Time.get_ticks_msec()
	prediction.reconcile(state, local_slot, int(acknowledgements.get(multiplayer.get_unique_id(), 0)), state.room.id)
	var typed_events: Array[Dictionary] = []
	for event in events: typed_events.append(event)
	state_changed.emit(state, typed_events)

func _peer_disconnected(id: int) -> void:
	_waiting.erase(id)
	if not is_host() or not members.has(id): return
	var member: Dictionary = members[id]
	if state != null and running:
		var slot = state.slots[int(member.slot)]
		Abilities.finish(state, slot)
		var actor = state.actor_of_slot(slot.index)
		state.actors.erase(actor)
		slot.occupied = false
		slot.actor_id = -1
		slot.downed = true
	members.erase(id)
	buffers.erase(id)
	_broadcast_lobby()
	notice.emit("%s отключился." % member.name)

func _failed() -> void:
	leave(false)
	notice.emit("Не удалось подключиться: комната недоступна или заполнена.")

func _lost_host() -> void:
	leave(false)
	notice.emit("Связь с ведущим потеряна. Можно создать новую комнату.")
