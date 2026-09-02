extends RefCounted
## Оружие. Правило 7: данные, а не классы.
##
## Оружие устроено как предмет и не случайно: и то и другое кладёт
## модификаторы в стек. Поэтому смена оружия — это снять модификаторы одного
## источника и положить модификаторы другого, тем же механизмом, которым
## подбирается и теряется предмет. Второе оружие не стоит ни строчки нового
## кода в бою.
##
## Боевых статов в персонаже нет вовсе: урон, скорострельность, скорость и
## дальность броска приходят от оружия. Безоружный не стреляет не потому,
## что где-то стоит проверка, а потому что скорострельность нулевая.

const Schemas = preload("res://sim/data/schemas.gd")
const Modifier = preload("res://sim/core/modifier.gd")

const SOURCE_PREFIX := "weapon:"

## Чемодан: то, с чем служащий выходит из офиса. Стартовое оружие,
## меняется на что угодно другое.
const SUITCASE := {
	"id": "suitcase",
	"name": "Чемодан",
	"projectile": "folder",
	"modifiers": [
		{"stat": "damage", "op": "add", "value": 12.0},
		{"stat": "fire_rate", "op": "add", "value": 3.5},
		{"stat": "projectile_speed", "op": "add", "value": 620.0},
		{"stat": "range", "op": "add", "value": 620.0},
		# Часть скорости бросающего переходит папке: заимствовано из Isaac,
		# даёт разницу между броском стоя и на бегу. Число подбирается руками.
		{"stat": "shot_momentum", "op": "add", "value": 0.35},
		# Кувырок в конце броска: чемодан переворачивается и доезжает
		# ещё треть дальности. Приём Mr. P из Brawl Stars.
		{"stat": "tumble_range", "op": "add", "value": 220.0},
	],
	"tags": ["office", "starter"],
	"unlocked_by_default": true,
}

## Кольт: первое оружие, которое не бросают, а из которого стреляют.
##
## Заведён не ради разнообразия, а как проверка того, что оружие правда
## сменяемые данные: если второе оружие потребовало хоть строчки нового кода
## в бою, значит первое было зашито в него, и это надо чинить сейчас, а не
## на сороковом стволе.
##
## Отличается от чемодана всем, чем оружие вообще может отличаться:
## бьёт вдвое сильнее, стреляет реже, летит вдвое быстрее и дальше, не
## кувыркается вовсе и почти не наследует скорость стрелка — пуля тяжёлой
## папке не родня. Разгоняться перед выстрелом с ним бессмысленно, и это
## осознанная разница в том, как с ним двигаются.
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


## Выдать оружие. Прежнее снимается целиком — по источнику, а не по списку
## статов: снять надо ровно то, что положило старое оружие, и ничего
## больше. Предметы и органы в стеке остаются нетронутыми.
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


## Снять оружие. Безоружный остаётся живым и ходит, но не стреляет.
static func unequip(actor) -> void:
	if actor.weapon_id == "":
		return
	actor.stack.remove_source(source_of(actor.weapon_id))
	actor.weapon_id = ""


## Чем стреляет то, что в руках. Пустая строка — нечем.
static func projectile_of(actor) -> String:
	return weapon(actor.weapon_id).get("projectile", "")


## Проверить все записи тем же валидатором, что и остальной контент.
static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for id in WEAPONS:
		errors.append_array(Schemas.validate("weapon", WEAPONS[id]))
	return errors
