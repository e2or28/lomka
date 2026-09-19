extends "res://tests/framework/test_case.gd"
## Класс: поведение. Проходы открывает зачистка; возвращение не воскрешает врагов и лут.

const Travel = preload("res://sim/room_travel.gd")
const Map = preload("res://sim/room_map.gd")
const RoomArt = preload("res://game/room_art.gd")
const Arena = preload("res://tests/framework/arena.gd")
const Actor = preload("res://sim/actor.gd")
const Encounter = preload("res://sim/encounter.gd")
const Command = preload("res://sim/input/command.gd")
const SaveGame = preload("res://sim/save/save_game.gd")
const Organs = preload("res://sim/organs.gd")


func title() -> String:
	return "комнаты и переходы"


func _clear(state) -> void:
	state.pending_spawns.clear()
	state.encounter_waves.clear()
	for actor in state.actors:
		if actor.kind == Actor.Kind.ENEMY:
			actor.alive = false
			actor.health = 0


func _walk(state, direction: String, slot: int = 0) -> void:
	var normal: Vector2 = Map.DIRECTIONS[direction]
	var actor = state.actor_of_slot(slot)
	actor.position = Map.door(state.room, direction) - normal * actor.radius
	actor.velocity = Vector2.ZERO
	Travel.advance(state, {slot: Command.from_axes(state.tick, normal, Vector2.ZERO)})


func _test_all_links_work_both_ways_through_real_ticks() -> bool:
	for id in Map.IDS:
		for direction in Map.LINKS[id]:
			var state = Encounter.dev_room("routes", 1, 0, Map.make(id))
			var normal: Vector2 = Map.DIRECTIONS[direction]
			state.actor_of_slot(0).position = Map.door(state.room, direction) - normal * 55
			for i in 40:
				Arena.hold(state, 1, normal)
				if state.room.id != id: break
			eq(state.room.id, Map.LINKS[id][direction], "проём %s/%s не пропускает" % [id, direction])
			var actor = state.actor_of_slot(0)
			eq(state.room.clamp_body(actor.position, actor.radius), actor.position, "приход в стену")
			_clear(state)
			_walk(state, Map.OPPOSITE[direction])
			eq(state.room.id, id, "обратный проход потерян")
	return true


func _test_combat_and_solid_walls_block_transition() -> bool:
	var state = Travel.start("locks", 1)
	var enemy = Encounter.add_enemy(state, "runner", Vector2.ZERO)
	_walk(state, "north")
	eq(state.room.id, "south", "выход до зачистки")
	enemy.alive = false
	var player = state.actor_of_slot(0)
	player.position = Vector2(300, state.room.bounds.position.y + player.radius)
	Arena.hold(state, 60, Vector2.UP)
	eq(state.room.id, "south", "переход сквозь стену мимо двери")
	almost_eq(player.position.y - player.radius, state.room.bounds.position.y, "тело ушло в верхнюю стену")
	_walk(state, "north")
	eq(state.room.id, "center", "зачистка не открыла проход")
	return true


func _test_revisit_and_save_keep_corpses_loot_and_build() -> bool:
	var state = Travel.start("persistent", 1)
	state.pickups[0].position = Vector2(50, 50)
	var original_pickup: int = state.pickups[0].id
	check(Organs.equip(state.actor_of_slot(0), state.slots[0], "armored_spine"), "орган не установился")
	state.heat = 35
	state.actor_of_slot(0).health = 71
	_walk(state, "north")
	_clear(state)
	var corpse = state.actors[1]
	corpse.harvested = true
	var corpse_id: int = corpse.id
	var last_id: int = state.next_id
	_walk(state, "south")
	eq(state.pickups.size(), 3, "лут стартовой комнаты потерян или продублирован")
	eq(state.pickups[0].id, original_pickup, "подмена оставленного предмета")
	eq(state.pickups[0].position, Vector2(50, 50), "лут переместился")
	var restored = Arena.after_save(state)
	bytes_eq(SaveGame.to_bytes(state), SaveGame.to_bytes(restored), "сейв карты неустойчив")
	_walk(restored, "north")
	check(restored.room_cleared(), "враги воскресли при возвращении")
	check(restored.actor_by_id(corpse_id).harvested, "труп снова разрешил харвест")
	eq(restored.next_id, last_id, "повторно созданы враги")
	eq(restored.slots[0].organs["spine"], "armored_spine", "переход потерял орган")
	almost_eq(restored.actor_of_slot(0).stack.compute()["damage"], state.actor_of_slot(0).stack.compute()["damage"], "переход потерял модификатор органа")
	eq(restored.heat, 35, "переход изменил Heat")
	almost_eq(restored.actor_of_slot(0).health, 71, "переход восстановил здоровье")
	return true


func _test_party_transfer_does_not_revive_or_bounce() -> bool:
	var state = Travel.start("coop", 4)
	state.slots[0].downed = true
	state.actor_of_slot(0).health = 0
	_walk(state, "north", 0)
	eq(state.room.id, "south", "упавший сам перевёл группу")
	_walk(state, "north", 2)
	eq(state.room.id, "center", "живой игрок не перевёл группу")
	check(state.slots[0].downed, "между комнатами бесплатно подняли упавшего")
	for actor in Arena.players(state):
		eq(state.room.clamp_body(actor.position, actor.radius), actor.position, "группа в стене")
	_clear(state)
	Arena.hold(state, 1, Vector2.DOWN)
	eq(state.room.id, "center", "мгновенный обратный переход")
	return true


func _test_lower_boundary_matches_black_outline_and_stops_bodies() -> bool:
	# Чёрный контур над лицевой полосой замерен в исходных PNG, вне дверей.
	var outline := {"south": 890, "center": 890, "north": 890, "west": 1386, "east": 1386, "oil_baron": 890}
	for id in Map.IDS:
		var room = Map.make(id)
		var inset := RoomArt.floor_inset(id)
		var image := Image.new()
		eq(image.load("res://art/room_%s.png" % id), OK, "нет PNG комнаты " + id)
		var bottom: float = inset.y + room.bounds.size.y
		almost_eq(bottom, outline[id], "граница не на чёрном контуре стены " + id)
		var state = Encounter.dev_room("lower-wall", 1, 0, room)
		var player = state.actor_of_slot(0)
		player.position = Vector2(-200, room.bounds.end.y - 150)
		Arena.hold(state, 120, Vector2.DOWN)
		almost_eq(player.position.y - room.bounds.position.y + inset.y,
			outline[id], "ноги остановились до контура или прошли сквозь него " + id)
		eq(state.room.id, id, "переход через стену мимо нижней двери " + id)
		var top: float = -623 if id in ["west", "east"] else (-340 if id == "south" else -375)
		almost_eq(RoomArt.image_rect(room, image.get_size()).position.y, top - RoomArt.WALL_HEIGHT,
			"граница по контуру сдвинула рисунок комнаты " + id)
		var limits: Rect2 = room.bounds.grow(-15.99)
		limits.size.y += 16.0
		for n in 16:
			var at: Vector2 = room.clamp_body(Vector2.RIGHT.rotated(TAU * n / 16) * 5000, 16)
			check(limits.has_point(at), "тело за стеной " + id)
		for blocker in room.blockers:
			var at: Vector2 = room.clamp_body(blocker.get_center(), 16)
			check(not blocker.grow(15.99).has_point(at), "тело в косяке " + id)
	return true


## Комната босса — единственная, куда пускают из боя: к барону ходят
## пробовать бой, а не зачищать зал перед ним заново.
func _test_boss_room_opens_without_clearing_the_hall() -> bool:
	var state = Travel.start("boss-door", 1)
	_walk(state, "north")
	eq(state.room.id, "center", "приёмная не выпустила в зал")
	check(not state.room_cleared(), "в зале некого держать за дверью")

	_walk(state, "east")
	eq(state.room.id, "center", "архив открылся до зачистки зала")
	_walk(state, "south")
	eq(state.room.id, "center", "приёмная открылась до зачистки зала")

	_walk(state, "west")
	eq(state.room.id, "oil_baron", "проход к барону закрыт до зачистки зала")
	check(not state.room_cleared(), "барон не встретил группу")
	_walk(state, "east")
	eq(state.room.id, "oil_baron", "из комнаты босса выпустили до зачистки")
	_clear(state)
	_walk(state, "east")
	eq(state.room.id, "center", "зачистка не открыла выход из комнаты босса")
	check(not state.room_cleared(), "зал зачистился, пока группа была у барона")
	return true
