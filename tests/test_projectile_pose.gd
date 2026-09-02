extends "res://tests/framework/test_case.gd"
## Вид летящей папки: переворот и тень.
##
## Дуга отсюда ушла. Раньше высота была декорацией: симуляция двигала снаряд
## по прямой, а представление подрисовывало прыжок. Теперь снаряд правда
## поднимается и падает, и от высоты зависит, попадёт он или пройдёт над
## головой — проверяется это в tests/test_ballistics.gd.
##
## Здесь осталось то, что действительно ни на что не влияет.

const ProjectilePose = preload("res://game/projectile_pose.gd")


func title() -> String:
	return "вид снаряда"


## Переворот считается от возраста, а не от доли пути: короткий бросок
## должен крутиться так же, как длинный, иначе оружие малой дальности
## выглядит вялым.
func _test_spin_speed_does_not_depend_on_range() -> bool:
	var quarter := ProjectilePose.rotation(ProjectilePose.SPIN_PERIOD * 0.25)
	almost_eq(quarter, TAU * 0.25, "четверть оборота за четверть периода не набралась", 1e-5)

	almost_eq(ProjectilePose.rotation(0.0), 0.0, "переворот начинается не с нуля", 1e-6)
	almost_eq(ProjectilePose.rotation(ProjectilePose.SPIN_PERIOD), 0.0,
		"за полный период не набрался ровно один оборот", 1e-5)
	return true


func _test_spin_keeps_turning() -> bool:
	var seen_high := false
	var out_of_range := 0
	for step in 40:
		var angle := ProjectilePose.rotation(step * 0.05)
		if angle < 0.0 or angle >= TAU + 1e-6:
			out_of_range += 1
		if angle > TAU * 0.75:
			seen_high = true
	eq(out_of_range, 0, "угол переворота вышел за оборот")
	check(seen_high, "папка не доходит до конца оборота")
	return true


## Тень читается по настоящей высоте: по ней игрок понимает, пройдёт
## снаряд над врагом или заденет.
func _test_shadow_follows_real_height() -> bool:
	var ground_scale := ProjectilePose.shadow_scale(0.0)
	var air_scale := ProjectilePose.shadow_scale(ProjectilePose.SHADOW_FULL_HEIGHT)
	check(air_scale < ground_scale, "тень наверху не уменьшилась")
	almost_eq(ground_scale, 1.0, "тень на полу не в полный размер", 1e-6)

	var ground_alpha := ProjectilePose.shadow_alpha(0.0)
	var air_alpha := ProjectilePose.shadow_alpha(ProjectilePose.SHADOW_FULL_HEIGHT)
	check(air_alpha < ground_alpha, "тень наверху не побледнела")
	return true


func _test_shadow_is_monotonic_and_bounded() -> bool:
	var previous := ProjectilePose.shadow_scale(0.0)
	var grew := 0
	for step in 40:
		var height := step * 5.0
		var scale := ProjectilePose.shadow_scale(height)
		if scale > previous + 1e-6:
			grew += 1
		previous = scale
	eq(grew, 0, "тень росла при подъёме снаряда")

	almost_eq(ProjectilePose.shadow_scale(10000.0), ProjectilePose.SHADOW_MIN_SCALE,
		"тень уменьшается без предела", 1e-6)
	check(ProjectilePose.shadow_alpha(10000.0) > 0.0, "тень исчезла совсем")
	return true
