extends "res://tests/framework/test_case.gd"
## Класс: поведение. Шаг меняет ноги, а не лицо, корпус и точку хвата.

const View = preload("res://game/world_view.gd")
const Arena = preload("res://tests/framework/arena.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Art = preload("res://game/art_library.gd")
const Arms = preload("res://game/character_arms.gd")
const Gait = preload("res://game/character_gait.gd")

func title() -> String:
	return "стабильность ходьбы"


func _test_upper_body_and_grip_stay_the_same_through_a_stride() -> bool:
	var view := View.new()
	var art := Art.new()
	for name in ["player_side_stand", "player_colt_walk_4"]:
		view.textures[name] = art.get_texture(name)
	for i in 6:
		for prefix in ["player_side_walk_", "player_colt_walk_"]:
			var name: String = prefix + str(i + 1)
			view.textures[name] = art.get_texture(name)
	view.state = Arena.solo("walk-art")
	var player := view.state.actor_of_slot(0)
	for weapon in ["suitcase", "colt"]:
		Arsenal.equip(player, weapon)
		player.velocity = Vector2.ZERO
		var rest: Dictionary = view._player_pose(player)
		player.velocity = Vector2(260, 0)
		var legs := {}
		for i in 6:
			view.stride_phase[player.id] = TAU * (i + 0.1) / 6.0
			var pose: Dictionary = view._player_pose(player)
			eq(pose.frame, rest.frame, "%s: шаг %d меняет лицо и плечо" % [weapon, i + 1])
			legs[pose.get("gait", "")] = true
		check(legs.size() == 6 and not legs.has(""), "цикл ног потерян: " + weapon)
	view.free()
	return true


func _test_prepared_frames_keep_identical_face_pixels_and_ground_contact() -> bool:
	var art := Art.new()
	var arms := Arms.new()
	var backing := art.get_texture("player_side_stand")
	for frame in ["player_side_stand", "player_colt_walk_4"]:
		var texture := art.get_texture(frame)
		var still: Dictionary = arms._prepare(texture, frame, backing)
		var reference: Image = still.body.get_image()
		var prefix := "player_side_walk_" if frame == "player_side_stand" else "player_colt_walk_"
		for i in 6:
			var gait: String = prefix + str(i + 1)
			var data: Dictionary = arms._prepare(texture, frame, backing, art.get_texture(gait), gait)
			var image: Image = data.body.get_image()
			bytes_eq(image.get_region(Rect2i(0, 0, 128, Gait.waist(frame))).get_data(),
				reference.get_region(Rect2i(0, 0, 128, Gait.waist(frame))).get_data(), "шаг перекрасил верх тела: " + gait)
			eq(image.get_used_rect().end.y, 175, "стопа потеряла опору: " + gait)
	return true
