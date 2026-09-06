extends RefCounted

const Pose = preload("res://game/arm_pose.gd")

var _frames := {}
var _meshes := {}


func draw(view: Node2D, actor_id: int, texture: Texture2D, frame: String,
		motion: Transform2D, tint: Color) -> void:
	if not _frames.has(frame) or _frames[frame].texture != texture:
		_frames[frame] = _prepare(texture, frame)
	var data: Dictionary = _frames[frame]
	var vertices: PackedVector3Array = data.vertices.duplicate()
	var indices: PackedInt32Array = data.moving
	var weights: PackedFloat32Array = data.weights
	for i in indices.size():
		var index := indices[i]
		var source := Vector2(vertices[index].x, vertices[index].y)
		var point := source.lerp(motion * source, weights[i])
		vertices[index] = Vector3(point.x, point.y, 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = data.uv
	arrays[Mesh.ARRAY_INDEX] = data.triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# CanvasItem хранит RID до конца кадра, поэтому mesh должен дожить до него.
	_meshes[actor_id] = mesh
	view.draw_texture(data.body, Vector2.ZERO, tint)
	view.draw_mesh(mesh, data.arm, Transform2D.IDENTITY, tint)


func clear() -> void:
	_frames.clear()
	_meshes.clear()


func _prepare(texture: Texture2D, frame: String) -> Dictionary:
	var size := texture.get_size()
	var original := texture.get_image()
	var body := Image.create_empty(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	body.blit_rect(original, Rect2i(Vector2i.ZERO, Vector2i(size)), Vector2i.ZERO)
	var arm := Image.create_empty(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	var bones := Pose.joints(frame)
	var shoulder: Vector2 = bones[0]
	var elbow: Vector2 = bones[1]
	var palm: Vector2 = bones[2]
	var raised := Pose.is_raised(frame)
	var polygon := PackedVector2Array([
		shoulder + Vector2(-9, -6), shoulder + Vector2(4, -4),
		elbow + Vector2(6, 0), palm + Vector2(8, -8),
		palm + Vector2(8, 10), palm + Vector2(-9, 10), elbow + Vector2(-9, 2)])
	if raised:
		polygon = PackedVector2Array([
			shoulder + Vector2(-9, -6), shoulder + Vector2(3, -4),
			elbow + Vector2(10, -10), palm + Vector2(9, -9),
			palm + Vector2(9, 9), elbow + Vector2(-7, 10), shoulder + Vector2(-10, 12)])
	# Под рукавом восстанавливаем закрытую часть рубашки/брюк из соседней
	# колонки того же кадра. Исходные PNG остаются нетронутыми.
	for y in int(size.y):
		for x in int(size.x):
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
				continue
			arm.set_pixel(x, y, original.get_pixel(x, y))
			var fill := Color.TRANSPARENT
			if raised:
				if x >= shoulder.x - 3 and x <= elbow.x + 10 and y >= shoulder.y + 2 and y <= elbow.y + 10:
					fill = original.get_pixel(int(elbow.x + 7), y)
			elif x >= shoulder.x + 3 and y >= shoulder.y + 2:
				fill = original.get_pixel(int(shoulder.x + 11), y)
			body.set_pixel(x, y, fill)
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var moving := PackedInt32Array()
	var weights := PackedFloat32Array()
	var triangles := PackedInt32Array()
	var bounds := arm.get_used_rect().grow(2).intersection(Rect2i(Vector2i.ZERO, Vector2i(size)))
	var columns := ceili(bounds.size.x / 2.0) + 1
	var rows := ceili(bounds.size.y / 2.0) + 1
	for y in rows:
		for x in columns:
			var point := Vector2(bounds.position) + Vector2(x * 2, y * 2)
			var influence := Pose.arm_weight(point, frame)
			if influence > 0.0:
				moving.append(vertices.size())
				weights.append(influence)
			vertices.append(Vector3(point.x, point.y, 0))
			uv.append(point / size)
	for y in rows - 1:
		for x in columns - 1:
			var i := y * columns + x
			triangles.append_array(PackedInt32Array([i, i + 1, i + columns,
				i + 1, i + columns + 1, i + columns]))
	return {"texture": texture, "body": ImageTexture.create_from_image(body),
		"arm": ImageTexture.create_from_image(arm), "vertices": vertices, "uv": uv,
		"moving": moving, "weights": weights, "triangles": triangles}
