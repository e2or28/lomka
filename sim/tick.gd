extends RefCounted
## Шаг симуляции: функция от состояния и команд, без часов, узлов и
## случайности сверх именованных потоков.
##
## Порядок фаз менять нельзя: от него зависит, попал снаряд до или после
## того, как цель сдвинулась.

const Motion = preload("res://sim/motion.gd")
const RunState = preload("res://sim/run_state.gd")
const CommandLog = preload("res://sim/input/command_log.gd")
const Command = preload("res://sim/input/command.gd")
const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")
const Arsenal = preload("res://sim/arsenal.gd")

## Плавающий шаг сделал бы сверку хоста с клиентом невоспроизводимой.
const DELTA := 1.0 / 60.0

## Даётся только игрокам и только от касания. У врагов период перезарядки
## короче этих кадров, поэтому каждый следующий снаряд продлевал бы их, и
## враг под плотным огнём становился бессмертным — так и было.
const HIT_INVULNERABILITY := 0.4

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

		if slot.downed:
			move = Vector2.ZERO
			firing = false

		if aim != Vector2.ZERO:
			actor.aim = aim.normalized()

		var stats := actor.stack.compute()
		actor.velocity = Motion.step_velocity(actor.velocity, move, stats, DELTA)

		if firing and actor.cooldown <= 0.0:
			_fire(state, actor, stats)


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
			move = _behaviour_move(actor, offset, state.tick, actor.radius + target.radius)
		var stats := actor.stack.compute()
		actor.velocity = Motion.step_velocity(actor.velocity, move, stats, DELTA)


## Случайности здесь нет намеренно: разброс должен браться из потока
## AI_SPREAD, а лишний бросок сдвигает поток и рассинхронизирует забег.
## reach — сумма хитбоксов: расстояние, на котором тела уже касаются.
## Подходят враги до его половины, то есть заходя в цель наполовину: на
## самой границе они дрожали бы, то входя в касание, то выходя.
static func _behaviour_move(actor, offset: Vector2, tick: int, reach: float) -> Vector2:
	var distance := offset.length()
	if distance <= 0.001:
		return Vector2.ZERO
	var towards := offset / distance

	match actor.behaviour:
		"harrier":
			var cycle := (tick % HARRIER_PERIOD) < HARRIER_PERIOD / 2
			if distance < HARRIER_BACKOFF and not cycle:
				return -towards
			if distance > reach * 0.5:
				return towards
			return Vector2.ZERO

		"bruiser":
			return towards

		_:  # charger
			if distance > reach * 0.5:
				return towards
			return Vector2.ZERO


## Упавшего враги не добивают: иначе поднять его будет невозможно.
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
		actor.position = state.room.clamp_body(actor.position, actor.radius)


static func _fire(state: RunState, actor, stats: Dictionary) -> void:
	var rate := float(stats.get("fire_rate", 0.0))
	var speed := float(stats.get("projectile_speed", 0.0))
	var reach := float(stats.get("range", 0.0))
	if rate <= 0.0 or speed <= 0.0 or reach <= 0.0:
		return

	state.projectiles.append(
		Projectile.spawn(state.take_id(), actor, actor.aim, stats,
			Arsenal.projectile_of(actor)))
	actor.cooldown = 1.0 / rate


## Попадание проверяется после перемещения снаряда, но до перемещения тел в
## следующем тике — иначе быстрый снаряд проскочил бы сквозь цель.
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
			var reach := projectile.radius + actor.radius
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


## Темп ударов задают кадры неуязвимости жертвы: своего отсчёта у врага нет.
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
			var reach := enemy.radius + target.radius
			if enemy.position.distance_squared_to(target.position) > reach * reach:
				continue
			if target.take_damage(damage) and target.slot >= 0:
				_knock_down(state, target)
			target.invulnerable = HIT_INVULNERABILITY


## Тело остаётся живым при нулевом здоровье намеренно: упавшего поднимает
## товарищ, и мёртвое тело поднимать было бы некому.
static func _knock_down(state: RunState, actor) -> void:
	state.slots[actor.slot].downed = true
	actor.alive = true
	actor.health = 0.0
	actor.velocity = Vector2.ZERO


static func _tick_timers(state: RunState) -> void:
	for actor in state.actors:
		actor.cooldown = maxf(actor.cooldown - DELTA, 0.0)
		actor.invulnerable = maxf(actor.invulnerable - DELTA, 0.0)


## Трупы врагов остаются в списке: над ними делается харвест органов.
static func _collect_dead(state: RunState) -> void:
	var surviving: Array[Projectile] = []
	for projectile in state.projectiles:
		if not projectile.expired():
			surviving.append(projectile)
	state.projectiles = surviving


static func run_log(state: RunState, journal: CommandLog, until_tick: int = -1) -> void:
	var last: int = journal.last_tick if until_tick < 0 else until_tick
	while state.tick <= last:
		step(state, journal.frame(state.tick))
