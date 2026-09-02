extends "res://tests/framework/test_case.gd"
## Класс: инвариант. Не трогать: расхождение здесь — это рассинхрон в сети,
## который иначе ищут по симптомам через минуту игры.
##
## Реплей-детерминизм: один журнал команд из одного сида даёт один результат.
##
## Это заготовка под M2, сделанная на M1 сознательно. Рассинхрон в сети не
## показывает себя сразу — он проявляется через минуту игры тем, что у
## клиента враг стоит не там. Искать причину в этот момент невозможно.
## Здесь же расхождение видно на конкретном тике и на конкретном журнале.
##
## Правило 6 (ввод — поток команд) существует ровно ради этой возможности.

const RunState = preload("res://sim/run_state.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const CommandLog = preload("res://sim/input/command_log.gd")
const Motion = preload("res://sim/motion.gd")
const Encounter = preload("res://sim/encounter.gd")
const Actor = preload("res://sim/actor.gd")
const SaveGame = preload("res://sim/save/save_game.gd")

const SEED := "реплей-1"
const TICKS := 600


func title() -> String:
	return "реплей-детерминизм"


func _make_state() -> RunState:
	return Encounter.dev_room(SEED, 2, 2)


## Журнал строится из потока случайности, а не из Rand-функций: сам тест
## обязан быть воспроизводимым, иначе он краснеет через раз.
func _make_log() -> CommandLog:
	var journal := CommandLog.new()
	var source := RandomNumberGenerator.new()
	source.seed = 20260901
	for tick in TICKS:
		for slot in 2:
			var move := Vector2(
				source.randf_range(-1.0, 1.0),
				source.randf_range(-1.0, 1.0))
			var buttons := source.randi() & 15
			journal.record(slot, Command.from_axes(tick, move, Vector2.ZERO, buttons))
	return journal


func _test_same_log_same_state() -> bool:
	var journal := _make_log()

	var first := _make_state()
	SimTick.run_log(first, journal)

	var second := _make_state()
	SimTick.run_log(second, journal)

	eq(first.tick, TICKS, "симуляция прошла не столько тиков, сколько в журнале")
	eq(second.state_hash(), first.state_hash(), "два прогона одного журнала разошлись")
	bytes_eq(var_to_bytes(second.to_dict()), var_to_bytes(first.to_dict()),
		"состояния после двух прогонов не совпали побайтово")
	return true


## Прогон по одному тику должен давать то же, что прогон целиком: иначе
## пауза, кадр отладки или досылка команд по сети меняют результат.
func _test_stepwise_matches_bulk() -> bool:
	var journal := _make_log()

	var bulk := _make_state()
	SimTick.run_log(bulk, journal)

	var stepwise := _make_state()
	for tick in TICKS:
		SimTick.step(stepwise, journal.frame(tick))

	eq(stepwise.state_hash(), bulk.state_hash(), "потиковый прогон разошёлся со сплошным")
	return true


## Забег, продолженный из сейва, обязан прийти туда же, куда пришёл бы
## непрерывный. Это то самое «бросить и продолжить в другой вечер».
func _test_survives_save_in_the_middle() -> bool:
	var journal := _make_log()
	var half := TICKS / 2

	var straight := _make_state()
	SimTick.run_log(straight, journal)

	var interrupted := _make_state()
	for tick in half:
		SimTick.step(interrupted, journal.frame(tick))

	var resumed = SaveGame.from_bytes(SaveGame.to_bytes(interrupted))
	check(resumed != null, "забег не загрузился на половине")
	if resumed == null:
		return true
	for tick in range(half, TICKS):
		SimTick.step(resumed, journal.frame(tick))

	eq(resumed.state_hash(), straight.state_hash(),
		"забег, продолженный из сейва, пришёл не туда, куда непрерывный")
	return true


## Команда квантуется в целые: аналоговый стик у двух игроков не обязан
## давать одинаковый float, и это не должно разводить симуляцию.
func _test_command_quantization_is_stable() -> bool:
	# Квантование не склеивает близкий ввод — на границе шага соседние
	# значения честно расходятся на единицу. Смысл в другом: команда состоит
	# из целых, поэтому по сети она передаётся и сравнивается точно, а хост и
	# клиент считают из одной и той же команды, а не из двух похожих float.
	var a: Command = Command.from_axes(0, Vector2(0.3000001, -0.25), Vector2.ZERO)
	var b: Command = Command.from_axes(0, Vector2(0.2999998, -0.25), Vector2.ZERO)
	eq(a.to_dict(), b.to_dict(), "ввод, различающийся в седьмом знаке, дал разные команды")

	# Разброс ограничен одним шагом даже на границе.
	var edge_hi: Command = Command.from_axes(0, Vector2(0.5000001, 0), Vector2.ZERO)
	var edge_lo: Command = Command.from_axes(0, Vector2(0.4999998, 0), Vector2.ZERO)
	check(absi(edge_hi.move_x - edge_lo.move_x) <= 1,
		"на границе шага команды разошлись больше чем на единицу")

	# Одно и то же значение обязано давать одну и ту же команду всегда.
	eq(Command.from_axes(0, Vector2(0.5000001, 0), Vector2.ZERO).to_dict(),
		edge_hi.to_dict(), "одинаковый ввод дал разные команды")

	var loud: Command = Command.from_axes(0, Vector2(9.0, -9.0), Vector2.ZERO)
	eq(loud.move_x, Command.AXIS_SCALE, "ось не обрезана сверху")
	eq(loud.move_y, -Command.AXIS_SCALE, "ось не обрезана снизу")

	var pressed: Command = Command.from_axes(3, Vector2.ZERO, Vector2.ZERO,
		Command.BTN_FIRE | Command.BTN_HARVEST)
	check(pressed.pressed(Command.BTN_FIRE), "огонь не прочитался из маски")
	check(pressed.pressed(Command.BTN_HARVEST), "харвест не прочитался из маски")
	check(not pressed.pressed(Command.BTN_SKILL), "скилл прочитался, хотя не нажимался")
	return true


func _test_log_roundtrip() -> bool:
	var journal := _make_log()
	var data := journal.to_dict()
	var restored: CommandLog = CommandLog.from_dict(data)
	eq(restored.to_dict(), data, "журнал команд не пережил круг через словарь")
	eq(restored.last_tick, journal.last_tick, "последний тик журнала потерян")

	var from_original := _make_state()
	SimTick.run_log(from_original, journal)
	var from_restored := _make_state()
	SimTick.run_log(from_restored, restored)
	eq(from_restored.state_hash(), from_original.state_hash(),
		"восстановленный журнал привёл в другое состояние")
	return true


## Упавший не ходит. Проверка тут, а не в тесте движения, потому что это
## правило симуляции, а не математики.
func _test_downed_slot_does_not_move() -> bool:
	var state := _make_state()
	state.slots[1].downed = true
	var started_at: Vector2 = state.actor_of_slot(1).position
	var journal := CommandLog.new()
	for tick in 60:
		journal.record(0, Command.from_axes(tick, Vector2(1, 0), Vector2.ZERO))
		journal.record(1, Command.from_axes(tick, Vector2(1, 0), Vector2.ZERO))
	SimTick.run_log(state, journal)

	check(state.actor_of_slot(0).position.x > started_at.x + 1.0, "живой слот не сдвинулся")
	almost_eq(state.actor_of_slot(1).position.x, started_at.x, "упавший слот уехал", 1e-6)
	return true
