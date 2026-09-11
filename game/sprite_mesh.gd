extends RefCounted

var points := PackedVector2Array()
var uv := PackedVector2Array()
var indices := PackedInt32Array()
var size := Vector2.ZERO
var mesh := ArrayMesh.new()

func prepare(dimensions: Vector2, spacing: float = 5.0) -> void:
	if size == dimensions: return
	size = dimensions
	points.clear()
	uv.clear()
	indices.clear()
	var columns := ceili(size.x / spacing) + 1
	var rows := ceili(size.y / spacing) + 1
	for y in rows:
		for x in columns:
			var p := Vector2(minf(x * spacing, size.x), minf(y * spacing, size.y))
			points.append(p)
			uv.append(p / size)
	for y in rows - 1:
		for x in columns - 1:
			var i := y * columns + x
			indices.append_array(PackedInt32Array([i, i + 1, i + columns, i + 1, i + columns + 1, i + columns]))

func draw(view: Node2D, texture: Texture2D, vertices: PackedVector2Array, tint: Color) -> void:
	var positions := PackedVector3Array()
	for p in vertices: positions.append(Vector3(p.x, p.y, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	view.draw_mesh(mesh, texture, Transform2D.IDENTITY, tint)
