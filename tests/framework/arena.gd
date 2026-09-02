extends RefCounted
## Оснастка боевых тестов: собрать комнату, прогнать тики, выстрелить.
##
## Заводится потому, что подготовка у боевых тестов одна и та же, а писалась
## трижды: «прогнать N тиков с пустой командой» жило как `_coast` в
## баллистике, `_hold` в бою и `_idle` во врагах. Три имени одного действия —
## это не дублирование ради экономии строк, а три места, где может
## разъехаться смысл: стоит одному из них начать слать не пустую команду, и
## соседние тесты будут проверять разное, называя это одинаково.
##
## Впереди по M1 предметы, органы и способности — каждому нужен тест, и
## каждый начнётся с той же комнаты. Пусть она будет одна.
##
## Здесь только сборка и ход времени. Проверок тут нет и быть не должно:
## оснастка, которая сама что-то утверждает, прячет утверждение от глаз
## читающего тест.

const Encounter = preload("res://sim/encounter.gd")
const SimTick = preload("res://sim/tick.gd")
const Command = preload("res://sim/input/command.gd")
const Actor = preload("res://sim/actor.gd")
const RunState = preload("res://sim/run_state.gd")
const Projectile = preload("res://sim/projectile.gd")
const SaveGame = preload("res://sim/save/save_game.gd")

## Кнопка огня. Пробрасывается, чтобы боевому тесту не приходилось тянуть
## весь Command ради одного числа.
const FIRE := Command.BTN_FIRE

## Куда отправляют тело, которое в пробе мешает, но убить его нельзя:
## смерть меняет состав комнаты, а зачистка — ход тика.
const FAR_AWAY := Vector2(100000.0, 100000.0)


# --- сборка -----------------------------------------------------------------

## Комната разработчиков как есть.
static func room(seed_text: String, players: int = 1, enemies: int = 1) -> RunState:
	return Encounter.dev_room(seed_text, players, enemies)


## Один игрок, комната пустая. Для проб, где враг только мешает.
static func solo(seed_text: String) -> RunState:
	return Encounter.dev_room(seed_text, 1, 0)


## Игрок в начале координат, один враг заданного типа на известном отступе.
## Расстояние здесь — главный вход повадки, поэтому оно задаётся, а не
## достаётся из точек появления комнаты.
static func duel(seed_text: String, enemy_id: String, offset: Vector2) -> RunState:
	var state := solo(seed_text)
	state.actor_of_slot(0).position = Vector2.ZERO
	Encounter.add_enemy(state, enemy_id, offset)
	return state


## Стрелок у левой стены. Полная дальность броска длиннее половины комнаты,
## и из центра снаряд гас бы о стену раньше, чем выдыхался сам.
static func shooting_range(seed_text: String) -> RunState:
	var state := solo(seed_text)
	state.actor_of_slot(0).position = Vector2(state.room.bounds.position.x + 40.0, 0.0)
	return state


# --- ход времени ------------------------------------------------------------

## Прогнать тики, удерживая одну и ту же команду.
static func hold(state: RunState, ticks: int, move: Vector2,
		aim: Vector2 = Vector2.ZERO, buttons: int = 0) -> void:
	for i in ticks:
		SimTick.step(state, {0: Command.from_axes(state.tick, move, aim, buttons)})


## Прогнать тики с отпущенными клавишами. Мир при этом не стоит: летят
## снаряды, идут враги, тикают таймеры.
static func coast(state: RunState, ticks: int) -> void:
	hold(state, ticks, Vector2.ZERO)


## Разогнать игрока до полной скорости. Ставить velocity руками бесполезно:
## тик пересчитывает её из команды, и торможение гасит подставленное за пару
## кадров.
static func run_up(state: RunState, move: Vector2, ticks: int = 30) -> void:
	hold(state, ticks, move)


# --- действия ---------------------------------------------------------------

## Выстрелить и вернуть родившийся снаряд, либо null, если выстрела не вышло
## (перезарядка, пустой прицел). Различать эти случаи — дело теста.
static func shoot(state: RunState, aim: Vector2, move: Vector2 = Vector2.ZERO) -> Projectile:
	var before := state.projectiles.size()
	hold(state, 1, move, aim, Command.BTN_FIRE)
	return state.projectiles[-1] if state.projectiles.size() > before else null


## Убрать тело с глаз, не убивая. Живым оно остаётся намеренно: труп
## зачищает комнату, а зачищенная комната — уже другая проба.
static func banish(actor: Actor) -> void:
	actor.position = FAR_AWAY


# --- запросы ----------------------------------------------------------------

static func enemies(state: RunState) -> Array[Actor]:
	return state.living(Actor.Kind.ENEMY)


static func players(state: RunState) -> Array[Actor]:
	return state.living(Actor.Kind.PLAYER)


## Состояние после сейва туда-обратно. Возвращает null, если загрузка не
## удалась — тест обязан это проверить, молча продолжать с null нельзя.
##
## Имя не `reload`: у самого GDScript есть встроенный `Script.reload(bool)`,
## и статический метод с таким именем он перебивает молча — вызов уходит в
## движок и падает на несовпадении типов.
static func after_save(state: RunState) -> RunState:
	return SaveGame.from_bytes(SaveGame.to_bytes(state))
