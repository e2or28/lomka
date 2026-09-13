extends "res://tests/framework/test_case.gd"
## Класс: поведение. Подбор и смена оружия следуют фактической смене предмета.
const FX = preload("res://game/loot_feedback.gd")
const Arena = preload("res://tests/framework/arena.gd")
const Pickup = preload("res://sim/pickup.gd")
const Arsenal = preload("res://sim/arsenal.gd")
func title() -> String: return "подбор и смена оружия"
func _test_swap_animates_both_directions_without_load_pop() -> bool:
	var fx := FX.new()
	var state := Arena.solo("loot-animation")
	var actor = state.actor_of_slot(0)
	var pickup = Pickup.weapon(state.take_id(), "colt", actor.position)
	state.pickups.append(pickup)
	fx.advance(state, 0.0)
	check(fx.births.is_empty(), "загрузка подбрасывает все вещи")
	Arsenal.equip(actor, "colt")
	pickup.content_id = "suitcase"
	fx.advance(state, 0.0)
	check(fx.births.has(pickup.id), "старое оружие не падает на пол")
	eq(fx.takes.size(), 1, "новое оружие не переходит в руку")
	check(fx.switch_progress(actor.id) >= 0.0, "нет смены оружия")
	fx.advance(state, 1.0)
	check(fx.takes.is_empty() and fx.births.is_empty() and fx.switches.is_empty(), "анимации не заканчиваются")
	fx.clear()
	fx.advance(state, 0.0)
	check(fx.takes.is_empty() and fx.births.is_empty(), "загрузка повторяет подбор")
	return true
func _test_cover_does_not_start_weapon_swap() -> bool:
	var fx := FX.new()
	var state := Arena.solo("cover-swap")
	fx.advance(state, 0)
	Arsenal.unequip(state.actor_of_slot(0))
	state.slots[0].cover_ticks = 240
	fx.advance(state, 0.02)
	check(fx.switches.is_empty(), "установка чемодана запустила смену оружия")
	return true
