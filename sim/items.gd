extends RefCounted

const Schemas = preload("res://sim/data/schemas.gd")
const Modifier = preload("res://sim/core/modifier.gd")

const RECORDS := {
	"carbon_copy": {"id": "carbon_copy", "name": "Копирка", "badge": "К", "rarity": "uncommon",
		"description": "Дополнительный выстрел назад. −25% урона.",
		"modifiers": [{"stat": "rear_shots", "op": "add", "value": 1.0}, {"stat": "damage", "op": "mul", "value": 0.75}]},
	"rubber_stamp": {"id": "rubber_stamp", "name": "Резиновая печать", "badge": "Р", "rarity": "uncommon",
		"description": "Снаряд один раз отскакивает от стены. −15% урона.",
		"modifiers": [{"stat": "bounces", "op": "add", "value": 1.0}, {"stat": "damage", "op": "mul", "value": 0.85}]},
	"heavy_seal": {"id": "heavy_seal", "name": "Тяжёлая печать", "badge": "Т", "rarity": "rare",
		"description": "Удерживай направление 0,6 с для выстрела. Урон ×2,5.",
		"modifiers": [{"stat": "charge_time", "op": "add", "value": 0.6}, {"stat": "damage", "op": "mul", "value": 2.5}]},
	"hole_punch": {"id": "hole_punch", "name": "Дырокол", "badge": "Д", "rarity": "uncommon",
		"description": "Снаряд пробивает ещё одну цель.",
		"modifiers": [{"stat": "pierce", "op": "add", "value": 1.0}]},
	"red_folder": {"id": "red_folder", "name": "Красная папка", "badge": "П", "rarity": "common",
		"description": "+40% урона. −20% скорострельности.",
		"modifiers": [{"stat": "damage", "op": "mul", "value": 1.4}, {"stat": "fire_rate", "op": "mul", "value": 0.8}]},
	"optical_ruler": {"id": "optical_ruler", "name": "Оптическая линейка", "badge": "Л", "rarity": "common",
		"description": "+35% скорости снарядов, +30% дальности. −20% урона.",
		"modifiers": [{"stat": "projectile_speed", "op": "mul", "value": 1.35}, {"stat": "range", "op": "mul", "value": 1.3}, {"stat": "damage", "op": "mul", "value": 0.8}]},
	"runners": {"id": "runners", "name": "Бегунки", "badge": "Б", "rarity": "common",
		"description": "+15% скорости движения. −10% максимума здоровья.",
		"modifiers": [{"stat": "move_speed", "op": "mul", "value": 1.15}, {"stat": "health", "op": "mul", "value": 0.9}]},
	"spring": {"id": "spring", "name": "Пружина", "badge": "С", "rarity": "common",
		"description": "+25% скорострельности. −20% дальности.",
		"modifiers": [{"stat": "fire_rate", "op": "mul", "value": 1.25}, {"stat": "range", "op": "mul", "value": 0.8}]},
}

static func item(id: String) -> Dictionary:
	return RECORDS.get(id, {})

static func equip(actor, slot, id: String) -> bool:
	var record := item(id)
	if record.is_empty(): return false
	var source := "item:%d:%s" % [slot.items.size(), id]
	for entry in record["modifiers"]:
		actor.stack.add(Modifier.make(entry["stat"], Schemas.OPS.find(entry["op"]) as Modifier.Op, entry["value"], source))
	slot.items.append(id)
	slot.charge_ticks = 0
	actor.health = minf(actor.health, actor.max_health())
	return true

static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for id in RECORDS:
		errors.append_array(Schemas.validate("item", RECORDS[id]))
	return errors
