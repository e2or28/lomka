extends RefCounted

const SpriteMesh = preload("res://game/sprite_mesh.gd")
const RISE_TIME := 0.6
var rising := {}
var _downed := {}
var _surfaces := {}

func clear() -> void:
	rising.clear()
	_downed.clear()
	_surfaces.clear()

func advance(state, delta: float) -> void:
	for id in rising.keys():
		rising[id] += delta
		if rising[id] >= RISE_TIME: rising.erase(id)
	var live := {}
	for slot in state.slots:
		var actor = state.actor_of_slot(slot.index)
		if actor == null or not slot.occupied: continue
		live[actor.id] = true
		if bool(_downed.get(actor.id, false)) and not slot.downed and actor.alive:
			rising[actor.id] = 0.0
		if slot.downed: rising.erase(actor.id)
		_downed[actor.id] = slot.downed
	for id in _downed.keys():
		if not live.has(id):
			_downed.erase(id)
			rising.erase(id)
			_surfaces.erase(id)

static func downed_point(p: Vector2, time: float) -> Vector2:
	var chest := smoothstep(58.0, 74.0, p.y) * (1.0 - smoothstep(102.0, 116.0, p.y))
	p.x += sin(time * 2.5) * 0.65 * chest
	if p.y > 115.0 and p.x < 65.0:
		p.x -= sin(clampf((p.y - 115.0) / 59.0, 0.0, 1.0) * PI) * 13.0
	return p

func draw_downed(view: Node2D, texture: Texture2D, actor, at: Vector2,
		tint: Color, time: float, fall: float) -> bool:
	if texture == null: return false
	if not _surfaces.has(actor.id): _surfaces[actor.id] = SpriteMesh.new()
	var surface = _surfaces[actor.id]
	surface.prepare(texture.get_size(), 3.0)
	var vertices := PackedVector2Array()
	for p in surface.points: vertices.append(p.lerp(downed_point(p, time), fall) - Vector2(64, 95))
	var center := at + Vector2(0, lerpf(-79.0, -13.0, fall))
	view.draw_set_transform(center, actor.facing * PI * 0.5 * fall, Vector2(1, lerpf(1.0, 0.85, fall)))
	surface.draw(view, texture, vertices, tint)
	view.draw_set_transform(Vector2.ZERO)
	return true

func draw_helper(view: Node2D, textures: Dictionary, actor, slot, at: Vector2,
		tint: Color, poses, target) -> bool:
	if slot.revive_target < 0 or target == null: return false
	var bend := smoothstep(0.0, 16.0, slot.revive_ticks)
	var reach := bend * (0.8 + sin(float(slot.revive_ticks) * 0.16) * 0.15)
	var side := -1 if target.position.x < actor.position.x else 1
	return poses.draw_pose(view, textures.get("player_side_stand"), actor.id, at, tint, side, bend * 1.1, reach, bend)

func draw_rising(view: Node2D, textures: Dictionary, actor, at: Vector2, tint: Color, poses) -> bool:
	if not rising.has(actor.id): return false
	var texture: Texture2D = textures.get("player_side_stand")
	if texture == null: return false
	if not _surfaces.has(actor.id): _surfaces[actor.id] = SpriteMesh.new()
	var surface = _surfaces[actor.id]
	surface.prepare(texture.get_size(), 3.0)
	var progress := clampf(float(rising[actor.id]) / RISE_TIME, 0.0, 1.0)
	var kneel := 1.0 - smoothstep(0.45, 1.0, progress)
	var vertices := PackedVector2Array()
	var prone := Transform2D(actor.facing * PI * 0.5, Vector2(1, 0.85), 0.0, Vector2(0, -13))
	for p in surface.points:
		var lying: Vector2 = prone * (downed_point(p, 0.0) - Vector2(64, 95))
		var standing: Vector2 = poses.pose_point(p, kneel * 1.1, kneel, kneel) - Vector2(64, 174)
		standing.x *= actor.facing
		vertices.append(lying.lerp(standing, smoothstep(0.0, 0.45, progress)))
	view.draw_set_transform(at)
	surface.draw(view, texture, vertices, tint)
	view.draw_set_transform(Vector2.ZERO)
	return true
