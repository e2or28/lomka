extends SceneTree
## Весь цикл через WorldView: проверка лица, пояса, стоп и хвата на обе стороны.

const CharacterPose = preload("res://game/character_pose.gd")
const Actor = preload("res://sim/actor.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const ArtLibrary = preload("res://game/art_library.gd")

class Gallery extends "res://game/world_view.gd":
	var actors: Array = []
	var animated := false
	func _draw() -> void:
		for i in actors.size():
			var col := i % 7
			var row := i / 7
			if animated and col != 0:
				continue
			var at := Vector2(68 + col * 138, 186 + row * 205)
			if animated:
				at = Vector2(150 + (row % 2) * 260, 200 + (row / 2) * 230)
			draw_line(at + Vector2(-60, 0), at + Vector2(60, 0), Color(0.6, 0.7, 0.6, 0.25))
			_draw_player(actors[i], at, Color.WHITE)
			draw_string(ThemeDB.fallback_font, at + Vector2(-35, 18),
				actors[i].weapon_id if animated else ("IDLE" if col == 0 else "STEP %d" % col), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)

var gallery: Gallery
var library := ArtLibrary.new()

func _initialize() -> void:
	root.size = Vector2i(980, 830)
	gallery = Gallery.new()
	gallery.scale = Vector2.ONE
	gallery.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for file in DirAccess.get_files_at("res://art"):
		if file.ends_with(".png"):
			gallery.textures[file.get_basename()] = library.get_texture(file.get_basename())
	for row in 4:
		for col in 7:
			var actor := Actor.new()
			actor.id = gallery.actors.size() + 1
			actor.kind = Actor.Kind.PLAYER
			Arsenal.equip(actor, "suitcase" if row % 2 == 0 else "colt")
			gallery.actors.append(actor)
			gallery.stride_phase[actor.id] = TAU * (col - 0.9) / 6.0
			gallery.facing[actor.id] = 1 if row < 2 else -1
			if col > 0:
				actor.velocity = Vector2(260 if row < 2 else -260, 0)
	root.add_child(gallery)
	capture.call_deferred()

func capture() -> void:
	gallery.animated = "--frames" in OS.get_cmdline_user_args()
	root.size = Vector2i(560, 470) if gallery.animated else Vector2i(980, 830)
	DirAccess.make_dir_recursive_absolute("res://.cache/walk-frames")
	for i in (60 if gallery.animated else 1):
		if gallery.animated:
			for actor in gallery.actors:
				actor.velocity = Vector2(260 * gallery.facing[actor.id], 0)
				gallery.stride_phase[actor.id] = fmod(i / 30.0 * 260.0 / CharacterPose.STRIDE * TAU, TAU)
		gallery.queue_redraw()
		await RenderingServer.frame_post_draw
		var path := "res://.cache/walk-frames/%03d.png" % i if gallery.animated else "res://.cache/walk-preview.png"
		root.get_texture().get_image().save_png(path)
	print("Walk preview: " + ProjectSettings.globalize_path("res://.cache/walk-preview.png"))
	quit()
