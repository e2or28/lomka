extends "res://tests/framework/test_case.gd"
## Класс: поведение. Пороги подбираются рукой на стенде; тест стережёт
## форму зоны, а не конкретные числа.
##
## Круговая мёртвая зона стика.

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


func _test_zone_is_round_not_square() -> bool:
	# DZ*0.6 по каждой оси даёт длину DZ*0.85 — внутри круга, но снаружи
	# был бы квадрат со стороной DZ.
	var corner := Vector2(DZ * 0.6, DZ * 0.6)
	check(corner.length() < DZ, "проба построена неверно: угол должен быть внутри круга")
	eq(InputReader.apply_deadzone(corner), Vector2.ZERO,
		"наклон в угол короче порога прошёл фильтр — зона квадратная")

	var beyond := Vector2(DZ * 0.9, DZ * 0.9)
	check(beyond.length() > DZ, "проба построена неверно")
	ne(InputReader.apply_deadzone(beyond), Vector2.ZERO,
		"наклон в угол длиннее порога срезан — зона слишком велика по диагонали")
	return true


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


func _test_keyboard_is_untouched() -> bool:
	eq(InputReader.apply_deadzone(Vector2(1, 0)), Vector2(1, 0), "клавиша срезана фильтром")
	eq(InputReader.apply_deadzone(Vector2(-1, 0)), Vector2(-1, 0), "клавиша влево срезана фильтром")

	var diagonal := InputReader.apply_deadzone(Vector2(1, 1))
	almost_eq(diagonal.length(), 1.0, "диагональ клавиатуры быстрее прямой", 1e-5)
	return true


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


func _test_aiming_has_no_free_angle() -> bool:
	eq(InputReader.AIM_DIRECTIONS, 4,
		"число направлений прицела разошлось с решением из DECISIONS.md")

	var free := Vector2(1.0, 0.15).normalized()
	var snapped := InputReader.CharacterPose.snap_aim(free, InputReader.AIM_DIRECTIONS)
	check(absf(snapped.angle() - free.angle()) > 0.05,
		"прицел не притянулся к направлению — свободный угол вернулся")
	return true


func _test_two_keys_do_not_give_a_diagonal() -> bool:
	var both := InputReader.apply_deadzone(Vector2(1.0, -1.0))
	var aim := InputReader.resolve_aim(both, Vector2.ZERO)
	check(aim.is_equal_approx(Vector2.UP),
		"вправо и вверх вместе дали диагональ: " + str(aim))
	return true


func _test_last_pressed_direction_wins() -> bool:
	var both := InputReader.apply_deadzone(Vector2(1.0, -1.0))

	var late_right := InputReader.resolve_aim(both, Vector2.RIGHT)
	check(late_right.is_equal_approx(Vector2.RIGHT),
		"вверх зажат раньше, стрелять должно вправо, а вышло " + str(late_right))

	var late_up := InputReader.resolve_aim(both, Vector2.UP)
	check(late_up.is_equal_approx(Vector2.UP),
		"вправо зажат раньше, стрелять должно вверх, а вышло " + str(late_up))

	var single := InputReader.resolve_aim(Vector2(0.0, -1.0), Vector2.RIGHT)
	check(single.is_equal_approx(Vector2.UP),
		"отпущенная стрелка продолжает держать прицел: " + str(single))
	return true
