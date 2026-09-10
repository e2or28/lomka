extends "res://tests/framework/test_case.gd"
## Класс: инвариант. Клиент управляет только назначенным слотом и не ускоряет тик.

const Buffer = preload("res://game/network_input.gd")
const Prediction = preload("res://game/network_prediction.gd")
const Command = preload("res://sim/input/command.gd")
const Arena = preload("res://tests/framework/arena.gd")

func title() -> String:
	return "сетевой ввод"

func _test_input_limits_order_and_duplicates() -> bool:
	var input = Buffer.new()
	check(not input.submit(0, 0, 0, 0, 0, 0), "нулевой номер принят")
	check(not input.submit(1, 128, 0, 0, 0, 0), "ось вне диапазона принята")
	check(not input.submit(1, 0, 0, 0, 0, 16), "чужая кнопка принята")
	check(input.submit(1, 127, 0, 0, 0, 0), "первый ввод потерян")
	check(not input.submit(1, -127, 0, 0, 0, 0), "дубликат переписал команду")
	check(input.submit(2, 0, 127, 0, 0, 0), "второй ввод потерян")
	eq(input.take(42).move_vector(), Vector2.RIGHT, "порядок команд изменился")
	eq(input.acknowledged, 1, "подтверждено неприменённое")
	eq(input.take(43).move_vector(), Vector2.DOWN, "за один тик вычерпана очередь")
	eq(input.acknowledged, 2, "не подтверждено применённое")
	for i in 20: input.take(44 + i)
	eq(input.take(64).buttons, 0, "потерянный клиент удерживает кнопку")
	eq(input.take(65).move_vector(), Vector2.ZERO, "потерянный клиент продолжает движение")
	return true

func _test_prediction_replays_only_unconfirmed_movement() -> bool:
	var state = Arena.solo("prediction")
	var player = state.actor_of_slot(0)
	player.position = Vector2.ZERO
	var predictor = Prediction.new()
	var cmd = Command.from_axes(0, Vector2.RIGHT, Vector2.ZERO)
	predictor.push(1, cmd)
	predictor.push(2, cmd)
	predictor.reconcile(state, 0, 1, "")
	check(player.position.x > 0, "непринятый ввод не предсказан")
	check(player.position.x < 5, "подтвержденный ввод применён повторно")
	eq(predictor.pending.size(), 1, "подтверждение не очистило историю")
	state.slots[0].downed = true
	var before = player.position
	predictor.advance(state, 0, cmd)
	eq(player.position, before, "упавший двигается по предсказанию")
	return true

func _test_input_recovers_after_a_burst_overflows_the_queue() -> bool:
	var input = Buffer.new()
	for sequence in range(1, 242): input.submit(sequence, 127, 0, 0, 0, 0)
	eq(input.queue.size(), Buffer.LIMIT, "всплеск превысил предел памяти")
	for tick in Buffer.LIMIT: input.take(tick)
	check(input.submit(242, -127, 0, 0, 0, 0), "переполнение навсегда заблокировало управление")
	eq(input.take(300).move_vector(), Vector2.LEFT, "новое направление потеряно после всплеска")
	eq(input.acknowledged, 242, "клиент не узнал о восстановлении")
	check(not input.submit(2147483648, 0, 0, 0, 0, 0), "номер вне диапазона принят")
	return true

func _test_old_movement_does_not_leave_a_permanent_network_delay() -> bool:
	var input = Buffer.new()
	for sequence in range(1, 61): input.submit(sequence, 127, 0, 0, 0, 0)
	input.take(0)
	check(input.acknowledged >= 58, "старый ввод сохранил секундную задержку")
	check(input.queue.size() <= 2, "очередь не сократилась после сетевой паузы")
	input.submit(61, -127, 0, 0, 0, 0)
	for tick in range(1, 3): input.take(tick)
	eq(input.take(3).move_vector(), Vector2.LEFT, "новый поворот застрял за устаревшим вводом")
	return true
