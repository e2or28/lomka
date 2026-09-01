extends RefCounted
## Слот игрока в забеге: кто играет, а не чем.
##
## Сейв принадлежит хосту и хранит состояние по слотам: возобновить забег
## может любой состав, пришедшие занимают слоты, пустые убираются, сложность
## пересчитывается от числа занятых.
##
## Тело жило здесь, пока врагов не было. Теперь тела — акторы (sim/actor.gd),
## а слот держит только то, что переживает смену тела: кем играют, занят ли
## слот, упал ли игрок.

var index: int = 0
var occupied: bool = false
var character_id: String = ""

## Упал, но не выбыл: поднимает товарищ, простояв рядом. На переходе в
## следующую зону упавшие поднимаются автоматически.
var downed: bool = false

## Тело этого слота или -1, если слот пуст.
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
