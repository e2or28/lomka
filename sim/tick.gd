extends RefCounted
## Шаг симуляции. Считает хост (правило 1), клиент шлёт команды.
##
## Функция от состояния и команд, ничего больше: ни времени системных часов,
## ни случайности сверх именованных потоков, ни обращений к узлам. Только так
## один и тот же журнал команд даёт один и тот же результат — на хосте,
## у клиента и в тесте.

const Motion = preload("res://sim/motion.gd")
const RunState = preload("res://sim/run_state.gd")
const CommandLog = preload("res://sim/input/command_log.gd")
const Command = preload("res://sim/input/command.gd")

## Шаг фиксирован: 60 тиков в секунду, как в project.godot. Плавающий шаг
## сделал бы сверку состояния между хостом и клиентом невоспроизводимой.
const DELTA := 1.0 / 60.0


## Один тик. commands — словарь «индекс слота -> Command»; слот, которого там
## нет, считается отпустившим всё, а не пропускается.
static func step(state: RunState, commands: Dictionary) -> void:
	for slot in state.slots:
		if not slot.occupied:
			continue

		var move := Vector2.ZERO
		if commands.has(slot.index):
			var command: Command = commands[slot.index]
			move = command.move_vector()

		# Упавший не ходит: он ждёт, пока поднимут.
		if slot.downed:
			move = Vector2.ZERO

		var stats := slot.stack.compute()
		slot.velocity = Motion.step_velocity(slot.velocity, move, stats, DELTA)
		slot.position = Motion.step_position(slot.position, slot.velocity, DELTA)

	state.tick += 1


## Прогнать журнал команд с начала и до последнего записанного тика.
## Основа реплей-теста и разбора рассинхрона.
static func run_log(state: RunState, journal: CommandLog, until_tick: int = -1) -> void:
	var last: int = journal.last_tick if until_tick < 0 else until_tick
	var tick := state.tick
	while tick <= last:
		step(state, journal.frame(tick))
		tick = state.tick
