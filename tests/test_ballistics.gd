extends "res://tests/framework/test_case.gd"
## Полёт снаряда: дуга и наследование скорости.
##
## Оба заимствованы из Isaac и оба про ощущение боя, но проверяемая часть
## у них строгая: дальность обязана оставаться той, что задана статом, а
## наследование — работать симметрично в обе стороны.
##
## Как это ощущается — решается на стенде. Здесь только то, что можно
## посчитать.

const Encounter = preload("res://sim/encounter.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const Projectile = preload("res://sim/projectile.gd")
const Actor = preload("res://sim/actor.gd")
const RunState = preload("res://sim/run_state.gd")
const Arsenal = preload("res://sim/arsenal.gd")

const SEED := "баллистика"


func title() -> String:
	return "полёт снаряда"


func _lone_shooter() -> RunState:
	## Комната с одним игроком и врагом, убранным подальше: проверяется
	## полёт, а не попадание.
	var state := Encounter.dev_room(SEED, 1, 1)
	state.living(Actor.Kind.ENEMY)[0].position = Vector2(100000, 100000)
	return state


func _shoot(state: RunState, aim: Vector2, move: Vector2 = Vector2.ZERO) -> Projectile:
	var before := state.projectiles.size()
	SimTick.step(state, {0: Command.from_axes(state.tick, move, aim, Command.BTN_FIRE)})
	return state.projectiles[-1] if state.projectiles.size() > before else null


## Разогнать до полной скорости. Ставить velocity руками бесполезно:
## тик пересчитывает её из команды и торможение гасит за пару кадров.
func _run_up(state: RunState, move: Vector2) -> void:
	for i in 30:
		SimTick.step(state, {0: Command.from_axes(state.tick, move, Vector2.ZERO)})


## Дальность задана статом и обязана ей остаться: дуга — это способ
## долететь, а не повод пролететь мимо.
func _test_arc_keeps_the_declared_range() -> bool:
	var state := _lone_shooter()
	var actor := state.actor_of_slot(0)
	var stats := actor.stack.compute()
	var declared: float = stats["range"]
	var start := actor.position

	var projectile := _shoot(state, Vector2.RIGHT)
	check(projectile != null, "снаряд не появился")
	if projectile == null:
		return true

	var travelled := 0.0
	for i in 600:
		SimTick.step(state, {0: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO)})
		travelled = projectile.position.distance_to(start)
		if state.projectiles.is_empty():
			break

	check(state.projectiles.is_empty(), "снаряд не упал за десять секунд")
	almost_eq(travelled, declared, "снаряд пролетел не свою дальность", declared * 0.06)
	return true


## Летит по дуге, а не по прямой: поднимается, потом падает.
func _test_projectile_rises_then_falls() -> bool:
	var state := _lone_shooter()
	var projectile := _shoot(state, Vector2.RIGHT)
	if projectile == null:
		fail("снаряд не появился")
		return true

	var peak := projectile.height
	var rising_ended := false
	var previous := projectile.height
	for i in 600:
		SimTick.step(state, {0: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO)})
		if state.projectiles.is_empty():
			break
		peak = maxf(peak, projectile.height)
		if projectile.height < previous:
			rising_ended = true
		elif rising_ended:
			fail("снаряд снова полетел вверх после падения")
			break
		previous = projectile.height

	check(peak > Projectile.START_HEIGHT, "снаряд не поднялся выше точки броска")
	check(rising_ended, "снаряд так и не начал падать")
	almost_eq(projectile.height, 0.0, "снаряд остановился не на полу", 1.0)
	return true


## Снаряд, летящий выше тела, проходит над ним. Без этого дуга была бы
## чистой декорацией.
func _test_high_projectile_flies_over() -> bool:
	var state := Encounter.dev_room(SEED, 1, 1)
	var actor := state.actor_of_slot(0)
	var enemy := state.living(Actor.Kind.ENEMY)[0]

	# Враг далеко, чтобы снаряд не погас о него на вылете
	enemy.position = actor.position + Vector2(400, 0)
	var projectile := _shoot(state, Vector2.RIGHT)
	if projectile == null:
		fail("снаряд не появился")
		return true

	# Ставим снаряд на врага, но выше уровня попадания
	var health := enemy.health
	projectile.position = enemy.position
	projectile.height = SimTick.HIT_HEIGHT + 20.0
	projectile.height_speed = 0.0
	SimTick.step(state, {0: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO)})
	almost_eq(enemy.health, health, "снаряд ударил, пролетая над головой", 0.01)

	# Тот же снаряд на уровне тела обязан попасть
	if not state.projectiles.is_empty():
		var low := state.projectiles[-1]
		low.position = enemy.position
		low.height = 10.0
		low.height_speed = 0.0
		SimTick.step(state, {0: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO)})
		check(enemy.health < health, "снаряд на уровне тела не попал — проверка высоты режет всё")
	return true


## Наследование скорости: бросок на бегу сносит снаряд в сторону движения.
func _test_momentum_carries_the_shot() -> bool:
	var still := _lone_shooter()
	var still_shot := _shoot(still, Vector2.UP)
	if still_shot == null:
		fail("снаряд не появился")
		return true
	var upright := still_shot.velocity

	var running := _lone_shooter()
	_run_up(running, Vector2.RIGHT)
	var running_shot := _shoot(running, Vector2.UP, Vector2.RIGHT)
	if running_shot == null:
		fail("снаряд на бегу не появился")
		return true

	almost_eq(upright.x, 0.0, "стоя снаряд ушёл вбок", 0.01)
	check(running_shot.velocity.x > 50.0,
		"на бегу снаряд не снесло: %.1f" % running_shot.velocity.x)
	almost_eq(running_shot.velocity.y, upright.y, "снос изменил вертикальную скорость", 0.01)
	return true


func _test_momentum_is_symmetric() -> bool:
	var right := _lone_shooter()
	_run_up(right, Vector2.RIGHT)
	var right_shot := _shoot(right, Vector2.UP, Vector2.RIGHT)

	var left := _lone_shooter()
	_run_up(left, Vector2.LEFT)
	var left_shot := _shoot(left, Vector2.UP, Vector2.LEFT)

	if right_shot == null or left_shot == null:
		fail("снаряды не появились")
		return true
	almost_eq(right_shot.velocity.x, -left_shot.velocity.x,
		"снос вправо и влево несимметричен", 0.01)
	return true


## Коэффициент — стат, значит предмет сможет его крутить.
func _test_momentum_is_a_stat() -> bool:
	var state := _lone_shooter()
	var actor := state.actor_of_slot(0)
	# Снимаем то, что положило оружие, и ставим свой коэффициент нулём.
	# Остальные статы оружия возвращаем: без них стрелять нечем.
	actor.stack.remove_source(Arsenal.source_of(actor.weapon_id))
	actor.stack.base["damage"] = 12.0
	actor.stack.base["fire_rate"] = 3.5
	actor.stack.base["projectile_speed"] = 620.0
	actor.stack.base["range"] = 620.0
	actor.stack.base["shot_momentum"] = 0.0
	_run_up(state, Vector2.RIGHT)

	var shot := _shoot(state, Vector2.UP, Vector2.RIGHT)
	if shot == null:
		fail("снаряд не появился")
		return true
	almost_eq(shot.velocity.x, 0.0, "при нулевом коэффициенте снаряд всё равно снесло", 0.01)
	return true


func _test_arc_survives_a_save() -> bool:
	var SaveGame = preload("res://sim/save/save_game.gd")
	var state := _lone_shooter()
	var projectile := _shoot(state, Vector2.RIGHT)
	if projectile == null:
		fail("снаряд не появился")
		return true
	for i in 20:
		SimTick.step(state, {0: Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO)})

	var loaded = SaveGame.from_bytes(SaveGame.to_bytes(state))
	check(loaded != null, "забег со снарядом в полёте не загрузился")
	if loaded == null:
		return true
	eq(loaded.projectiles.size(), state.projectiles.size(), "снаряд в полёте потерян")
	if not loaded.projectiles.is_empty():
		almost_eq(loaded.projectiles[0].height, state.projectiles[0].height,
			"высота снаряда не пережила сейв", 1e-6)
		almost_eq(loaded.projectiles[0].height_speed, state.projectiles[0].height_speed,
			"вертикальная скорость не пережила сейв", 1e-6)
	return true
