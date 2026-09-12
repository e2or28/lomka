extends RefCounted
## Шаг симуляции: функция от состояния и команд, без часов, узлов и
## случайности сверх именованных потоков.
##
## Порядок фаз менять нельзя: от него зависит, попал снаряд до или после
## того, как цель сдвинулась.

const Revive = preload("res://sim/revive.gd")
const Director = preload("res://sim/encounter_director.gd")
const Motion = preload("res://sim/motion.gd")
const RunState = preload("res://sim/run_state.gd")
const CommandLog = preload("res://sim/input/command_log.gd")
const Command = preload("res://sim/input/command.gd")
const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Pickup = preload("res://sim/pickup.gd")
const Organs = preload("res://sim/organs.gd")
const Harvest = preload("res://sim/harvest.gd")
const RoomTravel = preload("res://sim/room_travel.gd")
const Miniboss = preload("res://sim/miniboss.gd")
const GuardAttacks = preload("res://sim/guard_attacks.gd")
const Reinforcements = preload("res://sim/reinforcements.gd")
const Props = preload("res://sim/props.gd")
const Encounter = preload("res://sim/encounter.gd")
const Corpses = preload("res://sim/corpses.gd")
const Items = preload("res://sim/items.gd")
const Shooting = preload("res://sim/shooting.gd")
const Abilities = preload("res://sim/abilities.gd")
const Hitboxes = preload("res://sim/hitboxes.gd")
const BodyFacing = preload("res://sim/body_facing.gd")

## Плавающий шаг сделал бы сверку хоста с клиентом невоспроизводимой.
const DELTA := 1.0 / 60.0

## Даётся только игрокам и только от касания. У врагов период перезарядки
## короче этих кадров, поэтому каждый следующий снаряд продлевал бы их, и
## враг под плотным огнём становился бессмертным — так и было.
const HIT_INVULNERABILITY := 0.4

const HARRIER_PERIOD := 96
const HARRIER_BACKOFF := 120.0


static func step(state: RunState, commands: Dictionary) -> Array[Dictionary]:
	# Одноразовый результат тика: не хранится в забеге и не меняет его хеш.
	var events: Array[Dictionary] = []
	var first_new_id := state.next_id
	var room_id := state.room.id
	commands = Revive.prepare(state, commands)
	Director.advance(state, events)
	Reinforcements.advance(state)
	Abilities.advance(state, commands)
	_drive_players(state, commands)
	_drive_enemies(state, events)
	for projectile in state.projectiles:
		if projectile.id < first_new_id:
			continue
		var owner := state.actor_by_id(projectile.owner_id)
		events.append({"type": "shot", "actor_id": projectile.owner_id,
			"projectile_id": projectile.id, "kind": projectile.kind,
			"projection_offset": projectile.projection_offset,
			"position": projectile.position, "direction": projectile.velocity.normalized(),
			"aim": owner.aim, "weapon": owner.weapon_id})
	_move_bodies(state, events)
	_take_pickups(state, commands)
	_fly_projectiles(state, events)
	_touch_damage(state, events)
	for fallen in Props.advance(state, events):
		_knock_down(state, fallen)
	Revive.advance(state, events)
	Harvest.advance(state, commands)
	Corpses.advance(state)
	_tick_timers(state)
	_collect_dead(state)
	RoomTravel.advance(state, commands)
	state.tick += 1
	for event in events:
		event["room_id"] = room_id
	return events


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

		if slot.downed or slot.revive_target >= 0:
			move = Vector2.ZERO
			firing = false

		if aim != Vector2.ZERO:
			actor.aim = aim.normalized()

		Organs.update_threat(state, actor, slot)
		var stats := actor.stack.compute()
		actor.velocity = Motion.step_velocity(actor.velocity, move, stats, DELTA)
		actor.facing = BodyFacing.aiming_side(actor.aim, actor.velocity, firing, actor.facing)
		actor.standing_front = BodyFacing.front(actor.aim, actor.velocity, firing, actor.standing_front)

		Shooting.advance(state, actor, slot, stats, firing)


static func _drive_enemies(state: RunState, events: Array[Dictionary]) -> void:
	for actor in state.actors:
		if not actor.alive or actor.kind != Actor.Kind.ENEMY or Props.is_prop(actor):
			continue
		var target := _nearest_target(state, actor)
		if actor.behaviour == "oil_baron" and Reinforcements.drive_call(state, actor):
			Reinforcements.land(state, Encounter, actor.position.x)
			events.append({"type": "reinforcements", "actor_id": actor.id})
		if GuardAttacks.PROFILES.has(actor.behaviour):
			if GuardAttacks.drive(state, actor, target, DELTA):
				for player in state.living(Actor.Kind.PLAYER):
					if state.slots[player.slot].downed or not GuardAttacks.in_swing(actor, player): continue
					var health_before := player.health
					if player.take_damage(float(actor.stack.compute().get("damage", 0.0))):
						_knock_down(state, player)
					_record_hit(events, player, health_before, "baton", actor.attack_aim)
					if player.health < health_before: player.invulnerable = HIT_INVULNERABILITY
			continue
		if actor.behaviour == "tank":
			Miniboss.drive(state, actor, target, DELTA)
			continue
		var move := Vector2.ZERO
		if target != null:
			var offset := target.position - actor.position
			if offset != Vector2.ZERO:
				actor.aim = offset.normalized()
				if not is_zero_approx(offset.x): actor.facing = 1 if offset.x > 0.0 else -1
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


static func _move_bodies(state: RunState, events: Array[Dictionary]) -> void:
	for actor in state.actors:
		if not actor.alive:
			continue
		var before := actor.position
		actor.position = Motion.step_position(actor.position, actor.velocity, DELTA)
		actor.position = state.room.clamp_body(actor.position, actor.radius)
		Abilities.constrain_enemy(state, actor, before)
		if actor.kind == Actor.Kind.PLAYER and actor.slot >= 0:
			var health_before := actor.health
			_tick_organs(state, actor, before)
			_record_hit(events, actor, health_before, "strain", Vector2.ZERO)


static func _tick_organs(state: RunState, actor, before: Vector2) -> void:
	var slot := state.slots[actor.slot]
	if slot.downed or not Organs.has_behaviour(slot, "keep_moving"):
		slot.stationary_ticks = 0
		return
	if actor.position.distance_squared_to(before) > 0.0001:
		slot.stationary_ticks = 0
		return
	slot.stationary_ticks += 1
	if slot.stationary_ticks > 180 and (slot.stationary_ticks - 181) % 60 == 0:
		# Внутренний штраф проходит сквозь неуязвимость от касания.
		actor.health = maxf(0.0, actor.health - 5.0)
		if actor.health <= 0.0:
			_knock_down(state, actor)


## После перемещения тел, до полёта снарядов: подобранное оружие стреляет
## со следующего тика, а не в тот же самый.
static func _take_pickups(state: RunState, commands: Dictionary) -> void:
	for slot in state.slots:
		if not slot.occupied:
			continue
		var down: bool = commands.has(slot.index) \
			and commands[slot.index].pressed(Command.BTN_INTERACT)
		var pressed_now := down and not slot.interact_held
		slot.interact_held = down
		if not pressed_now or slot.downed:
			continue

		var actor := state.actor_by_id(slot.actor_id)
		if actor != null and actor.alive:
			_swap_pickup(state, actor)


## Обмен, а не поглощение: прежнее оружие остаётся лежать на месте
## подобранного, и за ним можно вернуться. Безоружный забирает предмет
## насовсем — иначе на полу оставалась бы пустая ячейка.
static func _swap_pickup(state: RunState, actor) -> void:
	var nearest: Pickup = Pickup.nearest(state, actor)
	if nearest == null:
		return
	if nearest.kind == Pickup.KIND_ITEM:
		if Items.equip(actor, state.slots[actor.slot], nearest.content_id):
			state.pickups.erase(nearest)
		return

	var dropped: String = actor.weapon_id
	if nearest.kind == Pickup.KIND_ORGAN:
		var record := Organs.organ(nearest.content_id)
		if record.is_empty():
			return
		var slot := state.slots[actor.slot]
		dropped = slot.organs[record["slot"]]
		if not Organs.equip(actor, slot, nearest.content_id):
			return
	elif not Arsenal.equip(actor, nearest.content_id):
		return
	state.slots[actor.slot].charge_ticks = 0
	if dropped == "":
		state.pickups.erase(nearest)
		return
	nearest.content_id = dropped


## Попадание проверяется после перемещения снаряда, но до перемещения тел в
## следующем тике — иначе быстрый снаряд проскочил бы сквозь цель.
## Цель ракеты — ближайший стоящий на ногах игрок. Упавшего она не
## добивает: он и так лежит, а подбежавшему на подъём прилетело бы дважды.
static func _nearest_player(state: RunState, at: Vector2):
	var nearest = null
	var best := INF
	for player in state.living(Actor.Kind.PLAYER):
		if player.slot >= 0 and state.slots[player.slot].downed: continue
		var distance := at.distance_squared_to(player.position)
		if distance < best:
			best = distance
			nearest = player
	return nearest


static func _fly_projectiles(state: RunState, events: Array[Dictionary]) -> void:
	var surviving: Array[Projectile] = []
	for projectile in state.projectiles:
		if projectile.homing > 0.0:
			var chased = _nearest_player(state, projectile.position)
			if chased != null: projectile.steer(chased.position, DELTA)
		var flight := projectile.fly(DELTA, state.room)
		var destination := projectile.position
		var spent := false
		var points: Array = flight["points"]
		for i in range(1, points.size()):
			if _hit_segment(state, projectile, points[i - 1], points[i], events):
				spent = true
				break
		projectile.position = destination
		if not spent and flight["flying"]:
			surviving.append(projectile)
	state.projectiles = surviving


static func _hit_segment(state: RunState, projectile: Projectile, from: Vector2,
		to: Vector2, events: Array[Dictionary]) -> bool:
	var hits: Array = []
	for actor in state.actors:
		if not projectile.can_hit(actor): continue
		if actor.kind == Actor.Kind.PLAYER and actor.slot >= 0 and state.slots[actor.slot].downed: continue
		var fraction := Projectile.hit_fraction(from, to, actor.position, projectile.radius + actor.radius)
		if not actor.hurtboxes.is_empty():
			fraction = Hitboxes.hit_fraction(projectile, from, to, actor)
		if fraction != INF: hits.append({"actor": actor, "fraction": fraction})
	hits.sort_custom(func(a, b): return a.fraction < b.fraction if a.fraction != b.fraction else a.actor.id < b.actor.id)
	for hit in hits:
		projectile.position = from.lerp(to, hit.fraction)
		if Abilities.blocks_shot(state, projectile, from): return true
		var actor: Actor = hit.actor
		var health_before := actor.health
		var finished := actor.take_damage(projectile.damage)
		_record_hit(events, actor, health_before, projectile.kind, (to - from).normalized(), projectile.id,
			projectile.position + projectile.flight_offset())
		if finished and actor.kind == Actor.Kind.PLAYER and actor.slot >= 0: _knock_down(state, actor)
		projectile.hit_ids.append(actor.id)
		if projectile.pierce <= 0: return true
		projectile.pierce -= 1
	projectile.position = to
	return Abilities.blocks_shot(state, projectile, from)


## Темп ударов задают кадры неуязвимости жертвы: своего отсчёта у врага нет.
static func _touch_damage(state: RunState, events: Array[Dictionary]) -> void:
	for enemy in state.actors:
		if not enemy.alive or enemy.kind != Actor.Kind.ENEMY:
			continue
		if GuardAttacks.PROFILES.has(enemy.behaviour): continue
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
			var health_before := target.health
			if target.take_damage(damage) and target.slot >= 0:
				_knock_down(state, target)
			_record_hit(events, target, health_before, "contact",
				(target.position - enemy.position).normalized())
			target.invulnerable = HIT_INVULNERABILITY


static func _record_hit(events: Array[Dictionary], actor: Actor, health_before: float,
		kind: String, direction: Vector2, projectile_id: int = -1, impact_position: Vector2 = Vector2.INF) -> void:
	if actor.health >= health_before:
		return
	events.append({"type": "hit", "actor_id": actor.id, "kind": kind,
		"position": actor.position, "direction": direction,
		"damage": health_before - actor.health, "fallen": actor.health <= 0.0,
		"projectile_id": projectile_id})
	if impact_position != Vector2.INF:
		events[-1]["impact_position"] = impact_position


## Тело остаётся живым при нулевом здоровье намеренно: упавшего поднимает
## товарищ, и мёртвое тело поднимать было бы некому.
static func _knock_down(state: RunState, actor) -> void:
	Revive.cancel(state.slots[actor.slot])
	state.slots[actor.slot].downed = true
	state.slots[actor.slot].charge_ticks = 0
	Abilities.finish(state, state.slots[actor.slot])
	actor.alive = true
	actor.health = 0.0
	actor.velocity = Vector2.ZERO


static func _tick_timers(state: RunState) -> void:
	for actor in state.actors:
		actor.cooldown = maxf(actor.cooldown - DELTA, 0.0)
		actor.invulnerable = maxf(actor.invulnerable - DELTA, 0.0)


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
