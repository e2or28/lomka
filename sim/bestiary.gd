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
	## Снаряд принимает видимое тело, как у врагов: корпус с ногами и голова
	## отдельно. Обе зоны уже силуэта — разведённые руки и волосы в них не
	## входят, промах по краю читается промахом. Рост 156, ширина торса 34,
	## головы 40 (art/player_layers.json).
	"hurtboxes": [Rect2(-17, -118, 34, 118), Rect2(-16, -154, 32, 40)],
	"start_items": [],
	"skill": "lunch_break",
	"unlocked_by_default": true,
}

## Различаются повадкой (behaviour, разбирается в sim/tick.gd), а не только
## числами: одинаковые по поведению враги в толпе не читаются.
##
## radius задаёт след на полу, hurtboxes — видимое тело для снарядов.
## Зоны тела соответствуют отдельным спрайтам, обращённым вправо.
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
	"hurtboxes": [Rect2(-25, -78, 46, 76), Rect2(-5, -110, 29, 35)],
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
	"hurtboxes": [Rect2(-28, -80, 47, 48), Rect2(0, -106, 29, 32), Rect2(-26, -36, 50, 34)],
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
	"hurtboxes": [Rect2(-49, -118, 98, 85), Rect2(-6, -146, 37, 39), Rect2(-47, -38, 94, 36)],
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
	"hurtboxes": [Rect2(-270, -68, 418, 90), Rect2(-128, -112, 226, 48),
		Rect2(-84, -218, 140, 110), Rect2(-282, -76, 164, 18)],
	"organ_drops": [{"organ": "armored_spine", "chance": 1.0}],
	"zones": ["dev_room"], "tier": 3,
}

const OIL_BARON := {
	"id": "oil_baron", "name": "Нефтяной барон", "behaviour": "oil_baron",
	"base_stats": {"health": 420.0, "damage": 16.0, "move_speed": 0.0,
		"acceleration": 0.0, "friction": 1200.0, "projectile_speed": 280.0, "range": 1200.0},
	"radius": 110.0,
	"hurtboxes": [Rect2(-180, -38, 360, 38), Rect2(-78, -170, 155, 136),
		Rect2(-180, -130, 80, 92), Rect2(-149, -291, 307, 57), Rect2(147, -326, 44, 143)],
	"organ_drops": [], "zones": ["oil_baron"], "tier": 3,
}
const SOLDIER := {
	"id": "soldier", "name": "Солдат", "behaviour": "rifleman",
	"base_stats": {"health": 48.0, "damage": 8.0, "move_speed": 100.0,
		"acceleration": 1000.0, "friction": 1800.0, "projectile_speed": 430.0, "range": 850.0},
	"radius": 22.0, "hurtboxes": [Rect2(-23, -115, 46, 113), Rect2(-24, -154, 49, 45)],
	"organ_drops": [], "zones": ["oil_baron"], "tier": 2,
}
const SOLDIER_DARK := {
	"id": "soldier_dark", "name": "Солдат", "behaviour": "rifleman",
	"base_stats": SOLDIER.base_stats,
	"radius": 22.0, "hurtboxes": SOLDIER.hurtboxes,
	"organ_drops": [], "zones": ["oil_baron"], "tier": 2,
}
const ICE_AGENT := {
	"id": "ice_agent", "name": "Агент ICE", "behaviour": "baton",
	"base_stats": {"health": 62.0, "damage": 14.0, "move_speed": 135.0,
		"acceleration": 1400.0, "friction": 2200.0},
	"radius": 24.0, "hurtboxes": [Rect2(-26, -113, 52, 111), Rect2(-27, -150, 55, 42)],
	"organ_drops": [], "zones": ["oil_baron"], "tier": 2,
}

const CHARACTERS := {"clerk": CLERK}
## Летает и не касается пола: напольный радиус нужен только для того, чтобы
## снаряд, прошедший мимо зон, не считался попаданием в пустоту.
const GUNSHIP := {
	"id": "gunship", "name": "Вертушка", "behaviour": "gunship",
	"base_stats": {"health": 260.0, "damage": 18.0, "move_speed": 90.0,
		"acceleration": 260.0, "friction": 300.0, "projectile_speed": 130.0,
		"range": 3000.0, "homing": 1.5},
	"radius": 70.0,
	"hurtboxes": [Rect2(-233, -106, 424, 68), Rect2(-85, -148, 148, 47)],
	"organ_drops": [], "zones": ["oil_baron"], "tier": 3,
}

## Обстановка, а не противник: стоит, не ходит и не бьёт. Здоровья ровно
## столько, чтобы рвануть от одного попадания чем угодно.
const OIL_BARREL := {
	"id": "barrel", "name": "Бочка с нефтью", "behaviour": "prop",
	"base_stats": {"health": 1.0, "damage": 0.0, "move_speed": 0.0,
		"acceleration": 0.0, "friction": 0.0},
	"radius": 26.0,
	"hurtboxes": [Rect2(-26, -84, 52, 84)],
	"organ_drops": [], "zones": ["oil_baron"], "tier": 1,
}

const ENEMIES := {
	"test_monster": TEST_MONSTER,
	"runner": RUNNER,
	"heavy": HEAVY,
	"tandem": TANDEM,
	"oil_baron": OIL_BARON,
	"soldier": SOLDIER,
	"soldier_dark": SOLDIER_DARK,
	"ice_agent": ICE_AGENT,
	"gunship": GUNSHIP,
	"barrel": OIL_BARREL,
}


static func character(id: String) -> Dictionary:
	return CHARACTERS.get(id, {})


static func enemy(id: String) -> Dictionary:
	return ENEMIES.get(id, {})


static func validate_all() -> PackedStringArray:
	var errors := Schemas.validate_records("character", CHARACTERS)
	errors.append_array(Schemas.validate_records("enemy", ENEMIES))
	# Зоны нужны каждому телу: снаряд больше не ловится напольным кругом,
	# и запись без них молча стала бы неуязвимой.
	for records in [CHARACTERS, ENEMIES]:
		for id in records:
			if records[id].get("hurtboxes", []).is_empty():
				errors.append("'%s': hurtboxes required" % id)
			for rect in records[id].get("hurtboxes", []):
				if typeof(rect) == TYPE_RECT2 and (rect.size.x <= 0 or rect.size.y <= 0):
					errors.append("'%s': hurtbox must have positive size" % id)
	for id in ENEMIES:
		for drop in ENEMIES[id].get("organ_drops", []):
			if Organs.organ(drop["organ"]).is_empty():
				errors.append("enemy '%s': unknown organ %s" % [id, drop["organ"]])
	return errors
