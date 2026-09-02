extends RefCounted
## Схемы контента: предмет, орган, персонаж, враг. Правила 5 и 7.
##
## Персонаж здесь — такая же запись данных, как предмет: стат-блок, стартовые
## предметы, пассивный модификатор, ссылка на активный скилл. Поэтому
## четвёртый персонаж стоит столько же, сколько первый.

const Schema = preload("res://sim/data/schema.gd")

## Закрытый список статов. Опечатка в имени стата иначе не падает, а тихо
## заводит стат, который никто не читает.
const STATS: Array[String] = [
	"acceleration",
	"damage",
	"fire_rate",
	"friction",
	"health",
	"luck",
	"move_speed",
	"projectile_speed",
	"range",
	"shot_momentum",
	"withdrawal_rate",
]

const RARITIES: Array[String] = ["common", "uncommon", "rare", "boss"]

## Операции соответствуют Modifier.Op по порядку.
const OPS: Array[String] = ["add", "mul", "set"]

const MODIFIER := {
	"stat": {"type": TYPE_STRING, "values": STATS},
	"op": {"type": TYPE_STRING, "values": OPS},
	"value": {"type": TYPE_FLOAT},
}

const STAT_BLOCK := {"type": TYPE_DICTIONARY, "value_type": TYPE_FLOAT, "keys": STATS}

const ITEM := {
	"id": {"type": TYPE_STRING, "id": true},
	"name": {"type": TYPE_STRING},
	"rarity": {"type": TYPE_STRING, "values": RARITIES},
	"modifiers": {"type": TYPE_ARRAY, "element_schema": MODIFIER, "required": false, "default": []},
	"behaviours": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
	"tags": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
	"unlocked_by_default": {"type": TYPE_BOOL, "required": false, "default": true},
}

## Оружие. Устроено как предмет и не случайно: и то и другое кладёт
## модификаторы в стек, поэтому смена оружия и подбор предмета проходят
## одним и тем же механизмом (правило 4).
##
## Боевых статов в персонаже нет — они целиком приходят от оружия. Персонаж
## без оружия не стреляет, потому что скорострельность нулевая, а не потому
## что где-то стоит проверка.
const WEAPON := {
	"id": {"type": TYPE_STRING, "id": true},
	"name": {"type": TYPE_STRING},
	"projectile": {"type": TYPE_STRING, "id": true},
	"modifiers": {"type": TYPE_ARRAY, "element_schema": MODIFIER},
	"tags": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
	"unlocked_by_default": {"type": TYPE_BOOL, "required": false, "default": false},
}

const ORGAN := {
	"id": {"type": TYPE_STRING, "id": true},
	"name": {"type": TYPE_STRING},
	"price": {"type": TYPE_INT, "min": 0},
	"rarity": {"type": TYPE_STRING, "values": RARITIES},
	"tags": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
}

const CHARACTER := {
	"id": {"type": TYPE_STRING, "id": true},
	"name": {"type": TYPE_STRING},
	"base_stats": STAT_BLOCK,
	"start_items": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
	"passive": {"type": TYPE_ARRAY, "element_schema": MODIFIER, "required": false, "default": []},
	"skill": {"type": TYPE_STRING, "required": false, "default": ""},
	"unlocked_by_default": {"type": TYPE_BOOL, "required": false, "default": false},
}

## Шанс дропа органа. Хранится долей, бросается из потока ORGAN_DROP.
const ORGAN_DROP := {
	"organ": {"type": TYPE_STRING, "id": true},
	"chance": {"type": TYPE_FLOAT, "min": 0.0, "max": 1.0},
}

const ENEMY := {
	"id": {"type": TYPE_STRING, "id": true},
	"name": {"type": TYPE_STRING},
	"base_stats": STAT_BLOCK,
	"organ_drops": {"type": TYPE_ARRAY, "element_schema": ORGAN_DROP, "required": false, "default": []},
	"zones": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
	"tier": {"type": TYPE_INT, "min": 1, "max": 3, "required": false, "default": 1},
}

const BY_KIND := {
	"item": ITEM,
	"weapon": WEAPON,
	"organ": ORGAN,
	"character": CHARACTER,
	"enemy": ENEMY,
}


static func schema_for(kind: String) -> Dictionary:
	if not BY_KIND.has(kind):
		push_error("Неизвестный вид контента: '%s'" % kind)
		assert(false, "Неизвестный вид контента: " + kind)
		return {}
	return BY_KIND[kind]


static func validate(kind: String, data: Dictionary) -> PackedStringArray:
	return Schema.validate(data, schema_for(kind), "%s '%s'" % [kind, data.get("id", "?")])


static func validate_or_fail(kind: String, data: Dictionary) -> bool:
	return Schema.validate_or_fail(data, schema_for(kind), "%s '%s'" % [kind, data.get("id", "?")])
