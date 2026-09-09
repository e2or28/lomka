extends "res://tests/framework/test_case.gd"
## Класс: поведение. Видимая траектория попадает в тело, а не в круг у ног.

const Arena = preload("res://tests/framework/arena.gd")
const Projectile = preload("res://sim/projectile.gd")
const Tick = preload("res://sim/tick.gd")
const View = preload("res://game/world_view.gd")
const Art = preload("res://game/art_library.gd")

func title() -> String:
	return "попадания в силуэт"


func _test_visible_bullet_crossing_upper_body_hits_every_enemy() -> bool:
	for id in ["test_monster", "runner", "heavy", "tandem"]:
		var state := Arena.duel("visible-hit", id, Vector2(240, -50))
		var enemy := Arena.enemies(state)[0]
		var shot: Projectile = Projectile.spawn(state.take_id(), state.actor_of_slot(0), Vector2.RIGHT,
			{"damage": 10.0, "projectile_speed": 12000.0, "range": 1500.0}, "bullet")
		var events: Array[Dictionary] = []
		var health := enemy.health
		# Горизонтальная пуля видна на y=-85, тело цели занимает y=-138..-50.
		var spent := Tick._hit_segment(state, shot, Vector2.ZERO, Vector2(400, 0), events)
		check(spent and enemy.health < health, "пуля прошла через верх тела: " + id)
	return true


func _test_tank_hull_hits_on_both_sides_beyond_the_old_circle() -> bool:
	for direction in [Vector2.LEFT, Vector2.RIGHT]:
		var state := Arena.duel("tank-edge", "tandem", Vector2.ZERO)
		var tank := Arena.enemies(state)[0]
		tank.aim = direction
		var x := -220.0 if direction.x < 0 else 220.0
		var shot: Projectile = Projectile.spawn(state.take_id(), state.actor_of_slot(0), Vector2.DOWN,
			{"damage": 10.0, "projectile_speed": 12000.0, "range": 1500.0}, "")
		var events: Array[Dictionary] = []
		check(Tick._hit_segment(state, shot, Vector2(x, -100), Vector2(x, 60), events),
			"край корпуса танка не принимает снаряд: " + str(direction))
	return true


func _test_empty_space_above_tank_barrel_does_not_count_as_body() -> bool:
	var state := Arena.duel("tank-gap", "tandem", Vector2.ZERO)
	var tank := Arena.enemies(state)[0]
	tank.aim = Vector2.LEFT
	var shot: Projectile = Projectile.spawn(state.take_id(), state.actor_of_slot(0), Vector2.RIGHT,
		{"damage": 10.0, "projectile_speed": 12000.0, "range": 1500.0}, "")
	var events: Array[Dictionary] = []
	check(not Tick._hit_segment(state, shot, Vector2(-290, -160), Vector2(-160, -160), events),
		"пустота над стволом оказалась частью тела")
	return true


func _test_rendered_muzzle_and_authoritative_launch_match_in_all_stances() -> bool:
	var view := View.new()
	var art := Art.new()
	for name in ["player", "player_side_stand", "player_colt_walk_4"]:
		view.textures[name] = art.get_texture(name)
	view.state = Arena.solo("muzzle-geometry")
	var actor := view.state.actor_of_slot(0)
	var errors := PackedStringArray()
	var arms = load("res://game/arm_pose.gd")
	var character = load("res://game/character_pose.gd")
	for weapon in ["colt", "suitcase"]:
		actor.weapon_id = weapon
		for side in [-1, 1]:
			actor.facing = side
			for front in [false, true]:
				actor.standing_front = front
				for speed in [0, 260]:
					actor.velocity = Vector2(speed * side, 0)
					for aim in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
						var kind := "bullet" if weapon == "colt" else "folder"
						var shot: Projectile = Projectile.spawn(999, actor, aim, {}, kind)
						var pose: Dictionary = view._player_pose(actor, aim, weapon, 0.0)
						var muzzle: Vector2 = arms.emission(pose.frame, pose.motion, weapon,
							character.weapon_offset(weapon, Vector2.ZERO, false), pose.side, aim) - View.PLAYER_ROOT
						if muzzle.distance_to(shot.projection_offset) > 0.01:
							errors.append("%s side=%d front=%s speed=%d aim=%s" % [weapon, side, front, speed, aim])
	check(errors.is_empty(), "траектория разошлась с дулом/кистью: " + ", ".join(errors))
	view.free()
	return true


func _test_visible_sweeps_hit_in_all_four_directions() -> bool:
	var errors := PackedStringArray()
	for id in ["runner", "heavy", "tandem"]:
		for kind in ["bullet", "folder"]:
			for aim in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				var state := Arena.duel("four-hit-directions", id, Vector2(240, 0))
				var enemy := Arena.enemies(state)[0]
				var shot: Projectile = Projectile.spawn(state.take_id(), state.actor_of_slot(0), aim,
					{"damage": 10.0, "projectile_speed": 12000.0, "range": 1500.0}, kind)
				var center: Vector2 = enemy.position + Vector2(0, -44)
				var from: Vector2 = center - aim * 180 - shot.flight_offset()
				var to: Vector2 = center + aim * 180 - shot.flight_offset()
				var events: Array[Dictionary] = []
				if not Tick._hit_segment(state, shot, from, to, events):
					errors.append("%s %s %s" % [id, kind, aim])
	check(errors.is_empty(), "видимое пересечение не нанесло урона: " + ", ".join(errors))
	return true


func _test_save_and_shooter_turn_do_not_move_an_existing_trajectory() -> bool:
	var state := Arena.solo("saved-flight")
	var arsenal = load("res://sim/arsenal.gd")
	arsenal.equip(state.actor_of_slot(0), "colt")
	Arena.hold(state, 3, Vector2.LEFT)
	var shot := Arena.shoot(state, Vector2.UP)
	if not check(shot != null, "нет снаряда для проверки сейва"):
		return true
	var loaded := Arena.after_save(state)
	var restored = loaded.projectiles[0]
	eq(restored.projection_offset, shot.projection_offset, "сейв сдвинул траекторию")
	eq(loaded.actor_of_slot(0).facing, -1, "сейв забыл сторону стрелка")
	arsenal.equip(loaded.actor_of_slot(0), "suitcase")
	loaded.actor_of_slot(0).facing = 1
	loaded.actor_of_slot(0).aim = Vector2.DOWN
	var view := View.new()
	view.state = loaded
	view.advance(0.1)
	eq(view._projectile_at(restored), shot.position + shot.flight_offset(),
		"после загрузки картинка полетела по новой позе стрелка")
	view.free()
	return true


func _test_fast_piercing_shot_hits_nearest_bodies_once() -> bool:
	var state := Arena.duel("fast-pierce", "runner", Vector2(240, 0))
	var encounter = load("res://sim/encounter.gd")
	var near = encounter.add_enemy(state, "runner", Vector2(120, 0))
	var shot: Projectile = Projectile.spawn(state.take_id(), state.actor_of_slot(0), Vector2.RIGHT,
		{"damage": 10.0, "projectile_speed": 24000.0, "range": 1500.0, "pierce": 1.0}, "bullet")
	state.projectiles.append(shot)
	var events: Array[Dictionary] = []
	Tick._fly_projectiles(state, events)
	eq(events.size(), 2, "быстрый пробивающий снаряд пропустил цель или ударил дважды")
	if events.size() == 2:
		eq(events[0].actor_id, near.id, "ближняя цель получила урон после дальней")
	eq(state.projectiles.size(), 0, "после двух попаданий пробитие не закончилось")
	return true
