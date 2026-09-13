extends RefCounted

const SpriteMesh = preload("res://game/sprite_mesh.gd")
const Harvest = preload("res://sim/harvest.gd")
const ROOT := Vector2(64, 174)
const INSTALL_TIME := 0.7
var installs := {}
var _previous := {}
var _surfaces := {}

func clear() -> void:
	installs.clear()
	_previous.clear()
	_surfaces.clear()

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
		_previous[actor.id] = {"organs": slot.organs.duplicate(),
			"source": corpse.position if corpse != null else actor.position + Vector2(0, 18)}
	for id in _previous.keys():
		if not live.has(id):
			_previous.erase(id)
			installs.erase(id)
			_surfaces.erase(id)

static func pose_point(p: Vector2, bend: float, reach: float) -> Vector2:
	var waist := Vector2(64, 112)
	var upper := 1.0 - smoothstep(100.0, 133.0, p.y)
	var point := p + ((p - waist).rotated(bend * 0.36) - (p - waist)) * upper
	point.y += bend * 17.0 * (1.0 - smoothstep(120.0, 174.0, p.y))
	var arm := smoothstep(76.0, 109.0, p.y) * (1.0 - smoothstep(119.0, 127.0, p.y))
	arm *= 1.0 - smoothstep(55.0, 64.0, p.x)
	point += Vector2(35, 9) * arm * reach
	return point

func draw_pose(view: Node2D, texture: Texture2D, actor_id: int, at: Vector2,
		tint: Color, side: int, bend: float, reach: float) -> bool:
	if texture == null: return false
	if not _surfaces.has(actor_id): _surfaces[actor_id] = SpriteMesh.new()
	var surface = _surfaces[actor_id]
	surface.prepare(texture.get_size(), 2.0)
	var vertices := PackedVector2Array()
	for p in surface.points: vertices.append(pose_point(p, bend, reach) - ROOT)
	view.draw_set_transform(at, 0.0, Vector2(side, 1))
	surface.draw(view, texture, vertices, tint)
	view.draw_set_transform(Vector2.ZERO)
	return true

func draw_actor(view: Node2D, textures: Dictionary, actor, slot, at: Vector2, tint: Color) -> bool:
	if slot.downed: return false
	if slot.harvest_ticks <= 0:
		var pulse := install_pulse(actor.id)
		if pulse <= 0.0 or actor.velocity.length() > 1.0: return false
		return draw_pose(view, textures.get("player_side_stand"), actor.id, at, tint, actor.facing, pulse * 0.18, pulse * 0.3)
	var progress := float(slot.harvest_ticks) / Harvest.DURATION_TICKS
	var bend := smoothstep(0.0, 0.2, progress)
	var reach := bend * (0.8 + sin(progress * TAU * 2) * 0.2)
	return draw_pose(view, textures.get("player_side_stand"), actor.id, at, tint, actor.facing, bend, reach)

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
