extends RefCounted

static func draw_ground(view: Node2D, textures: Dictionary, id: String, at: Vector2) -> bool:
	var texture: Texture2D = textures.get(id)
	if texture == null:
		return false
	var height := 44.0 if id == "courier_heart" else 60.0
	var size := texture.get_size() * (height / texture.get_height())
	var angle := -0.2 if id == "courier_heart" else -1.05
	view.draw_set_transform(at, angle, Vector2.ONE)
	view.draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func draw_body(view: Node2D, textures: Dictionary, organs: Dictionary,
		canvas: Vector2, side: int, tint: Color, time: float, behind: bool) -> void:
	var id: String = organs.get("spine" if behind else "heart", "")
	var texture: Texture2D = textures.get(id)
	if texture == null:
		return
	# Привязки к груди и спине на общем холсте 128×192, не к ногам в мире.
	var at := Vector2(42, 89) if behind else Vector2(73, 83)
	var height := 64.0 if behind else 28.0
	if side == 0:
		at = Vector2(64, 88) if behind else Vector2(72, 82)
	if not behind:
		var beat := pow(maxf(0.0, sin(time * TAU * 1.8)), 6.0)
		height *= 1.0 + beat * 0.12
	var size := texture.get_size() * (height / texture.get_height())
	var mirror := -1.0 if side < 0 else 1.0
	view.draw_set_transform(canvas + Vector2(128 if side < 0 else 0, 0), 0, Vector2(mirror, 1))
	view.draw_texture_rect(texture, Rect2(at - size * 0.5, size), false, tint)
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
