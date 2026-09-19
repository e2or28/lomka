extends SceneTree
## Зоны урона поверх всех тел — врагов и игрока — через WorldView.

const Arena = preload("res://tests/framework/arena.gd")
const Encounter = preload("res://sim/encounter.gd")
const ArtLibrary = preload("res://game/art_library.gd")
const Hitboxes = preload("res://sim/hitboxes.gd")
const Projectile = preload("res://sim/projectile.gd")

class Gallery extends "res://game/world_view.gd":
	var labels := {}
	func _draw() -> void:
		draw_string(ThemeDB.fallback_font, Vector2(28, 30), "ORANGE: PROJECTILE HITBOX    RED: GROUND COLLISION", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		for actor in state.actors:
			_draw_actor(actor)
			draw_string(ThemeDB.fallback_font, actor.position + Vector2(-35, 45), labels[actor.id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			var shot: Projectile = Projectile.spawn(9999, state.actor_of_slot(0), Vector2.RIGHT, {}, "bullet")
			var start: Vector2 = actor.position + Vector2(-110, -42)
			var end: Vector2 = actor.position + Vector2(110, -42)
			if actor.kind == Actor.Kind.PLAYER:
				start = actor.position + Vector2(-110, -60)
				end = actor.position + Vector2(110, -60)
			if actor.behaviour == "tank":
				start = actor.position + Vector2(-310, -170)
				end = actor.position + Vector2(150, -170)
			var fraction := Hitboxes.hit_fraction(shot, start - shot.flight_offset(), end - shot.flight_offset(), actor)
			if fraction != INF:
				var impact := start.lerp(end, fraction)
				draw_dashed_line(start, impact, Color(0.4, 0.9, 1.0), 2.0, 6.0)
				draw_circle(impact, 5.0, Color(0.4, 0.9, 1.0))

var gallery: Gallery
var art := ArtLibrary.new()

func _initialize() -> void:
	gallery = Gallery.new()
	gallery.state = Arena.solo("hitbox-gallery")
	gallery.show_hitboxes = true
	for file in DirAccess.get_files_at("res://art"):
		if file.ends_with(".png"):
			gallery.textures[file.get_basename()] = art.get_texture(file.get_basename())
	var player := gallery.state.actor_of_slot(0)
	player.position = Vector2(100, 215)
	gallery.labels[player.id] = "clerk"
	for i in 3:
		var id: String = ["test_monster", "runner", "heavy"][i]
		var actor := Encounter.add_enemy(gallery.state, id, Vector2(210 + i * 280, 165))
		gallery.labels[actor.id] = id
	for i in 2:
		var tank := Encounter.add_enemy(gallery.state, "tandem", Vector2(310 + i * 390, 490))
		tank.aim = Vector2.LEFT if i == 0 else Vector2.RIGHT
		gallery.labels[tank.id] = "TANDEM"
	root.add_child(gallery)
	capture.call_deferred()

func capture() -> void:
	root.size = Vector2i(1000, 560)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/hitbox-preview.png")
	print("Hitboxes preview: " + ProjectSettings.globalize_path("res://.cache/hitbox-preview.png"))
	quit()
