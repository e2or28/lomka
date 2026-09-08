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
	"bounces",
	"charge_time",
	"damage",
	"fire_rate",
	"friction",
	"health",
	"luck",
	"move_speed",
	"projectile_speed",
	"pierce",
	"range",
	"rear_shots",
	"shot_momentum",
	"tumble_range",
	"withdrawal_rate",
]

const RARITIES: Array[String] = ["common", "uncommon", "rare", "boss"]

const ORGAN_SLOTS: Array[String] = [
	"brain", "eyes", "heart", "lungs", "liver", "spine", "legs", "genitals",
]

## Повадки врагов. Закрытый список: опечатка в поведении иначе даёт врага,
## который молча стоит на месте.
const BEHAVIOURS: Array[String] = ["charger", "harrier", "bruiser", "tank"]

## Операции соответствуют Modifier.Op по порядку.
const OPS: Array[String] = ["add", "mul", "set"]

const MODIFIER := {
	"stat": {"type": TYPE_STRING, "values": STATS},
	"op": {"type": TYPE_STRING, "values": OPS},
	"value": {"type": TYPE_FLOAT},
}

const STAT_BLOCK := {"type": TYPE_DICTIONARY, "value_type": TYPE_FLOAT, "keys": STATS}

## Радиус хитбокса. Не стат намеренно: это свойство тела, а не число
## баланса, и читается оно в цикле попаданий, где пересборка стека на
## каждую пару стоила бы дороже самой проверки. Значение по умолчанию —
## в Actor.radius, здесь только проверка на осмысленность.
const HITBOX := {"type": TYPE_FLOAT, "min": 1.0, "required": false}

const ITEM := {
	"id": {"type": TYPE_STRING, "id": true},
	"name": {"type": TYPE_STRING},
	"description": {"type": TYPE_STRING, "required": false},
	"badge": {"type": TYPE_STRING, "required": false},
	"rarity": {"type": TYPE_STRING, "values": RARITIES},
	"modifiers": {"type": TYPE_ARRAY, "element_schema": MODIFIER, "required": false, "default": []},
	"behaviours": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
	"tags": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
	"unlocked_by_default": {"type": TYPE_BOOL, "required": false, "default": true},
}

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
	"slot": {"type": TYPE_STRING, "values": ORGAN_SLOTS, "required": false},
	"description": {"type": TYPE_STRING, "required": false},
	"badge": {"type": TYPE_STRING, "required": false},
	"heat": {"type": TYPE_INT, "min": 0, "required": false},
	"modifiers": {"type": TYPE_ARRAY, "element_schema": MODIFIER, "required": false},
	"behaviour": {"type": TYPE_STRING, "values": ["", "keep_moving", "coward"], "required": false},
	"tags": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
}

const SYNERGY := {
	"id": {"type": TYPE_STRING, "id": true},
	"name": {"type": TYPE_STRING},
	"description": {"type": TYPE_STRING},
	"requires": {"type": TYPE_ARRAY, "element_type": TYPE_STRING},
	"modifiers": {"type": TYPE_ARRAY, "element_schema": MODIFIER},
}

const CHARACTER := {
	"id": {"type": TYPE_STRING, "id": true},
	"name": {"type": TYPE_STRING},
	"base_stats": STAT_BLOCK,
	"radius": HITBOX,
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
	"radius": HITBOX,
	"behaviour": {"type": TYPE_STRING, "values": BEHAVIOURS, "required": false, "default": "charger"},
	"organ_drops": {"type": TYPE_ARRAY, "element_schema": ORGAN_DROP, "required": false, "default": []},
	"zones": {"type": TYPE_ARRAY, "element_type": TYPE_STRING, "required": false, "default": []},
	"tier": {"type": TYPE_INT, "min": 1, "max": 3, "required": false, "default": 1},
}

const BY_KIND := {
	"item": ITEM,
	"weapon": WEAPON,
	"organ": ORGAN,
	"synergy": SYNERGY,
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
