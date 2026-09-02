extends RefCounted
## Сборка комнаты: кто в ней стоит на старте.
##
## Отделено от тика намеренно. Тик — чистая функция от состояния и команд,
## и если бы он умел создавать тела из воздуха, воспроизвести забег по
## журналу команд стало бы невозможно: состав комнаты пришлось бы угадывать.
## Здесь состав задаётся один раз, до первого тика, и дальше только меняется.
##
## На M3 сюда придут таблицы спавна из data/ и поток LOOT_PLACEMENT.
## Пока состав фиксирован — это тестовый полигон, а не игра.

const RunState = preload("res://sim/run_state.gd")
const Actor = preload("res://sim/actor.gd")
const Room = preload("res://sim/room.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Modifier = preload("res://sim/core/modifier.gd")
const Schemas = preload("res://sim/data/schemas.gd")
const Arsenal = preload("res://sim/arsenal.gd")


## Комната разработчиков: N игроков против M манекенов.
static func dev_room(seed_text: String, players: int, monsters: int) -> RunState:
	var state := RunState.new(seed_text)
	state.room = Room.dev_room()

	for i in mini(players, RunState.MAX_PLAYERS):
		add_player(state, i, "clerk")
	for i in monsters:
		add_enemy(state, "test_monster", state.room.enemy_spawn(i))

	return state


static func add_player(state: RunState, slot_index: int, character_id: String,
		weapon_id: String = Arsenal.DEFAULT_WEAPON) -> Actor:
	var record := Bestiary.character(character_id)
	var actor := Actor.new(state.take_id(), Actor.Kind.PLAYER)
	actor.slot = slot_index
	actor.archetype = character_id
	actor.position = state.room.player_spawn(slot_index)
	actor.stack.base = record.get("base_stats", {}).duplicate()
	_apply_passive(actor, record.get("passive", []))
	# Оружие кладёт свои модификаторы в тот же стек — до подсчёта здоровья,
	# потому что оружие может его менять.
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
	actor.position = position
	actor.stack.base = record.get("base_stats", {}).duplicate()
	actor.heal_to_full()
	state.actors.append(actor)
	return actor


## Пассивные модификаторы персонажа кладутся в стек, а не в базу: снять их
## должно быть так же просто, как модификатор от предмета (правило 4).
static func _apply_passive(actor: Actor, passive: Array) -> void:
	for entry in passive:
		var op: int = Schemas.OPS.find(entry.get("op", "add"))
		actor.stack.add(Modifier.make(
			entry.get("stat", ""), op as Modifier.Op, float(entry.get("value", 0.0)),
			"character:" + actor.archetype))
