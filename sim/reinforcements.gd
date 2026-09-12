extends RefCounted
## Второй этап боя с бароном: кнопка, вертолёт и высадка по канатам.
##
## Барон не машина и не стреляет из вертолёта сам — он жмёт кнопку на
## пульте, и дальше всё делает техника. Поэтому вызов живёт здесь, а не в
## его профиле атаки: его собственный веер от этого не зависит.

const Bestiary = preload("res://sim/bestiary.gd")

## Нажатие видно глазом: кадр с пультом держится, пока идут эти тики.
const CALL_TICKS := 72
## Спуск по канату. Дольше — и высадка успевает надоесть, короче — солдат
## просто мигает в воздухе.
const DROP_TICKS := 96
## Высота, с которой едут. Больше — и спускающийся уезжает за верхний край
## кадра: комната 750 в высоту, а сверху ещё стена.
const ROPE_HEIGHT := 150.0
## Доля здоровья, ниже которой барон зовёт подкрепление.
const CALL_AT_HEALTH := 0.5
## Где висит вертолёт и куда встают высаженные.
const HOVER_Y := -160.0
const DROP_SPREAD := 190.0


## Высота над полом, на которой сейчас висит спускающийся. Ноль у всех
## остальных, поэтому вызывать можно для любого тела.
static func rope_height(actor) -> float:
	if actor.drop_ticks <= 0:
		return 0.0
	return ROPE_HEIGHT * float(actor.drop_ticks) / float(DROP_TICKS)


## Пока едет по канату, боец не воюет: не стреляет, не бежит и не машет.
## Стрелять по нему можно — зоны урона едут вместе с ним.
static func riding(actor) -> bool:
	return actor.alive and actor.drop_ticks > 0


## Пульт занимает руки: пока барон жмёт кнопку, веером он не стреляет.
static func pressing(actor) -> bool:
	return actor.alive and actor.call_ticks > 0


static func summoning(state) -> bool:
	for actor in state.actors:
		if riding(actor):
			return true
	return false


## Возвращает true, если в этот тик барон дожал кнопку и пора высаживать.
static func drive_call(state, baron) -> bool:
	if baron.call_ticks < 0 or not baron.alive:
		return false
	if baron.call_ticks > 0:
		baron.call_ticks -= 1
		if baron.call_ticks > 0:
			return false
		baron.call_ticks = -1
		return true
	var full: float = baron.max_health()
	if full <= 0.0 or baron.health > full * CALL_AT_HEALTH:
		return false
	baron.call_ticks = CALL_TICKS
	# Веер отменяется: барон занят пультом, и стрелять ему нечем.
	baron.attack_ticks = 0
	return false


## Вертолёт с парой бойцов на канатах. Encounter передаётся вызывающим —
## sim/ не знает о нём напрямую, чтобы не закольцевать загрузку.
static func land(state, encounter, at_x: float) -> void:
	var gunship = encounter.add_enemy(state, "gunship", Vector2(at_x, HOVER_Y))
	if gunship == null:
		return
	var pair := ["soldier", "soldier_dark"]
	for i in pair.size():
		var side := -1.0 if i == 0 else 1.0
		var soldier = encounter.add_enemy(state, pair[i],
			Vector2(at_x + side * DROP_SPREAD, HOVER_Y + ROPE_HEIGHT))
		if soldier == null:
			continue
		soldier.drop_ticks = DROP_TICKS
		soldier.facing = int(-side)


## Канат отпускается по тику. Остановка боя не держит бойца в воздухе:
## спуск идёт своим ходом и заканчивается всегда.
static func advance(state) -> void:
	for actor in state.actors:
		if riding(actor):
			actor.drop_ticks -= 1
