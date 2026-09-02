extends "res://tests/framework/test_case.gd"
## Вид летящей папки: переворот и тень.
##
## Класс: поведение. Ничто здесь не влияет на попадание — снаряд летит по
## прямой, а высоты у него нет вовсе (падение отменено решением от 2 сентября
## 2026). Это чистое представление: подсказка глазу, вошёл ли бросок в
## добавочный отрезок. Сам полёт проверяется в tests/test_ballistics.gd.

const ProjectilePose = preload("res://game/projectile_pose.gd")


func title() -> String:
	return "вид снаряда"


## Переворот считается от возраста, а не от доли пути: короткий бросок
## должен крутиться так же, как длинный, иначе оружие малой дальности
## выглядит вялым.
func _test_spin_speed_does_not_depend_on_range() -> bool:
	var quarter := ProjectilePose.rotation(ProjectilePose.SPIN_PERIOD * 0.25, -1.0)
	almost_eq(quarter, TAU * 0.25, "четверть оборота за четверть периода не набралась", 1e-5)

	almost_eq(ProjectilePose.rotation(0.0, -1.0), 0.0, "переворот начинается не с нуля", 1e-6)
	almost_eq(ProjectilePose.rotation(ProjectilePose.SPIN_PERIOD, -1.0), 0.0,
		"за полный период не набрался ровно один оборот", 1e-5)
	return true


## На кувырке чемодан крутится заметно быстрее — по этому игрок и видит,
## что бросок вошёл в добавочный отрезок.
func _test_tumble_spins_faster() -> bool:
	var age := ProjectilePose.SPIN_PERIOD * 0.2
	var straight := ProjectilePose.rotation(age, -1.0)
	var tumbling := ProjectilePose.rotation(age, 0.5)
	check(tumbling > straight + 0.5,
		"кувырок крутится не быстрее ровного полёта: %.2f против %.2f" % [tumbling, straight])
	return true


## Подскок только на кувырке и только вверх.
func _test_hop_happens_only_while_tumbling() -> bool:
	almost_eq(ProjectilePose.hop(-1.0), 0.0, "чемодан подскакивает в ровном полёте", 1e-6)
	almost_eq(ProjectilePose.hop(0.0), 0.0, "подскок начинается не с нуля", 1e-6)
	almost_eq(ProjectilePose.hop(1.0), 0.0, "подскок не вернулся к нулю", 1e-6)
	check(ProjectilePose.hop(0.5) > 1.0, "на середине кувырка подскока нет")
	return true


func _test_spin_keeps_turning() -> bool:
	var seen_high := false
	var out_of_range := 0
	for step in 40:
		var angle := ProjectilePose.rotation(step * 0.05, -1.0)
		if angle < 0.0 or angle >= TAU + 1e-6:
			out_of_range += 1
		if angle > TAU * 0.75:
			seen_high = true
	eq(out_of_range, 0, "угол переворота вышел за оборот")
	check(seen_high, "папка не доходит до конца оборота")
	return true


## Тень отмечает кувырок: она уменьшается и бледнеет, пока чемодан идёт
## добавочный отрезок. Высоты у снаряда нет, тень рисует не её, а фазу
## полёта — по ней игрок читает, что бросок ещё жив.
func _test_shadow_marks_the_tumble() -> bool:
	almost_eq(ProjectilePose.shadow_scale(-1.0), 1.0, "в ровном полёте тень не в полный размер", 1e-6)
	check(ProjectilePose.shadow_scale(0.5) < 1.0, "на кувырке тень не уменьшилась")
	check(ProjectilePose.shadow_alpha(0.5) < ProjectilePose.shadow_alpha(-1.0),
		"на кувырке тень не побледнела")
	return true


func _test_shadow_stays_bounded() -> bool:
	var smallest := 1.0
	for step in 41:
		var scale := ProjectilePose.shadow_scale(step / 40.0)
		smallest = minf(smallest, scale)
		check(scale <= 1.0 + 1e-6, "тень выросла больше полного размера")
		check(ProjectilePose.shadow_alpha(step / 40.0) > 0.0, "тень исчезла совсем")
	almost_eq(smallest, ProjectilePose.SHADOW_MIN_SCALE,
		"тень уменьшается не до заданного предела", 1e-6)
	return true
