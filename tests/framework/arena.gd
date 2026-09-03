extends RefCounted
## Оснастка боевых тестов: собрать комнату, прогнать тики, выстрелить.
##
## Проверок здесь нет и быть не должно: оснастка, которая сама что-то
## утверждает, прячет утверждение от глаз читающего тест.

const Encounter = preload("res://sim/encounter.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const Actor = preload("res://sim/actor.gd")
const RunState = preload("res://sim/run_state.gd")
const Projectile = preload("res://sim/projectile.gd")
const SaveGame = preload("res://sim/save/save_game.gd")

const FIRE := Command.BTN_FIRE

## Куда отправляют мешающее тело: убить его нельзя — смерть меняет состав
## комнаты, а зачистка меняет ход тика.
const FAR_AWAY := Vector2(100000.0, 100000.0)


# --- сборка -----------------------------------------------------------------

static func room(seed_text: String, players: int = 1, enemies: int = 1) -> RunState:
	return Encounter.dev_room(seed_text, players, enemies)


static func solo(seed_text: String) -> RunState:
	return Encounter.dev_room(seed_text, 1, 0)


static func duel(seed_text: String, enemy_id: String, offset: Vector2) -> RunState:
	var state := solo(seed_text)
	state.actor_of_slot(0).position = Vector2.ZERO
	Encounter.add_enemy(state, enemy_id, offset)
	return state


## Полная дальность броска длиннее половины комнаты: из центра снаряд гас
## бы о стену раньше, чем выдыхался сам.
static func shooting_range(seed_text: String) -> RunState:
	var state := solo(seed_text)
	state.actor_of_slot(0).position = Vector2(state.room.bounds.position.x + 40.0, 0.0)
	return state


# --- ход времени ------------------------------------------------------------

static func hold(state: RunState, ticks: int, move: Vector2,
		aim: Vector2 = Vector2.ZERO, buttons: int = 0) -> void:
	for i in ticks:
		SimTick.step(state, {0: Command.from_axes(state.tick, move, aim, buttons)})


static func coast(state: RunState, ticks: int) -> void:
	hold(state, ticks, Vector2.ZERO)


## Ставить velocity руками бесполезно: тик пересчитывает её из команды.
static func run_up(state: RunState, move: Vector2, ticks: int = 30) -> void:
	hold(state, ticks, move)


# --- действия ---------------------------------------------------------------

static func shoot(state: RunState, aim: Vector2, move: Vector2 = Vector2.ZERO) -> Projectile:
	var before := state.projectiles.size()
	hold(state, 1, move, aim, Command.BTN_FIRE)
	return state.projectiles[-1] if state.projectiles.size() > before else null


static func banish(actor: Actor) -> void:
	actor.position = FAR_AWAY


# --- запросы ----------------------------------------------------------------

static func enemies(state: RunState) -> Array[Actor]:
	return state.living(Actor.Kind.ENEMY)


static func players(state: RunState) -> Array[Actor]:
	return state.living(Actor.Kind.PLAYER)


## Не `reload`: у GDScript есть встроенный Script.reload(bool), и статический
## метод с таким именем он перебивает молча.
static func after_save(state: RunState) -> RunState:
	return SaveGame.from_bytes(SaveGame.to_bytes(state))
