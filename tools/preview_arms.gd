extends SceneTree
## Визуальная проверка реального WorldView: стойка, шаг, атака, зеркало, анфас.
## Godot --path . --script res://tools/preview_arms.gd

const Actor = preload("res://sim/actor.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const ArtLibrary = preload("res://game/art_library.gd")

class Gallery extends "res://game/world_view.gd":
	var labels := ["IDLE", "STEP 1", "STEP 4", "ATTACK", "RETURN", "LEFT", "FRONT"]
	var actors: Array = []
	func _draw() -> void:
		for i in actors.size():
			var col := i % 7
			var row := i / 7
			var at := Vector2(66 + col * 133, 205 + row * 225)
			_draw_player(actors[i], at, Color.WHITE)
			draw_string(ThemeDB.fallback_font, at + Vector2(-40, 20), labels[col], HORIZONTAL_ALIGNMENT_LEFT, -1, 9)

var gallery: Gallery
var library := ArtLibrary.new()

func _initialize() -> void:
	gallery = Gallery.new()
	gallery.scale = Vector2(1.5, 1.5)
	gallery.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for file in DirAccess.get_files_at("res://art"):
		if file.ends_with(".png"):
			var name := file.get_basename()
			gallery.textures[name] = library.get_texture(name)
	for weapon in ["suitcase", "colt"]:
		for col in 7:
			var actor := Actor.new()
			actor.id = gallery.actors.size() + 1
			actor.kind = Actor.Kind.PLAYER
			actor.aim = Vector2.LEFT if col == 5 else Vector2.RIGHT
			Arsenal.equip(actor, weapon)
			gallery.actors.append(actor)
			gallery.stride_phase[actor.id] = 0.0 if col != 2 else PI
			gallery.facing[actor.id] = -1 if col == 5 else 1
			gallery.standing_front[actor.id] = col == 6
			if col in [1, 2]:
				actor.velocity = Vector2(260, 0)
			if col in [3, 4, 5]:
				var progress := 0.5 if col == 4 else 0.18
				gallery.feedback.shots[actor.id] = {"age": progress * 0.18, "weapon": weapon, "kind": Arsenal.projectile_of(actor)}
	root.add_child(gallery)
	capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.cache")
	var path := "res://.cache/arms-preview.png"
	root.get_texture().get_image().save_png(path)
	print("Arms preview: " + ProjectSettings.globalize_path(path))
	quit()
