extends SceneTree
## Цикл езды, предупреждения и отдачи через настоящий WorldView.
## Снимок: .cache/tank-preview.png; с -- --frames пишет 120 кадров для клипа.

const Arena = preload("res://tests/framework/arena.gd")
const ArtLibrary = preload("res://game/art_library.gd")
const Miniboss = preload("res://sim/miniboss.gd")

class Gallery extends "res://game/world_view.gd":
	var tank
	var time := 0.0
	func _draw() -> void:
		breath = time
		var label := "MOVING"
		tank.velocity = Vector2(45, 0)
		tank.attack_ticks = 0
		tank.cooldown = 0.6
		if time >= 1.0 and time < 1.9:
			label = "AIMING"
			tank.velocity = Vector2.ZERO
			tank.attack_ticks = maxi(1, roundi((1.9 - time) * 60))
		elif time >= 1.9:
			label = "RECOIL" if time < 2.4 else "RECOVERED"
			tank.velocity = Vector2.ZERO
			tank.cooldown = Miniboss.RECOVERY - (time - 1.9)
		for side in 2:
			tank.id = 10000 + side
			tank.aim = Vector2.LEFT if side == 0 else Vector2.RIGHT
			var at := Vector2(315 if side == 0 else 700, 280)
			draw_line(at + Vector2(-280, 23), at + Vector2(155, 23), Color(0.6, 0.7, 0.6, 0.3))
			_draw_sprite(tank, at, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(390, 340), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

var gallery: Gallery
var art := ArtLibrary.new()

func _initialize() -> void:
	root.size = Vector2i(1000, 380)
	gallery = Gallery.new()
	gallery.state = Arena.duel("tank-preview", "tandem", Vector2(320, 0))
	gallery.tank = Arena.enemies(gallery.state)[0]
	gallery.textures["tandem"] = art.get_texture("tandem")
	root.add_child(gallery)
	capture.call_deferred()

func capture() -> void:
	root.size = Vector2i(1000, 380)
	var movie := "--frames" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://.cache/tank-frames")
	for i in (120 if movie else 1):
		gallery.time = i / 30.0 if movie else 1.96
		gallery.queue_redraw()
		await RenderingServer.frame_post_draw
		var path := "res://.cache/tank-frames/%03d.png" % i if movie else "res://.cache/tank-preview.png"
		root.get_texture().get_image().save_png(path)
	print("Tank preview: " + ProjectSettings.globalize_path("res://.cache"))
	quit()
