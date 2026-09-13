extends "res://tests/framework/test_case.gd"
## Класс: поведение. Операции видны один раз и не меняют состояние забега.
const Arena = preload("res://tests/framework/arena.gd")
const Organs = preload("res://sim/organs.gd")
const Save = preload("res://sim/save/save_game.gd")
func title() -> String: return "анимации действий героя"
func _test_install_observes_changes_without_replaying_loaded_organs() -> bool:
	var script = load("res://game/player_actions.gd")
	check(script != null and script.can_instantiate(), "нет анимации установки")
	if script == null or not script.can_instantiate(): return true
	var fx = script.new()
	var state = Arena.solo("install-animation")
	var player = state.actor_of_slot(0)
	fx.advance(state, 0.0)
	Organs.equip(player, state.slots[0], "courier_heart")
	var bytes := Save.to_bytes(state)
	fx.advance(state, 0.0)
	check(fx.installs.has(player.id), "смена органа не запустила установку")
	fx.advance(state, 1.0)
	check(fx.installs.is_empty(), "установка не закончилась")
	fx.clear()
	fx.advance(state, 0.0)
	check(fx.installs.is_empty(), "загрузка повторяет установку")
	bytes_eq(Save.to_bytes(state), bytes, "анимация изменила симуляцию")
	return true
func _test_harvest_pose_keeps_feet_grounded() -> bool:
	var script = load("res://game/player_actions.gd")
	for bend in [0.0, 0.4, 1.0]:
		for foot in [Vector2(50, 174), Vector2(77, 174)]:
			eq(script.pose_point(foot, bend, 1.0), foot, "операция сдвигает стопы")
	check(script.pose_point(Vector2(64, 30), 1.0, 1.0).x > 64, "голова не наклоняется к телу")
	return true
func _test_actions_survive_snapshot_and_clear_with_room() -> bool:
	var View = load("res://game/world_view.gd")
	var view = View.new()
	view.state = Arena.solo("actions-snapshots")
	view.advance(0.0)
	var actor = view.state.actor_of_slot(0)
	Organs.equip(actor, view.state.slots[0], "courier_heart")
	view.advance(0.05)
	check(view.actions.installs.has(actor.id), "вид не подключил установку")
	view.state = Arena.after_save(view.state)
	view.state.tick += 1
	view.advance(0.05)
	check(view.actions.installs.has(actor.id), "снимок прервал установку")
	view.state.room.id = "another-room"
	view.advance(0.0)
	check(view.actions.installs.is_empty(), "эффект переехал в другую комнату")
	view.free()
	return true
