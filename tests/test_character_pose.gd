extends "res://tests/framework/test_case.gd"
## Класс: поведение. Придёт настоящая анимация — ожидания уедут вместе
## с ней. Не проверяется, красиво ли: размах, темп и вес подбирает человек.

const Pose = preload("res://game/character_pose.gd")

const WALK := 260.0


func title() -> String:
	return "поза персонажа"


func _test_standing_still_does_not_swing() -> bool:
	var angles := Pose.arm_angles(1.2, 0.0, -1.0, true)
	almost_eq(angles[0], 0.0, "левая рука машет на месте", 1e-6)
	almost_eq(angles[1], 0.0, "правая рука машет на месте", 1e-6)
	return true


func _test_stride_follows_distance_not_time() -> bool:
	var slow := Pose.advance_stride(0.0, 60.0, 1.0)
	var fast := Pose.advance_stride(0.0, 120.0, 0.5)
	almost_eq(slow, fast, "одинаковый путь дал разную фазу", 1e-6)

	eq(Pose.advance_stride(0.7, 0.0, 1.0), 0.7, "фаза сдвинулась при нулевой скорости")
	eq(Pose.advance_stride(0.7, Pose.WALK_THRESHOLD - 1.0, 1.0), 0.7,
		"фаза сдвинулась от дрожания ниже порога ходьбы")
	return true


func _test_stride_stays_in_range() -> bool:
	var phase := 0.0
	var out_of_range := 0
	for i in 500:
		phase = Pose.advance_stride(phase, WALK, 1.0 / 60.0)
		if phase < 0.0 or phase >= TAU:
			out_of_range += 1
	eq(out_of_range, 0, "фаза вышла за оборот — синус поедет на длинной дистанции")
	return true


func _test_running_arms_are_opposed() -> bool:
	var seen_left_forward := false
	var seen_right_forward := false
	for step in 16:
		var phase := TAU * step / 16.0
		var angles := Pose.arm_angles(phase, WALK, -1.0, true)
		almost_eq(angles[0], -angles[1], "руки на бегу не в противофазе", 1e-6)
		if angles[0] > 0.1:
			seen_left_forward = true
		if angles[1] > 0.1:
			seen_right_forward = true
	check(seen_left_forward and seen_right_forward, "какая-то из рук ни разу не пошла вперёд")
	return true


func _test_swing_amplitude_is_bounded() -> bool:
	var peak := 0.0
	for step in 64:
		var angles := Pose.arm_angles(TAU * step / 64.0, WALK, -1.0, true)
		peak = maxf(peak, absf(angles[0]))
	almost_eq(peak, Pose.ARM_SWING, "размах маха разошёлся с заданным", 0.01)
	return true


func _test_throw_happens_only_right_after_the_shot() -> bool:
	var rate := 3.5
	var period := 1.0 / rate

	eq(Pose.throw_progress(period, rate), 0.0, "бросок не начался в момент выстрела")
	check(Pose.throw_progress(period - Pose.THROW_TIME * 0.5, rate) > 0.4,
		"бросок не идёт в середине своего времени")
	eq(Pose.throw_progress(period - Pose.THROW_TIME * 2.0, rate), -1.0,
		"бросок тянется дольше отведённого")
	eq(Pose.throw_progress(0.0, rate), -1.0, "бросок идёт при отсутствии перезарядки")
	eq(Pose.throw_progress(period, 0.0), -1.0, "бросок идёт при нулевой скорострельности")
	return true


func _test_throw_overrides_the_swing() -> bool:
	var running := Pose.arm_angles(1.0, WALK, -1.0, true)
	var throwing := Pose.arm_angles(1.0, WALK, 0.5, true)
	check(absf(throwing[1]) > absf(running[1]) + 0.3,
		"бросок не перебил мах: было %.2f, стало %.2f" % [running[1], throwing[1]])

	var left_throw := Pose.arm_angles(1.0, WALK, 0.5, false)
	check(absf(left_throw[0]) > absf(running[0]) + 0.3, "левой рукой бросок не работает")
	return true


func _test_idle_breathes() -> bool:
	var lowest := 0.0
	var highest := 0.0
	for step in 60:
		var offset := Pose.head_offset(0.0, 0.0, Pose.IDLE_PERIOD * step / 60.0)
		lowest = minf(lowest, offset.y)
		highest = maxf(highest, offset.y)
	check(highest - lowest > 0.1, "в покое голова не двигается вовсе")
	check(highest - lowest <= Pose.IDLE_BREATH + 0.01,
		"дыхание в покое слишком размашистое: %.2f" % (highest - lowest))
	return true


func _test_body_bobs_twice_per_cycle() -> bool:
	var peaks := 0
	var previous := 0.0
	var current := Pose.body_offset(0.0, WALK, 0.0).y
	for step in range(1, 121):
		var phase := TAU * step / 120.0
		var next := Pose.body_offset(phase, WALK, 0.0).y
		if current < previous and current < next:
			peaks += 1
		previous = current
		current = next
	eq(peaks, 2, "корпус подбрасывает не дважды за цикл шага")
	return true


func _test_head_lags_behind_the_body() -> bool:
	var differs := false
	for step in 24:
		var phase := TAU * step / 24.0
		if absf(Pose.head_offset(phase, WALK, 0.0).y - Pose.body_offset(phase, WALK, 0.0).y) > 0.05:
			differs = true
	check(differs, "голова повторяет корпус в точности — шея не читается")
	return true


func _test_walk_frame_covers_the_whole_cycle() -> bool:
	var seen := {}
	for step in 60:
		seen[Pose.walk_frame(TAU * step / 60.0)] = true
	eq(seen.size(), Pose.WALK_FRAMES, "цикл ходьбы использует не все кадры")

	var out_of_range := 0
	for step in 200:
		var frame := Pose.walk_frame(TAU * step / 37.0)
		if frame < 0 or frame >= Pose.WALK_FRAMES:
			out_of_range += 1
	eq(out_of_range, 0, "номер кадра вышел за набор")
	return true


func _test_walk_frame_advances_in_order() -> bool:
	eq(Pose.walk_frame(0.0), 0, "цикл начинается не с первого кадра")
	check(Pose.walk_frame(TAU * 0.5) > Pose.walk_frame(TAU * 0.1),
		"кадры идут не по порядку")
	eq(Pose.walk_frame(TAU - 0.001), Pose.WALK_FRAMES - 1, "последний кадр не достигается")
	return true


func _test_facing_holds_until_direction_changes() -> bool:
	eq(Pose.facing(Vector2(200, 0), -1), 1, "движение вправо не развернуло")
	eq(Pose.facing(Vector2(-200, 0), 1), -1, "движение влево не развернуло")
	eq(Pose.facing(Vector2(0, 200), 1), 1, "вертикальное движение сбросило направление")
	eq(Pose.facing(Vector2.ZERO, -1), -1, "остановка сбросила направление")
	eq(Pose.facing(Vector2(Pose.WALK_THRESHOLD - 1.0, 0), 1), 1,
		"дрожание ниже порога развернуло персонажа")
	return true


func _test_profile_only_while_moving() -> bool:
	check(Pose.use_walk_frames(WALK), "в движении не берутся кадры ходьбы")
	check(not Pose.use_walk_frames(0.0), "в покое берутся кадры ходьбы вместо анфаса")
	check(not Pose.use_walk_frames(Pose.WALK_THRESHOLD - 1.0),
		"дрожание ниже порога включает ходьбу")
	return true


func _test_aim_wins_over_movement_while_firing() -> bool:
	eq(Pose.aiming_facing(Vector2.LEFT, Vector2(300, 0), true, 1), -1,
		"стреляя влево на бегу вправо, персонаж смотрит вправо")
	eq(Pose.aiming_facing(Vector2.RIGHT, Vector2(-300, 0), true, -1), 1,
		"стреляя вправо на бегу влево, персонаж смотрит влево")
	return true


func _test_movement_decides_when_not_firing() -> bool:
	eq(Pose.aiming_facing(Vector2.LEFT, Vector2(300, 0), false, -1), 1,
		"без стрельбы направление берётся не от движения")
	eq(Pose.aiming_facing(Vector2.ZERO, Vector2.ZERO, false, -1), -1,
		"в покое направление не сохранилось")
	return true


func _test_vertical_aim_does_not_turn_the_body() -> bool:
	eq(Pose.aiming_facing(Vector2.UP, Vector2.ZERO, true, 1), 1,
		"прицел вверх развернул тело")
	eq(Pose.aiming_facing(Vector2.DOWN, Vector2.ZERO, true, -1), -1,
		"прицел вниз развернул тело")
	return true


func _test_snap_aim_quantises_to_eight() -> bool:
	var snapped := Pose.snap_aim(Vector2(1.0, 0.15).normalized(), 8)
	almost_eq(snapped.angle(), 0.0, "почти горизонтальный прицел не притянулся к оси", 1e-5)

	var diagonal := Pose.snap_aim(Vector2(1.0, 0.9).normalized(), 8)
	almost_eq(diagonal.angle(), PI / 4.0, "прицел под 45 градусов не притянулся к диагонали", 1e-5)

	var seen := {}
	for step in 64:
		var angle := TAU * step / 64.0
		var result := Pose.snap_aim(Vector2.RIGHT.rotated(angle), 8)
		seen[snappedf(fposmod(result.angle(), TAU), 0.0001)] = true
		almost_eq(result.length(), 1.0, "притянутый прицел не единичной длины", 1e-5)
	eq(seen.size(), 8, "получилось не восемь направлений")
	return true


func _test_snap_aim_keeps_zero_zero() -> bool:
	eq(Pose.snap_aim(Vector2.ZERO, 8), Vector2.ZERO, "нулевой прицел превратился в направление")
	var free := Vector2(1.0, 0.15).normalized()
	eq(Pose.snap_aim(free, 0), free, "при нуле направлений прицел всё равно притянулся")
	return true


func _test_walk_frames_follow_the_weapon() -> bool:
	var colt := Pose.walk_frame_names("colt", 2)
	eq(colt.size(), 2, "у оружия со своим набором нет запасного варианта")
	eq(colt[0], "player_colt_walk_3", "свой набор кадров назван не так")
	eq(colt[1], "player_side_walk_3", "запасным набором оказался не базовый")

	var bare := Pose.walk_frame_names("", 2)
	eq(bare.size(), 1, "у безоружного набор кадров не один")
	eq(bare[0], "player_side_walk_3", "безоружный ходит не базовым набором")
	return true


func _test_stand_frame_follows_the_weapon() -> bool:
	var colt := Pose.stand_names("colt")
	eq(colt[0], "player_colt_stand", "стойка с кольтом названа не так")
	eq(colt[1], "player_side_stand", "запасной стойкой оказалась не базовая")
	eq(Pose.stand_names("")[0], "player_side_stand", "безоружный стоит не базовой стойкой")
	return true


## Файлы на диске называются player_side_walk_1..6, а кадры внутри
## считаются с нуля.
func _test_frame_numbering_starts_at_one() -> bool:
	eq(Pose.walk_frame_names("colt", 0)[0], "player_colt_walk_1", "первый кадр назван не так")
	eq(Pose.walk_frame_names("colt", Pose.WALK_FRAMES - 1)[0], "player_colt_walk_6",
		"последний кадр назван не так")
	return true


func _test_weapon_hangs_by_its_grip() -> bool:
	var size := Vector2(19.0, 12.0)
	eq(Pose.weapon_offset("colt", size, false), Vector2(4.0, 6.0),
		"кольт совмещается с кистью не рукоятью")
	eq(Pose.weapon_offset("suitcase", size, false), size * 0.5,
		"оружие без заданной рукояти перестало совмещаться по центру")
	return true


func _test_mirrored_grip_moves_with_the_sprite() -> bool:
	var size := Vector2(19.0, 12.0)
	var straight := Pose.weapon_offset("colt", size, false)
	var mirrored := Pose.weapon_offset("colt", size, true)
	almost_eq(straight.x + mirrored.x, size.x,
		"зеркальная рукоять не симметрична исходной")
	almost_eq(straight.y, mirrored.y, "рукоять при отражении переехала по высоте")
	return true
