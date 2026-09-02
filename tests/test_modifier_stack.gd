extends "res://tests/framework/test_case.gd"
## Класс: инвариант. Правило 4 записано в docs/PLAN.md как нерушимое, и
## порядок фаз здесь — его определение.
##
## Стек модификаторов. Правило 4 из docs/PLAN.md.
##
## Проверяется главное свойство: порядок применения задаётся фазой (ADD, MUL,
## SET), а не тем, в каком порядке предметы попали в стек. Без этого один и
## тот же набор предметов даёт у хоста и клиента разные статы — и забег
## расходится не сразу, а к третьей зоне.

const ModifierStack = preload("res://sim/core/modifier_stack.gd")
const Modifier = preload("res://sim/core/modifier.gd")

const BASE := {"damage": 10.0, "health": 100.0}


func title() -> String:
	return "стек модификаторов"




func _test_phases_before_insertion_order() -> bool:
	# Множитель положен первым, прибавка второй. Если бы применялось в
	# порядке добавления, вышло бы 10*2+5 = 25.
	var stack := ModifierStack.new(BASE)
	stack.add(Modifier.make("damage", Modifier.Op.MUL, 2.0, "item:a"))
	stack.add(Modifier.make("damage", Modifier.Op.ADD, 5.0, "item:b"))
	almost_eq(stack.compute()["damage"], 30.0, "MUL применился раньше ADD")

	# Тот же набор в обратном порядке добавления — тот же итог.
	var mirror := ModifierStack.new(BASE)
	mirror.add(Modifier.make("damage", Modifier.Op.ADD, 5.0, "item:b"))
	mirror.add(Modifier.make("damage", Modifier.Op.MUL, 2.0, "item:a"))
	almost_eq(mirror.compute()["damage"], 30.0, "итог зависит от порядка добавления")
	return true


func _test_set_wins_last() -> bool:
	var stack := ModifierStack.new(BASE)
	stack.add(Modifier.make("damage", Modifier.Op.SET, 1.0, "state:cursed"))
	stack.add(Modifier.make("damage", Modifier.Op.ADD, 99.0, "item:c"))
	stack.add(Modifier.make("damage", Modifier.Op.MUL, 3.0, "item:d"))
	almost_eq(stack.compute()["damage"], 1.0, "SET не оказался последним")
	return true


func _test_base_untouched() -> bool:
	var stack := ModifierStack.new(BASE)
	stack.add(Modifier.make("damage", Modifier.Op.ADD, 5.0, "item:e"))
	stack.compute()
	almost_eq(float(stack.base["damage"]), 10.0, "compute переписал базовый стат")
	almost_eq(float(BASE["damage"]), 10.0, "стек держит ссылку на чужой словарь базы")
	return true


func _test_remove_source() -> bool:
	var stack := ModifierStack.new(BASE)
	stack.add(Modifier.make("damage", Modifier.Op.ADD, 5.0, "item:lost"))
	stack.add(Modifier.make("damage", Modifier.Op.MUL, 2.0, "item:lost"))
	stack.add(Modifier.make("health", Modifier.Op.ADD, 20.0, "item:kept"))

	eq(stack.remove_source("item:lost"), 2, "снялось не два модификатора")
	almost_eq(stack.compute()["damage"], 10.0, "урон не вернулся к базовому после потери предмета")
	almost_eq(stack.compute()["health"], 120.0, "снялось лишнее")
	eq(stack.remove_source("item:never"), 0, "снялось что-то от несуществующего источника")
	return true


func _test_unknown_stat_starts_from_zero() -> bool:
	var stack := ModifierStack.new(BASE)
	stack.add(Modifier.make("luck", Modifier.Op.ADD, 3.0, "item:f"))
	almost_eq(stack.compute()["luck"], 3.0, "стат вне базы начался не с нуля")
	return true


## Одинаково собранный стек обязан давать побитово одинаковый результат:
## на этом держится сверка состояния между хостом и клиентом.
func _test_repeatable() -> bool:
	var a := ModifierStack.new(BASE)
	var b := ModifierStack.new(BASE)
	for stack in [a, b]:
		stack.add(Modifier.make("damage", Modifier.Op.ADD, 0.1, "item:g"))
		stack.add(Modifier.make("damage", Modifier.Op.ADD, 0.2, "item:h"))
		stack.add(Modifier.make("damage", Modifier.Op.MUL, 1.07, "item:i"))
		stack.add(Modifier.make("damage", Modifier.Op.ADD, 0.3, "item:j"))
	eq(var_to_bytes(a.compute()), var_to_bytes(b.compute()), "два одинаковых стека посчитались по-разному")
	return true


func _test_roundtrip() -> bool:
	var stack := ModifierStack.new(BASE)
	stack.add(Modifier.make("damage", Modifier.Op.ADD, 5.0, "item:k", "mk"))
	stack.add(Modifier.make("damage", Modifier.Op.MUL, 1.25, "item:l", "ml"))
	stack.add(Modifier.make("health", Modifier.Op.SET, 50.0, "state:m", "mm"))

	var data := stack.to_dict()
	var restored = ModifierStack.from_dict(data)
	eq(restored.to_dict(), data, "стек не пережил круг через словарь")
	eq(restored.compute(), stack.compute(), "восстановленный стек считает иначе")
	eq(restored.size(), 3, "модификаторы потерялись")

	# Порядок обязан пережить загрузку: новый модификатор ложится после всех.
	restored.add(Modifier.make("damage", Modifier.Op.ADD, 1.0, "item:n", "mn"))
	stack.add(Modifier.make("damage", Modifier.Op.ADD, 1.0, "item:n", "mn"))
	eq(restored.to_dict(), stack.to_dict(), "нумерация модификаторов после загрузки поехала")
	return true
