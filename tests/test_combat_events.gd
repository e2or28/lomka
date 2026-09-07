extends "res://tests/framework/test_case.gd"
## Класс: поведение. Выстрел и попадание одного тика не теряются для представления.

const Arena = preload("res://tests/framework/arena.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const Command = preload("res://sim/input/command.gd")
const Tick: Script = preload("res://sim/tick.gd")

func title() -> String:
	return "события боя"


func _test_point_blank_shot_reports_both_shot_and_hit() -> bool:
	var state := Arena.duel("events", "test_monster", Vector2(26, 0))
	Arsenal.equip(state.actor_of_slot(0), "colt")
	var events: Variant = Tick.call("step", state, {0: Command.from_axes(0, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)})
	if not check(events is Array, "тик не возвращает события выстрела и попадания"):
		return true
	var shots: Array = events.filter(func(e): return e.type == "shot")
	var hits: Array = events.filter(func(e): return e.type == "hit" and e.kind == "bullet")
	eq(shots.size(), 1, "ближний выстрел потерян или продублирован")
	eq(hits.size(), 1, "попадание не доставлено")
	if shots.size() == 1 and hits.size() == 1:
		eq(hits[0].kind, "bullet", "потерян тип удара")
		eq(hits[0].projectile_id, shots[0].projectile_id, "удар связан с чужим снарядом")
		check(hits[0].damage > 0, "эффект создан без урона")
	return true


func _test_invulnerable_target_has_no_hit_feedback() -> bool:
	var state := Arena.duel("blocked", "test_monster", Vector2(26, 0))
	Arena.enemies(state)[0].invulnerable = 1.0
	var events: Variant = Tick.call("step", state, {0: Command.from_axes(0, Vector2.ZERO, Vector2.RIGHT, Command.BTN_FIRE)})
	if not check(events is Array, "нет списка событий"):
		return true
	eq(events.filter(func(e): return e.type == "hit" and e.actor_id == Arena.enemies(state)[0].id).size(), 0, "иммунитет нарисовал ложное попадание")
	return true


func _test_contact_and_lethal_hit_are_distinguished() -> bool:
	var state := Arena.duel("contact", "test_monster", Vector2.ZERO)
	state.actor_of_slot(0).health = 1.0
	var events: Variant = Tick.call("step", state, {})
	if not check(events is Array, "нет списка событий"):
		return true
	var hits: Array = events.filter(func(e): return e.type == "hit")
	eq(hits.size(), 1, "касание не создало одно попадание")
	if hits.size() == 1:
		eq(hits[0].kind, "contact", "касание перепутано с пулей")
		check(hits[0].fallen, "не отмечено падение игрока")
	return true
