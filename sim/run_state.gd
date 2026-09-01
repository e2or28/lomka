extends RefCounted
## Состояние забега — корень всего, что уходит в сейв.
##
## На M0 здесь только фундамент: сид, позиции потоков случайности, зона и
## слоты со стеками модификаторов. Геймплея нет, и это правильно — но
## дисциплина сериализации заведена сразу, задним числом её не ввести
## (правило 8).

const RngStreams = preload("res://sim/core/rng_streams.gd")
const PlayerSlot = preload("res://sim/player_slot.gd")
const Fnv = preload("res://sim/core/fnv.gd")

const MAX_PLAYERS := 4

var run_seed: String = ""
var zone_index: int = 0

## Номер тика с начала забега. Часть состояния, а не счётчик кадров:
## по нему сверяются хост и клиент, и он же переживает сейв.
var tick: int = 0

var rng: RngStreams = null
var slots: Array[PlayerSlot] = []


func _init(seed_text: String = "") -> void:
	run_seed = seed_text
	rng = RngStreams.new(seed_text)
	slots = []
	for i in MAX_PLAYERS:
		slots.append(PlayerSlot.new(i))


## Сколько слотов занято. От этого считается масштабирование сложности,
## поэтому число выводится из состояния, а не хранится отдельно: иначе оно
## разъедется с составом после переподключения.
func occupied_count() -> int:
	var n := 0
	for slot in slots:
		if slot.occupied:
			n += 1
	return n


func to_dict() -> Dictionary:
	var slots_out: Array = []
	for slot in slots:
		slots_out.append(slot.to_dict())
	return {
		"rng": rng.to_dict(),
		"run_seed": run_seed,
		"slots": slots_out,
		"tick": tick,
		"zone_index": zone_index,
	}


## Отпечаток состояния целиком. Сверять по нему дешевле, чем сравнивать
## структуры: расхождение хоста и клиента видно одним числом, а реплей-тест
## сводится к сравнению двух отпечатков.
func state_hash() -> int:
	return Fnv.hash_bytes(var_to_bytes(to_dict()))


static func from_dict(data: Dictionary):
	var state := new(data.get("run_seed", ""))
	state.zone_index = int(data.get("zone_index", 0))
	state.tick = int(data.get("tick", 0))
	state.rng = RngStreams.from_dict(data.get("rng", {}))
	var slots_in: Array = data.get("slots", [])
	var restored: Array[PlayerSlot] = []
	for entry in slots_in:
		restored.append(PlayerSlot.from_dict(entry))
	state.slots = restored
	return state
