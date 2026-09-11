extends SceneTree
## Godot --path . --script res://tools/preview_vertical_gait.gd [-- --frames]
const Gait = preload("res://game/vertical_gait.gd")
const ArtLibrary = preload("res://game/art_library.gd")

class Gallery extends Node2D:
	var gait := Gait.new()
	var textures := {}
	var animated := false
	var phase := 0.0
	func _draw() -> void:
		for row in 4:
			for col in (1 if animated else 8):
				var at := Vector2(70 + col * 118, 180 + row * 204)
				if animated: at = Vector2(90 + (row % 2) * 180, 180 + (row / 2) * 205)
				draw_line(at + Vector2(-45, 0), at + Vector2(45, 0), Color(0.5, 0.6, 0.7, 0.4))
				var frame := Gait.FRONT if row < 2 else Gait.BACK
				var weapon := "suitcase" if row % 2 == 0 else "colt"
				gait.draw(self, textures, row * 8 + col, at, Color.WHITE, frame,
					phase if animated else col * TAU / 8, true, weapon)
				draw_string(ThemeDB.fallback_font, at + Vector2(-35, 18),
					("FRONT" if row < 2 else "BACK") + " " + weapon, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)

var gallery: Gallery
func _initialize() -> void:
	root.size = Vector2i(950, 830)
	gallery = Gallery.new()
	gallery.animated = "--frames" in OS.get_cmdline_user_args()
	if gallery.animated: root.size = Vector2i(360, 410)
	gallery.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var library := ArtLibrary.new()
	for name in [Gait.FRONT, Gait.BACK, "colt", "suitcase"]:
		gallery.textures[name] = library.get_texture(name)
	root.add_child(gallery)
	capture.call_deferred()

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://.cache/vertical-frames")
	for i in (48 if gallery.animated else 1):
		gallery.phase = i * TAU / 24.0
		gallery.queue_redraw()
		await RenderingServer.frame_post_draw
		var path := "res://.cache/vertical-frames/%03d.png" % i if gallery.animated else "res://.cache/vertical-gait-preview.png"
		root.get_texture().get_image().save_png(path)
	print("Vertical gait preview captured")
	quit()
