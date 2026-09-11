extends "res://tests/framework/test_case.gd"
## Класс: поведение. Механизм работает, опоры и точка атаки остаются устойчивыми.
const OilBaronArt = preload("res://game/oil_baron_art.gd")
const Actor = preload("res://sim/actor.gd")

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
func _test_body_and_flags_move_without_shifting_foundation() -> bool:
	var art = load("res://game/oil_baron_art.gd")
	check(art.has_method("detail_offset"), "нет живых деталей барона")
	if not art.has_method("detail_offset"): return true
	eq(art.detail_offset(Vector2(150, 320), 1.0, 1.0), Vector2.ZERO, "удар двигает фундамент")
	check(art.detail_offset(Vector2(190, 215), 0.3, 0.0) != art.detail_offset(Vector2(190, 215), 1.0, 0.0), "барон не дышит")
	check(art.detail_offset(Vector2(190, 190), 0.0, 1.0).length() > 1.0, "барон не реагирует на удар")
	return true
func _test_pump_stalls_before_the_frame_changes() -> bool:
	var art = load("res://game/oil_baron_art.gd")
	if art == null or not art.can_instantiate(): return true
	check(art.pump_angle(0.8, -1.0, -1.0, 0.0) == 0.0, "качание не гаснет при остановке")
	check(absf(art.pump_angle(0.8, -1.0, -1.0, 0.3)) < absf(art.pump_angle(0.8, -1.0, -1.0, 1.0)),
		"остановка не уменьшает размах")
	eq(art.detail_offset(Vector2(190, 215), 1.0, 0.0, 0.0), Vector2.ZERO, "барон дышит после смерти")
	return true

func _test_death_plays_once_and_not_on_return() -> bool:
	var art = load("res://game/oil_baron_art.gd")
	if art == null or not art.can_instantiate(): return true
	var view = art.new()
	var baron = Actor.new()
	baron.id = 7
	baron.alive = true
	eq(view.death_progress(baron, 10.0), -1.0, "живой барон уже падает")
	baron.alive = false
	check(view.death_progress(baron, 10.0) < 0.01, "смерть на глазах проскакивает мгновенно")
	check(view.death_progress(baron, 10.0 + OilBaronArt.STALL_TIME) >= 1.0, "остановка не заканчивается")
	var returned = art.new()
	check(returned.death_progress(baron, 4.0) >= 1.0, "барон умирает заново при входе в комнату")
	view.clear()
	check(view.death_progress(baron, 4.0) >= 1.0, "сброс вида воскрешает павшего")
	return true

func _test_drop_leaves_the_muzzle_straight_and_keeps_its_volume() -> bool:
	var drop = load("res://game/oil_drop_art.gd")
	check(drop != null and drop.can_instantiate(), "нет вида нефтяной капли")
	if drop == null or not drop.can_instantiate(): return true
	almost_eq(drop.wobble(0.0), 0.0, "капля виляет прямо из ствола")
	var seen := 0.0
	for i in 40:
		var age := i * 0.05
		var size: Vector2 = drop.stretch(age)
		almost_eq(size.x * size.y, 1.0, "капля меняет объём в полёте", 1e-4)
		check(size.x >= 1.0 and size.x < 1.5, "капля растянулась в нитку")
		check(absf(drop.wobble(age)) <= 2.3, "капля виляет сильнее собственного радиуса")
		check(drop.tail_length(age) < 31.0, "хвост тянется без предела")
		seen = maxf(seen, absf(drop.wobble(age)))
	check(seen > 1.0, "капля летит неподвижным шариком")
	eq(drop.speck(0.05, 0).z, 0.0, "брызги отрываются раньше вылета")
	check(drop.speck(0.9, 0).z > 0.0 and drop.speck(0.9, 0).x < 0.0, "брызги не отстают от капли")
	return true
