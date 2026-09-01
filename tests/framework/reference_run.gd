extends RefCounted
## Эталонный забег: фиксированное состояние, собранное из констант.
##
## Один строитель на двоих — генератор фикстуры (tools/gen_fixture.sh) и
## тест, который эту фикстуру читает. Если бы каждый строил своё, тест
## проверял бы совпадение двух своих же представлений, а не формат на диске.
##
## Менять этот файл нельзя, не пересобрав фикстуру: он и есть определение
## того, что означает «сейв версии N».

const RunState = preload("res://sim/run_state.gd")
const RngStreams = preload("res://sim/core/rng_streams.gd")
const Modifier = preload("res://sim/core/modifier.gd")
const Encounter = preload("res://sim/encounter.gd")
const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")

const SEED := "эталон-format-2"


static func build() -> RunState:
	var state := Encounter.dev_room(SEED, 2, 2)
	state.zone_index = 2
	state.tick = 4321

	# Забег в середине: предметы собраны, кто-то упал, снаряд в полёте.
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
