extends RefCounted
## Записи врагов и персонажей: данные, а не классы (правило 7).
##
## На M3 записи переедут в data/*.json через тот же валидатор.

const Schemas = preload("res://sim/data/schemas.gd")
const Organs = preload("res://sim/organs.gd")

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
	"radius": 16.0,
	"start_items": [],
	"skill": "lunch_break",
	"unlocked_by_default": true,
}

## Различаются повадкой (behaviour, разбирается в sim/tick.gd), а не только
## числами: одинаковые по поведению враги в толпе не читаются.
##
## radius — круг хитбокса. Чем тело тяжелее и медленнее, тем он больше:
## в толстяка легче попасть и труднее от него увернуться. Числа стартовые,
## под заглушку monster.png; с настоящими спрайтами радиус приезжает
## вместе с каждым.
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
	"radius": 24.0,
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
	"radius": 18.0,
	"behaviour": "harrier",
	"organ_drops": [{"organ": "courier_heart", "chance": 1.0}],
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
	"radius": 34.0,
	"behaviour": "bruiser",
	"organ_drops": [{"organ": "coward_heart", "chance": 1.0}],
	"zones": ["dev_room"],
	"tier": 2,
}

const TANDEM := {
	"id": "tandem", "name": "Тандем", "behaviour": "tank",
	"base_stats": {
		"health": 360.0, "damage": 18.0, "move_speed": 45.0,
		"acceleration": 240.0, "friction": 1200.0,
		"projectile_speed": 340.0, "range": 1200.0,
	},
	"radius": 92.0,
	"organ_drops": [{"organ": "armored_spine", "chance": 1.0}],
	"zones": ["dev_room"], "tier": 3,
}

const CHARACTERS := {"clerk": CLERK}
const ENEMIES := {
	"test_monster": TEST_MONSTER,
	"runner": RUNNER,
	"heavy": HEAVY,
	"tandem": TANDEM,
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
		for drop in ENEMIES[id].get("organ_drops", []):
			if Organs.organ(drop["organ"]).is_empty():
				errors.append("enemy '%s': unknown organ %s" % [id, drop["organ"]])
	return errors
