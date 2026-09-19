extends "res://tests/framework/test_case.gd"
## Класс: поведение. Второй этап боя с бароном: кнопка, высадка, ракеты.

const Arena = preload("res://tests/framework/arena.gd")
const Encounter = preload("res://sim/encounter.gd")
const Map = preload("res://sim/room_map.gd")
const Tick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const Actor = preload("res://sim/actor.gd")
const Director = preload("res://sim/encounter_director.gd")
const Reinforcements = preload("res://sim/reinforcements.gd")
const Projectile = preload("res://sim/projectile.gd")
const Props = preload("res://sim/props.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const SaveGame = preload("res://sim/save/save_game.gd")


func title() -> String:
	return "подкрепление барона"


func _room():
	var state = Encounter.dev_room("reinforce", 1, 0, Map.make("oil_baron"))
	Director.begin(state)
	# Охрана мешает считать высадку: интерес здесь к барону и вертушке.
	for actor in state.actors:
		if actor.kind == Actor.Kind.ENEMY and actor.behaviour != "oil_baron":
			actor.alive = false
	return state


func _baron(state):
	for actor in state.actors:
		if actor.behaviour == "oil_baron":
			return actor
	return null


func _count(state, behaviour: String) -> int:
	var total := 0
	for actor in state.actors:
		if actor.behaviour == behaviour and actor.alive:
			total += 1
	return total


func _steps(state, count: int) -> void:
	for i in count:
		Tick.step(state, {0: Command.new()})


func _test_button_waits_for_half_health_and_presses_once() -> bool:
	var state = _room()
	var baron = _baron(state)
	check(baron != null, "в комнате нет барона")
	if baron == null: return true
	_steps(state, 30)
	eq(baron.call_ticks, 0, "барон зовёт подмогу целым")
	eq(_count(state, "gunship"), 0, "вертушка прилетела без вызова")
	baron.health = baron.max_health() * 0.4
	_steps(state, 1)
	check(baron.call_ticks > 0, "барон не дотянулся до кнопки на половине здоровья")
	eq(baron.attack_ticks, 0, "барон жмёт кнопку и стреляет одновременно")
	_steps(state, Reinforcements.CALL_TICKS + 1)
	eq(_count(state, "gunship"), 1, "вертушка не прилетела")
	eq(baron.call_ticks, -1, "кнопка не осталась нажатой")
	# Второй раз подмога не приходит, даже если барон осел ещё сильнее.
	baron.health = baron.max_health() * 0.1
	_steps(state, Reinforcements.CALL_TICKS + 60)
	eq(_count(state, "gunship"), 1, "вертушка прилетает по второму разу")
	return true


func _test_squad_rides_the_rope_down_and_only_then_fights() -> bool:
	var state = _room()
	var baron = _baron(state)
	if baron == null: return true
	baron.health = 1.0
	_steps(state, Reinforcements.CALL_TICKS + 2)
	var riders := 0
	var gunship = null
	for actor in state.actors:
		if Reinforcements.riding(actor): riders += 1
		if actor.behaviour == "gunship": gunship = actor
	eq(riders, 2, "по канатам спускаются не двое")
	check(gunship != null, "вертушки нет")
	if gunship == null: return true
	check(Reinforcements.summoning(state), "высадка не идёт")
	for actor in state.actors:
		if not Reinforcements.riding(actor): continue
		check(Reinforcements.rope_height(actor) > 0.0, "боец уже на полу, хотя висит")
		eq(actor.velocity, Vector2.ZERO, "висящий на канате бежит")
	eq(state.projectiles.size(), 0, "вертушка бьёт сквозь собственные канаты")
	_steps(state, Reinforcements.DROP_TICKS + 2)
	check(not Reinforcements.summoning(state), "высадка не заканчивается")
	for actor in state.actors:
		if actor.behaviour != "rifleman": continue
		almost_eq(Reinforcements.rope_height(actor), 0.0, "боец завис над полом")
	return true


func _test_rocket_turns_but_can_be_outrun() -> bool:
	var rocket = Projectile.new()
	rocket.homing = 1.5
	rocket.velocity = Vector2(130, 0)
	rocket.position = Vector2.ZERO
	var target := Vector2(400, 400)
	var before: float = rocket.velocity.angle_to(target - rocket.position)
	rocket.steer(target, 1.0 / 60.0)
	var after: float = rocket.velocity.angle_to(target - rocket.position)
	check(absf(after) < absf(before), "ракета не доворачивает на цель")
	almost_eq(rocket.velocity.length(), 130.0, "доводка разгоняет ракету", 1e-3)
	# Полный разворот за один тик невозможен: от ракеты можно уйти по дуге.
	var sharp = Projectile.new()
	sharp.homing = 1.5
	sharp.velocity = Vector2(130, 0)
	sharp.steer(Vector2(-400, 0), 1.0 / 60.0)
	check(sharp.velocity.x > 0.0, "ракета разворачивается на месте")

	var straight = Projectile.new()
	straight.velocity = Vector2(130, 0)
	straight.steer(Vector2(0, 400), 1.0 / 60.0)
	eq(straight.velocity, Vector2(130, 0), "обычный снаряд погнался за целью")
	return true


func _test_landing_survives_a_save() -> bool:
	var state = _room()
	var baron = _baron(state)
	if baron == null: return true
	baron.health = 1.0
	_steps(state, Reinforcements.CALL_TICKS + 20)
	var bytes := SaveGame.to_bytes(state)
	var loaded = SaveGame.from_bytes(bytes)
	check(loaded != null, "сейв высадки не прочитался")
	if loaded == null: return true
	eq(_count(loaded, "gunship"), 1, "вертушка потерялась при загрузке")
	eq(_baron(loaded).call_ticks, -1, "барон после загрузки зовёт подмогу заново")
	var riding := 0
	for actor in loaded.actors:
		if Reinforcements.riding(actor): riding += 1
	eq(riding, 2, "спускающиеся потеряли канат при загрузке")
	return true


func _test_barrels_stand_aside_and_do_not_hold_the_exit() -> bool:
	var state = _room()
	var barrels := 0
	for actor in state.actors:
		if Props.is_prop(actor): barrels += 1
	check(barrels >= 2, "в комнате барона нет бочек")
	for actor in state.actors:
		if not Props.is_prop(actor): continue
		eq(actor.velocity, Vector2.ZERO, "бочка поехала")
		eq(state.room.clamp_body(actor.position, actor.radius), actor.position, "бочка в стене")
	# Обстановка не держит выход: комната считается зачищенной без неё.
	for actor in state.actors:
		if actor.kind == Actor.Kind.ENEMY and not Props.is_prop(actor):
			actor.take_damage(100000.0)
	_steps(state, 2)
	check(state.room_cleared(), "бочки держат дверь закрытой")
	return true


func _test_barrel_blast_hurts_whoever_is_near() -> bool:
	var state = _room()
	var barrel = null
	for actor in state.actors:
		if Props.is_prop(actor): barrel = actor
	if not check(barrel != null, "бочки нет"): return true
	var player = state.actor_of_slot(0)
	player.position = barrel.position + Vector2(Props.BLAST_RADIUS - 30.0, 0)
	player.invulnerable = 0.0
	var baron = _baron(state)
	baron.position = barrel.position + Vector2(Props.BLAST_RADIUS + 400.0, 0)
	var health: float = player.health
	var baron_health: float = baron.health
	barrel.take_damage(1000.0)
	_steps(state, 1)
	check(player.health < health, "взрыв не задел стоящего рядом")
	almost_eq(baron.health, baron_health, "взрыв достал через полкомнаты")
	for actor in state.actors:
		check(not Props.is_prop(actor), "разорванная бочка осталась на сцене")
	return true


func _test_barrel_takes_any_hit() -> bool:
	var record: Dictionary = Bestiary.ENEMIES["barrel"]
	eq(record.behaviour, "prop", "бочка перестала быть обстановкой")
	almost_eq(float(record.base_stats.health), 1.0, "бочку стало нужно расстреливать")
	almost_eq(float(record.base_stats.move_speed), 0.0, "бочка научилась ходить")
	return true


## Топливо кончается, и это видно: без срока ракета висела над комнатой
## двадцать три секунды, а их в воздухе копилось по полдюжины.
func _test_rocket_burns_out_and_leaves_a_flash() -> bool:
	var state = _room()
	var gunship = Encounter.add_enemy(state, "gunship", Vector2(0, Reinforcements.HOVER_Y))
	var shot: Projectile = Projectile.spawn(state.take_id(), gunship, Vector2.UP,
		gunship.stack.compute(), "rocket")
	state.projectiles.append(shot)
	var lifetime := 0
	var flash := {}
	for i in 900:
		var events: Array = Tick.step(state, {0: Command.new()})
		for event in events:
			if event.type == "explosion": flash = event
		if state.projectiles.is_empty(): break
		lifetime = i + 1
	check(state.projectiles.is_empty(), "ракета не кончилась за пятнадцать секунд")
	check(lifetime <= 8 * 60, "ракета живёт дольше восьми секунд: %.1f с" % (lifetime / 60.0))
	check(not flash.is_empty(), "догоревшая ракета исчезла без вспышки")

	var player = state.actor_of_slot(0)
	var health: float = player.health
	var near: Projectile = Projectile.spawn(state.take_id(), gunship, Vector2.UP,
		gunship.stack.compute(), "rocket")
	near.position = player.position + Vector2(40, 0)
	near.travelled = near.total_range()
	state.projectiles.append(near)
	Tick.step(state, {0: Command.new()})
	almost_eq(player.health, health, "вспышка догоревшей ракеты нанесла урон")
	return true
