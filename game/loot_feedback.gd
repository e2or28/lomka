extends RefCounted

const LootArt = preload("res://game/loot_art.gd")
const Pickup = preload("res://sim/pickup.gd")
var births := {}
var takes: Array[Dictionary] = []
var switches := {}
var _pickups := {}
var _players := {}
var _initialized := false

func clear() -> void:
	births.clear()
	takes.clear()
	switches.clear()
	_pickups.clear()
	_players.clear()
	_initialized = false

func advance(state, delta: float) -> void:
	for id in births.keys():
		births[id] += delta
		if births[id] >= 0.6: births.erase(id)
	for take in takes: take.age += delta
	takes = takes.filter(func(t): return t.age < 0.3)
	for id in switches.keys():
		switches[id].age += delta
		if switches[id].age >= 0.24: switches.erase(id)
	var players := {}
	for slot in state.slots:
		var actor = state.actor_of_slot(slot.index)
		if actor == null or not slot.occupied: continue
		players[actor.id] = {"weapon": actor.weapon_id, "organs": slot.organs.duplicate(),
			"items": slot.items.duplicate(), "position": actor.position, "cover": slot.cover_ticks > 0}
		if _players.has(actor.id):
			var old: Dictionary = _players[actor.id]
			if old.weapon != actor.weapon_id and old.weapon != "" and actor.weapon_id != "" and not old.cover and slot.cover_ticks <= 0:
				switches[actor.id] = {"age": 0.0, "from": old.weapon}
	var current := {}
	for pickup in state.pickups:
		current[pickup.id] = pickup.to_dict()
		if _initialized and (not _pickups.has(pickup.id) or _pickups[pickup.id].content_id != pickup.content_id):
			births[pickup.id] = 0.0
	if _initialized:
		for id in _pickups:
			var old: Dictionary = _pickups[id]
			if current.has(id) and current[id].content_id == old.content_id: continue
			var recipient := receiver(old, players, _players)
			if recipient >= 0:
				takes.append({"pickup": Pickup.from_dict(old), "actor": recipient, "age": 0.0})
	_pickups = current
	_players = players
	_initialized = true
	for id in switches.keys():
		if not players.has(id): switches.erase(id)

static func receiver(pickup: Dictionary, players: Dictionary, previous: Dictionary) -> int:
	for id in players:
		if not previous.has(id): continue
		var now: Dictionary = players[id]
		var old: Dictionary = previous[id]
		if Vector2(now.position).distance_to(pickup.position) > 120.0: continue
		match pickup.kind:
			Pickup.KIND_WEAPON:
				if now.weapon == pickup.content_id and old.weapon != now.weapon: return id
			Pickup.KIND_ORGAN:
				for socket in now.organs:
					if now.organs[socket] == pickup.content_id and old.organs.get(socket) != pickup.content_id: return id
			Pickup.KIND_ITEM:
				if now.items.count(pickup.content_id) > old.items.count(pickup.content_id): return id
	return -1

static func bounce(age: float) -> float:
	if age < 0.0 or age >= 0.6: return 0.0
	var progress := age / 0.6
	return -absf(sin(progress * TAU)) * 15.0 * (1.0 - progress)

func draw_pickup(view: Node2D, textures: Dictionary, pickup, at: Vector2, highlighted: bool, key: String) -> void:
	var lift := bounce(float(births.get(pickup.id, -1.0)))
	LootArt.draw(view, textures, pickup, at, highlighted, key, lift)

func draw_takes(view: Node2D, textures: Dictionary, state, origin: Vector2) -> void:
	for take in takes:
		if take.pickup.kind == Pickup.KIND_ORGAN: continue
		var actor = state.actor_by_id(take.actor)
		if actor == null: continue
		var progress := clampf(float(take.age) / 0.3, 0.0, 1.0)
		var at: Vector2 = origin + take.pickup.position.lerp(actor.position + Vector2(actor.facing * 6, -57), smoothstep(0, 1, progress))
		var scale := 1.0 - progress * 0.7
		var texture: Texture2D = textures.get(take.pickup.content_id + "_ground", textures.get(take.pickup.content_id))
		if texture != null:
			var size := texture.get_size() * (32.0 / texture.get_height()) * scale
			view.draw_texture_rect(texture, Rect2(at - size * 0.5, size), false, Color(1, 1, 1, 1.0 - progress))
		else:
			view.draw_set_transform(at, progress * 0.3, Vector2.ONE * scale)
			view.draw_rect(Rect2(-9, -11, 18, 22), Color(0.93, 0.88, 0.72, 1.0 - progress))
			view.draw_set_transform(Vector2.ZERO)

func switch_progress(actor_id: int) -> float:
	return clampf(float(switches[actor_id].age) / 0.24, 0.0, 1.0) if switches.has(actor_id) else -1.0
