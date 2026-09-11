extends "res://tests/framework/test_case.gd"
## Класс: поведение. Вертикальная походка и её выбор в живом виде.

const Gait = preload("res://game/vertical_gait.gd")
const View = preload("res://game/world_view.gd")
const Arena = preload("res://tests/framework/arena.gd")
const Art = preload("res://game/art_library.gd")

func title() -> String:
	return "вертикальная ходьба героя"

func _test_direction_and_firing_override() -> bool:
	eq(Gait.facing(Vector2(0, 260), Vector2.ZERO), Gait.FRONT, "вниз нужен анфас")
	eq(Gait.facing(Vector2(0, -260), Vector2.ZERO), Gait.BACK, "вверх нужна спина")
	eq(Gait.facing(Vector2(260, 30), Vector2.ZERO), "", "вбок нужен прежний профиль")
	eq(Gait.facing(Vector2.ZERO, Vector2.ZERO, Gait.BACK), Gait.BACK, "остановка не разворачивает спину")
	for aim in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		eq(Gait.facing(Vector2(0, 260), aim), "", "стрельба должна сохранить точку выпуска")
	return true

func _test_support_foot_and_cycle() -> bool:
	for index in 32:
		var phase := TAU * index / 32.0
		var left := Gait.point(Vector2(53, 174), phase, true, false)
		var right := Gait.point(Vector2(75, 174), phase, true, false)
		almost_eq(maxf(left.y, right.y), 174.0, "обе ноги оторвались от пола")
		check(minf(left.y, right.y) >= 165.0, "слишком большой подъём колена")
		almost_eq(left.x, 53.0, "опорная стопа скользит вбок")
		almost_eq(right.x, 75.0, "опорная стопа скользит вбок")
		var wrapped := Gait.point(Vector2(53, 174), phase + TAU, true, false)
		check(left.distance_to(wrapped) < 0.001, "стык цикла заметен")
	return true

func _test_swing_changes_feet_without_idle_motion() -> bool:
	check(Gait.step_lift(PI / 2, true) > 8, "левая нога не поднимается")
	almost_eq(Gait.step_lift(PI / 2, false), 0, "правая нога не опорная")
	check(Gait.step_lift(PI * 1.5, false) > 8, "правая нога не поднимается")
	for p in [Vector2(52, 174), Vector2(76, 174), Vector2(64, 20), Vector2(85, 113)]:
		eq(Gait.point(p, 1.0, false, true), p, "в покое продолжается шаг")
	return true

func _test_back_art_has_canvas_and_floor() -> bool:
	var image := Image.load_from_file("res://art/player_back_stand.png")
	check(image != null, "задний вид не сохранён в проекте")
	if image == null: return false
	eq(image.get_size(), Vector2i(128, 192), "холст заднего вида отличается")
	var bounds := image.get_used_rect()
	eq(bounds.end.y, 175, "задние ботинки не стоят на y=174")
	return true


func _test_view_picks_frame_and_returns_it_to_the_profile() -> bool:
	var view := View.new()
	var art := Art.new()
	for name in [Gait.FRONT, Gait.BACK, "player_side_stand", "player_colt_walk_4"]:
		view.textures[name] = art.get_texture(name)
	view.state = Arena.solo("vertical-art")
	var player := view.state.actor_of_slot(0)
	player.velocity = Vector2(0, -260)
	eq(view.vertical_frame(player, Vector2.ZERO), Gait.BACK, "шаг вверх не показал спину")
	player.velocity = Vector2.ZERO
	eq(view.vertical_frame(player, Vector2.ZERO), Gait.BACK, "остановка развернула спину")
	eq(view.vertical_frame(player, Vector2.UP), "", "стрельба не вернула штатную позу")
	player.velocity = Vector2(260, 0)
	eq(view.vertical_frame(player, Vector2.ZERO), "", "шаг вбок перестал быть профилем")
	player.velocity = Vector2(0, 260)
	eq(view.vertical_frame(player, Vector2.ZERO), Gait.FRONT, "шаг вниз не показал анфас")
	player.velocity = Vector2.ZERO
	eq(view.vertical_frame(player, Vector2.ZERO), "", "анфасный покой отобран у штатной позы")
	view.free()
	return true
