extends "res://tests/framework/test_case.gd"
## Класс: поведение. Вращение на месте, однократное падение, окончание взрыва.
const Arena = preload("res://tests/framework/arena.gd")
const Encounter = preload("res://sim/encounter.gd")
const Save = preload("res://sim/save/save_game.gd")
const View = preload("res://game/world_view.gd")
const Helicopter = preload("res://game/helicopter_art.gd")
const Feedback = preload("res://game/combat_feedback.gd")
const Guard = preload("res://game/guard_art.gd")
const Art = preload("res://game/art_library.gd")
const Recovery = preload("res://game/recovery_frames.gd")
func title() -> String: return "полировка боевых анимаций"

func _test_hovering_rotor_and_observed_crash_survive_snapshot() -> bool:
	var view := View.new()
	view.state = Arena.solo("helicopter-polish")
	var actor = Encounter.add_enemy(view.state, "gunship", Vector2.ZERO)
	var id: int = actor.id
	view.advance(0.0)
	var bytes := Save.to_bytes(view.state)
	var phase: float = view.helicopter._phases[id]
	view.advance(0.1)
	check(view.helicopter._phases[id] != phase, "неподвижный вертолёт остановил винт")
	bytes_eq(Save.to_bytes(view.state), bytes, "вращение изменило симуляцию")
	actor.take_damage(10000)
	view.advance(0.0)
	almost_eq(view.helicopter.ages[id], 0.0, "смерть сразу показала обломки")
	view.advance(0.2)
	view.state = Arena.after_save(view.state)
	view.state.tick += 1
	view.advance(0.1)
	almost_eq(view.helicopter.ages[id], 0.3, "сетевой снимок начал падение заново")
	view.advance(3.0)
	almost_eq(view.helicopter.ages[id], Helicopter.EFFECT_TIME, "падение не завершилось")
	view.state.room.id = "elsewhere"
	view.advance(0.0)
	almost_eq(view.helicopter.ages[id], Helicopter.EFFECT_TIME, "возврат повторил падение")
	view.free()
	return true

func _test_barrel_smoke_ends_and_clear_removes_blasts() -> bool:
	var fx := Feedback.new()
	fx.explosion({"radius": 150}, Vector2.ZERO)
	fx.advance(0.8)
	check(not fx.blasts.is_empty(), "дым исчез вместе со вспышкой")
	fx.advance(2.0)
	check(fx.blasts.is_empty(), "взрыв не завершился")
	fx.explosion({}, Vector2.ZERO)
	fx.clear()
	check(fx.blasts.is_empty(), "взрыв пережил смену комнаты")
	return true

func _test_light_and_dark_riders_use_their_own_art() -> bool:
	var state := Arena.solo("rope-art")
	var art := Art.new()
	var textures := {"soldier_rope": art.get_texture("soldier_rope"), "soldier_dark_rope": art.get_texture("soldier_dark_rope")}
	for name in ["soldier", "soldier_dark"]:
		var actor = Encounter.add_enemy(state, name, Vector2.ZERO)
		actor.drop_ticks = 60
		eq(Guard.riding_frame(actor, textures), name + "_rope", "десантник использует чужую форму")
	return true

func _test_recovery_frames_are_grounded_and_finish_standing() -> bool:
	for name in Recovery.NAMES:
		var image := Image.load_from_file("res://art/%s.png" % name)
		check(image != null, "нет отдельной позы " + name)
		if image == null: continue
		eq(image.get_size(), Vector2i(128, 192), "нарушен масштаб позы " + name)
		var floor_y := image.get_used_rect().end.y
		check(floor_y >= 170 and floor_y <= 178, "опора не совмещена с полом: %s y=%d" % [name, floor_y])
	for pair in [[0.0, ""], [0.1, "player_support"], [0.25, "player_kneel"], [0.43, "player_crouch"], [0.59, "player_side_stand"]]:
		eq(Recovery.rise_pose(pair[0]).from, pair[1], "пропущена опорная поза")
	almost_eq(Recovery.rise_pose(0.6).blend, 0.0, "после вставания осталась двойная поза")
	return true

func _test_fragments_land_and_remain_finite() -> bool:
	for i in Helicopter.PIECES.size():
		for step in 22:
			check(Helicopter.fragment_motion(i, step * 0.1).is_finite(), "осколок получил неверную координату")
		eq(Helicopter.fragment_motion(i, 1.6), Helicopter.fragment_motion(i, 2.0), "упавший осколок продолжает скользить")
	return true
