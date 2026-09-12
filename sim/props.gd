extends RefCounted
## Обстановка комнаты: бочки с нефтью. Стоят, ничего не делают и взрываются
## от любого попадания.
##
## Бочка — тело в списке актёров, а не отдельный список: так ей достаются
## готовые зоны урона, попадания снарядов и сериализация. Ценой одной
## проверки в зачистке комнаты: обстановка не держит выход закрытым.

const BLAST_RADIUS := 150.0
const BLAST_DAMAGE := 40.0


static func is_prop(actor) -> bool:
	return actor.behaviour == "prop"


## Взрывает бочки, погибшие в этом тике, и убирает их со сцены. Соседняя
## бочка от взрыва тоже гибнет, но рванёт уже следующим тиком — цепь идёт
## волной, а не схлопывается в один кадр.
##
## Возвращает игроков, которых взрывом свалило: поднимать их — дело тика,
## там же гасятся способности и отменяется чужой подъём.
static func advance(state, events: Array[Dictionary]) -> Array:
	var blasts: Array[Vector2] = []
	var surviving: Array = []
	for actor in state.actors:
		if is_prop(actor) and not actor.alive:
			blasts.append(actor.position)
			continue
		surviving.append(actor)
	var downed: Array = []
	if blasts.is_empty():
		return downed
	state.actors.assign(surviving)
	for at in blasts:
		events.append({"type": "explosion", "position": at, "radius": BLAST_RADIUS})
		for actor in state.actors:
			if not actor.alive or actor.position.distance_to(at) > BLAST_RADIUS:
				continue
			var health_before: float = actor.health
			var direction: Vector2 = actor.position - at
			if direction == Vector2.ZERO:
				direction = Vector2.UP
			if actor.take_damage(BLAST_DAMAGE) and actor.slot >= 0:
				downed.append(actor)
			if actor.health < health_before:
				events.append({"type": "hit", "actor_id": actor.id, "kind": "oil_drop",
					"position": actor.position, "direction": direction.normalized(),
					"damage": health_before - actor.health, "fallen": actor.health <= 0.0,
					"projectile_id": -1})
	return downed
