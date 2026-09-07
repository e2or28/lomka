extends SceneTree
## Контрольный рендер направлений, дула, попаданий и падения через WorldView.

const Projectile = preload("res://sim/projectile.gd")
const Actor = preload("res://sim/actor.gd")
const RunState = preload("res://sim/run_state.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const ArtLibrary = preload("res://game/art_library.gd")

class Gallery extends "res://game/world_view.gd":
	var labels := []
	func _draw() -> void:
		for i in state.actors.size():
			var actor = state.actors[i]
			_draw_actor(actor)
			draw_string(ThemeDB.fallback_font, actor.position + Vector2(-42, 26), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		for projectile in state.projectiles:
			_draw_projectile(projectile)
		feedback.draw_impacts(self, Vector2.ZERO)

var gallery: Gallery
var library := ArtLibrary.new()

func _initialize() -> void:
	gallery = Gallery.new()
	gallery.scale = Vector2(1.3, 1.3)
	gallery.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gallery.state = RunState.new("preview")
	gallery.consume_events([])
	for file in DirAccess.get_files_at("res://art"):
		if file.ends_with(".png"):
			gallery.textures[file.get_basename()] = library.get_texture(file.get_basename())
	var directions := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for weapon in ["colt", "suitcase"]:
		for col in 4:
			var row := 0 if weapon == "colt" else 1
			var actor := Actor.new(gallery.state.take_id())
			actor.position = Vector2(90 + col * 190, 205 + row * 230)
			actor.health = 100
			actor.stack.base = {"health": 100.0}
			actor.aim = directions[col]
			Arsenal.equip(actor, weapon)
			gallery.state.actors.append(actor)
			gallery.labels.append(weapon + " / " + ["RIGHT", "LEFT", "UP", "DOWN"][col])
			gallery.firing[actor.id] = true
			gallery.consume_events([{"type": "shot", "actor_id": actor.id,
				"room_id": "", "position": actor.position, "aim": actor.aim, "direction": actor.aim,
				"weapon": weapon, "kind": "bullet" if weapon == "colt" else "folder", "projectile_id": 100 + actor.id}])
			gallery.feedback.shots[actor.id].age = 0.032
			var projectile = Projectile.spawn(100 + actor.id, actor, actor.aim, actor.stack.compute(), Arsenal.projectile_of(actor))
			projectile.position += actor.aim * 55
			projectile.travelled = 55
			gallery.state.projectiles.append(projectile)
	for col in 4:
		var actor := Actor.new(gallery.state.take_id(), Actor.Kind.ENEMY)
		actor.position = Vector2(90 + col * 190, 600)
		actor.stack.base = {"health": 100.0}
		actor.health = 76
		actor.archetype = "monster"
		gallery.state.actors.append(actor)
		var kind := "bullet" if col == 0 else "folder"
		var fallen := col >= 2
		actor.alive = not fallen
		gallery.labels.append(["BULLET HIT", "PAPER HIT", "FALL", "LANDED"][col])
		gallery.consume_events([{"type": "hit", "actor_id": actor.id, "room_id": "",
			"position": actor.position, "direction": Vector2.LEFT, "kind": kind, "fallen": fallen}])
		var age := 0.04 if col < 2 else (0.16 if col == 2 else 0.4)
		gallery.feedback.hits[actor.id].age = age
		gallery.feedback.impacts[-1].age = age
		if fallen:
			gallery.feedback.falls[actor.id].age = age
	for i in 3:
		var actor := Actor.new(gallery.state.take_id())
		actor.position = Vector2(850, [205, 435, 600][i])
		actor.stack.base = {"health": 100.0}
		actor.health = 72.0 if i == 0 else 0.0
		actor.slot = i
		gallery.state.slots[i].downed = i > 0
		gallery.state.actors.append(actor)
		gallery.labels.append(["PLAYER HIT", "PLAYER FALL", "PLAYER DOWN"][i])
		gallery.consume_events([{"type": "hit", "actor_id": actor.id, "room_id": "",
			"position": actor.position, "direction": Vector2.RIGHT, "kind": "contact", "fallen": i > 0}])
		var age: float = [0.04, 0.16, 0.4][i]
		gallery.feedback.hits[actor.id].age = age
		gallery.feedback.impacts[-1].age = age
		if i > 0:
			gallery.feedback.falls[actor.id].age = age
	root.add_child(gallery)
	capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var path := "res://.cache/combat-preview.png"
	root.get_texture().get_image().save_png(path)
	print("Combat preview: " + ProjectSettings.globalize_path(path))
	quit()
