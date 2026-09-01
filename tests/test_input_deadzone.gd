extends "res://tests/framework/test_case.gd"
## Круговая мёртвая зона стика.
##
## Твин-стик — ядро игры (docs/DECISIONS.md), и всё, что стоит между рукой
## и скоростью тела, влияет на ощущение управления напрямую. Поосевая зона
## движка образует квадрат: по диагонали порог ниже, чем по прямой, а на
## переходе через порог ось прыгает с нуля сразу на порог.
##
## Здесь проверяется, что зона круглая, что остаток растянут обратно на весь
## диапазон (у порога скорость начинается с нуля, а не с рывка) и что
## клавиатуру фильтр не трогает.

const InputReader = preload("res://game/input_reader.gd")

const DZ = InputReader.STICK_DEADZONE


func title() -> String:
	return "мёртвая зона стика"


func _test_below_zone_is_zero() -> bool:
	eq(InputReader.apply_deadzone(Vector2.ZERO), Vector2.ZERO, "покой дал ненулевой ввод")
	eq(InputReader.apply_deadzone(Vector2(DZ * 0.5, 0)), Vector2.ZERO, "дрожание прошло фильтр")
	eq(InputReader.apply_deadzone(Vector2(0, -DZ * 0.9)), Vector2.ZERO, "дрожание по Y прошло фильтр")
	eq(InputReader.apply_deadzone(Vector2(DZ, 0)), Vector2.ZERO, "ровно на границе зона не сработала")
	return true


## Зона круглая, а не квадратная: по диагонали порог такой же, как по прямой.
## Иначе изношенный стик, тянущий в угол, проезжает фильтр.
func _test_zone_is_round_not_square() -> bool:
	# 0.6 по каждой оси даёт длину DZ*0.85 — внутри круга, но снаружи
	# был бы квадрат со стороной DZ: ровно та разница, которую ловим.
	var corner := Vector2(DZ * 0.6, DZ * 0.6)
	check(corner.length() < DZ, "проба построена неверно: угол должен быть внутри круга")
	eq(InputReader.apply_deadzone(corner), Vector2.ZERO,
		"наклон в угол короче порога прошёл фильтр — зона квадратная")

	var beyond := Vector2(DZ * 0.9, DZ * 0.9)
	check(beyond.length() > DZ, "проба построена неверно")
	ne(InputReader.apply_deadzone(beyond), Vector2.ZERO,
		"наклон в угол длиннее порога срезан — зона слишком велика по диагонали")
	return true


## Главное свойство: сразу за порогом скорость начинается с нуля, а не
## прыгает на величину порога. Иначе малый наклон стика даёт рывок.
func _test_no_jump_at_the_threshold() -> bool:
	var just_over := InputReader.apply_deadzone(Vector2(DZ + 0.001, 0))
	check(just_over.length() < 0.01,
		"сразу за порогом ввод прыгнул на %.3f вместо почти нуля" % just_over.length())

	var half := InputReader.apply_deadzone(Vector2((1.0 + DZ) * 0.5, 0))
	almost_eq(half.length(), 0.5, "середина хода стика даёт не половину", 0.01)
	return true


func _test_direction_survives() -> bool:
	var broken := PackedStringArray()
	for raw in [Vector2(0.6, 0.0), Vector2(-0.5, 0.5), Vector2(0.0, -0.8), Vector2(-0.3, -0.9)]:
		var out := InputReader.apply_deadzone(raw)
		if out == Vector2.ZERO:
			broken.append("(%.1f %.1f) срезан" % [raw.x, raw.y])
		elif absf(out.normalized().angle() - raw.normalized().angle()) > 1e-5:
			broken.append("(%.1f %.1f) повернулся" % [raw.x, raw.y])
	check(broken.is_empty(), "наклон стика искажён: " + ", ".join(broken))
	return true


## Клавиатура даёт единицу по оси и корень из двух по диагонали. Фильтр не
## должен ни резать её, ни делать диагональ быстрее прямой.
func _test_keyboard_is_untouched() -> bool:
	eq(InputReader.apply_deadzone(Vector2(1, 0)), Vector2(1, 0), "клавиша срезана фильтром")
	eq(InputReader.apply_deadzone(Vector2(-1, 0)), Vector2(-1, 0), "клавиша влево срезана фильтром")

	var diagonal := InputReader.apply_deadzone(Vector2(1, 1))
	almost_eq(diagonal.length(), 1.0, "диагональ клавиатуры быстрее прямой", 1e-5)
	return true


## Чем сильнее наклон, тем быстрее — без провалов и ступенек.
func _test_monotonic() -> bool:
	var dips := PackedStringArray()
	var previous := 0.0
	var value := DZ
	while value <= 1.0:
		var length := InputReader.apply_deadzone(Vector2(value, 0)).length()
		if length < previous - 1e-6:
			dips.append("на %.2f упало с %.3f до %.3f" % [value, previous, length])
		previous = length
		value += 0.05
	check(dips.is_empty(), "скорость проваливается при росте наклона: " + ", ".join(dips))
	almost_eq(previous, 1.0, "полный наклон не даёт полной скорости", 0.06)
	return true
