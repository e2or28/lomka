extends "res://tests/framework/test_case.gd"
## Класс: поведение. Новый бой: честные атаки, все охранники, сохранение и выход.

const Arena = preload("res://tests/framework/arena.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Map = preload("res://sim/room_map.gd")
const Travel = preload("res://sim/room_travel.gd")
const Encounter = preload("res://sim/encounter.gd")
const Director = preload("res://sim/encounter_director.gd")
const Command = preload("res://sim/input/command.gd")
const GuardArt = preload("res://game/guard_art.gd")
const Art = preload("res://game/art_library.gd")
const View = preload("res://game/world_view.gd")

func title() -> String:
	return "нефтяной барон и охрана"

func _available() -> bool:
	return check(Bestiary.ENEMIES.has("oil_baron") and Bestiary.ENEMIES.has("soldier") \
		and Bestiary.ENEMIES.has("soldier_dark") and Bestiary.ENEMIES.has("ice_agent"), "новый состав не зарегистрирован")

func _test_baron_locks_fan_and_save_preserves_attack() -> bool:
	if not _available(): return true
	var state := Arena.duel("baron", "oil_baron", Vector2(320, 0))
	var boss = Arena.enemies(state)[0]
	Arena.coast(state, 1)
	check(boss.attack_ticks > 0, "нет предупреждения")
	var locked: Vector2 = boss.attack_aim
	state.actor_of_slot(0).position = Vector2(0, 180)
	Arena.coast(state, 74)
	eq(state.projectiles.size(), 0, "веер раньше предупреждения")
	var loaded := Arena.after_save(state)
	Arena.coast(state, 1)
	Arena.coast(loaded, 1)
	eq(state.projectiles.size(), 5, "веер не состоит из пяти снарядов")
	if state.projectiles.size() == 5:
		check(state.projectiles[2].velocity.normalized().is_equal_approx(locked), "веер перенавёлся после предупреждения")
	eq(state.state_hash(), loaded.state_hash(), "сейв изменил выстрел")
	Arena.coast(state, 90)
	Arena.coast(loaded, 90)
	eq(state.state_hash(), loaded.state_hash(), "бой после сейва разошёлся")
	return true

func _test_soldiers_warn_and_hit_from_distance() -> bool:
	if not _available(): return true
	for id in ["soldier", "soldier_dark"]:
		var state := Arena.duel(id, id, Vector2(300, 0))
		Arena.coast(state, 1)
		check(Arena.enemies(state)[0].attack_ticks > 0, "солдат стреляет без предупреждения")
		eq(state.projectiles.size(), 0, "мгновенная пуля")
		Arena.coast(state, 110)
		check(state.actor_of_slot(0).health < 100, "солдат не достал неподвижную цель издалека")
	return true

func _test_ice_windup_damages_once_and_can_be_dodged() -> bool:
	if not _available(): return true
	var state := Arena.duel("baton", "ice_agent", Vector2(48, 0))
	Arena.coast(state, 36)
	almost_eq(state.actor_of_slot(0).health, 100, "касание или замах нанесли ранний урон")
	var saved := Arena.after_save(state)
	Arena.coast(state, 1)
	Arena.coast(saved, 1)
	eq(state.state_hash(), saved.state_hash(), "замах не пережил сейв")
	almost_eq(state.actor_of_slot(0).health, 86, "дубинка должна ударить один раз")
	Arena.coast(state, 35)
	almost_eq(state.actor_of_slot(0).health, 86, "контакт бьёт во время восстановления")
	var dodge := Arena.duel("dodge", "ice_agent", Vector2(48, 0))
	Arena.coast(dodge, 1)
	dodge.actor_of_slot(0).position = Vector2(100, 0)
	Arena.coast(dodge, 36)
	almost_eq(dodge.actor_of_slot(0).health, 100, "за спиной замах всё равно попал")
	return true

func _test_dead_enemies_cancel_pending_attacks() -> bool:
	if not _available(): return true
	for id in ["oil_baron", "soldier", "ice_agent"]:
		var state := Arena.duel("cancel", id, Vector2(48, 0))
		Arena.coast(state, 1)
		Arena.enemies(state)[0].take_damage(10000)
		Arena.coast(state, 90)
		eq(state.projectiles.size(), 0, "мёртвый враг выстрелил")
		almost_eq(state.actor_of_slot(0).health, 100, "мёртвый враг ударил")
	return true

func _test_new_room_has_every_mob_and_stays_cleared_after_revisit() -> bool:
	if not check(Map.IDS.has("oil_baron"), "нет шестой комнаты"): return true
	var state := Encounter.dev_room("baron-room", 4, 0, Map.make("center"))
	state.actor_of_slot(0).position = Map.door(state.room, "west") + Vector2(16, 0)
	Travel.advance(state, {0: Command.from_axes(0, Vector2.LEFT, Vector2.ZERO)})
	eq(state.room.id, "oil_baron", "комната недоступна слева от главного зала")
	var roster: Array[String] = []
	for enemy in Arena.enemies(state): roster.append(enemy.archetype)
	roster.sort()
	eq(roster, ["ice_agent", "ice_agent", "oil_baron", "soldier", "soldier_dark"], "не вся охрана в комнате")
	check(not state.room_cleared(), "дверь открыта во время боя")
	for enemy in Arena.enemies(state):
		eq(state.room.clamp_body(enemy.position, enemy.radius), enemy.position, "охранник в стене")
		for player in Arena.players(state):
			check(enemy.position.distance_to(player.position) >= Director.SAFE_DISTANCE, "враг появился у игрока")
		enemy.take_damage(10000)
	state.actor_of_slot(0).position = Map.door(state.room, "east") - Vector2(16, 0)
	Travel.advance(state, {0: Command.from_axes(0, Vector2.RIGHT, Vector2.ZERO)})
	eq(state.room.id, "center", "нет обратного прохода в главный зал")
	var saved := Arena.after_save(state)
	saved.actor_of_slot(0).position = Map.door(saved.room, "west") + Vector2(16, 0)
	Travel.advance(saved, {0: Command.from_axes(0, Vector2.LEFT, Vector2.ZERO)})
	check(saved.room_cleared(), "босс или охрана воскресли после возврата")
	return true

func _test_all_poses_have_art_and_camera_keeps_player_visible() -> bool:
	if not _available(): return true
	var art := Art.new()
	for name in GuardArt.SPRITES:
		var texture: Texture2D = art.get_texture(name)
		if not check(texture != null, "поза заменится заглушкой: " + name): continue
		var image := texture.get_image()
		check(image.get_used_rect().size.x > 20 and image.get_used_rect().size.y > 100, "пустая или обрезанная поза: " + name)
		if name != "oil_baron":
			check(image.get_used_rect().position.y > 0, "дубинка обрезана верхом холста: " + name)
			almost_eq(image.get_used_rect().end.y, GuardArt.ROOT.y + 1, "стопы потеряли опору: " + name)
	var view := View.new()
	view.state = Encounter.dev_room("camera", 1, 0, Map.make("oil_baron"))
	view.textures["room_oil_baron"] = art.get_texture("room_oil_baron")
	var player := view.state.actor_of_slot(0)
	for y in [-359, 0, 280, 375]:
		player.position = Vector2(0, y)
		var screen: Vector2 = view.centering_origin(Vector2(1400, 880)) + player.position
		check(screen.y > 156 and screen.y < 760, "камера прячет игрока за краем или телом HUD")
	view.free()
	return true
