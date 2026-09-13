extends "res://tests/framework/test_case.gd"
## Класс: поведение. Загрузка и истечение времени не взрывают чемодан.
const Arena = preload("res://tests/framework/arena.gd")
func title() -> String: return "анимация чемодана"
func _test_cover_lifecycle() -> bool:
	var script = load("res://game/cover_art.gd")
	check(script != null and script.can_instantiate(), "нет анимации чемодана")
	if script == null or not script.can_instantiate(): return true
	var art = script.new()
	var state := Arena.solo("cover-animation")
	var slot = state.slots[0]
	art.advance(state, 0.0)
	slot.cover_ticks = 240
	slot.cover_health = 54
	art.advance(state, 0.0)
	almost_eq(art.covers[0].age, 0.0, "постановка пропущена")
	slot.cover_health = 30
	art.advance(state, 0.02)
	almost_eq(art.covers[0].hit, 0.0, "нет реакции на попадание")
	slot.cover_ticks = 0
	slot.cover_health = 0
	art.advance(state, 0.02)
	eq(art.debris.size(), 1, "нет разрушения")
	art.advance(state, 1.0)
	check(art.debris.is_empty(), "обломки не исчезли")
	art.clear()
	slot.cover_ticks = 1
	art.advance(state, 0.0)
	slot.cover_ticks = 0
	art.advance(state, 0.02)
	check(art.debris.is_empty(), "истечение времени показано взрывом")
	return true
