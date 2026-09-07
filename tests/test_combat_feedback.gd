extends "res://tests/framework/test_case.gd"
## Класс: поведение. Эффекты конечны, не двигают симуляцию и переживают исчезновение снаряда.

const Feedback = preload("res://game/combat_feedback.gd")
const View = preload("res://game/world_view.gd")
const Arena = preload("res://tests/framework/arena.gd")
const Tick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Save = preload("res://sim/save/save_game.gd")

func title() -> String:
	return "отклик боя"


func _test_paper_pushes_more_and_recovers_slower_than_bullet() -> bool:
	var f := Feedback.new()
	for pair in [[1, "bullet"], [2, "folder"]]:
		f.hit({"actor_id": pair[0], "kind": pair[1], "direction": Vector2.RIGHT, "fallen": false}, Vector2.ZERO)
	f.advance(0.08)
	check(f.offset(2).length() > f.offset(1).length(), "папка ощущается слабее пули")
	f.advance(0.10)
	eq(f.offset(1), Vector2.ZERO, "пуля слишком долго трясёт цель")
	check(f.offset(2).x > 0, "тяжёлый удар завершился раньше лёгкого")
	f.advance(1.0)
	eq(f.hits.size(), 0, "зависло состояние удара")
	eq(f.impacts.size(), 0, "частицы не закончились")
	return true


func _test_point_blank_hit_reaches_view_without_changing_save() -> bool:
	var state := Arena.duel("view", "runner", Vector2(25, 0))
	Arsenal.equip(state.actor_of_slot(0), "colt")
	var events := Tick.step(state, {0: Command.from_axes(0, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)})
	var view := View.new()
	view.state = state
	var before := Save.to_bytes(state)
	view.consume_events(events)
	check(view.feedback.shots.has(state.actor_of_slot(0).id), "пропущена вспышка ближнего выстрела")
	check(not view.feedback.impacts.is_empty(), "попадание пропало вместе со снарядом")
	view.advance(0.08)
	bytes_eq(Save.to_bytes(state), before, "эффект изменил игровой мир")
	view.free()
	return true


func _test_launch_offset_does_not_follow_shooter_after_firing() -> bool:
	var f := Feedback.new()
	f.shot({"actor_id": 1, "projectile_id": 9, "position": Vector2(10, 20), "kind": "bullet"}, Vector2(35, -60))
	var offset: Vector2 = f.projectile_offsets[9]
	f.shot({"actor_id": 1, "projectile_id": 10, "position": Vector2(200, 30), "kind": "folder"}, Vector2(210, -20))
	f.advance(1)
	eq(f.projectile_offsets[9], offset, "смена оружия сдвинула уже летящую пулю")
	eq(f.shots.size(), 0, "зависла вспышка выстрела")
	return true


func _test_old_room_events_are_discarded() -> bool:
	var view := View.new()
	view.state = Arena.solo("room-clear")
	view.consume_events([{"type": "shot", "room_id": "previous-room"}])
	eq(view.feedback.shots.size(), 0, "выстрел старой комнаты появился в новой")
	view.free()
	return true


func _test_fall_direction_survives_the_hit_flash() -> bool:
	var f := Feedback.new()
	f.hit({"actor_id": 1, "kind": "bullet", "direction": Vector2.LEFT, "fallen": true}, Vector2.ZERO)
	f.advance(1.0)
	eq(f.hits.size(), 0, "вспышка не закончилась")
	eq(f.falls[1].direction, Vector2.LEFT, "тело перевернулось после вспышки")
	almost_eq(f.fall_progress(1), 1.0, "падение не завершилось")
	return true


func _test_view_uses_muzzle_for_launch_and_freezes_it_after_turning() -> bool:
	var state := Arena.solo("muzzle")
	var player := state.actor_of_slot(0)
	player.position = Vector2.ZERO
	Arsenal.equip(player, "colt")
	var view := View.new()
	view.state = state
	for name in ["player_colt_walk_4", "player_side_stand"]:
		view.textures[name] = ImageTexture.create_from_image(Image.load_from_file("res://art/" + name + ".png"))
	var events := Tick.step(state, {0: Command.from_axes(0, Vector2.ZERO, Vector2.UP, Command.BTN_FIRE)})
	view.consume_events(events)
	var id := state.projectiles[0].id
	var at: Vector2 = view.feedback.projectile_offsets[id]
	check(at.y < -100, "вертикальная пуля появилась на общей высоте вместо поднятого дула")
	player.aim = Vector2.DOWN
	Arsenal.equip(player, "suitcase")
	view.advance(0.06)
	eq(view.feedback.projectile_offsets[id], at, "пуля последовала за новой позой или оружием")
	var pose := view._player_pose(player)
	eq(pose.aim, Vector2.ZERO, "выстрел кольта запустил бросок нового чемодана")
	view.free()
	return true
