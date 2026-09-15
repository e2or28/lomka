extends SceneTree
## Свободный визуальный прогон. Кнопки заменяют удержание клавиш для UI-инструмента.
## Все действия игрока, противников и урон проходят через обычный SimTick.
const Sandbox = preload("res://game/dev_sandbox.gd")
const Arena = preload("res://tests/framework/arena.gd")
const Command = preload("res://sim/input/command.gd")
const Tick = preload("res://sim/tick.gd")
const Encounter = preload("res://sim/encounter.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Reinforcements = preload("res://sim/reinforcements.gd")
var game
var move := Vector2.ZERO
var aim := Vector2.RIGHT
var buttons := 0
var ticks_left := 0
var is_paused := true
var status: Label
var evidence := {}

func _initialize() -> void:
	root.size = Vector2i(1400, 880)
	game = Sandbox.new()
	root.add_child.call_deferred(game)
	setup.call_deferred()

func setup() -> void:
	game.set_physics_process(false)
	game._state = Arena.room("free-polish", 2, 0)
	game._active_slots = 2
	game._view.state = game._state
	game._organ_hud.state = game._state
	var p = game._state.actor_of_slot(0)
	p.position = Vector2(-150, 80)
	Arsenal.equip(p, "colt")
	var buddy = game._state.actor_of_slot(1)
	buddy.position = Vector2(-95, 80)
	buddy.health = 0
	game._state.slots[1].downed = true
	var corpse = Encounter.add_enemy(game._state, "runner", Vector2(-100, 120))
	corpse.take_damage(10000)
	Encounter.add_enemy(game._state, "barrel", Vector2(200, 80))
	var layer := CanvasLayer.new()
	layer.layer = 30
	root.add_child(layer)
	var rows := VBoxContainer.new()
	rows.position = Vector2(12, 100)
	layer.add_child(rows)
	var row := HBoxContainer.new()
	rows.add_child(row)
	button(row, "PAUSE / RUN", func(): is_paused = not is_paused)
	button(row, "UP", func(): act(Vector2.UP, aim, 0, 24))
	button(row, "DOWN", func(): act(Vector2.DOWN, aim, 0, 24))
	button(row, "LEFT", func(): act(Vector2.LEFT, aim, 0, 24))
	button(row, "RIGHT", func(): act(Vector2.RIGHT, aim, 0, 24))
	button(row, "FIRE UP", func(): act(Vector2.UP, Vector2.UP, 1, 24))
	button(row, "FIRE DOWN", func(): act(Vector2.DOWN, Vector2.DOWN, 1, 24))
	button(row, "FIRE RIGHT", func(): act(Vector2.ZERO, Vector2.RIGHT, 1, 90))
	row = HBoxContainer.new()
	rows.add_child(row)
	button(row, "HARVEST", func(): act(Vector2.ZERO, aim, 4, 65))
	button(row, "HELP", func(): act(Vector2.ZERO, aim, 2, 310))
	button(row, "SOLDIER", func(): Encounter.add_enemy(game._state, "soldier", Vector2(350, 120)))
	button(row, "HELICOPTER", func(): Reinforcements.land(game._state, Encounter, 130))
	button(row, "CRASH", crash)
	status = Label.new()
	rows.add_child(status)
	root.title = "Ломка — свободная проверка анимаций"

func button(row: HBoxContainer, label: String, action: Callable) -> void:
	var control := Button.new()
	control.text = label
	control.pressed.connect(action)
	row.add_child(control)

func act(direction: Vector2, target: Vector2, mask: int, ticks: int) -> void:
	move = direction
	aim = target
	buttons = mask
	ticks_left = ticks
	is_paused = false
	print("MANUAL ACTION ", direction, " aim=", target, " buttons=", mask)

func crash() -> void:
	for actor in game._state.actors:
		if actor.behaviour == "gunship": actor.take_damage(10000)

func _physics_process(_delta: float) -> bool:
	if status == null or is_paused: return false
	var command = Command.from_axes(game._state.tick, move, aim if buttons & 1 else Vector2.ZERO, buttons)
	var events = Tick.step(game._state, {0: command})
	game._view.firing[game._state.actor_of_slot(0).id] = buttons & 1 != 0
	game._view.consume_events(events)
	game._sounds.consume(game._state, events, 0)
	for event in events:
		evidence[event.type] = evidence.get(event.type, 0) + 1
		if event.type in ["revived", "harvested", "explosion"]: print("MANUAL EVENT ", event)
	if ticks_left > 0:
		ticks_left -= 1
		if ticks_left == 0:
			move = Vector2.ZERO
			buttons = 0
	status.text = "Tick %d | %s" % [game._state.tick, str(evidence)]
	return false
