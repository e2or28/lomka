extends RefCounted
## Эталонный забег: один строитель на двоих — генератор фикстуры
## (tools/gen_fixture.sh) и тест, который её читает.
##
## Менять нельзя, не пересобрав фикстуру: этот файл и есть определение
## того, что означает «сейв версии N».

const RunState = preload("res://sim/run_state.gd")
const RngStreams = preload("res://sim/core/rng_streams.gd")
const Modifier = preload("res://sim/core/modifier.gd")
const Encounter = preload("res://sim/encounter.gd")
const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")
const Room = preload("res://sim/room.gd")

const SEED := "эталон-format-2"


static func build() -> RunState:
	# Историческая геометрия фикстуры: новый фон стенда не меняет формат
	# сохранения и не должен заставлять пересобирать эталонные байты.
	var layout := Room.new()
	layout.bounds = Rect2(-593, -302, 1186, 604)
	layout.blockers = [Rect2(-593, -115, 35, 226), Rect2(559, -115, 34, 226)]
	layout.player_spawns = [
		Vector2(-70, 150), Vector2(70, 150), Vector2(-70, 240), Vector2(70, 240),
	]
	layout.enemy_spawns = [
		Vector2(-380, -180), Vector2(380, -180), Vector2(-380, 20), Vector2(380, 20),
	]
	var state := Encounter.dev_room(SEED, 2, 2, layout)
	state.zone_index = 2
	state.tick = 4321

	var first := state.actor_of_slot(0)
	first.position = Vector2(128.5, -64.25)
	first.velocity = Vector2(-12.0, 3.5)
	first.health = 66.0
	first.stack.add(Modifier.make("damage", Modifier.Op.ADD, 4.0, "item:shprits", "m1"))
	first.stack.add(Modifier.make("move_speed", Modifier.Op.MUL, 1.15, "item:pechen", "m2"))
	first.stack.add(Modifier.make("health", Modifier.Op.SET, 66.0, "organ:serdce", "m3"))

	var second := state.actor_of_slot(1)
	second.position = Vector2(-7.75, 40.0)
	second.health = 0.0
	state.slots[1].downed = true
	state.slots[0].revive_target = second.id
	state.slots[0].revive_ticks = 123
	state.pending_spawns.append({"id": "runner", "position": Vector2(240, -180), "spawn_tick": 4411})
	state.encounter_waves = [["heavy"]]

	var wounded := state.living(Actor.Kind.ENEMY)[0]
	wounded.health = 12.0
	wounded.invulnerable = 0.25

	var flying: Projectile = Projectile.spawn(state.take_id(), first, Vector2(1, 0), first.stack.compute())
	flying.position = Vector2(160.0, -60.0)
	state.projectiles.append(flying)

	for i in 37:
		state.rng.stream(RngStreams.LOOT_PLACEMENT).randi()
	for i in 11:
		state.rng.stream(RngStreams.ORGAN_DROP).randi()

	return state
