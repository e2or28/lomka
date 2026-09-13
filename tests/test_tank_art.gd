extends "res://tests/framework/test_case.gd"
## Класс: поведение. Вес танка читается в корпусе, опора и телеграф неподвижны.

const Art = preload("res://game/tank_art.gd")

func title() -> String:
	return "анимация танка"


func _test_tracks_stay_on_the_floor_while_passengers_move() -> bool:
	var head := Vector2(290, 30)
	var floor := Vector2(290, 240)
	check(Art.deform(head, 45, 0.1, -1, -1, true) != Art.deform(head, 45, 0.2, -1, -1, true),
		"пассажиры не покачиваются при езде")
	for time in [0.0, 0.1, 0.4, 1.0]:
		eq(Art.deform(floor, 45, time, -1, -1, true), floor, "гусеница оторвалась от пола")
	return true


func _test_windup_freezes_the_idle_rattle() -> bool:
	var point := Vector2(280, 40)
	eq(Art.deform(point, 45, 0.1, 0.5, -1, true), Art.deform(point, 45, 0.3, 0.5, -1, true),
		"танк продолжает трястись во время прицеливания")
	return true


func _test_barrel_recoils_and_returns_without_moving_the_ground() -> bool:
	var muzzle := Vector2(8, 157)
	check(Art.deform(muzzle, 0, 0, -1, 0.06, true).x > muzzle.x + 5,
		"ствол не откатился после выстрела")
	eq(Art.deform(muzzle, 0, 0, -1, Art.RECOIL_TIME, true), muzzle, "ствол не вернулся")
	eq(Art.deform(Vector2(290, 240), 0, 0, -1, 0.06, true), Vector2(290, 240), "отдача подняла опору")
	return true


func _test_dead_tank_is_still_even_during_an_unfinished_attack() -> bool:
	for p in [Vector2(8, 157), Vector2(290, 30), Vector2(290, 240)]:
		eq(Art.deform(p, 45, 0.1, 0.8, 0.06, false), p, "мёртвый танк анимируется")
	return true

func _test_tracks_move_only_with_actual_travel_and_clear() -> bool:
	var state = preload("res://tests/framework/arena.gd").duel("tracks", "tandem", Vector2(300, 0))
	var actor = preload("res://tests/framework/arena.gd").enemies(state)[0]
	var art = Art.new()
	actor.aim = Vector2.LEFT
	actor.velocity = Vector2(-45, 0)
	art.advance(state.actors)
	actor.position.x -= 9
	art.advance(state.actors)
	almost_eq(art.track_distance(actor.id), 9.0, "лента не связана с пройденным расстоянием")
	art.advance(state.actors)
	almost_eq(art.track_distance(actor.id), 9.0, "лента движется на месте")
	actor.alive = false
	actor.position.x -= 9
	art.advance(state.actors)
	almost_eq(art.track_distance(actor.id), 9.0, "мёртвый танк крутит гусеницы")
	art.clear()
	eq(art.track_distance(actor.id), 0.0, "смена комнаты сохранила гусеницы")
	return true

func _test_wheel_rotation_keeps_center_and_radius() -> bool:
	var center := Vector2(206, 222)
	var rim := center + Vector2(12, 0)
	var moved: Vector2 = Art.wheel_uv(rim, center, 12.0)
	almost_eq(moved.distance_to(center), 12.0, "поворот растянул колесо", 0.00001)
	ne(moved, rim, "колесо не вращается")
	eq(Art.wheel_uv(center, center, 12.0), center, "центр колеса съехал")
	return true
