extends "res://tests/framework/test_case.gd"
## Класс: поведение. Общая трансформация не даёт оружию оторваться от руки.

const Pose = preload("res://game/arm_pose.gd")
const CharacterPose = preload("res://game/character_pose.gd")

func title() -> String:
	return "руки и хват"


func _test_grip_follows_animated_hand_in_both_directions() -> bool:
	var errors := PackedStringArray()
	for weapon in ["colt", "suitcase"]:
		for step in 7:
			var frame: String = CharacterPose.stand_names(weapon)[0] if step == 0 else CharacterPose.walk_frame_names(weapon, step - 1)[0]
			if weapon == "suitcase" and step > 0:
				frame = CharacterPose.walk_frame_names("", step - 1)[0]
			for side in [-1, 1]:
				for progress in [-1.0, 0.0, 0.18, 0.5, 1.0]:
					var motion := Pose.motion(frame, weapon, 1.3, 260.0, progress)
					var grip := CharacterPose.weapon_offset(weapon, Vector2(26, 18), false)
					var attachment := Pose.weapon_transform(frame, motion, grip, side, weapon)
					var hand := Pose.hand(frame, motion)
					if side < 0:
						hand.x = 128.0 - hand.x
					if (attachment * grip).distance_to(hand) > 0.0001:
						errors.append("%s side=%d progress=%.2f" % [frame, side, progress])
	check(errors.is_empty(), "рукоять оторвалась: " + ", ".join(errors))
	return true


func _test_hand_moves_fully_while_shoulder_stays_anchored() -> bool:
	var wrong := PackedStringArray()
	for weapon in ["colt", ""]:
		for step in 6:
			var frame: String = CharacterPose.walk_frame_names(weapon, step)[0]
			var palm: Vector2 = Pose.joints(frame)[2]
			if Pose.arm_weight(palm, frame) < 0.999 or Pose.arm_weight(Pose.joints(frame)[0], frame) > 0.0:
				wrong.append(frame)
	check(wrong.is_empty(), "плечо потеряло опору или кисть отстала от оружия: " + ", ".join(wrong))
	return true


func _test_recoil_goes_back_and_throw_goes_forward() -> bool:
	var gun_frame := "player_colt_walk_1"
	var gun := Pose.hand(gun_frame, Pose.motion(gun_frame, "colt", 0, 0, 0.18))
	check(gun.x < Pose.hand(gun_frame, Transform2D.IDENTITY).x, "отдача толкает пистолет вперёд")
	var case_frame := "player_side_stand"
	var thrown := Pose.hand(case_frame, Pose.motion(case_frame, "suitcase", 0, 0, 0.18))
	check(thrown.x > Pose.hand(case_frame, Transform2D.IDENTITY).x, "бросок уходит за спину")
	return true


func _test_lowered_colt_recoils_against_its_barrel() -> bool:
	for frame in ["player_colt_front", "player_side_stand"]:
		var resting := Pose.hand(frame, Transform2D.IDENTITY)
		var recoil := Pose.hand(frame, Pose.motion(frame, "colt", 0, 0, 0.18))
		check(recoil.y < resting.y, "опущенный кольт отдаёт по направлению ствола: " + frame)
	return true


func _test_motion_returns_without_a_snap() -> bool:
	almost_eq(Pose.pulse(0), 0, "выстрел начинается со скачка")
	almost_eq(Pose.pulse(1), 0, "рука не вернулась")
	check(Pose.pulse(0.18) > 0.99, "нет акцента атаки")
	check(Pose.pulse(0.999) < 0.001, "конец отдачи обрывается")
	return true
