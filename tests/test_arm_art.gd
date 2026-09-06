extends "res://tests/framework/test_case.gd"
## Класс: эвристика. Новый рисунок может требовать новых координат хвата.

const Pose = preload("res://game/arm_pose.gd")

func title() -> String:
	return "хват на исходном арте"


func _test_grips_land_on_the_hand_in_every_source_frame() -> bool:
	var frames: Array[String] = ["player", "player_colt_front", "player_side_stand", "player_colt_stand"]
	for i in 6:
		frames.append("player_side_walk_%d" % (i + 1))
		frames.append("player_colt_walk_%d" % (i + 1))
	var wrong := PackedStringArray()
	for frame in frames:
		var image := Image.load_from_file("res://art/%s.png" % frame)
		var palm: Vector2 = Pose.joints(frame)[2]
		var skin := 0
		for y in range(int(palm.y) - 2, int(palm.y) + 3):
			for x in range(int(palm.x) - 2, int(palm.x) + 3):
				var c := image.get_pixel(x, y)
				if c.a > 0.5 and c.r > 0.58 and c.r > c.g + 0.12 and c.g > c.b:
					skin += 1
		if skin < 6:
			wrong.append("%s: %d пикселей кожи около хвата" % [frame, skin])
	check(wrong.is_empty(), "рукоять попала мимо кисти: " + ", ".join(wrong))
	return true
