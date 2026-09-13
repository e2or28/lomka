extends SceneTree
## Настоящий WorldView: четыре фазы походок и две фазы движущихся гусениц.
## Результат .cache/enemy-tracks-preview.png.
const Arena = preload("res://tests/framework/arena.gd")
const Library = preload("res://game/art_library.gd")
const Gait = preload("res://game/enemy_gait.gd")

class Gallery extends "res://game/world_view.gd":
	var subjects := []
	func _draw() -> void:
		draw_rect(get_viewport_rect(), Color(0.12, 0.13, 0.14))
		for i in subjects.size():
			var actor = subjects[i]
			var at := Vector2(120 + (i % 4) * 200, 165 + (i / 4) * 185)
			if i >= 12: at = Vector2(295 + (i - 12) * 470, 905)
			draw_line(at + Vector2(-65, 0), at + Vector2(65, 0), Color(0.6, 0.65, 0.6, 0.35))
			_draw_sprite(actor, at, Color.WHITE)
			if i % 4 == 0 or i >= 12:
				draw_string(ThemeDB.fallback_font, at + Vector2(-55, 50 if i >= 12 else 28), actor.archetype,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

func _initialize() -> void:
	root.size = Vector2i(1000, 965)
	var gallery = Gallery.new()
	var library = Library.new()
	gallery.state = Arena.duel("enemy-preview", "runner", Vector2(300, 0))
	gallery.state.actors.clear()
	for kind in ["test_monster", "runner", "heavy", "tandem"]:
		gallery.textures[kind] = library.get_texture(kind)
		for column in (2 if kind == "tandem" else 4):
			var temporary = Arena.duel("preview", kind, Vector2(300, 0))
			var actor = Arena.enemies(temporary)[0]
			actor.id = 2000 + gallery.subjects.size()
			actor.aim = Vector2.LEFT
			actor.velocity = Vector2(95, 0)
			actor.cooldown = 0
			gallery.state.actors.append(actor)
			gallery.subjects.append(actor)
	root.add_child(gallery)
	gallery.advance(0.0)
	for i in gallery.subjects.size():
		var actor = gallery.subjects[i]
		actor.position.x += Gait.stride_length(actor.archetype) * (0.08 + (i % 4) * 0.25) if i < 12 else -(i - 11) * 10.0
	gallery.state.tick += 1
	gallery.advance(0.1)
	capture.call_deferred(gallery)

func capture(gallery) -> void:
	root.size = Vector2i(1000, 965)
	gallery.queue_redraw()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.cache")
	root.get_texture().get_image().save_png("res://.cache/enemy-tracks-preview.png")
	print("Preview: .cache/enemy-tracks-preview.png")
	quit()
