extends RefCounted
## Предмет, лежащий на полу. Пока это только оружие; на M3 сюда придут
## сами предметы и органы — вид лежит полем, а не отдельным классом
## (правило 7).
##
## Подбор устроен обменом, а не поглощением: подобравший отдаёт в лежащее
## своё прежнее оружие. Поэтому за предмет можно вернуться и поменяться
## обратно, а комната не теряет содержимое от одного нажатия.

const KIND_WEAPON := "weapon"

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
