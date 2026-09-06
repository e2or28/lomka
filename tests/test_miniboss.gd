extends "res://tests/framework/test_case.gd"
## Класс: поведение. Предупреждение танка честно фиксирует направление выстрела.

const Arena = preload("res://tests/framework/arena.gd")
const Bestiary = preload("res://sim/bestiary.gd")
const Command = preload("res://sim/input/command.gd")


func title() -> String:
	return "мини-босс танк"


func _test_tank_warns_then_fires_at_locked_direction() -> bool:
	if not check(Bestiary.ENEMIES.has("tandem"), "танк не добавлен в бестиарий"):
		return true
	var state := Arena.duel("танк", "tandem", Vector2(320, 0))
	var tank = Arena.enemies(state)[0]
	Arena.coast(state, 1)
	eq(state.projectiles.size(), 0, "выстрел без предупреждения")
	check(tank.attack_ticks > 0, "предупреждение не началось")
	var locked: Vector2 = tank.attack_aim
	state.actor_of_slot(0).position = Vector2(0, 150)
	Arena.coast(state, 53)
	eq(state.projectiles.size(), 0, "выстрел раньше 0,9 с")
	Arena.coast(state, 1)
	eq(state.projectiles.size(), 1, "после предупреждения нет выстрела")
	if state.projectiles.is_empty():
		return true
	check(state.projectiles[0].velocity.normalized().is_equal_approx(locked), "прицел изменился после предупреждения")
	eq(state.projectiles[0].kind, "tank_shell", "неверный снаряд танка")
	return true


func _test_dead_tank_does_not_fire_and_gives_unique_organ() -> bool:
	if not check(Bestiary.ENEMIES.has("tandem"), "нет мини-босса"):
		return true
	var state := Arena.duel("труп танка", "tandem", Vector2(50, 0))
	var tank = Arena.enemies(state)[0]
	Arena.coast(state, 1)
	tank.take_damage(1000)
	Arena.hold(state, 60, Vector2.ZERO, Vector2.ZERO, Command.BTN_HARVEST)
	eq(state.projectiles.size(), 0, "мёртвый танк стреляет")
	eq(state.heat, 25, "орган босса не стоит 25 Heat")
	eq(state.slots[0].organs["spine"], "armored_spine", "не извлечён позвоночник")
	return true


func _test_save_during_telegraph_preserves_shot() -> bool:
	if not check(Bestiary.ENEMIES.has("tandem"), "нет мини-босса"):
		return true
	var state := Arena.duel("сейв танка", "tandem", Vector2(320, 0))
	Arena.coast(state, 24)
	var loaded := Arena.after_save(state)
	Arena.hold(state, 150, Vector2.UP, Vector2.RIGHT, Command.BTN_FIRE)
	Arena.hold(loaded, 150, Vector2.UP, Vector2.RIGHT, Command.BTN_FIRE)
	eq(state.state_hash(), loaded.state_hash(), "атака танка разошлась после сейва")
	return true
