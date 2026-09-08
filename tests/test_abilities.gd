# Класс: поведение.
extends "res://tests/framework/test_case.gd"

const Abilities = preload("res://sim/abilities.gd")
const Arena = preload("res://tests/framework/arena.gd")
const Actor = preload("res://sim/actor.gd")
const Projectile = preload("res://sim/projectile.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Command = preload("res://sim/input/command.gd")
const PlayerSlot = preload("res://sim/player_slot.gd")


func title() -> String:
	return "Обеденный перерыв"


func _test_cover_lifetime_and_return() -> bool:
	var state := Arena.solo("lunch-lifetime")
	var slot = state.slots[0]
	var actor = state.actor_of_slot(0)
	slot.charge_ticks = 20
	check(Abilities.activate(state, slot), "чемодан устанавливается")
	eq(actor.weapon_id, "", "чемодан снят из рук")
	eq(slot.charge_ticks, 0, "заряд сброшен")
	eq(slot.cover_ticks, 240, "четыре секунды укрытия")
	eq(slot.skill_cooldown_ticks, 600, "перезарядка начинается сразу")
	eq(slot.cover_position, actor.position + Vector2.RIGHT * 72.0, "укрытие впереди героя")
	for i in 239:
		Abilities.advance(state, {})
	eq(actor.weapon_id, "", "до конца последнего тика оружия нет")
	Abilities.advance(state, {})
	eq(actor.weapon_id, "suitcase", "срок вернул чемодан")
	eq(slot.cover_health, 0.0, "укрытия больше нет")
	eq(slot.skill_cooldown_ticks, 360, "перезарядка продолжалась параллельно")
	var stats: Dictionary = actor.stack.compute()
	Abilities.finish(state, slot)
	eq(actor.stack.compute(), stats, "повторный возврат не дублирует модификаторы")
	return true


func _test_skill_button_requires_new_press() -> bool:
	var state := Arena.solo("lunch-button")
	var slot = state.slots[0]
	var command = Command.from_axes(0, Vector2.ZERO, Vector2.ZERO, Command.BTN_SKILL)
	Abilities.advance(state, {0: command})
	eq(slot.cover_ticks, 240, "нажатие включает способность персонажа")
	for i in 600:
		Abilities.advance(state, {0: command})
	eq(slot.cover_ticks, 0, "удержание не включает снова после перезарядки")
	Abilities.advance(state, {})
	Abilities.advance(state, {0: command})
	eq(slot.cover_ticks, 240, "новое нажатие снова устанавливает укрытие")
	return true


func _test_placement_rejects_edges_walls_and_covers() -> bool:
	var state := Arena.room("lunch-placement", 2, 0)
	var actor = state.actor_of_slot(0)
	var slot = state.slots[0]
	actor.position = Vector2(state.room.bounds.end.x - 75.0, 0)
	check(not Abilities.activate(state, slot), "целый прямоугольник должен помещаться в комнате")
	eq(slot.skill_cooldown_ticks, 0, "неудачная установка не тратит перезарядку")
	eq(actor.weapon_id, "suitcase", "неудачная установка оставляет оружие")
	actor.position = Vector2.ZERO
	state.room.blockers.append(Rect2(60, -10, 10, 20))
	check(not Abilities.activate(state, slot), "укрытие не пересекает мебель")
	state.room.blockers.clear()
	check(Abilities.activate(state, slot), "свободное место разрешает установку")
	state.actor_of_slot(1).position = actor.position
	check(not Abilities.activate(state, state.slots[1]), "укрытия не накладываются")
	Abilities.finish(state, slot)
	slot.skill_cooldown_ticks = 0
	actor.aim = Vector2.UP
	check(Abilities.activate(state, slot), "укрытие ставится вверх")
	eq(Abilities.rect(slot).size, Vector2(88, 28), "укрытие разворачивается поперёк прицела")
	return true


func _test_enemy_projectiles_hit_nearest_cover_and_destroy_it() -> bool:
	var state := Arena.room("lunch-projectile", 2, 0)
	state.actor_of_slot(0).position = Vector2(150, 0)
	state.actor_of_slot(1).position = Vector2.ZERO
	check(Abilities.activate(state, state.slots[0]), "дальнее укрытие установлено первым")
	check(Abilities.activate(state, state.slots[1]), "ближнее установлено вторым")
	var shot := Projectile.new()
	shot.owner_kind = Actor.Kind.PLAYER
	shot.damage = 20.0
	shot.position = Vector2(300, 0)
	check(not Abilities.blocks_shot(state, shot, Vector2.ZERO), "дружеский выстрел проходит")
	shot.owner_kind = Actor.Kind.ENEMY
	check(Abilities.blocks_shot(state, shot, Vector2.ZERO), "вражеский выстрел перехвачен между концами шага")
	eq(state.slots[1].cover_health, 34.0, "повреждено ближайшее по пути укрытие")
	eq(state.slots[0].cover_health, 54.0, "дальнее не повреждено")
	shot.damage = 34.0
	check(Abilities.blocks_shot(state, shot, Vector2.ZERO), "последний удар тоже перехвачен")
	eq(state.actor_of_slot(1).weapon_id, "suitcase", "разрушение вернуло оружие")
	eq(state.slots[1].cover_ticks, 0, "разрушенное укрытие не активно")
	shot.position = Vector2(300, 49)
	check(Abilities.blocks_shot(state, shot, Vector2(0, 49)), "радиус снаряда задевает край")
	shot.position = Vector2(300, 51)
	check(not Abilities.blocks_shot(state, shot, Vector2(0, 51)), "снаряд вне радиуса проходит")
	return true


func _test_downed_and_wrong_weapon() -> bool:
	var state := Arena.solo("lunch-downed")
	var slot = state.slots[0]
	var actor = state.actor_of_slot(0)
	Arsenal.equip(actor, "colt")
	check(not Abilities.activate(state, slot), "кольт нельзя поставить вместо чемодана")
	Arsenal.equip(actor, "suitcase")
	check(Abilities.activate(state, slot), "чемодан установлен")
	slot.downed = true
	Abilities.advance(state, {})
	eq(actor.weapon_id, "suitcase", "падение возвращает чемодан")
	eq(slot.cover_ticks, 0, "при падении укрытие исчезает")
	slot.skill_cooldown_ticks = 0
	check(not Abilities.activate(state, slot), "упавший не ставит укрытие")
	return true


func _test_cover_blocks_enemies_but_not_players() -> bool:
	var state := Arena.duel("lunch-collision", "runner", Vector2(140, 0))
	check(Abilities.activate(state, state.slots[0]), "укрытие установлено")
	var enemy = Arena.enemies(state)[0]
	var before: Vector2 = enemy.position
	enemy.position = Vector2(10, 0)
	Abilities.constrain_enemy(state, enemy, before)
	check(enemy.position.x >= 86.0 + enemy.radius, "враг не проскочил укрытие за большой шаг")
	var actor = state.actor_of_slot(0)
	actor.position = Vector2(72, 0)
	Abilities.constrain_enemy(state, actor, Vector2.ZERO)
	eq(actor.position, Vector2(72, 0), "игрок проходит сквозь своё укрытие")
	enemy.alive = false
	enemy.position = Vector2(72, 0)
	Abilities.constrain_enemy(state, enemy, before)
	eq(enemy.position, Vector2(72, 0), "труп укрытие не выталкивает")
	return true


func _test_slot_preserves_skill_and_build_state() -> bool:
	var slot = PlayerSlot.new(2)
	slot.items.assign(["carbon_copy", "carbon_copy"])
	slot.charge_ticks = 17
	slot.skill_held = true
	slot.skill_cooldown_ticks = 432
	slot.cover_ticks = 81
	slot.cover_health = 19.5
	slot.cover_position = Vector2(40, -70)
	slot.cover_direction = Vector2.LEFT
	var restored = PlayerSlot.from_dict(slot.to_dict())
	bytes_eq(var_to_bytes(restored.to_dict()), var_to_bytes(slot.to_dict()), "все поля слота переживают сериализацию")
	return true


func _test_placement_cannot_trap_living_enemy() -> bool:
	var state := Arena.duel("lunch-overlap", "runner", Vector2(92, 0))
	var slot = state.slots[0]
	check(not Abilities.activate(state, slot), "установка не зажимает живого врага краем его радиуса")
	eq(slot.skill_cooldown_ticks, 0, "отказ рядом с врагом не тратит перезарядку")
	eq(state.actor_of_slot(0).weapon_id, "suitcase", "при отказе чемодан остаётся в руках")
	Arena.enemies(state)[0].alive = false
	check(Abilities.activate(state, slot), "труп не мешает установке")
	return true


func _test_skill_uses_current_command_aim() -> bool:
	var state := Arena.solo("lunch-aim")
	var command = Command.from_axes(0, Vector2.ZERO, Vector2.UP, Command.BTN_SKILL)
	Abilities.advance(state, {0: command})
	eq(state.actor_of_slot(0).aim, Vector2.UP, "способность видит текущий прицел до движения игрока")
	eq(state.slots[0].cover_position, state.actor_of_slot(0).position + Vector2.UP * 72.0,
		"одновременное направление и способность устанавливает в новую сторону")
	return true


func _test_enemy_can_leave_cover_boundary() -> bool:
	var state := Arena.duel("lunch-boundary", "runner", Vector2(104, 0))
	check(Abilities.activate(state, state.slots[0]), "касание границы не мешает установке")
	var enemy = Arena.enemies(state)[0]
	enemy.position = Vector2(110, 0)
	Abilities.constrain_enemy(state, enemy, Vector2(104, 0))
	eq(enemy.position, Vector2(110, 0), "враг может отойти от границы укрытия")
	return true
