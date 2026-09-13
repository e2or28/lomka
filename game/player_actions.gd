extends RefCounted

const CharacterArms = preload("res://game/character_arms.gd")
const SpriteMesh = preload("res://game/sprite_mesh.gd")
const Pickup = preload("res://sim/pickup.gd")
const Harvest = preload("res://sim/harvest.gd")
const ROOT := Vector2(64, 174)
const INSTALL_TIME := 0.7
var installs := {}
var _previous := {}
var _surfaces := {}
var _arm_surfaces := {}
var _parts := {}
var _arms := CharacterArms.new()

func clear() -> void:
	installs.clear()
	_previous.clear()
	_surfaces.clear()
	_arm_surfaces.clear()
	_parts.clear()

func advance(state, delta: float) -> void:
	for id in installs.keys():
		installs[id].age += delta
		if installs[id].age >= INSTALL_TIME: installs.erase(id)
	var live := {}
	for slot in state.slots:
		var actor = state.actor_of_slot(slot.index)
		if actor == null or not slot.occupied: continue
		live[actor.id] = true
		if _previous.has(actor.id):
			var old: Dictionary = _previous[actor.id]
			for socket in slot.organs:
				var organ: String = slot.organs[socket]
				if organ != "" and old.organs.get(socket, "") != organ:
					installs[actor.id] = {"age": 0.0, "organ": organ, "socket": socket, "from": old.source}
		var corpse = state.actor_by_id(slot.harvest_target)
		var pickup = Pickup.nearest(state, actor)
		_previous[actor.id] = {"organs": slot.organs.duplicate(),
			"source": corpse.position if corpse != null else (pickup.position if pickup != null else actor.position + Vector2(0, 18))}
	for id in _previous.keys():
		if not live.has(id):
			_previous.erase(id)
			installs.erase(id)
			_surfaces.erase(id)
			_arm_surfaces.erase(id)

static func pose_point(p: Vector2, bend: float, _reach: float, kneel: float = 0.0) -> Vector2:
	var waist := Vector2(64, 112)
	var upper := 1.0 - smoothstep(100.0, 133.0, p.y)
	var point := p + ((p - waist).rotated(bend * 0.36) - (p - waist)) * upper
	point.y += bend * 17.0 * (1.0 - smoothstep(120.0, 174.0, p.y))
	point.y += kneel * 30.0 * (1.0 - smoothstep(112.0, 174.0, p.y))
	if p.y > 112.0:
		point.x += sin(clampf((p.y - 112.0) / 62.0, 0.0, 1.0) * PI) * kneel * 12.0
	return point

func draw_pose(view: Node2D, texture: Texture2D, actor_id: int, at: Vector2,
		tint: Color, side: int, bend: float, reach: float, kneel: float = 0.0,
		textures: Dictionary = {}, organs: Dictionary = {}) -> bool:
	if texture == null: return false
	var key := texture.get_instance_id()
	if not _parts.has(key):
		_parts[key] = _arms._prepare(texture, "player_side_stand", texture)
	if not _surfaces.has(actor_id):
		_surfaces[actor_id] = SpriteMesh.new()
		_arm_surfaces[actor_id] = SpriteMesh.new()
	var body = _surfaces[actor_id]
	var arm = _arm_surfaces[actor_id]
	body.prepare(texture.get_size(), 3.0)
	arm.prepare(texture.get_size(), 3.0)
	var vertices := PackedVector2Array()
	var arm_vertices := PackedVector2Array()
	var shoulder := Vector2(50, 72)
	var rotation := Transform2D(-0.65 * reach, shoulder - shoulder.rotated(-0.65 * reach))
	for p in body.points:
		vertices.append(pose_point(p, bend, 0.0, kneel) - ROOT)
		arm_vertices.append(pose_point(rotation * p, bend, 0.0, kneel) - ROOT)
	view.draw_set_transform(at, 0.0, Vector2(side, 1))
	draw_organs(view, textures, organs, tint, bend, kneel, true)
	body.draw(view, _parts[key].body, vertices, tint)
	draw_organs(view, textures, organs, tint, bend, kneel, false)
	arm.draw(view, _parts[key].arm, arm_vertices, tint)
	view.draw_set_transform(Vector2.ZERO)
	return true

func draw_actor(view: Node2D, textures: Dictionary, actor, slot, at: Vector2, tint: Color) -> bool:
	if slot.downed: return false
	if slot.harvest_ticks <= 0:
		var pulse := install_pulse(actor.id)
		if pulse <= 0.0 or actor.velocity.length() > 1.0: return false
		return draw_pose(view, textures.get("player_side_stand"), actor.id, at, tint, actor.facing, pulse * 0.18, pulse * 0.3, 0.0, textures, slot.organs)
	var progress := float(slot.harvest_ticks) / Harvest.DURATION_TICKS
	var bend := smoothstep(0.0, 0.2, progress)
	var reach := bend * (0.8 + sin(progress * TAU * 2) * 0.2)
	var source: Vector2 = _previous.get(actor.id, {}).get("source", actor.position + Vector2(actor.facing, 0))
	var side: int = actor.facing if absf(source.x - actor.position.x) < 1.0 else (-1 if source.x < actor.position.x else 1)
	return draw_pose(view, textures.get("player_side_stand"), actor.id, at, tint, side, bend, reach, 0.0, textures, slot.organs)

func install_pulse(actor_id: int, socket: String = "") -> float:
	if not installs.has(actor_id): return 0.0
	var effect: Dictionary = installs[actor_id]
	if socket != "" and effect.socket != socket: return 0.0
	return sin(clampf(effect.age / INSTALL_TIME, 0.0, 1.0) * PI)

func draw_install(view: Node2D, textures: Dictionary, actor, at: Vector2, origin: Vector2) -> void:
	if not installs.has(actor.id): return
	var effect: Dictionary = installs[actor.id]
	var progress := clampf(float(effect.age) / INSTALL_TIME, 0.0, 1.0)
	var chest := at + Vector2(actor.facing * 5, -89)
	var from: Vector2 = origin + effect.from - Vector2(0, 12)
	var position := from.lerp(chest, smoothstep(0.0, 0.65, progress))
	position.y -= sin(minf(1.0, progress / 0.65) * PI) * 25
	var texture: Texture2D = textures.get(effect.organ)
	var fade := 1.0 - smoothstep(0.65, 1.0, progress)
	if texture != null:
		var size := texture.get_size() * (28.0 / texture.get_height())
		view.draw_texture_rect(texture, Rect2(position - size * 0.5, size), false, Color(1, 1, 1, fade))
	var pulse := install_pulse(actor.id)
	view.draw_arc(chest, 8 + progress * 15, 0, TAU, 24, Color(0.83, 0.46, 0.35, pulse * 0.65), 2)

static func draw_organs(view: Node2D, textures: Dictionary, organs: Dictionary, tint: Color,
		bend: float, kneel: float, behind: bool) -> void:
	var id: String = organs.get("spine" if behind else "heart", "")
	var texture: Texture2D = textures.get(id)
	if texture == null: return
	var anchor := Vector2(42, 89) if behind else Vector2(73, 83)
	var at := pose_point(anchor, bend, 0.0, kneel) - ROOT
	var size := texture.get_size() * ((64.0 if behind else 28.0) / texture.get_height())
	view.draw_texture_rect(texture, Rect2(at - size * 0.5, size), false, tint)
