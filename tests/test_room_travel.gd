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


func _test_every_floor_matches_source_and_stops_bodies() -> bool:
	for id in Map.IDS:
		var room = Map.make(id)
		var inset := RoomArt.floor_inset(id)
		var image := Image.new()
		eq(image.load("res://art/room_%s.png" % id), OK, "нет PNG комнаты " + id)
		var bottom: float = inset.y + room.bounds.size.y
		almost_eq(bottom, 1390 if id in ["west", "east"] else 890, "коллизия ниже нарисованного пола " + id)
		for n in 16:
			var at: Vector2 = room.clamp_body(Vector2.RIGHT.rotated(TAU * n / 16) * 5000, 16)
			check(room.bounds.grow(-15.99).has_point(at), "тело за стеной " + id)
		for blocker in room.blockers:
			var at: Vector2 = room.clamp_body(blocker.get_center(), 16)
			check(not blocker.grow(15.99).has_point(at), "тело в косяке " + id)
	return true
