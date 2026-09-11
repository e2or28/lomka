extends "res://tests/framework/test_case.gd"
## Класс: поведение. Механизм работает, опоры и точка атаки остаются устойчивыми.
func title() -> String: return "анимации барона"
func _test_pump_moves_with_fixed_base() -> bool:
	var script = load("res://game/oil_baron_art.gd")
	check(script != null and script.can_instantiate(), "нет анимации качалки")
	if script == null or not script.can_instantiate(): return true
	check(script.pump_angle(0.0, -1.0, -1.0) != script.pump_angle(0.8, -1.0, -1.0), "качалка неподвижна")
	for time in [0.0, 0.4, 1.2]:
		eq(script.deform(Vector2(150, 320), time, -1.0, -1.0), Vector2(150, 320), "основание движется")
	return true
func _test_attack_has_hold_and_return() -> bool:
	var script = load("res://game/oil_baron_art.gd")
	if script == null or not script.can_instantiate(): return true
	eq(script.pump_angle(0.0, 0.96, -1.0), script.pump_angle(1.0, 0.96, -1.0), "замах не удерживается")
	check(script.pump_angle(0.0, -1.0, 0.05) < script.pump_angle(0.0, 1.0, -1.0), "нет рабочего хода")
	return true
