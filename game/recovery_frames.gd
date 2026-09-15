extends RefCounted
const SpriteMesh = preload("res://game/sprite_mesh.gd")
const ROOT := Vector2(64, 174)
const NAMES := ["player_support", "player_kneel", "player_reach", "player_crouch"]
var _surfaces := {}

func clear() -> void:
	_surfaces.clear()

static func rise_pose(age: float) -> Dictionary:
	var names := ["", "player_support", "player_kneel", "player_crouch", "player_side_stand"]
	var times := [0.0, 0.08, 0.23, 0.41, 0.55]
	var index := 0
	for i in times.size():
		if age >= times[i]: index = i
	var next := mini(index + 1, names.size() - 1)
	var blend := 0.0 if next == index else smoothstep(maxf(times[index], times[next] - 0.045), times[next], age)
	return {"from": names[index], "to": names[next], "blend": blend}

func draw(view: Node2D, textures: Dictionary, actor_id: int, at: Vector2,
		tint: Color, side: int, frame: String, work: float = 0.0, organs: Dictionary = {}) -> bool:
	var texture: Texture2D = textures.get(frame)
	if texture == null: return false
	view.draw_set_transform(at, 0, Vector2(side, 1))
	var chest := Vector2(83, 124) if frame == "player_reach" else Vector2(76, 116)
	if frame == "player_crouch": chest = Vector2(70, 103)
	elif frame == "player_support": chest = Vector2(76, 151)
	elif frame == "player_side_stand": chest = Vector2(73, 83)
	organ(view, textures, organs.get("spine", ""), chest + Vector2(-22, 3), 52, tint)
	if frame == "player_reach" and work != 0:
		if not _surfaces.has(actor_id): _surfaces[actor_id] = SpriteMesh.new()
		var surface = _surfaces[actor_id]
		surface.prepare(texture.get_size(), 3.0)
		var points := PackedVector2Array()
		for p in surface.points:
			var wrist := smoothstep(87, 115, p.x) * smoothstep(123, 150, p.y)
			points.append(p - ROOT + Vector2(work * 1.6, work * 0.9) * wrist)
		surface.draw(view, texture, points, tint)
	else:
		view.draw_texture(texture, -ROOT, tint)
	organ(view, textures, organs.get("heart", ""), chest, 24, tint)
	view.draw_set_transform(Vector2.ZERO)
	return true

static func organ(view: Node2D, textures: Dictionary, id: String, at: Vector2, height: float, tint: Color) -> void:
	var texture: Texture2D = textures.get(id)
	if texture == null: return
	var size := texture.get_size() * height / texture.get_height()
	view.draw_texture_rect(texture, Rect2(at - ROOT - size * 0.5, size), false, tint)
