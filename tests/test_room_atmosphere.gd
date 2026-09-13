extends "res://tests/framework/test_case.gd"
## Класс: поведение. Пыль только после залпа, мерцание редко и ограничено.
const FX = preload("res://game/room_atmosphere.gd")
const Arena = preload("res://tests/framework/arena.gd")
func title() -> String: return "лампа и пыль барона"
func _test_dust_belongs_to_actual_live_volley() -> bool:
	var state = Arena.duel("dust", "oil_baron", Vector2(200, 0))
	var boss = Arena.enemies(state)[0]
	boss.cooldown = 2.2
	check(FX.dust_age(boss) > 0, "нет пыли после рабочего хода")
	boss.attack_ticks = 10
	eq(FX.dust_age(boss), -1.0, "пыль до залпа")
	boss.attack_ticks = 0
	boss.alive = false
	eq(FX.dust_age(boss), -1.0, "мёртвая качалка пылит")
	return true
func _test_lamp_is_steady_most_of_the_time() -> bool:
	var dimmed := 0
	var bounded := true
	for i in 1100:
		var dim := FX.lamp_dim(i / 100.0)
		if dim > 0: dimmed += 1
		bounded = bounded and dim >= 0.0 and dim <= 0.65
	check(bounded, "мерцание вышло за пределы")
	check(dimmed > 0 and dimmed < 25, "лампа мерцает непрерывно или не мерцает")
	return true
