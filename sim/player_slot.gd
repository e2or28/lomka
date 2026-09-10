extends RefCounted
const Schemas = preload("res://sim/data/schemas.gd")
## Слот игрока в забеге: кто играет, а не чем. Тело — актор (sim/actor.gd),
## слот держит только то, что переживает его смену.

var index: int = 0
var occupied: bool = false
var character_id: String = ""

## Поднимает товарищ; переход между комнатами не лечит.
var downed: bool = false

## -1, если слот пуст.
var actor_id: int = -1

## Подбор срабатывает на нажатии, а не на удержании: иначе зажатая E
## меняла бы оружие местами каждый тик. Признак живёт в состоянии, потому
## что от него зависит исход тика (правило 8).
var interact_held: bool = false

var items: Array[String] = []
var charge_ticks: int = 0
var skill_held: bool = false
var skill_cooldown_ticks: int = 0
var cover_ticks: int = 0
var cover_health: float = 0.0
var cover_position: Vector2 = Vector2.ZERO
var cover_direction: Vector2 = Vector2.RIGHT

var organs: Dictionary = {}
var stationary_ticks: int = 0
var revive_target: int = -1
var revive_ticks: int = 0
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
		"charge_ticks": charge_ticks,
		"cover_direction": cover_direction,
		"cover_health": cover_health,
		"cover_position": cover_position,
		"cover_ticks": cover_ticks,
		"downed": downed,
		"harvest_spent": harvest_spent,
		"harvest_target": harvest_target,
		"harvest_ticks": harvest_ticks,
		"index": index,
		"interact_held": interact_held,
		"items": items.duplicate(),
		"occupied": occupied,
		"organs": organs.duplicate(),
		"revive_target": revive_target,
		"revive_ticks": revive_ticks,
		"skill_cooldown_ticks": skill_cooldown_ticks,
		"skill_held": skill_held,
		"stationary_ticks": stationary_ticks,
	}


static func from_dict(data: Dictionary):
	var slot := new(int(data.get("index", 0)))
	slot.actor_id = int(data.get("actor_id", -1))
	slot.character_id = data.get("character_id", "")
	slot.downed = bool(data.get("downed", false))
	for item in data.get("items", []):
		slot.items.append(str(item))
	slot.charge_ticks = int(data.get("charge_ticks", 0))
	slot.skill_held = bool(data.get("skill_held", false))
	slot.skill_cooldown_ticks = int(data.get("skill_cooldown_ticks", 0))
	slot.cover_ticks = int(data.get("cover_ticks", 0))
	slot.cover_health = float(data.get("cover_health", 0.0))
	slot.cover_position = data.get("cover_position", Vector2.ZERO)
	slot.cover_direction = data.get("cover_direction", Vector2.RIGHT)
	slot.revive_target = int(data.get("revive_target", -1))
	slot.revive_ticks = int(data.get("revive_ticks", 0))
	slot.harvest_target = int(data.get("harvest_target", -1))
	slot.harvest_ticks = int(data.get("harvest_ticks", 0))
	slot.harvest_spent = bool(data.get("harvest_spent", false))
	for socket in Schemas.ORGAN_SLOTS:
		slot.organs[socket] = data.get("organs", {}).get(socket, "")
	slot.stationary_ticks = int(data.get("stationary_ticks", 0))
	slot.interact_held = bool(data.get("interact_held", false))
	slot.occupied = bool(data.get("occupied", false))
	return slot
