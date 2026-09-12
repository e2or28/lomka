extends "res://tests/framework/test_case.gd"
## Класс: поведение. Механизм работает, опоры и точка атаки остаются устойчивыми.
const OilBaronArt = preload("res://game/oil_baron_art.gd")
const Actor = preload("res://sim/actor.gd")
const GuardArt = preload("res://game/guard_art.gd")
const Attacks = preload("res://sim/guard_attacks.gd")

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

func _test_baton_strikes_down_and_returns_on_its_own() -> bool:
	var agent = Actor.new()
	agent.id = 3
	agent.behaviour = "baton"
	agent.archetype = "ice_agent"
	agent.attack_ticks = 12
	eq(GuardArt.strike_age(agent), -1.0, "замах уже считается ударом")
	eq(GuardArt.frame(agent), "ice_agent_windup", "замах потерял свой кадр")
	agent.attack_ticks = 0
	agent.cooldown = Attacks.PROFILES.baton.recovery
	var lean := 0.0
	for i in 40:
		agent.cooldown = Attacks.PROFILES.baton.recovery - i * 0.02
		if agent.cooldown <= 0.0: break
		var now := GuardArt.strike_lean(GuardArt.strike_age(agent))
		if i == 0: almost_eq(now, 0.0, "удар начинается с наклона", 1e-3)
		lean = maxf(lean, now)
	check(lean > 0.3, "дубинка не доходит вниз")
	agent.cooldown = 0.0
	eq(GuardArt.strike_lean(GuardArt.strike_age(agent)), 0.0, "боец остался в наклоне после удара")
	eq(GuardArt.frame(agent), "ice_agent", "после удара не вернулась стойка")
	for y in [130.0, 194.0]:
		eq(GuardArt.strike_point(Vector2(80, y), 0.42), Vector2(80, y), "удар отрывает ноги от пола")
	check(GuardArt.strike_point(Vector2(80, 40), 0.42).x > 80.0, "корпус не валится вперёд")
	return true

func _test_oil_splash_falls_and_fades() -> bool:
	var drop = load("res://game/oil_drop_art.gd")
	if drop == null or not drop.can_instantiate(): return true
	var start: Vector3 = drop.splash_drop(0, 0.0, Vector2.RIGHT)
	var late: Vector3 = drop.splash_drop(0, 0.8, Vector2.RIGHT)
	check(late.z < start.z and late.z > 0.0, "капли всплеска не тают")
	check(late.y > start.y, "нефть висит в воздухе, а не оседает")
	check(Vector2(late.x, late.y).length() > Vector2(start.x, start.y).length(), "всплеск не разлетается")
	for i in 10:
		eq(drop.splash_drop(i, 1.0, Vector2.UP).z, 0.0, "всплеск не гаснет к концу")
	return true

func _test_rifleman_kneels_to_aim_and_shows_the_shot() -> bool:
	var soldier = Actor.new()
	soldier.id = 5
	soldier.behaviour = "rifleman"
	soldier.archetype = "soldier_dark"
	var full := {"soldier_dark": true, "soldier_dark_kneel": true, "soldier_dark_fire": true}
	soldier.attack_ticks = Attacks.PROFILES.rifleman.windup
	eq(GuardArt.frame(soldier, full), "soldier_dark_kneel", "стрелок целится стоя")
	soldier.attack_ticks = 0
	soldier.cooldown = Attacks.PROFILES.rifleman.recovery
	eq(GuardArt.frame(soldier, full), "soldier_dark_fire", "выстрел не виден")
	soldier.cooldown = Attacks.PROFILES.rifleman.recovery - GuardArt.FIRE_HOLD - 0.01
	eq(GuardArt.frame(soldier, full), "soldier_dark", "стрелок застыл в выстреле")
	soldier.cooldown = 0.0
	eq(GuardArt.frame(soldier, full), "soldier_dark", "стойка не вернулась")
	soldier.archetype = "soldier"
	soldier.attack_ticks = Attacks.PROFILES.rifleman.windup
	eq(GuardArt.frame(soldier, {"soldier": true, "soldier_kneel": true}), "soldier_kneel",
		"светлый стрелок не встаёт на колено")
	# Пока кадра нет вовсе, поза откатывается к стойке: стенд без арта
	# рисует заглушки, а не падает.
	eq(GuardArt.frame(soldier, {"soldier": true}), "soldier", "недостающая поза не откатилась к стойке")
	return true

func _test_guard_stride_lifts_one_leg_at_a_time() -> bool:
	var guard = Actor.new()
	guard.id = 6
	guard.behaviour = "baton"
	guard.velocity = Vector2(160, 0)
	check(GuardArt.stride_amount(guard) > 0.5, "идущая охрана стоит на месте")
	guard.velocity = Vector2(6, 0)
	almost_eq(GuardArt.stride_amount(guard), 0.0, "стоящая охрана шагает")
	guard.velocity = Vector2(160, 0)
	guard.attack_ticks = 5
	almost_eq(GuardArt.stride_amount(guard), 0.0, "охрана шагает во время замаха")
	for i in 24:
		var phase := TAU * i / 24.0
		var left := GuardArt.stride_point(Vector2(66, 186), phase, 1.0)
		var right := GuardArt.stride_point(Vector2(94, 186), phase, 1.0)
		almost_eq(maxf(left.y, right.y), 186.0, "обе ноги охраны в воздухе", 1e-3)
		check(minf(left.y, right.y) > 178.0, "нога охраны задрана выше колена")
		eq(GuardArt.stride_point(Vector2(80, 194), phase, 0.0), Vector2(80, 194), "шаг идёт в покое")
	return true
