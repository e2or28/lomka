extends "res://tests/framework/test_case.gd"
## Класс: инвариант. Косметические переходы не записываются в сейв.
const View = preload("res://game/world_view.gd")
const Arena = preload("res://tests/framework/arena.gd")
const Save = preload("res://sim/save/save_game.gd")
const Organs = preload("res://sim/organs.gd")
const Arsenal = preload("res://sim/arsenal.gd")
func title() -> String: return "жизненный цикл анимаций"
func _test_effects_do_not_mutate_save_and_do_not_leak_between_rooms() -> bool:
	var view := View.new()
	view.state = Arena.room("animation-lifecycle", 2, 0)
	view.state.slots[1].downed = true
	view.advance(0.0)
	var actor = view.state.actor_of_slot(0)
	Organs.equip(actor, view.state.slots[0], "courier_heart")
	Arsenal.equip(actor, "colt")
	view.state.slots[1].downed = false
	var bytes := Save.to_bytes(view.state)
	view.advance(0.0)
	check(not view.actions.installs.is_empty(), "нет установки")
	check(not view.rescue.rising.is_empty(), "нет подъёма")
	check(not view.loot_feedback.switches.is_empty(), "нет смены оружия")
	for i in 12: view.advance(1.0 / 120.0)
	bytes_eq(Save.to_bytes(view.state), bytes, "отрисовка меняет сейв")
	view.state = Arena.after_save(view.state)
	view.state.tick += 1
	view.advance(0.01)
	check(not view.actions.installs.is_empty(), "снимок прервал эффект")
	view.state.room.id = "another"
	view.advance(0.0)
	check(view.actions.installs.is_empty(), "орган переехал между комнатами")
	check(view.rescue.rising.is_empty(), "подъём переехал между комнатами")
	check(view.loot_feedback.switches.is_empty(), "смена оружия переехала между комнатами")
	check(view.cover_art.debris.is_empty(), "обломки переехали между комнатами")
	view.free()
	return true
