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

## Три типа врагов, как требует M1. Различаются не числами, а тем, как
## себя ведут: одинаковые по повадкам враги в толпе не читаются, сколько
## бы у них ни было разного здоровья.
##
## Поведение задаётся полем behaviour и разбирается в sim/tick.gd. Это
## данные, а не классы (правило 7): четвёртый тип врага не должен стоить
## нового файла.
##
## Имена — заглушки. Тексты и юмор остаются человеку, docs/PLAN.md.

## Идёт напролом. Опорный враг, по которому меряются остальные.
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

## Быстрый и хрупкий: налетает, отходит, налетает снова. Заставляет
## двигаться, а не отстреливаться стоя.
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

## Медленный и толстый: держит дистанцию и давит массой. Наказывает
## тех, кто пятится в угол.
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
