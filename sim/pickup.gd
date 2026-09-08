extends RefCounted
## Оружие или извлечённый орган на полу. Вид — данные, не отдельный класс.
##
## Подбор устроен обменом, а не поглощением: подобравший отдаёт в лежащее
## своё прежнее оружие или орган. Поэтому за предмет можно вернуться и поменяться
## обратно, а комната не теряет содержимое от одного нажатия.

const KIND_WEAPON := "weapon"
const KIND_ORGAN := "organ"
const KIND_ITEM := "item"

var id: int = 0
var kind: String = KIND_WEAPON

## Что именно лежит: идентификатор из реестра нужного вида.
var content_id: String = ""

var position: Vector2 = Vector2.ZERO

## Круг подбора, как хитбокс тела: складывается с радиусом подбирающего.
## Щедрее хитбокса намеренно — промахнуться мимо лута обиднее, чем мимо врага.
var radius: float = 26.0


static func weapon(p_id: int, weapon_id: String, at: Vector2):
	var pickup := new()
	pickup.id = p_id
	pickup.kind = KIND_WEAPON
	pickup.content_id = weapon_id
	pickup.position = at
	return pickup


static func organ(p_id: int, organ_id: String, at: Vector2):
	var pickup = weapon(p_id, organ_id, at)
	pickup.kind = KIND_ORGAN
	return pickup


static func item(p_id: int, item_id: String, at: Vector2):
	var pickup = weapon(p_id, item_id, at)
	pickup.kind = KIND_ITEM
	return pickup


## Что заберёт это тело, нажав E. Одно место на игру: вид рисует подсказку
## по нему же, иначе подпись обещает подбор там, где тик его запретил —
## так и случилось с оружием при выставленном укрытии.
static func nearest(state, actor):
	var found = null
	var shortest := INF
	for pickup in state.pickups:
		if pickup.kind not in [KIND_WEAPON, KIND_ORGAN, KIND_ITEM]:
			continue
		if pickup.kind == KIND_WEAPON and state.slots[actor.slot].cover_ticks > 0:
			continue
		var reach: float = pickup.radius + actor.radius
		var distance: float = pickup.position.distance_squared_to(actor.position)
		if distance <= reach * reach and distance < shortest:
			found = pickup
			shortest = distance
	return found


func to_dict() -> Dictionary:
	return {
		"content_id": content_id,
		"id": id,
		"kind": kind,
		"position": position,
		"radius": radius,
	}


static func from_dict(data: Dictionary):
	var pickup := new()
	pickup.content_id = data.get("content_id", "")
	pickup.id = int(data.get("id", 0))
	pickup.kind = data.get("kind", KIND_WEAPON)
	pickup.position = data.get("position", Vector2.ZERO)
	pickup.radius = float(data.get("radius", 26.0))
	return pickup
