extends "res://tests/framework/test_case.gd"
## Прыжок метательного портфеля — чистая математика представления.
##
## Положение столкновения остаётся в sim/: здесь проверяются только высота,
## один полный оборот и тень, которые видит игрок.

const Pose = preload("res://game/projectile_pose.gd")


func title() -> String:
	return "поза снаряда"


func _test_progress_is_clamped_to_one_flight() -> bool:
	almost_eq(Pose.progress(-1.0, 2.0), 0.0, "отрицательный возраст дал прогресс", 1e-6)
	almost_eq(Pose.progress(1.0, 2.0), 0.5, "середина полёта посчиталась неверно", 1e-6)
	almost_eq(Pose.progress(3.0, 2.0), 1.0, "после конца начался второй полёт", 1e-6)
	almost_eq(Pose.progress(1.0, 0.0), 1.0, "нулевая длительность не завершила полёт", 1e-6)
	return true


func _test_jump_is_one_symmetric_arc() -> bool:
	almost_eq(Pose.lift(0.0), 0.0, "портфель поднят в момент броска", 1e-6)
	almost_eq(Pose.lift(0.5), Pose.JUMP_HEIGHT, "в середине не достигнута вершина", 1e-6)
	almost_eq(Pose.lift(1.0), 0.0, "портфель не приземлился в конце", 1e-6)
	almost_eq(Pose.lift(0.25), Pose.lift(0.75), "дуга несимметрична", 1e-6)
	return true


func _test_rotation_is_exactly_one_turn() -> bool:
	almost_eq(Pose.rotation(0.0), 0.0, "портфель повёрнут до броска", 1e-6)
	almost_eq(Pose.rotation(0.5), PI, "в середине нет половины оборота", 1e-6)
	almost_eq(Pose.rotation(1.0), TAU, "за полёт не сделан полный оборот", 1e-6)
	almost_eq(Pose.rotation(2.0), TAU, "после приземления начался второй оборот", 1e-6)
	return true


func _test_shadow_shrinks_at_the_top() -> bool:
	almost_eq(Pose.shadow_scale(0.0), 1.0, "тень сжата на земле", 1e-6)
	almost_eq(Pose.shadow_scale(0.5), Pose.SHADOW_MIN_SCALE,
		"тень не сжалась в вершине", 1e-6)
	almost_eq(Pose.shadow_scale(1.0), 1.0, "тень не вернулась при посадке", 1e-6)
	check(Pose.shadow_alpha(0.5) < Pose.shadow_alpha(0.0),
		"тень не стала светлее при подъёме")
	return true
