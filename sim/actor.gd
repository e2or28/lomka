extends RefCounted
## Тело в мире: игрок или враг, данные, а не класс (правило 7). Актор
## игрока отличается от актора врага только полями `slot` и `archetype`.

const ModifierStack = preload("res://sim/core/modifier_stack.gd")

enum Kind { PLAYER, ENEMY }

var id: int = 0
var kind: Kind = Kind.PLAYER

## -1 у врага.
var slot: int = -1

## Пустая строка у безымянных тел вроде манекена на стенде.
var archetype: String = ""

## Пустая строка у игрока: им управляет человек.
var behaviour: String = ""

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.RIGHT

## Статы стрельбы приходят от оружия через стек, здесь только ссылка.
var weapon_id: String = ""

var health: float = 0.0
var alive: bool = true
var cooldown: float = 0.0

## Без них враг, стоящий в снаряде, получает урон каждый тик и умирает
## мгновенно.
var invulnerable: float = 0.0

var stack: ModifierStack = null


func _init(p_id: int = 0, p_kind: Kind = Kind.PLAYER) -> void:
	id = p_id
	kind = p_kind
	stack = ModifierStack.new()


func max_health() -> float:
	return float(stack.compute().get("health", 0.0))


func heal_to_full() -> void:
	health = max_health()
	alive = health > 0.0


## true, если этим ударом тело добито — симуляция трупов не убирает.
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
		"behaviour": behaviour,
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
	actor.behaviour = data.get("behaviour", "")
	actor.cooldown = float(data.get("cooldown", 0.0))
	actor.health = float(data.get("health", 0.0))
	actor.invulnerable = float(data.get("invulnerable", 0.0))
	actor.position = data.get("position", Vector2.ZERO)
	actor.slot = int(data.get("slot", -1))
	actor.stack = ModifierStack.from_dict(data.get("stack", {}))
	actor.velocity = data.get("velocity", Vector2.ZERO)
	actor.weapon_id = data.get("weapon_id", "")
	return actor
