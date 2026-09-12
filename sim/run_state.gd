extends RefCounted
## Состояние забега — корень всего, что уходит в сейв.
##
## Дисциплина сериализации заведена с первого дня: задним числом её ввести
## невозможно (правило 8). Каждая новая сущность обязана уметь записываться
## и восстанавливаться в тот же день, когда появилась.

const RngStreams = preload("res://sim/core/rng_streams.gd")
const PlayerSlot = preload("res://sim/player_slot.gd")
const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")
const Pickup = preload("res://sim/pickup.gd")
const Room = preload("res://sim/room.gd")
const Fnv = preload("res://sim/core/fnv.gd")

const MAX_PLAYERS := 4

var run_seed: String = ""
var zone_index: int = 0

## Часть состояния, а не счётчик кадров: по нему сверяются хост и клиент.
var tick: int = 0
var heat: int = 0

var rng: RngStreams = null
var slots: Array[PlayerSlot] = []
var actors: Array[Actor] = []
var projectiles: Array[Projectile] = []
var pickups: Array[Pickup] = []
var room: Room = null
var room_states: Dictionary = {}
var pending_spawns: Array[Dictionary] = []
var encounter_waves: Array = []

## Не выводится из длины массива: иначе после смерти тела номер
## переиспользуется, и снаряд попадает не в того, кого целил.
var next_id: int = 1


func _init(seed_text: String = "") -> void:
	run_seed = seed_text
	rng = RngStreams.new(seed_text)
	room = Room.new()
	slots = []
	for i in MAX_PLAYERS:
		slots.append(PlayerSlot.new(i))


func take_id() -> int:
	var id := next_id
	next_id += 1
	return id


func actor_by_id(id: int) -> Actor:
	for actor in actors:
		if actor.id == id:
			return actor
	return null


func actor_of_slot(slot_index: int) -> Actor:
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return actor_by_id(slots[slot_index].actor_id)


func living(kind: Actor.Kind) -> Array[Actor]:
	var found: Array[Actor] = []
	for actor in actors:
		if actor.alive and actor.kind == kind:
			found.append(actor)
	return found


func room_cleared() -> bool:
	if not pending_spawns.is_empty() or not encounter_waves.is_empty(): return false
	for actor in actors:
		# Бочки и прочая обстановка не считаются: выход держат противники.
		if actor.alive and actor.kind == Actor.Kind.ENEMY and actor.behaviour != "prop":
			return false
	return true


## В одиночку падение заканчивает забег — docs/DECISIONS.md.
func party_down() -> bool:
	var occupied_slots := 0
	var standing := 0
	for slot in slots:
		if not slot.occupied:
			continue
		occupied_slots += 1
		if not slot.downed:
			standing += 1
	return occupied_slots > 0 and standing == 0


func occupied_count() -> int:
	var n := 0
	for slot in slots:
		if slot.occupied:
			n += 1
	return n


func to_dict() -> Dictionary:
	var actors_out: Array = []
	for actor in actors:
		actors_out.append(actor.to_dict())
	var projectiles_out: Array = []
	for projectile in projectiles:
		projectiles_out.append(projectile.to_dict())
	var pickups_out: Array = []
	for pickup in pickups:
		pickups_out.append(pickup.to_dict())
	var slots_out: Array = []
	for slot in slots:
		slots_out.append(slot.to_dict())
	return {
		"actors": actors_out,
		"encounter_waves": encounter_waves.duplicate(true),
		"heat": heat,
		"next_id": next_id,
		"pending_spawns": pending_spawns.duplicate(true),
		"pickups": pickups_out,
		"projectiles": projectiles_out,
		"rng": rng.to_dict(),
		"room": room.to_dict(),
		"room_states": room_states.duplicate(true),
		"run_seed": run_seed,
		"slots": slots_out,
		"tick": tick,
		"zone_index": zone_index,
	}


## Сверять дешевле, чем сравнивать структуры: расхождение хоста и клиента
## видно одним числом.
func state_hash() -> int:
	return Fnv.hash_bytes(var_to_bytes(to_dict()))


static func from_dict(data: Dictionary):
	var state := new(data.get("run_seed", ""))
	state.pending_spawns.assign(data.get("pending_spawns", []))
	state.encounter_waves = data.get("encounter_waves", []).duplicate(true)
	state.next_id = int(data.get("next_id", 1))
	state.rng = RngStreams.from_dict(data.get("rng", {}))
	state.room = Room.from_dict(data.get("room", {}))
	state.room_states = data.get("room_states", {}).duplicate(true)
	state.tick = int(data.get("tick", 0))
	state.heat = int(data.get("heat", 0))
	state.zone_index = int(data.get("zone_index", 0))

	var restored_actors: Array[Actor] = []
	for entry in data.get("actors", []):
		restored_actors.append(Actor.from_dict(entry))
	state.actors = restored_actors

	var restored_projectiles: Array[Projectile] = []
	for entry in data.get("projectiles", []):
		restored_projectiles.append(Projectile.from_dict(entry))
	state.projectiles = restored_projectiles

	var restored_pickups: Array[Pickup] = []
	for entry in data.get("pickups", []):
		restored_pickups.append(Pickup.from_dict(entry))
	state.pickups = restored_pickups

	var restored_slots: Array[PlayerSlot] = []
	for entry in data.get("slots", []):
		restored_slots.append(PlayerSlot.from_dict(entry))
	state.slots = restored_slots
	return state
