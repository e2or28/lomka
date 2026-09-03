extends RefCounted
## Записи врагов и персонажей: данные, а не классы (правило 7).
##
## Пока их две и лежат константами. На M3 переедут в data/*.json через тот
## же валидатор.

const Schemas = preload("res://sim/data/schemas.gd")

## Боевых статов здесь нет: они приходят от оружия (sim/arsenal.gd), иначе
## смена оружия складывалась бы с врождённым уроном, и безоружный стрелял бы.
const CLERK := {
	"id": "clerk",
	"name": "Служащий",
	"base_stats": {
		"acceleration": 9000.0,
		"friction": 18000.0,
		"move_speed": 260.0,
		"health": 100.0,
	},
	"start_items": [],
	"skill": "",
	"unlocked_by_default": true,
}

## Различаются повадкой (behaviour, разбирается в sim/tick.gd), а не только
## числами: одинаковые по поведению враги в толпе не читаются.
const TEST_MONSTER := {
	"id": "test_monster",
	"name": "Монстр",
	"base_stats": {
		"health": 40.0,
		"damage": 8.0,
		"move_speed": 95.0,
		"acceleration": 900.0,
		"friction": 1400.0,
	},
	"behaviour": "charger",
	"organ_drops": [],
	"zones": ["dev_room"],
	"tier": 1,
}

const RUNNER := {
	"id": "runner",
	"name": "Курьер",
	"base_stats": {
		"health": 22.0,
		"damage": 6.0,
		"move_speed": 175.0,
		"acceleration": 1600.0,
		"friction": 2200.0,
	},
	"behaviour": "harrier",
	"organ_drops": [],
	"zones": ["dev_room"],
	"tier": 1,
}

const HEAVY := {
	"id": "heavy",
	"name": "Начальник",
	"base_stats": {
		"health": 110.0,
		"damage": 16.0,
		"move_speed": 62.0,
		"acceleration": 420.0,
		"friction": 700.0,
	},
	"behaviour": "bruiser",
	"organ_drops": [],
	"zones": ["dev_room"],
	"tier": 2,
}

const CHARACTERS := {"clerk": CLERK}
const ENEMIES := {
	"test_monster": TEST_MONSTER,
	"runner": RUNNER,
	"heavy": HEAVY,
}


static func character(id: String) -> Dictionary:
	return CHARACTERS.get(id, {})


static func enemy(id: String) -> Dictionary:
	return ENEMIES.get(id, {})


static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for id in CHARACTERS:
		errors.append_array(Schemas.validate("character", CHARACTERS[id]))
	for id in ENEMIES:
		errors.append_array(Schemas.validate("enemy", ENEMIES[id]))
	return errors
