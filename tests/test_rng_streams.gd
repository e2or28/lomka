extends "res://tests/framework/test_case.gd"
## Обязательный тест номер один. Критерий выхода M0 из docs/ROADMAP.md:
## доказать, что вычерпывание одного потока случайности не сдвигает другой.
##
## Это единственная защита от класса багов, который иначе всплывёт на M2
## рассинхроном: хост бросил лишний раз на разброс ИИ — и лут у клиента лёг
## иначе, потому что генератор один на всех.

const RngStreams = preload("res://sim/core/rng_streams.gd")
const Fnv = preload("res://sim/core/fnv.gd")

const SEED := "забег-42"
const SAMPLE := 5
const DRAIN := 1000


func title() -> String:
	return "потоки случайности"




func _take(streams, name: String, count: int) -> Array:
	var out: Array = []
	var rng: RandomNumberGenerator = streams.stream(name)
	for i in count:
		out.append(rng.randi())
	return out


## FNV-1a должен давать те же числа, что и любая другая корректная
## реализация: сид забега пересекает сеть и версии движка.
func _test_fnv_reference_vectors() -> bool:
	eq(Fnv.hash_string(""), -3750763034362895579, "FNV-1a от пустой строки")
	eq(Fnv.hash_string("a"), -5808556873153909620, "FNV-1a от 'a'")
	eq(Fnv.hash_string("foobar"), -8821353812377114648, "FNV-1a от 'foobar'")
	return true


## Главная проверка вехи.
func _test_isolation() -> bool:
	var reference := RngStreams.new(SEED)
	var expected := _take(reference, RngStreams.ORGAN_DROP, SAMPLE)

	var drained := RngStreams.new(SEED)
	_take(drained, RngStreams.LOOT_PLACEMENT, DRAIN)
	_take(drained, RngStreams.AI_SPREAD, DRAIN)
	_take(drained, RngStreams.ITEM_POOL, DRAIN)
	var actual := _take(drained, RngStreams.ORGAN_DROP, SAMPLE)

	eq(actual, expected, "дроп органов сдвинулся после вычерпывания соседних потоков")
	return true


func _test_determinism() -> bool:
	var a := RngStreams.new(SEED)
	var b := RngStreams.new(SEED)
	for name in RngStreams.DECLARED:
		eq(_take(a, name, SAMPLE), _take(b, name, SAMPLE), "поток '%s' недетерминирован" % name)
	return true


func _test_seed_changes_everything() -> bool:
	var a := RngStreams.new(SEED)
	var b := RngStreams.new(SEED + "!")
	for name in RngStreams.DECLARED:
		ne(_take(a, name, SAMPLE), _take(b, name, SAMPLE), "поток '%s' не зависит от сида забега" % name)
	return true


func _test_streams_differ() -> bool:
	var streams := RngStreams.new(SEED)
	var seen := {}
	for name in RngStreams.DECLARED:
		var key := str(_take(streams, name, SAMPLE))
		check(not seen.has(key), "потоки '%s' и '%s' дают одну последовательность" % [name, seen.get(key, "")])
		seen[key] = name
	return true


func _test_reset() -> bool:
	var streams := RngStreams.new(SEED)
	var first := _take(streams, RngStreams.LOOT_PLACEMENT, SAMPLE)
	_take(streams, RngStreams.LOOT_PLACEMENT, DRAIN)
	streams.reset()
	eq(_take(streams, RngStreams.LOOT_PLACEMENT, SAMPLE), first, "reset не вернул поток в начало")
	return true


## Сид потока зависит от сида забега и имени — и больше ни от чего. Если он
## зависел бы от порядка или числа потоков, добавление пятой подсистемы
## сломало бы сиды всех сохранённых забегов.
func _test_seed_independent_of_composition() -> bool:
	var plain := RngStreams.new(SEED)
	var extended := RngStreams.new(SEED, ["shop_stock", "room_fill"] as Array[String])
	for name in RngStreams.DECLARED:
		eq(extended.stream_seed(name), plain.stream_seed(name),
			"сид потока '%s' поехал от добавления новых потоков" % name)
	eq(_take(extended, RngStreams.ITEM_POOL, SAMPLE), _take(plain, RngStreams.ITEM_POOL, SAMPLE),
		"последовательность пула предметов поехала от добавления новых потоков")
	check(extended.has("shop_stock"), "заявленный дополнительный поток не создан")
	check(not plain.has("shop_stock"), "незаявленный поток откуда-то взялся")
	return true
