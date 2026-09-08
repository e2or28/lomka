extends RefCounted
## Оружие: данные, а не классы (правило 7). Устроено как предмет — кладёт
## модификаторы в тот же стек, поэтому смена оружия не стоит ни строчки
## нового кода в бою. Безоружный не стреляет потому, что скорострельность
## нулевая, а не потому, что где-то стоит проверка.

const Schemas = preload("res://sim/data/schemas.gd")
const Modifier = preload("res://sim/core/modifier.gd")

const SOURCE_PREFIX := "weapon:"

const SUITCASE := {
	"id": "suitcase",
	"name": "Чемодан",
	"projectile": "folder",
	"modifiers": [
		{"stat": "damage", "op": "add", "value": 12.0},
		{"stat": "fire_rate", "op": "add", "value": 3.5},
		{"stat": "projectile_speed", "op": "add", "value": 620.0},
		{"stat": "range", "op": "add", "value": 620.0},
		{"stat": "shot_momentum", "op": "add", "value": 0.35},
		{"stat": "tumble_range", "op": "add", "value": 220.0},
	],
	"tags": ["office", "starter"],
	"unlocked_by_default": true,
}

const COLT := {
	"id": "colt",
	"name": "Кольт",
	"projectile": "bullet",
	"modifiers": [
		{"stat": "damage", "op": "add", "value": 24.0},
		{"stat": "fire_rate", "op": "add", "value": 2.2},
		{"stat": "projectile_speed", "op": "add", "value": 1180.0},
		{"stat": "range", "op": "add", "value": 900.0},
		{"stat": "shot_momentum", "op": "add", "value": 0.05},
	],
	"tags": ["gun"],
	"unlocked_by_default": false,
}

const WEAPONS := {"suitcase": SUITCASE, "colt": COLT}

const DEFAULT_WEAPON := "suitcase"


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, {})


static func exists(id: String) -> bool:
	return WEAPONS.has(id)


static func source_of(id: String) -> String:
	return SOURCE_PREFIX + id


## Прежнее оружие снимается по источнику, а не по списку статов: предметы
## и органы в стеке остаются нетронутыми.
static func equip(actor, weapon_id: String) -> bool:
	if not exists(weapon_id):
		push_error("Неизвестное оружие: '%s'" % weapon_id)
		return false

	if actor.weapon_id != "":
		actor.stack.remove_source(source_of(actor.weapon_id))

	var record := weapon(weapon_id)
	var source := source_of(weapon_id)
	for entry in record.get("modifiers", []):
		var op: int = Schemas.OPS.find(entry.get("op", "add"))
		actor.stack.add(Modifier.make(
			entry.get("stat", ""), op as Modifier.Op,
			float(entry.get("value", 0.0)), source))
	actor.weapon_id = weapon_id
	return true


static func unequip(actor) -> void:
	if actor.weapon_id == "":
		return
	actor.stack.remove_source(source_of(actor.weapon_id))
	actor.weapon_id = ""


static func projectile_of(actor) -> String:
	return weapon(actor.weapon_id).get("projectile", "")


static func validate_all() -> PackedStringArray:
	return Schemas.validate_records("weapon", WEAPONS)
