extends SceneTree
## Автобот: гоняет комнату без окна и пишет журнал команд с метриками.
##
## Шаг M1 из docs/LEVEL_EDITOR.md: одна комната, одна стратегия, разрез по
## сборкам. Бот не играет хорошо — он играет воспроизводимо и одинаково
## для всех сборок, поэтому разница в метриках принадлежит сборке, а не ему.

const Encounter = preload("res://sim/encounter.gd")
const RunState = preload("res://sim/run_state.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const CommandLog = preload("res://sim/input/command_log.gd")
const Actor = preload("res://sim/actor.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Items = preload("res://sim/items.gd")
const Organs = preload("res://sim/organs.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Fnv = preload("res://sim/core/fnv.gd")
const Aim = preload("res://sim/aim.gd")

const TIMEOUT_TICKS := 3600
const MONSTERS := 3
const ROSTER: Array[String] = ["test_monster", "runner", "heavy"]

## Расстановка врагов — единственный источник разброса между сидами: сама
## комната детерминирована, и без него пачка сидов была бы одним прогоном,
## показанным N раз. Генератор бота свой: игровые потоки принадлежат забегу,
## а не инструменту.
const SPAWN_RING := Vector2(340.0, 150.0)

## Дистанция боя: ближе бот отходит, дальше — подходит. Взята заведомо
## больше радиуса самого крупного врага, иначе бот дрался бы вплотную и
## метрика полученного урона мерила бы касания, а не сборку.
const KEEP_DISTANCE := 170.0
const APPROACH_BAND := 40.0

## Разрез, ради которого бот и написан: голое оружие, каждая яркая механика
## отдельно и два сочетания. Органы и предметы кладутся на старте — подбор
## с пола проверяют тесты, здесь он только внёс бы шум в метрики.
const BUILDS := {
	"чемодан": {"weapon": "suitcase", "items": [], "organs": []},
	"кольт": {"weapon": "colt", "items": [], "organs": []},
	"папка": {"weapon": "colt", "items": ["red_folder"], "organs": []},
	"пружина+копирка": {"weapon": "suitcase", "items": ["spring", "carbon_copy"], "organs": []},
	"печать": {"weapon": "colt", "items": ["heavy_seal"], "organs": []},
	"рикошет+дырокол": {"weapon": "colt", "items": ["rubber_stamp", "hole_punch"], "organs": []},
	"линейка": {"weapon": "colt", "items": ["optical_ruler"], "organs": []},
	"экспресс": {"weapon": "colt", "items": [], "organs": ["courier_heart", "armored_spine"]},
	"трус": {"weapon": "colt", "items": [], "organs": ["coward_heart"]},
	"нотариус": {"weapon": "colt", "items": [], "organs": ["notary_eye"]},
	"затылочник": {"weapon": "colt", "items": [], "organs": ["rear_eye"]},
}


func _initialize() -> void:
	var options := _options()
	var out_dir: String = options["out"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var names: Array = BUILDS.keys() if options["build"] == "all" else [options["build"]]
	for name in names:
		if not BUILDS.has(name):
			push_error("Неизвестная сборка: '%s'. Есть: %s" % [name, ", ".join(BUILDS.keys())])
			quit(2)
			return

	var runs: Array[Dictionary] = []
	for name in names:
		for index in int(options["seeds"]):
			var seed_text := "автобот-%d" % index
			var run := _run(seed_text, name, int(options["ticks"]))
			_write(out_dir, run)
			runs.append(run)

	_report(names, runs)
	var broken := 0
	for run in runs:
		if not run["replayable"]:
			broken += 1
	if broken > 0:
		push_error("Прогонов, не повторившихся из своего журнала: %d из %d" % [broken, runs.size()])
		quit(1)
		return
	print("АВТОБОТ ЗАКОНЧИЛ: %d прогонов, логи в %s" % [runs.size(), out_dir])
	quit()


func _options() -> Dictionary:
	var options := {"seeds": 5, "build": "all", "ticks": TIMEOUT_TICKS, "out": "res://data/logs"}
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if not args[i].begins_with("--") or i + 1 >= args.size():
			continue
		var key := args[i].substr(2)
		if options.has(key):
			options[key] = args[i + 1]
	return options


func _run(seed_text: String, build_name: String, limit: int) -> Dictionary:
	var state := Encounter.dev_room(seed_text, 1, 0)
	var rng_before: Dictionary = state.rng.to_dict()
	var actor := state.actor_of_slot(0)
	_equip(state, build_name)
	_place_enemies(state, seed_text)

	var journal := CommandLog.new()
	var dealt := 0.0
	var taken := 0.0
	var shots := 0
	var hits := 0
	var outcome := "таймаут"

	while state.tick < limit:
		var command := _decide(state, actor)
		journal.record(0, command)
		for event in SimTick.step(state, {0: command}):
			match event["type"]:
				"shot":
					if int(event["actor_id"]) == actor.id:
						shots += 1
				"hit":
					var victim := state.actor_by_id(int(event["actor_id"]))
					if victim == null:
						continue
					if victim.kind == Actor.Kind.ENEMY:
						dealt += float(event["damage"])
						hits += 1
					elif victim.id == actor.id:
						taken += float(event["damage"])
		if state.party_down():
			outcome = "пал"
			break
		if state.room_cleared():
			outcome = "зачистил"
			break

	return {
		"build": build_name,
		"seed": seed_text,
		"strategy": "боец",
		"outcome": outcome,
		"replayable": _replays(seed_text, build_name, journal, state.state_hash()),
		"ticks": state.tick,
		"damage_dealt": dealt,
		"damage_taken": taken,
		"shots": shots,
		"hits": hits,
		"health_end": actor.health,
		"rng_before": rng_before,
		"rng_after": state.rng.to_dict(),
		"journal": journal.to_dict(),
	}


## Лог, который не повторяется покомандно, для баланса бесполезен
## (docs/LEVEL_EDITOR.md): выборка тогда описывает случайность, а не сборку.
func _replays(seed_text: String, build_name: String, journal: CommandLog, expected: int) -> bool:
	var again := Encounter.dev_room(seed_text, 1, 0)
	_equip(again, build_name)
	_place_enemies(again, seed_text)
	SimTick.run_log(again, journal)
	return again.state_hash() == expected


func _equip(state: RunState, build_name: String) -> void:
	var build: Dictionary = BUILDS[build_name]
	var actor := state.actor_of_slot(0)
	var slot = state.slots[0]
	Arsenal.equip(actor, build["weapon"])
	for id in build["organs"]:
		Organs.equip(actor, slot, id)
	for id in build["items"]:
		Items.equip(actor, slot, id)
	actor.heal_to_full()


func _place_enemies(state: RunState, seed_text: String) -> void:
	var scatter := RandomNumberGenerator.new()
	scatter.seed = Fnv.hash_string(seed_text + "/расстановка")
	for i in MONSTERS:
		var angle := scatter.randf_range(0.0, TAU)
		var at := state.actor_of_slot(0).position + Vector2(
			cos(angle) * SPAWN_RING.x * scatter.randf_range(0.6, 1.0),
			sin(angle) * SPAWN_RING.y * scatter.randf_range(0.6, 1.0))
		var record := Bestiary.enemy(ROSTER[i % ROSTER.size()])
		Encounter.add_enemy(state, ROSTER[i % ROSTER.size()],
			state.room.clamp_body(at, float(record.get("radius", 24.0))))


## Одна стратегия на все сборки: держать дистанцию до ближайшего врага и
## стрелять в него по четырём направлениям. Случайности в решениях нет —
## прогон повторяется покомандно из журнала.
func _decide(state: RunState, actor) -> Command:
	var target = _nearest_enemy(state, actor)
	if target == null:
		return Command.from_axes(state.tick, Vector2.ZERO, Vector2.ZERO)

	var offset: Vector2 = target.position - actor.position
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.0 else Vector2.RIGHT
	var move := Vector2.ZERO
	if distance > KEEP_DISTANCE + APPROACH_BAND:
		move = direction
	elif distance < KEEP_DISTANCE - APPROACH_BAND:
		move = -direction
	else:
		move = Vector2(-direction.y, direction.x)
	return Command.from_axes(state.tick, move, Aim.snap(direction), Command.BTN_FIRE)


func _nearest_enemy(state: RunState, actor):
	var nearest = null
	var shortest := INF
	for enemy in state.living(Actor.Kind.ENEMY):
		var distance: float = enemy.position.distance_squared_to(actor.position)
		if distance < shortest:
			shortest = distance
			nearest = enemy
	return nearest


func _write(out_dir: String, run: Dictionary) -> void:
	var name := "%s_%s_%s.json" % [Time.get_datetime_string_from_system().replace(":", "-"),
		run["build"], run["seed"]]
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	if file == null:
		push_error("Не записать лог прогона: " + out_dir.path_join(name))
		return
	file.store_string(JSON.stringify(run, "  "))


func _report(names: Array, runs: Array[Dictionary]) -> void:
	print("")
	print("%-18s %7s %8s %8s %9s %7s" % ["сборка", "зачист", "секунд", "получил", "урон/с", "точн%"])
	for name in names:
		var cleared := 0
		var ticks := 0.0
		var dealt := 0.0
		var taken := 0.0
		var shots := 0.0
		var hits := 0.0
		var count := 0
		for run in runs:
			if run["build"] != name:
				continue
			count += 1
			if run["outcome"] == "зачистил":
				cleared += 1
			ticks += float(run["ticks"])
			dealt += float(run["damage_dealt"])
			taken += float(run["damage_taken"])
			shots += float(run["shots"])
			hits += float(run["hits"])
		if count == 0:
			continue
		print("%-18s %4d/%-2d %8.1f %8.0f %9.1f %7.0f" % [name, cleared, count,
			ticks / count / 60.0, taken / count, dealt * 60.0 / maxf(1.0, ticks),
			100.0 * hits / maxf(1.0, shots)])
