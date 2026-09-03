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


func _init(p_index: int = 0) -> void:
	index = p_index


func to_dict() -> Dictionary:
	return {
		"actor_id": actor_id,
		"character_id": character_id,
		"downed": downed,
		"index": index,
		"occupied": occupied,
	}


static func from_dict(data: Dictionary):
	var slot := new(int(data.get("index", 0)))
	slot.actor_id = int(data.get("actor_id", -1))
	slot.character_id = data.get("character_id", "")
	slot.downed = bool(data.get("downed", false))
	slot.occupied = bool(data.get("occupied", false))
	return slot
