extends "res://tests/framework/test_case.gd"
## Полёт снаряда: прямая, кувырок и наследование скорости.
##
## Класс: поведение. Правила ниже меняются вместе с игрой — предмет на
## дальность или на снос перепишет половину ожиданий, и это нормально.
## Инвариантов, которые держат кооп, здесь нет, кроме последней пробы.
##
## Снаряд летит ровно до заявленной дальности, потом переворачивается и
## проходит ещё отрезок — приём Mr. P из Brawl Stars. Обе дальности статы,
## поэтому предмет сможет крутить их по отдельности.
##
## Как это ощущается — решается на стенде. Здесь только то, что считается.

const Arena = preload("res://tests/framework/arena.gd")
const Projectile = preload("res://sim/projectile.gd")
const RunState = preload("res://sim/run_state.gd")
const Arsenal = preload("res://sim/arsenal.gd")

const SEED := "баллистика"


func title() -> String:
	return "полёт снаряда"


## Снаряд проходит обе дальности: ровную и кувырком.
func _test_flies_straight_range_then_tumbles() -> bool:
	var state := Arena.shooting_range(SEED)
	var start := state.actor_of_slot(0).position
	var projectile := Arena.shoot(state, Vector2.RIGHT)
	check(projectile != null, "снаряд не появился")
	if projectile == null:
		return true

	check(projectile.straight_range > 0.0, "ровная дальность нулевая")
	check(projectile.tumble_range > 0.0, "кувырок не выдан — чемодан не долетит дальше")

	var seen_tumbling := false
	var furthest := 0.0
	for i in 600:
		Arena.coast(state, 1)
		furthest = maxf(furthest, projectile.position.distance_to(start))
		if projectile.tumbling():
			seen_tumbling = true
		if state.projectiles.is_empty():
			break

	check(seen_tumbling, "снаряд ни разу не перешёл в кувырок")
	check(state.projectiles.is_empty(), "снаряд не выдохся за десять секунд")
	almost_eq(furthest, projectile.total_range(),
		"снаряд прошёл не обе дальности", projectile.total_range() * 0.06)
	return true


## Кувырок начинается ровно на заявленной дальности, не раньше.
func _test_tumble_starts_at_the_declared_range() -> bool:
	var state := Arena.shooting_range(SEED)
	var projectile := Arena.shoot(state, Vector2.RIGHT)
	if projectile == null:
		fail("снаряд не появился")
		return true

	var straight := projectile.straight_range
	var switched_at := -1.0
	for i in 600:
		Arena.coast(state, 1)
		if state.projectiles.is_empty():
			break
		if projectile.tumbling():
			switched_at = projectile.travelled
			break
	check(switched_at > 0.0, "переход в кувырок не случился")
	almost_eq(switched_at, straight, "кувырок начался не на своей дальности", straight * 0.05)
	return true


## Снаряд идёт по прямой линии броска, ничего не роняя: падения в этой игре
## нет, оно отменено решением от 2 сентября 2026.
func _test_flies_level() -> bool:
	var state := Arena.shooting_range(SEED)
	var shot := Arena.shoot(state, Vector2.RIGHT)
	if shot == null:
		fail("снаряд не появился")
		return true
	var line := shot.position.y
	Arena.coast(state, 20)
	almost_eq(shot.position.y, line, "снаряд ушёл по вертикали при горизонтальном броске", 0.01)
	return true


## Кувыркающийся чемодан бьёт не слабее ровно летящего.
func _test_tumbling_still_hits() -> bool:
	var state := Arena.room(SEED, 1, 1)
	var enemy := Arena.enemies(state)[0]
	Arena.banish(enemy)

	var projectile := Arena.shoot(state, Vector2.RIGHT)
	if projectile == null:
		fail("снаряд не появился")
		return true
	projectile.travelled = projectile.straight_range + 1.0
	check(projectile.tumbling(), "снаряд не в кувырке — проба построена неверно")

	var health := enemy.health
	enemy.position = projectile.position
	Arena.coast(state, 1)
	check(enemy.health < health, "кувыркающийся снаряд не нанёс урона")
	return true


## Наследование скорости: бросок на бегу сносит снаряд в сторону движения.
func _test_momentum_carries_the_shot() -> bool:
	var still := Arena.shooting_range(SEED)
	var still_shot := Arena.shoot(still, Vector2.UP)
	if still_shot == null:
		fail("снаряд не появился")
		return true

	var running := Arena.shooting_range(SEED)
	Arena.run_up(running, Vector2.RIGHT)
	var running_shot := Arena.shoot(running, Vector2.UP, Vector2.RIGHT)
	if running_shot == null:
		fail("снаряд на бегу не появился")
		return true

	almost_eq(still_shot.velocity.x, 0.0, "стоя снаряд ушёл вбок", 0.01)
	check(running_shot.velocity.x > 50.0,
		"на бегу снаряд не снесло: %.1f" % running_shot.velocity.x)
	almost_eq(running_shot.velocity.y, still_shot.velocity.y,
		"снос изменил вертикальную скорость", 0.01)
	return true


func _test_momentum_is_symmetric() -> bool:
	var right := Arena.shooting_range(SEED)
	Arena.run_up(right, Vector2.RIGHT)
	var right_shot := Arena.shoot(right, Vector2.UP, Vector2.RIGHT)

	var left := Arena.shooting_range(SEED)
	Arena.run_up(left, Vector2.LEFT)
	var left_shot := Arena.shoot(left, Vector2.UP, Vector2.LEFT)

	if right_shot == null or left_shot == null:
		fail("снаряды не появились")
		return true
	almost_eq(right_shot.velocity.x, -left_shot.velocity.x,
		"снос вправо и влево несимметричен", 0.01)
	return true


func _test_momentum_is_a_stat() -> bool:
	var state := Arena.shooting_range(SEED)
	var actor := state.actor_of_slot(0)
	actor.stack.remove_source(Arsenal.source_of(actor.weapon_id))
	actor.stack.base["damage"] = 12.0
	actor.stack.base["fire_rate"] = 3.5
	actor.stack.base["projectile_speed"] = 620.0
	actor.stack.base["range"] = 620.0
	actor.stack.base["shot_momentum"] = 0.0
	Arena.run_up(state, Vector2.RIGHT)

	var shot := Arena.shoot(state, Vector2.UP, Vector2.RIGHT)
	if shot == null:
		fail("снаряд не появился")
		return true
	almost_eq(shot.velocity.x, 0.0, "при нулевом коэффициенте снаряд всё равно снесло", 0.01)
	return true


## Класс: инвариант. Снаряд в полёте — часть состояния, и правило 8 требует
## от него переживать сейв целиком.
func _test_flight_survives_a_save() -> bool:
	var state := Arena.shooting_range(SEED)
	var projectile := Arena.shoot(state, Vector2.RIGHT)
	if projectile == null:
		fail("снаряд не появился")
		return true
	Arena.coast(state, 20)

	var loaded := Arena.after_save(state)
	check(loaded != null, "забег со снарядом в полёте не загрузился")
	if loaded == null or loaded.projectiles.is_empty():
		return true
	almost_eq(loaded.projectiles[0].travelled, state.projectiles[0].travelled,
		"пройденный путь не пережил сейв", 1e-6)
	almost_eq(loaded.projectiles[0].tumble_range, state.projectiles[0].tumble_range,
		"дальность кувырка не пережила сейв", 1e-6)
	return true
