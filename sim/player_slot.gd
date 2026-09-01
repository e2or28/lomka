extends RefCounted
## Слот игрока в забеге. Сейв принадлежит хосту и хранит состояние по слотам:
## возобновить забег может любой состав, пришедшие занимают слоты, пустые
## убираются, сложность пересчитывается от числа занятых.
##
## Слот — данные (правило 7) и целиком сериализуем (правило 8).

const ModifierStack = preload("res://sim/core/modifier_stack.gd")

var index: int = 0
var occupied: bool = false
var character_id: String = ""

## Упал, но не выбыл: поднимает товарищ, простояв рядом. На переходе в
## следующую зону упавшие поднимаются автоматически.
var downed: bool = false

## Тело в мире. Пока враги и комнаты не появились, отдельной сущности актора
## нет — заводить её ради одного квадрата значит городить абстракцию под
## пустоту. Появятся враги — тело переедет в sim/actor.gd.
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

var stack: ModifierStack = null


func _init(p_index: int = 0) -> void:
	index = p_index
	stack = ModifierStack.new()


func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"downed": downed,
		"index": index,
		"occupied": occupied,
		"position": position,
		"stack": stack.to_dict(),
		"velocity": velocity,
	}


static func from_dict(data: Dictionary):
	var slot := new(int(data.get("index", 0)))
	slot.character_id = data.get("character_id", "")
	slot.downed = bool(data.get("downed", false))
	slot.occupied = bool(data.get("occupied", false))
	slot.position = data.get("position", Vector2.ZERO)
	slot.stack = ModifierStack.from_dict(data.get("stack", {}))
	slot.velocity = data.get("velocity", Vector2.ZERO)
	return slot
