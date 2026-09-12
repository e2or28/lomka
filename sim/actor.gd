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

## Напольный радиус для стен, расталкивания и касаний. У игрока он также
## остаётся прощающей зоной попадания; у врагов урон принимают hurtboxes.
var radius: float = 16.0
## Зоны урона относительно опоры тела в плоскости видимого снаряда.
var hurtboxes: Array[Rect2] = []
var facing: int = 1
var standing_front: bool = false

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

var organ_id: String = ""
var harvested: bool = false
var corpse_until_tick: int = -1
var attack_ticks: int = 0
var attack_aim: Vector2 = Vector2.ZERO

## Нажатие кнопки подкрепления: тики до конца, -1 у того, кто уже вызвал.
var call_ticks: int = 0

## Спуск по канату: тики до земли. Ноль у всех, кто стоит на ней сам.
var drop_ticks: int = 0


func _init(p_id: int = 0, p_kind: Kind = Kind.PLAYER) -> void:
	id = p_id
	kind = p_kind
	stack = ModifierStack.new()


func max_health() -> float:
	return float(stack.compute().get("health", 0.0))


func heal_to_full() -> void:
	health = max_health()
	alive = health > 0.0


## true, если этим ударом тело добито; время исчезновения ставит Corpses.
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
		"attack_aim": attack_aim,
		"attack_ticks": attack_ticks,
		"behaviour": behaviour,
		"call_ticks": call_ticks,
		"cooldown": cooldown,
		"drop_ticks": drop_ticks,
		"corpse_until_tick": corpse_until_tick,
		"facing": facing,
		"health": health,
		"harvested": harvested,
		"hurtboxes": hurtboxes,
		"id": id,
		"invulnerable": invulnerable,
		"kind": int(kind),
		"organ_id": organ_id,
		"position": position,
		"radius": radius,
		"slot": slot,
		"stack": stack.to_dict(),
		"standing_front": standing_front,
		"velocity": velocity,
		"weapon_id": weapon_id,
	}


static func from_dict(data: Dictionary):
	var actor := new(int(data.get("id", 0)), data.get("kind", Kind.PLAYER) as Kind)
	actor.aim = data.get("aim", Vector2.RIGHT)
	actor.alive = bool(data.get("alive", true))
	actor.archetype = data.get("archetype", "")
	actor.attack_aim = data.get("attack_aim", Vector2.ZERO)
	actor.attack_ticks = int(data.get("attack_ticks", 0))
	actor.behaviour = data.get("behaviour", "")
	actor.call_ticks = int(data.get("call_ticks", 0))
	actor.cooldown = float(data.get("cooldown", 0.0))
	actor.drop_ticks = int(data.get("drop_ticks", 0))
	actor.corpse_until_tick = int(data.get("corpse_until_tick", -1))
	actor.facing = int(data.get("facing", 1))
	actor.standing_front = bool(data.get("standing_front", false))
	actor.hurtboxes.assign(data.get("hurtboxes", []))
	actor.health = float(data.get("health", 0.0))
	actor.harvested = bool(data.get("harvested", false))
	actor.organ_id = data.get("organ_id", "")
	actor.invulnerable = float(data.get("invulnerable", 0.0))
	actor.position = data.get("position", Vector2.ZERO)
	actor.radius = float(data.get("radius", actor.radius))
	actor.slot = int(data.get("slot", -1))
	actor.stack = ModifierStack.from_dict(data.get("stack", {}))
	actor.velocity = data.get("velocity", Vector2.ZERO)
	actor.weapon_id = data.get("weapon_id", "")
	return actor
