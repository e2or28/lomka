extends RefCounted

const Schemas = preload("res://sim/data/schemas.gd")
const Modifier = preload("res://sim/core/modifier.gd")

const SLOT_NAMES := {
	"brain": "Мозг", "eyes": "Глаза", "heart": "Сердце", "lungs": "Лёгкие",
	"liver": "Печень", "spine": "Позвоночник", "legs": "Ноги", "genitals": "Половой орган",
}

const RECORDS := {
	"coward_heart": {
		"id": "coward_heart", "name": "Сердце труса", "slot": "heart", "badge": "Тр",
		"price": 35, "rarity": "uncommon", "heat": 10,
		"description": "+35% скорости, если враг ближе 240. Иначе −15% скорости.",
		"behaviour": "coward", "modifiers": [],
	},
	"rear_eye": {
		"id": "rear_eye", "name": "Глаз затылочника", "slot": "eyes", "badge": "Зт",
		"price": 40, "rarity": "uncommon", "heat": 15,
		"description": "Дополнительный выстрел назад. −20% урона всех выстрелов.",
		"modifiers": [{"stat": "rear_shots", "op": "add", "value": 1.0},
			{"stat": "damage", "op": "mul", "value": 0.8}],
	},
	"notary_eye": {
		"id": "notary_eye", "name": "Глаз нотариуса", "slot": "eyes", "badge": "Нт",
		"price": 40, "rarity": "uncommon", "heat": 15,
		"description": "Урон ×2. Каждый выстрел требует 0,6 с удержания направления.",
		"modifiers": [{"stat": "charge_time", "op": "add", "value": 0.6},
			{"stat": "damage", "op": "mul", "value": 2.0}],
	},
	"courier_heart": {
		"id": "courier_heart", "name": "Сердце курьера", "slot": "heart", "badge": "Кр",
		"price": 30, "rarity": "uncommon", "heat": 10,
		"description": "+25% скорости. Стой дольше 3 с — теряешь 5 HP каждую секунду.",
		"behaviour": "keep_moving",
		"modifiers": [{"stat": "move_speed", "op": "mul", "value": 1.25}],
	},
	"armored_spine": {
		"id": "armored_spine", "name": "Бронированный позвоночник", "slot": "spine", "badge": "Пз",
		"price": 80, "rarity": "boss", "heat": 25,
		"description": "+35% урона. −15% скорости движения.",
		"modifiers": [
			{"stat": "damage", "op": "mul", "value": 1.35},
			{"stat": "move_speed", "op": "mul", "value": 0.85},
		],
	},
}

const SYNERGIES := {
	"express_delivery": {
		"id": "express_delivery", "name": "ЭКСПРЕСС-ДОСТАВКА",
		"description": "+30% скорости снарядов и пробитие ещё одной цели.",
		"requires": ["courier_heart", "armored_spine"],
		"modifiers": [
			{"stat": "projectile_speed", "op": "mul", "value": 1.3},
			{"stat": "pierce", "op": "add", "value": 1.0},
		],
	},
}


static func organ(id: String) -> Dictionary:
	return RECORDS.get(id, {})


static func active_synergies(slot) -> Array[String]:
	var found: Array[String] = []
	for id in SYNERGIES:
		var matches := true
		for required in SYNERGIES[id]["requires"]:
			if not slot.organs.values().has(required):
				matches = false
		if matches:
			found.append(id)
	return found


static func equip(actor, slot, id: String) -> bool:
	var record := organ(id)
	if record.is_empty():
		return false
	var socket: String = record["slot"]
	if slot.organs[socket] == id:
		return true
	slot.organs[socket] = id
	_rebuild(actor, slot)
	return true


static func unequip(actor, slot, socket: String) -> String:
	var previous: String = slot.organs.get(socket, "")
	if previous == "":
		return ""
	slot.organs[socket] = ""
	_rebuild(actor, slot)
	return previous


static func _rebuild(actor, slot) -> void:
	actor.stack.remove_source("organ:threat")
	slot.charge_ticks = 0
	for socket in Schemas.ORGAN_SLOTS:
		var source: String = "organ:" + socket
		actor.stack.remove_source(source)
		_apply(actor, organ(slot.organs[socket]).get("modifiers", []), source)
	for id in SYNERGIES:
		actor.stack.remove_source("synergy:" + id)
	for id in active_synergies(slot):
		_apply(actor, SYNERGIES[id]["modifiers"], "synergy:" + id)
	if not has_behaviour(slot, "keep_moving"):
		slot.stationary_ticks = 0
	actor.health = minf(actor.health, actor.max_health())


static func update_threat(state, actor, slot) -> void:
	if not has_behaviour(slot, "coward"): return
	var multiplier := 0.85
	for enemy in state.actors:
		if enemy.alive and enemy.kind != actor.kind and actor.position.distance_squared_to(enemy.position) <= 240.0 * 240.0:
			multiplier = 1.35
			break
	for modifier in actor.stack.modifiers():
		if modifier.source == "organ:threat" and modifier.value == multiplier:
			return
	actor.stack.remove_source("organ:threat")
	actor.stack.add(Modifier.make("move_speed", Modifier.Op.MUL, multiplier, "organ:threat"))


static func _apply(actor, entries: Array, source: String) -> void:
	for entry in entries:
		var op: int = Schemas.OPS.find(entry["op"])
		actor.stack.add(Modifier.make(entry["stat"], op as Modifier.Op, entry["value"], source))


static func has_behaviour(slot, behaviour: String) -> bool:
	for id in slot.organs.values():
		if organ(id).get("behaviour", "") == behaviour:
			return true
	return false


static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for id in RECORDS:
		var record: Dictionary = RECORDS[id]
		errors.append_array(Schemas.validate("organ", record))
		for field in ["slot", "heat", "description", "modifiers"]:
			if not record.has(field):
				errors.append("organ '%s': missing %s" % [id, field])
	for id in SYNERGIES:
		errors.append_array(Schemas.validate("synergy", SYNERGIES[id]))
		for required in SYNERGIES[id]["requires"]:
			if not RECORDS.has(required):
				errors.append("synergy '%s': unknown organ %s" % [id, required])
	return errors
