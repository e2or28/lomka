extends SceneTree
const Arena = preload("res://tests/framework/arena.gd")
const Encounter = preload("res://sim/encounter.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Library = preload("res://game/art_library.gd")
const Sandbox = preload("res://game/dev_sandbox.gd")
const Blast = preload("res://game/barrel_blast.gd")
class Gallery extends "res://game/world_view.gd":
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 2000, 920), Color(0.14, 0.13, 0.12))
		for i in 4:
			var actor = state.actor_of_slot(i)
			actor.position = Vector2(250 + i * 500, 210)
			actor.velocity = Vector2(0, -200 if i % 2 == 0 else 200)
			actor.aim = actor.velocity.normalized()
			firing[actor.id] = true
			stride_phase[actor.id] = PI * (0.5 if i % 2 == 0 else 1.5)
			_draw_actor(actor)
			draw_string(ThemeDB.fallback_font, actor.position + Vector2(-75, 26), ["COLT UP", "COLT DOWN", "CASE UP", "CASE DOWN"][i])
		for i in 4:
			var actor = state.actors[4 + i]
			actor.position = Vector2(250 + i * 500, 465)
			actor.alive = i == 0
			helicopter.ages[actor.id] = [0.0, 0.4, 0.75, 1.8][i]
			helicopter._phases[actor.id] = 0.5 + i * 0.5
			_draw_actor(actor)
		for i in 5:
			var at := Vector2(200 + i * 400, 740)
			Blast.draw(self, at, [0.03, 0.15, 0.35, 0.75, 1.4][i], 140)
			draw_string(ThemeDB.fallback_font, at + Vector2(-30, 80), ["FLASH", "FIRE", "DEBRIS", "SMOKE", "FADE"][i])
var gallery
func _initialize() -> void:
	root.size = Vector2i(1400, 880)
	gallery = Gallery.new()
	gallery.scale = Vector2(0.7, 0.7)
	gallery.state = Arena.room("polish-preview", 4, 0)
	for i in 4:
		Arsenal.equip(gallery.state.actor_of_slot(i), "colt" if i < 2 else "suitcase")
		Encounter.add_enemy(gallery.state, "gunship", Vector2.ZERO)
	var library := Library.new()
	for name in Sandbox.SPRITES:
		var texture = library.get_texture(name)
		if texture != null: gallery.textures[name] = texture
	root.add_child(gallery)
	capture.call_deferred()
func capture() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cache/combat-polish.png")
	print("COMBAT POLISH PREVIEW OK")
	quit()
