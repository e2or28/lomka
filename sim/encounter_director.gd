extends RefCounted
## Состав и расстановка зависят от комнаты и сида, а не от порядка обхода.
## Оставшиеся волны и уже объявленные точки — часть состояния забега.
const Encounter = preload("res://sim/encounter.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Actor = preload("res://sim/actor.gd")
const Fnv = preload("res://sim/core/fnv.gd")
const RoomMap = preload("res://sim/room_map.gd")
const TELEGRAPH_TICKS := 90
const SAFE_DISTANCE := 220.0

static func _rng(state, suffix: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Fnv.hash_string(state.run_seed + "/encounter/" + state.room.id + "/" + suffix)
	return rng

static func begin(state) -> void:
	state.pending_spawns.clear()
	state.encounter_waves.clear()
	var rng := _rng(state, "initial")
	var roster: Array = []
	var wave: Array = []
	match state.room.id:
		"south": return
		"oil_baron":
			var roster_ids: Array = RoomMap.ROSTERS["oil_baron"]
			var positions := [Vector2(0, 20), Vector2(-340, -140), Vector2(340, -140),
				Vector2(-350, 100), Vector2(350, 100)]
			for i in roster_ids.size():
				var at: Vector2 = positions[i]
				if not _safe_from_players(state, at):
					at = _position(state, rng, float(Bestiary.enemy(roster_ids[i]).radius), [])
				if at != Vector2.INF: Encounter.add_enemy(state, roster_ids[i], at)
			# Бочки стоят по краям площадки: попал — рвануло, и достаётся
			# тому, кто рядом, кем бы он ни был.
			for at in [Vector2(-380, -60), Vector2(380, -60), Vector2(-300, 240), Vector2(300, 240)]:
				Encounter.add_enemy(state, "barrel", at)
			return
		"north": roster = ["tandem"]
		"center":
			roster = ["test_monster", "runner", "heavy"]
			wave = ["runner" if rng.randi_range(0, 1) == 0 else "test_monster"]
		"west":
			roster = ["runner", "runner", "test_monster" if rng.randi_range(0, 1) else "runner"]
			wave = ["runner"]
		"east":
			roster = ["heavy", "test_monster"]
			wave = ["heavy" if rng.randi_range(0, 1) == 0 else "test_monster"]
		_: return
	if state.room.id != "north":
		# Четверо получают на два тела больше, а не четырёхкратную толпу.
		if state.occupied_count() >= 2: roster.append("runner" if state.room.id == "west" else "test_monster")
		if state.occupied_count() >= 4: wave.append("runner" if state.room.id != "east" else "heavy")
	for id in roster:
		var radius := float(Bestiary.enemy(id).get("radius", 20.0))
		var at := _position(state, rng, radius, [])
		if at != Vector2.INF: Encounter.add_enemy(state, id, at)
	if not wave.is_empty(): state.encounter_waves.append(wave)

static func advance(state, events: Array[Dictionary]) -> void:
	if state.party_down(): return
	var remaining: Array[Dictionary] = []
	for pending in state.pending_spawns:
		if state.tick < int(pending.spawn_tick):
			remaining.append(pending)
			continue
		if not _safe_from_players(state, pending.position):
			var radius := float(Bestiary.enemy(pending.id).get("radius", 20.0))
			var at := _position(state, _rng(state, "relocate/%d" % state.tick), radius, state.pending_spawns + remaining)
			var delayed: Dictionary = pending.duplicate()
			if at != Vector2.INF: delayed.position = at
			delayed.spawn_tick = state.tick + TELEGRAPH_TICKS
			remaining.append(delayed)
			events.append({"type": "wave_warning", "count": 1, "spawn_tick": delayed.spawn_tick})
			continue
		var actor = Encounter.add_enemy(state, pending.id, pending.position)
		events.append({"type": "enemy_spawned", "actor_id": actor.id, "position": actor.position})
	state.pending_spawns = remaining
	if not state.pending_spawns.is_empty() or state.encounter_waves.is_empty() \
			or not state.living(Actor.Kind.ENEMY).is_empty(): return
	var roster: Array = state.encounter_waves.pop_front()
	var rng := _rng(state, "reinforcement")
	for id in roster:
		var radius := float(Bestiary.enemy(id).get("radius", 20.0))
		var at := _position(state, rng, radius, state.pending_spawns)
		if at == Vector2.INF: continue
		state.pending_spawns.append({"id": id, "position": at, "spawn_tick": state.tick + TELEGRAPH_TICKS})
	if not state.pending_spawns.is_empty():
		events.append({"type": "wave_warning", "count": state.pending_spawns.size(),
			"spawn_tick": state.tick + TELEGRAPH_TICKS})

## Игрок мог занять отмеченное место за время предупреждения. Перенос
## всегда запускает полный новый отсчёт и повторяется, пока точка занята.
static func _safe_from_players(state, at: Vector2) -> bool:
	for player in state.living(Actor.Kind.PLAYER):
		if player.position.distance_to(at) < SAFE_DISTANCE: return false
	return true

## Сначала случайные точки, затем конечная сетка: не зависаем при тесной
## планировке. Небезопасное тело лучше пропустить, чем создать в игроке.
static func _position(state, rng: RandomNumberGenerator, radius: float, pending: Array) -> Vector2:
	var limits: Rect2 = state.room.bounds.grow(-radius - 24.0)
	for i in 336:
		var at := Vector2(rng.randf_range(limits.position.x, limits.end.x), rng.randf_range(limits.position.y, limits.end.y))
		if i >= 192:
			at = limits.position + limits.size * Vector2(float((i - 192) % 12) / 11.0, float((i - 192) / 12) / 11.0)
		if not state.room.clamp_body(at, radius).is_equal_approx(at): continue
		var safe := true
		for actor in state.actors:
			if not actor.alive: continue
			var reach: float = SAFE_DISTANCE if actor.kind == Actor.Kind.PLAYER else actor.radius + radius + 40.0
			if actor.position.distance_to(at) < reach:
				safe = false
				break
		for entry in pending:
			if at.distance_to(entry.position) < radius * 2 + 60: safe = false
		if safe: return at
	return Vector2.INF
