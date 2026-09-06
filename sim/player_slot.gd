extends RefCounted
const Schemas = preload("res://sim/data/schemas.gd")
## Слот игрока в забеге: кто играет, а не чем. Тело — актор (sim/actor.gd),
## слот держит только то, что переживает его смену.

var index: int = 0
var occupied: bool = false
var character_id: String = ""

## Поднимает товарищ, простояв рядом; на переходе в зону поднимаются
## автоматически.
var downed: bool = false

## -1, если слот пуст.
var actor_id: int = -1

## Подбор срабатывает на нажатии, а не на удержании: иначе зажатая E
## меняла бы оружие местами каждый тик. Признак живёт в состоянии, потому
## что от него зависит исход тика (правило 8).
var interact_held: bool = false

var organs: Dictionary = {}
var stationary_ticks: int = 0
var harvest_target: int = -1
var harvest_ticks: int = 0
var harvest_spent: bool = false


func _init(p_index: int = 0) -> void:
	index = p_index
	for socket in Schemas.ORGAN_SLOTS:
		organs[socket] = ""


func to_dict() -> Dictionary:
	return {
		"actor_id": actor_id,
		"character_id": character_id,
		"downed": downed,
		"harvest_spent": harvest_spent,
		"harvest_target": harvest_target,
		"harvest_ticks": harvest_ticks,
		"index": index,
		"interact_held": interact_held,
		"occupied": occupied,
		"organs": organs.duplicate(),
		"stationary_ticks": stationary_ticks,
	}


static func from_dict(data: Dictionary):
	var slot := new(int(data.get("index", 0)))
	slot.actor_id = int(data.get("actor_id", -1))
	slot.character_id = data.get("character_id", "")
	slot.downed = bool(data.get("downed", false))
	slot.harvest_target = int(data.get("harvest_target", -1))
	slot.harvest_ticks = int(data.get("harvest_ticks", 0))
	slot.harvest_spent = bool(data.get("harvest_spent", false))
	for socket in Schemas.ORGAN_SLOTS:
		slot.organs[socket] = data.get("organs", {}).get(socket, "")
	slot.stationary_ticks = int(data.get("stationary_ticks", 0))
	slot.interact_held = bool(data.get("interact_held", false))
	slot.occupied = bool(data.get("occupied", false))
	return slot
