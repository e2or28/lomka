extends RefCounted
## Тело в мире: игрок или враг. Правило 7 — это данные, а не класс.
##
## До появления врагов тело жило прямо в слоте игрока: заводить сущность ради
## одного квадрата значило городить абстракцию под пустоту. Теперь врагов
## больше одного, и общее у них со слотом ровно это — позиция, скорость,
## здоровье и стек модификаторов.
##
## Чем актор игрока отличается от актора врага — только полями `slot` и
## `archetype`. Поведение задаётся данными, а не наследованием: пятый тип
## врага не должен стоить нового класса.

const ModifierStack = preload("res://sim/core/modifier_stack.gd")

enum Kind { PLAYER, ENEMY }

var id: int = 0
var kind: Kind = Kind.PLAYER

## Слот игрока или -1 у врага.
var slot: int = -1

## Идентификатор записи в данных: персонаж или враг. Пустая строка
## у безымянных тел вроде манекена на стенде.
var archetype: String = ""

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.RIGHT

## Что в руках. Пустая строка — безоружен: ходит, но не стреляет.
## Статы стрельбы приходят от оружия через стек, здесь только ссылка.
var weapon_id: String = ""

var health: float = 0.0
var alive: bool = true

## Секунд до следующего выстрела. Считается вниз шагом тика, поэтому
## скорострельность одинакова у хоста и клиента.
var cooldown: float = 0.0

## Кадры неуязвимости после попадания, в секундах. Без них враг, стоящий
## в снаряде, получает урон каждый тик и умирает мгновенно.
var invulnerable: float = 0.0

var stack: ModifierStack = null


func _init(p_id: int = 0, p_kind: Kind = Kind.PLAYER) -> void:
	id = p_id
	kind = p_kind
	stack = ModifierStack.new()


## Максимум здоровья берётся из стека: предмет на здоровье поднимает и его.
func max_health() -> float:
	return float(stack.compute().get("health", 0.0))


func heal_to_full() -> void:
	health = max_health()
	alive = health > 0.0


## Урон. Возвращает true, если этим ударом тело добито — вызывающий код
## решает, что с этим делать, сама симуляция трупов не убирает.
func take_damage(amount: float) -> bool:
	if not alive or invulnerable > 0.0 or amount <= 0.0:
		return false
	health -= amount
	if health <= 0.0:
		health = 0.0
		alive = false
		return true
	return false


func to_dict() -> Dictionary:
	return {
		"aim": aim,
		"alive": alive,
		"archetype": archetype,
		"cooldown": cooldown,
		"health": health,
		"id": id,
		"invulnerable": invulnerable,
		"kind": int(kind),
		"position": position,
		"slot": slot,
		"stack": stack.to_dict(),
		"velocity": velocity,
		"weapon_id": weapon_id,
	}


static func from_dict(data: Dictionary):
	var actor := new(int(data.get("id", 0)), data.get("kind", Kind.PLAYER) as Kind)
	actor.aim = data.get("aim", Vector2.RIGHT)
	actor.alive = bool(data.get("alive", true))
	actor.archetype = data.get("archetype", "")
	actor.cooldown = float(data.get("cooldown", 0.0))
	actor.health = float(data.get("health", 0.0))
	actor.invulnerable = float(data.get("invulnerable", 0.0))
	actor.position = data.get("position", Vector2.ZERO)
	actor.slot = int(data.get("slot", -1))
	actor.stack = ModifierStack.from_dict(data.get("stack", {}))
	actor.velocity = data.get("velocity", Vector2.ZERO)
	actor.weapon_id = data.get("weapon_id", "")
	return actor
