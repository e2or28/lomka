extends RefCounted
## Записи врагов и персонажей. Правило 7: это данные, а не классы.
##
## Пока их две и лежат они здесь константами. На M3 переедут в data/*.json
## и будут читаться через тот же валидатор — схемы под них уже написаны
## в sim/data/schemas.gd, менять ничего не придётся.
##
## Имена и характеры — заглушки. Тексты и юмор остаются человеку, это
## записано в docs/PLAN.md.

const Schemas = preload("res://sim/data/schemas.gd")

## Офисный работник. Кидается тем, что даёт оружие; по умолчанию это
## чемодан, из которого летят папки с документами.
##
## Боевых статов здесь нет намеренно: урон, скорострельность, скорость и
## дальность броска приходят от оружия (sim/arsenal.gd). Иначе смена оружия
## складывалась бы с врождённым уроном персонажа, и безоружный стрелял бы.
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

## Манекен для стенда. Ходит к ближайшему игроку и бьёт касанием.
## Имя и повадки — за Егором, это заглушка под проверку боя.
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
	"organ_drops": [],
	"zones": ["dev_room"],
	"tier": 1,
}

const CHARACTERS := {"clerk": CLERK}
const ENEMIES := {"test_monster": TEST_MONSTER}


static func character(id: String) -> Dictionary:
	return CHARACTERS.get(id, {})


static func enemy(id: String) -> Dictionary:
	return ENEMIES.get(id, {})


## Проверить всё, что здесь лежит, тем же валидатором, что и остальной
## контент. Расхождение со схемой должно падать здесь, а не всплывать
## пустым статом в бою.
static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for id in CHARACTERS:
		errors.append_array(Schemas.validate("character", CHARACTERS[id]))
	for id in ENEMIES:
		errors.append_array(Schemas.validate("enemy", ENEMIES[id]))
	return errors
