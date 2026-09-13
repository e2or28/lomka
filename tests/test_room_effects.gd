extends "res://tests/framework/test_case.gd"
## Класс: поведение. Повторный вход не повторяет смерть босса или открытие.
const Wreck = preload("res://game/tank_wreck.gd")
const Effects = preload("res://game/room_effects.gd")
const Arena = preload("res://tests/framework/arena.gd")
func title() -> String: return "смерть Тандема и проходы"
func _test_wreck_plays_only_new_death() -> bool:
	var state = Arena.duel("wreck", "tandem", Vector2(200, 0))
	var tank = Arena.enemies(state)[0]
	var fx := Wreck.new()
	fx.advance(state.actors, 0)
	tank.alive = false
	fx.advance(state.actors, 0)
	almost_eq(fx.ages[tank.id], 0.0, "смерть не началась")
	fx.advance(state.actors, 3)
	almost_eq(fx.ages[tank.id], 3.0, "смерть не завершилась")
	fx.clear()
	fx.advance(state.actors, 0)
	almost_eq(fx.ages[tank.id], 3.0, "загрузка повторяет смерть")
	for p in [Vector2(150, 240), Vector2(300, 240)]:
		eq(Wreck.deform(p, 0.5), p, "разрушение сдвигает опору")
	return true
func _test_opening_runs_on_clear_and_restores_finished() -> bool:
	var state = Arena.duel("door", "runner", Vector2(100, 0))
	var fx := Effects.new()
	fx.advance(state, 0)
	almost_eq(fx.open_progress, 0.0, "бой открыл проход")
	Arena.enemies(state)[0].alive = false
	fx.advance(state, 0.2)
	check(fx.open_progress > 0 and fx.open_progress < 1, "проход открылся мгновенно")
	fx.advance(state, 0.3)
	almost_eq(fx.open_progress, 1.0, "проход не открылся")
	fx.clear()
	fx.advance(state, 0)
	almost_eq(fx.open_progress, 1.0, "возвращение повторяет открытие")
	return true
