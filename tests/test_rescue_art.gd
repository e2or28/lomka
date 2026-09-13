extends "res://tests/framework/test_case.gd"
## Класс: поведение. Подъём проигрывается при спасении, а не при загрузке.
const Art = preload("res://game/rescue_art.gd")
const Arena = preload("res://tests/framework/arena.gd")
func title() -> String: return "позы раненого и спасения"
func _test_rise_requires_downed_transition() -> bool:
	var fx := Art.new()
	var state := Arena.room("rescue-animation", 2, 0)
	var actor = state.actor_of_slot(1)
	state.slots[1].downed = true
	fx.advance(state, 0.0)
	check(fx.rising.is_empty(), "загрузка запускает подъём")
	state.slots[1].downed = false
	fx.advance(state, 0.0)
	check(fx.rising.has(actor.id), "спасённый не встаёт")
	fx.advance(state, 0.7)
	check(fx.rising.is_empty(), "подъём не завершился")
	state.slots[1].downed = true
	fx.advance(state, 0.0)
	state.slots[1].downed = false
	fx.advance(state, 0.0)
	fx.clear()
	check(fx.rising.is_empty(), "очистка сохранила подъём")
	return true
func _test_breathing_is_local_to_chest() -> bool:
	check(Art.downed_point(Vector2(52, 85), 0.0) != Art.downed_point(Vector2(52, 85), 0.5), "раненый не дышит")
	eq(Art.downed_point(Vector2(52, 174), 0.0), Art.downed_point(Vector2(52, 174), 0.5), "дыхание двигает стопу")
	return true
