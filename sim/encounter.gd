extends RefCounted
## Сборка комнаты: кто в ней стоит на старте, отдельно от тика — тик
## чистая функция от состояния и команд, а не создаёт тела из воздуха,
## иначе воспроизвести забег по журналу стало бы невозможно.
##
## На M3 сюда придут таблицы спавна из data/ и поток LOOT_PLACEMENT.

const RunState = preload("res://sim/run_state.gd")
const Actor = preload("res://sim/actor.gd")
const Room = preload("res://sim/room.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Modifier = preload("res://sim/core/modifier.gd")
const Pickup = preload("res://sim/pickup.gd")

const ROSTER: Array[String] = ["test_monster", "runner", "heavy"]
const Schemas = preload("res://sim/data/schemas.gd")
const Arsenal = preload("res://sim/arsenal.gd")


static func dev_room(seed_text: String, players: int, monsters: int,
		layout: Room = null) -> RunState:
	var state := RunState.new(seed_text)
	state.room = Room.dev_room() if layout == null else layout

	for i in mini(players, RunState.MAX_PLAYERS):
		add_player(state, i, "clerk")
	for i in monsters:
		add_enemy(state, ROSTER[i % ROSTER.size()], state.room.enemy_spawn(i))

	# Пока лут не раскладывается по сиду (M3), кольт лежит на виду от места
	# появления группы: без него второе оружие в игре недостижимо.
	add_pickup(state, "colt", Vector2(180, 150))

	return state


static func add_player(state: RunState, slot_index: int, character_id: String,
		weapon_id: String = Arsenal.DEFAULT_WEAPON) -> Actor:
	var record := Bestiary.character(character_id)
	var actor := Actor.new(state.take_id(), Actor.Kind.PLAYER)
	actor.slot = slot_index
	actor.archetype = character_id
	actor.radius = float(record.get("radius", actor.radius))
	actor.position = state.room.player_spawn(slot_index)
	actor.stack.base = record.get("base_stats", {}).duplicate()
	_apply_passive(actor, record.get("passive", []))
	# До heal_to_full: оружие может менять здоровье через тот же стек.
	if weapon_id != "":
		Arsenal.equip(actor, weapon_id)
	actor.heal_to_full()
	state.actors.append(actor)

	var slot := state.slots[slot_index]
	slot.occupied = true
	slot.character_id = character_id
	slot.downed = false
	slot.actor_id = actor.id
	return actor


static func add_enemy(state: RunState, enemy_id: String, position: Vector2) -> Actor:
	var record := Bestiary.enemy(enemy_id)
	var actor := Actor.new(state.take_id(), Actor.Kind.ENEMY)
	actor.archetype = enemy_id
	actor.behaviour = record.get("behaviour", "charger")
	actor.radius = float(record.get("radius", actor.radius))
	actor.position = position
	actor.stack.base = record.get("base_stats", {}).duplicate()
	actor.heal_to_full()
	state.actors.append(actor)
	return actor


static func add_pickup(state: RunState, weapon_id: String, at: Vector2) -> Pickup:
	# Тип не выводится: у статической фабрики его нет, см. «Ловушки» в CLAUDE.md
	var pickup: Pickup = Pickup.weapon(state.take_id(), weapon_id, at)
	state.pickups.append(pickup)
	return pickup


static func _apply_passive(actor: Actor, passive: Array) -> void:
	for entry in passive:
		var op: int = Schemas.OPS.find(entry.get("op", "add"))
		actor.stack.add(Modifier.make(
			entry.get("stat", ""), op as Modifier.Op, float(entry.get("value", 0.0)),
			"character:" + actor.archetype))
