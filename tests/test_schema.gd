extends "res://tests/framework/test_case.gd"
## Класс: инвариант. Правило 5 нерушимо: валидатор, который что-то
## пропускает, хуже отсутствующего.
##
## Схемы контента. Смысл проверок ниже — не в том, что верные данные
## проходят, а в том, что неверные не проходят.

const Schema = preload("res://sim/data/schema.gd")
const Schemas = preload("res://sim/data/schemas.gd")

const GOOD_ITEM := {
	"id": "rzhavyi_shprits",
	"name": "Ржавый шприц",
	"rarity": "common",
	"modifiers": [
		{"stat": "damage", "op": "add", "value": 2.0},
		{"stat": "fire_rate", "op": "mul", "value": 1.1},
	],
	"tags": ["injector"],
}

const GOOD_CHARACTER := {
	"id": "khimik",
	"name": "Химик",
	"base_stats": {"health": 100.0, "damage": 10.0, "move_speed": 220.0},
	"start_items": ["rzhavyi_shprits"],
	"skill": "sintez",
}

const GOOD_ENEMY := {
	"id": "sanitar",
	"name": "Санитар",
	"base_stats": {"health": 40.0, "damage": 6.0, "move_speed": 90.0},
	"organ_drops": [{"organ": "pechen", "chance": 0.25}],
	"zones": ["priemnyi_pokoy"],
	"tier": 1,
}

## Слот, Heat, описание и модификаторы обязательны: орган без них не
## показать в теле и не оценить перед установкой.
const GOOD_ORGAN := {
	"id": "pechen",
	"name": "Печень",
	"price": 12,
	"rarity": "common",
	"slot": "liver",
	"heat": 10,
	"description": "Пьёт за двоих.",
	"modifiers": [],
}


func title() -> String:
	return "схемы контента"


func _test_good_content_passes() -> bool:
	no_errors(Schemas.validate("item", GOOD_ITEM), "верный предмет не прошёл схему")
	no_errors(Schemas.validate("character", GOOD_CHARACTER), "верный персонаж не прошёл схему")
	no_errors(Schemas.validate("enemy", GOOD_ENEMY), "верный враг не прошёл схему")
	no_errors(Schemas.validate("organ", GOOD_ORGAN), "верный орган не прошёл схему")
	return true


func _with(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in patch.keys():
		out[key] = patch[key]
	return out


func _without(base: Dictionary, field: String) -> Dictionary:
	var out := base.duplicate(true)
	out.erase(field)
	return out


func _test_unknown_field_fails() -> bool:
	var errors := Schemas.validate("item", _with(GOOD_ITEM, {"damge": 5.0}))
	has_error(errors, "неизвестное поле", "опечатка в имени поля проехала")
	return true


func _test_missing_required_fails() -> bool:
	has_error(Schemas.validate("item", _without(GOOD_ITEM, "name")),
		"обязательное поле", "предмет без имени проехал")
	has_error(Schemas.validate("character", _without(GOOD_CHARACTER, "base_stats")),
		"обязательное поле", "персонаж без стат-блока проехал")
	return true


func _test_wrong_type_fails() -> bool:
	has_error(Schemas.validate("organ", _with(GOOD_ORGAN, {"price": "двенадцать"})),
		"ожидался int", "цена строкой проехала")
	has_error(Schemas.validate("item", _with(GOOD_ITEM, {"tags": [1, 2]})),
		"ожидался String", "теги числами проехали")
	return true


func _test_unknown_stat_fails() -> bool:
	var bad := _with(GOOD_CHARACTER, {"base_stats": {"helth": 100.0}})
	has_error(Schemas.validate("character", bad), "неизвестный ключ", "опечатка в имени стата проехала")

	var bad_mod := _with(GOOD_ITEM, {"modifiers": [{"stat": "dmg", "op": "add", "value": 1.0}]})
	has_error(Schemas.validate("item", bad_mod), "не входит", "модификатор несуществующего стата проехал")
	return true


func _test_bad_rarity_fails() -> bool:
	has_error(Schemas.validate("item", _with(GOOD_ITEM, {"rarity": "legendary"})),
		"не входит", "выдуманная редкость проехала")
	return true


func _test_bad_id_fails() -> bool:
	has_error(Schemas.validate("item", _with(GOOD_ITEM, {"id": "Ржавый Шприц"})),
		"не подходит", "идентификатор не по шаблону проехал")
	has_error(Schemas.validate("item", _with(GOOD_ITEM, {"id": "9_shprits"})),
		"не подходит", "идентификатор с цифры проехал")
	return true


func _test_nested_element_checked() -> bool:
	var bad_op := _with(GOOD_ITEM, {"modifiers": [{"stat": "damage", "op": "divide", "value": 2.0}]})
	has_error(Schemas.validate("item", bad_op), "не входит", "неизвестная операция модификатора проехала")

	var bad_shape := _with(GOOD_ITEM, {"modifiers": [{"stat": "damage", "value": 2.0}]})
	has_error(Schemas.validate("item", bad_shape), "обязательное поле", "модификатор без операции проехал")
	return true


func _test_range_checked() -> bool:
	var bad_chance := _with(GOOD_ENEMY, {"organ_drops": [{"organ": "pechen", "chance": 1.5}]})
	has_error(Schemas.validate("enemy", bad_chance), "больше максимума", "шанс дропа больше единицы проехал")

	has_error(Schemas.validate("organ", _with(GOOD_ORGAN, {"price": -1})),
		"меньше минимума", "отрицательная цена проехала")
	return true


func _test_int_accepted_as_float() -> bool:
	var whole := _with(GOOD_ITEM, {"modifiers": [{"stat": "damage", "op": "add", "value": 2}]})
	no_errors(Schemas.validate("item", whole), "целое значение модификатора не прошло")
	return true


func _test_defaults() -> bool:
	var minimal := {"id": "kost", "name": "Кость", "price": 3, "rarity": "common"}
	var filled := Schema.with_defaults(minimal, Schemas.ORGAN)
	eq(filled["tags"], [], "необязательное поле не получило значение по умолчанию")
	check(not minimal.has("tags"), "with_defaults испортил исходный словарь")
	return true
