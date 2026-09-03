extends RefCounted
## Именованные потоки случайности. Правило 3 из docs/PLAN.md.
##
## Один генератор на подсистему. При общем генераторе любой лишний вызов на
## одной стороне сдвигает последовательность и рассинхронизирует забег: хост
## бросил лишний раз на разброс ИИ — и лут у клиента лёг иначе.
##
## Сид потока = FNV-1a(сид_забега + "/" + имя). Потоки независимы по
## построению: вычерпывание одного не может сдвинуть другой.
##
## Состав потоков закрыт списком DECLARED. Опечатка в имени должна падать,
## а не молча заводить пятый генератор с другой последовательностью.

const Fnv = preload("res://sim/core/fnv.gd")

const LOOT_PLACEMENT := "loot_placement"
const ORGAN_DROP := "organ_drop"
const AI_SPREAD := "ai_spread"
const ITEM_POOL := "item_pool"

const DECLARED: Array[String] = [
	LOOT_PLACEMENT,
	ORGAN_DROP,
	AI_SPREAD,
	ITEM_POOL,
]

var run_seed: String = ""

var _streams: Dictionary = {}
var _names: Array[String] = []


func _init(seed_text: String = "", extra: Array[String] = []) -> void:
	run_seed = seed_text
	var all: Array[String] = DECLARED.duplicate()
	for name in extra:
		if not all.has(name):
			all.append(name)
	# Порядок имён канонический (отсортированный), а не порядок объявления:
	# от него зависит порядок ключей в сейве, а значит и байты.
	all.sort()
	_names = all
	for name in _names:
		var rng := RandomNumberGenerator.new()
		rng.seed = stream_seed(name)
		_streams[name] = rng


func stream_seed(name: String) -> int:
	return Fnv.hash_string(run_seed + "/" + name)


func names() -> Array[String]:
	return _names.duplicate()


func has(name: String) -> bool:
	return _streams.has(name)


## Незаявленное имя — ошибка проекта, а не повод завести новый генератор
## на лету.
func stream(name: String) -> RandomNumberGenerator:
	if not _streams.has(name):
		push_error("Неизвестный поток случайности: '%s'. Заявленные: %s" % [name, ", ".join(_names)])
		assert(false, "Неизвестный поток случайности: " + name)
		return null
	return _streams[name]


func reset() -> void:
	for name in _names:
		var rng: RandomNumberGenerator = _streams[name]
		rng.seed = stream_seed(name)


## Записываются позиции потоков, а не состояние мира (правило 8).
func to_dict() -> Dictionary:
	var states := {}
	for name in _names:
		var rng: RandomNumberGenerator = _streams[name]
		states[name] = rng.state
	return {
		"seed": run_seed,
		"states": states,
	}


static func from_dict(data: Dictionary):
	var seed_text: String = data.get("seed", "")
	var states: Dictionary = data.get("states", {})
	var extra: Array[String] = []
	for name in states.keys():
		if not DECLARED.has(name):
			extra.append(name)
	var streams := new(seed_text, extra)
	for name in streams.names():
		if states.has(name):
			var rng: RandomNumberGenerator = streams.stream(name)
			rng.state = int(states[name])
	return streams
