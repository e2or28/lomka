extends RefCounted
## Шаг симуляции. Считает хост (правило 1), клиент шлёт команды.
##
## Функция от состояния и команд, ничего больше: ни системных часов, ни
## случайности сверх именованных потоков, ни обращений к узлам. Только так
## один и тот же журнал команд даёт один и тот же результат — на хосте,
## у клиента и в тесте.
##
## Порядок фаз внутри тика зафиксирован и менять его нельзя без причины:
## от него зависит, попал снаряд до или после того, как цель сдвинулась,
## а значит и весь исход боя. Обход тел идёт по массиву, то есть по
## возрастанию идентификатора, а не по порядку появления в памяти.

const Motion = preload("res://sim/motion.gd")
const RunState = preload("res://sim/run_state.gd")
const CommandLog = preload("res://sim/input/command_log.gd")
const Command = preload("res://sim/input/command.gd")
const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")
const Arsenal = preload("res://sim/arsenal.gd")

## Шаг фиксирован: 60 тиков в секунду, как в project.godot. Плавающий шаг
## сделал бы сверку состояния между хостом и клиентом невоспроизводимой.
const DELTA := 1.0 / 60.0

## Половина ширины тела. Одна на всех, пока тела одного размера.
##
## Уже силуэта намеренно: спрайт 47 пикселей в плечах, а хитбокс 16 — так
## прощаются касания краем, и это часть ощущения, которую настраивает
## человек, а не формула.
const BODY_RADIUS := 16.0

## Неуязвимость после удара касанием. Без неё враг, стоящий вплотную,
## снимает урон каждый тик и убивает за треть секунды.
##
## Она даётся только игрокам и только от касания. Врагам её давать нельзя:
## период перезарядки короче кадров неуязвимости, поэтому каждый следующий
## снаряд продлевал бы её, и враг под плотным огнём становился бессмертным.
## Это уже случилось — тест «враг пережил четыре секунды обстрела в упор»
## написан именно про это.
const HIT_INVULNERABILITY := 0.4

## Насколько близко враг должен подойти, чтобы ударить касанием.
const TOUCH_RANGE := 40.0

## Курьер: сколько тиков длится полный цикл «налетел — отошёл» и с какой
## дистанции он начинает пятиться.
const HARRIER_PERIOD := 96
const HARRIER_BACKOFF := 120.0


static func step(state: RunState, commands: Dictionary) -> void:
	_drive_players(state, commands)
	_drive_enemies(state)
	_move_bodies(state)
	_fly_projectiles(state)
	_touch_damage(state)
	_tick_timers(state)
	_collect_dead(state)
	state.tick += 1


## Игроки: ввод превращается в намерение. Ни одно решение здесь не
## принимается клиентом — сюда приходит уже разобранная команда.
static func _drive_players(state: RunState, commands: Dictionary) -> void:
	for slot in state.slots:
		if not slot.occupied:
			continue
		var actor := state.actor_by_id(slot.actor_id)
		if actor == null or not actor.alive:
			continue

		var move := Vector2.ZERO
		var aim := Vector2.ZERO
		var firing := false
		if commands.has(slot.index):
			var command: Command = commands[slot.index]
			move = command.move_vector()
			aim = command.aim_vector()
			firing = command.pressed(Command.BTN_FIRE)

		# Упавший не ходит и не стреляет: он ждёт, пока поднимут.
		if slot.downed:
			move = Vector2.ZERO
			firing = false

		if aim != Vector2.ZERO:
			actor.aim = aim.normalized()

		var stats := actor.stack.compute()
		actor.velocity = Motion.step_velocity(actor.velocity, move, stats, DELTA)

		if firing and actor.cooldown <= 0.0:
			_fire(state, actor, stats)


## Враги: простейшее поведение — идти к ближайшему стоящему игроку.
##
## Разброс движения должен браться из потока AI_SPREAD, когда поведение
## станет сложнее. Пока движение строго детерминировано и случайности не
## требует — лишний бросок сдвинул бы поток и рассинхронизировал забег.
static func _drive_enemies(state: RunState) -> void:
	for actor in state.actors:
		if not actor.alive or actor.kind != Actor.Kind.ENEMY:
			continue
		var target := _nearest_target(state, actor)
		var move := Vector2.ZERO
		if target != null:
			var offset := target.position - actor.position
			if offset != Vector2.ZERO:
				actor.aim = offset.normalized()
			move = _behaviour_move(actor, offset, state.tick)
		var stats := actor.stack.compute()
		actor.velocity = Motion.step_velocity(actor.velocity, move, stats, DELTA)


## Куда враг хочет идти. Разбор повадки вынесен сюда, чтобы четвёртый тип
## стоил одной ветки, а не нового файла.
##
## Случайности здесь нет намеренно. Разброс должен браться из потока
## AI_SPREAD, а лишний бросок сдвигает поток и рассинхронизирует забег —
## поэтому все три повадки детерминированы от расстояния и номера тика.
static func _behaviour_move(actor, offset: Vector2, tick: int) -> Vector2:
	var distance := offset.length()
	if distance <= 0.001:
		return Vector2.ZERO
	var towards := offset / distance

	match actor.behaviour:
		"harrier":
			# Налетает и отходит: держаться на дистанции удара не даёт
			# отстреливаться стоя.
			var cycle := (tick % HARRIER_PERIOD) < HARRIER_PERIOD / 2
			if distance < HARRIER_BACKOFF and not cycle:
				return -towards
			if distance > TOUCH_RANGE * 0.5:
				return towards
			return Vector2.ZERO

		"bruiser":
			# Идёт напролом и не останавливается вплотную: давит массой.
			return towards

		_:
			# charger: подошёл на удар — встал.
			if distance > TOUCH_RANGE * 0.5:
				return towards
			return Vector2.ZERO


## Ближайший стоящий игрок. Упавшего враги не добивают — его поднимают
## товарищи, и добивание сделало бы подъём невозможным.
static func _nearest_target(state: RunState, hunter) -> Actor:
	var best: Actor = null
	var best_distance := INF
	for actor in state.actors:
		if not actor.alive or actor.kind != Actor.Kind.PLAYER:
			continue
		if actor.slot >= 0 and state.slots[actor.slot].downed:
			continue
		var distance := actor.position.distance_squared_to(hunter.position)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best


static func _move_bodies(state: RunState) -> void:
	for actor in state.actors:
		if not actor.alive:
			continue
		actor.position = Motion.step_position(actor.position, actor.velocity, DELTA)
		actor.position = state.room.clamp_body(actor.position, BODY_RADIUS)


static func _fire(state: RunState, actor, stats: Dictionary) -> void:
	# Оружия нет или оно ничего не бросает — стрелять нечем.
	# Проверяется по статам, а не по готовому снаряду: снаряд, который сразу
	# лежит на полу, всё равно не нужен.
	var rate := float(stats.get("fire_rate", 0.0))
	var speed := float(stats.get("projectile_speed", 0.0))
	var reach := float(stats.get("range", 0.0))
	if rate <= 0.0 or speed <= 0.0 or reach <= 0.0:
		return

	state.projectiles.append(
		Projectile.spawn(state.take_id(), actor, actor.aim, stats,
			Arsenal.projectile_of(actor)))
	actor.cooldown = 1.0 / rate


## Снаряды летят и бьют. Попадание проверяется после перемещения снаряда,
## но до перемещения тел в следующем тике — иначе быстрый снаряд проскочил
## бы сквозь цель между кадрами.
static func _fly_projectiles(state: RunState) -> void:
	var surviving: Array[Projectile] = []
	for projectile in state.projectiles:
		var flying := projectile.advance(DELTA)

		if not state.room.contains(projectile.position):
			continue

		var spent := false
		for actor in state.actors:
			if not projectile.can_hit(actor):
				continue
			var reach := projectile.radius + BODY_RADIUS
			if projectile.position.distance_squared_to(actor.position) > reach * reach:
				continue

			var finished := actor.take_damage(projectile.damage)
			if finished and actor.kind == Actor.Kind.PLAYER and actor.slot >= 0:
				_knock_down(state, actor)
			projectile.hit_ids.append(actor.id)
			if projectile.pierce <= 0:
				spent = true
				break
			projectile.pierce -= 1

		if not spent and flying:
			surviving.append(projectile)
	state.projectiles = surviving


## Урон касанием. Враг бьёт игрока, подойдя вплотную; кадры неуязвимости
## задают темп ударов, отдельного отсчёта у врага нет.
static func _touch_damage(state: RunState) -> void:
	for enemy in state.actors:
		if not enemy.alive or enemy.kind != Actor.Kind.ENEMY:
			continue
		var damage := float(enemy.stack.compute().get("damage", 0.0))
		if damage <= 0.0:
			continue
		for target in state.actors:
			if not target.alive or target.kind != Actor.Kind.PLAYER:
				continue
			if target.invulnerable > 0.0:
				continue
			if enemy.position.distance_squared_to(target.position) > TOUCH_RANGE * TOUCH_RANGE:
				continue
			if target.take_damage(damage) and target.slot >= 0:
				_knock_down(state, target)
			target.invulnerable = HIT_INVULNERABILITY


## Игрок не умирает, а падает: поднимает товарищ, простояв рядом пять секунд.
## Модель Soul Knight из docs/DECISIONS.md. Тело остаётся живым для
## симуляции — иначе поднимать будет некого.
static func _knock_down(state: RunState, actor) -> void:
	state.slots[actor.slot].downed = true
	actor.alive = true
	actor.health = 0.0
	actor.velocity = Vector2.ZERO


static func _tick_timers(state: RunState) -> void:
	for actor in state.actors:
		actor.cooldown = maxf(actor.cooldown - DELTA, 0.0)
		actor.invulnerable = maxf(actor.invulnerable - DELTA, 0.0)


## Мёртвых врагов из списка не убираем: над трупом делается харвест органов
## (docs/DECISIONS.md), значит тело должно остаться. Снимаются только
## снаряды, которым нечего делать.
static func _collect_dead(state: RunState) -> void:
	var surviving: Array[Projectile] = []
	for projectile in state.projectiles:
		if not projectile.expired():
			surviving.append(projectile)
	state.projectiles = surviving


## Прогнать журнал команд с начала и до последнего записанного тика.
static func run_log(state: RunState, journal: CommandLog, until_tick: int = -1) -> void:
	var last: int = journal.last_tick if until_tick < 0 else until_tick
	while state.tick <= last:
		step(state, journal.frame(state.tick))
