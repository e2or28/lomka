extends RefCounted
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


func _init(p_index: int = 0) -> void:
	index = p_index


func to_dict() -> Dictionary:
	return {
		"actor_id": actor_id,
		"character_id": character_id,
		"downed": downed,
		"index": index,
		"interact_held": interact_held,
		"occupied": occupied,
	}


static func from_dict(data: Dictionary):
	var slot := new(int(data.get("index", 0)))
	slot.actor_id = int(data.get("actor_id", -1))
	slot.character_id = data.get("character_id", "")
	slot.downed = bool(data.get("downed", false))
	slot.interact_held = bool(data.get("interact_held", false))
	slot.occupied = bool(data.get("occupied", false))
	return slot
