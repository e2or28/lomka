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

const SEED := "эталон-format-1"


static func build() -> RunState:
	var state := RunState.new(SEED)
	state.zone_index = 2
	state.tick = 4321

	state.slots[0].occupied = true
	state.slots[0].character_id = "khimik"
	state.slots[0].position = Vector2(128.5, -64.25)
	state.slots[0].velocity = Vector2(-12.0, 3.5)
	state.slots[0].stack.base = {
		"acceleration": 2400.0,
		"friction": 3200.0,
		"health": 100.0,
		"move_speed": 220.0,
	}
	state.slots[0].stack.add(Modifier.make("damage", Modifier.Op.ADD, 4.0, "item:shprits", "m1"))
	state.slots[0].stack.add(Modifier.make("move_speed", Modifier.Op.MUL, 1.15, "item:pechen", "m2"))
	state.slots[0].stack.add(Modifier.make("health", Modifier.Op.SET, 66.0, "organ:serdce", "m3"))

	state.slots[1].occupied = true
	state.slots[1].character_id = "sanitar"
	state.slots[1].downed = true
	state.slots[1].position = Vector2(-7.75, 40.0)
	state.slots[1].stack.base = {"health": 80.0, "move_speed": 240.0}

	for i in 37:
		state.rng.stream(RngStreams.LOOT_PLACEMENT).randi()
	for i in 11:
		state.rng.stream(RngStreams.ORGAN_DROP).randi()

	return state
