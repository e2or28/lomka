extends "res://tests/framework/test_case.gd"

const Gait = preload("res://game/enemy_gait.gd")
const Arena = preload("res://tests/framework/arena.gd")

func title() -> String:
	return "походки обычных врагов"

func _test_phase_follows_distance_and_stops_at_obstacles() -> bool:
	var state = Arena.duel("gait", "runner", Vector2(300, 0))
	var actor = Arena.enemies(state)[0]
	var gait = Gait.new()
	actor.velocity = Vector2(175, 0)
	gait.advance(state.actors, 0.1)
	actor.position.x += 17.5
	gait.advance(state.actors, 0.1)
	var phase: float = gait.phase(actor.id)
	check(phase > 0, "пройденное расстояние не продвинуло шаг")
	gait.advance(state.actors, 0.1)
	eq(gait.phase(actor.id), phase, "шагает, упершись в стену")
	eq(gait.amount(actor.id), 0.0, "не вернулся в стойку у стены")
	actor.alive = false
	actor.position.x += 10
	gait.advance(state.actors, 0.1)
	eq(gait.phase(actor.id), phase, "мёртвый шагает")
	gait.clear()
	eq(gait.phase(actor.id), 0.0, "смена комнаты сохранила фазу")
	return true

func _test_supporting_foot_stays_on_floor_and_swing_foot_lifts() -> bool:
	for kind in ["test_monster", "runner", "heavy"]:
		var size := Vector2(60, 112) if kind != "heavy" else Vector2(105, 148)
		var left := Vector2(size.x * 0.25, size.y)
		var right := Vector2(size.x * 0.8, size.y)
		var first: Vector2 = Gait.deform(left, size, kind, PI * 0.5, 1.0)
		var support: Vector2 = Gait.deform(right, size, kind, PI * 0.5, 1.0)
		check(first.y < left.y, "маховая нога не поднялась: " + kind)
		eq(support.y, right.y, "опорная нога оторвалась: " + kind)
		eq(Gait.deform(left, size, kind, 1.2, 0.0), left, "стойка деформирована: " + kind)
	return true

func _test_characters_have_different_weight_and_cadence() -> bool:
	var size := Vector2(100, 150)
	var foot := Vector2(25, 150)
	var runner: Vector2 = Gait.deform(foot, size, "runner", PI * 0.5, 1.0)
	var heavy: Vector2 = Gait.deform(foot, size, "heavy", PI * 0.5, 1.0)
	check(runner.y < heavy.y, "бегун не отрывает ногу выше тяжёлого")
	check(175.0 / Gait.stride_length("runner") > 2.0 * 62.0 / Gait.stride_length("heavy"),
		"у бегуна нет более частого шага")
	return true

func _test_render_between_ticks_keeps_the_same_pose() -> bool:
	var state = Arena.duel("gait-120fps", "runner", Vector2(300, 0))
	var actor = Arena.enemies(state)[0]
	var gait = Gait.new()
	gait.advance(state.actors, 1.0 / 120.0, 0)
	actor.position.x += 3.0
	gait.advance(state.actors, 1.0 / 120.0, 1)
	var strength: float = gait.amount(actor.id)
	check(strength > 0.0, "движение не началось")
	gait.advance(state.actors, 1.0 / 120.0, 1)
	eq(gait.amount(actor.id), strength, "кадр между тиками сбросил позу")
	gait.advance(state.actors, 1.0 / 120.0, 2)
	eq(gait.amount(actor.id), 0.0, "остановка на следующем тике не вернула стойку")
	return true
