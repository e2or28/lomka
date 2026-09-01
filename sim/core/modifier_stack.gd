extends RefCounted
## Стек модификаторов. Правило 4 из docs/PLAN.md.
##
## Предметы не пишут статы, а кладут модификаторы. Итог пересчитывается
## целиком из базы и всего стека — тогда снятие предмета не требует помнить,
## что именно он прибавил, а синергии складываются композицией, а не
## квадратичным перечнем «если есть A и B».
##
## Порядок применения строго детерминирован: сначала все ADD, потом все MUL,
## потом все SET; внутри фазы — по номеру добавления. Ничьих в этом порядке
## нет, поэтому накопление float одинаково на хосте и на клиенте независимо
## от того, в каком порядке предметы попали в стек в памяти.

const Modifier = preload("res://sim/core/modifier.gd")

## Базовый стат-блок: имя стата -> значение до модификаторов.
var base: Dictionary = {}

var _mods: Array[Modifier] = []
var _next_seq: int = 0


func _init(base_stats: Dictionary = {}) -> void:
	base = base_stats.duplicate(true)


## Положить модификатор. Номер присваивается здесь: вызывающий код не должен
## иметь возможности задать его сам и подменить порядок.
func add(mod: Modifier) -> Modifier:
	mod.seq = _next_seq
	_next_seq += 1
	_mods.append(mod)
	return mod


func add_all(mods: Array) -> void:
	for m in mods:
		add(m)


func size() -> int:
	return _mods.size()


func modifiers() -> Array[Modifier]:
	return _mods.duplicate()


## Снять всё, что положил один источник: предмет потерян, орган продан.
func remove_source(source: String) -> int:
	var kept: Array[Modifier] = []
	var removed := 0
	for m in _mods:
		if m.source == source:
			removed += 1
		else:
			kept.append(m)
	_mods = kept
	return removed


func clear() -> void:
	_mods.clear()
	_next_seq = 0


static func _order_less(a: Modifier, b: Modifier) -> bool:
	if a.op != b.op:
		return a.op < b.op
	return a.seq < b.seq


## Итоговый стат-блок. Ключи упорядочены — от этого зависят байты сейва.
func compute() -> Dictionary:
	var ordered := _mods.duplicate()
	ordered.sort_custom(_order_less)

	var acc := {}
	for key in base.keys():
		acc[key] = float(base[key])
	for m in ordered:
		if not acc.has(m.stat):
			acc[m.stat] = 0.0
		match m.op:
			Modifier.Op.ADD:
				acc[m.stat] = float(acc[m.stat]) + m.value
			Modifier.Op.MUL:
				acc[m.stat] = float(acc[m.stat]) * m.value
			Modifier.Op.SET:
				acc[m.stat] = m.value

	var keys := acc.keys()
	keys.sort()
	var out := {}
	for key in keys:
		out[key] = acc[key]
	return out


func to_dict() -> Dictionary:
	var base_keys := base.keys()
	base_keys.sort()
	var base_out := {}
	for key in base_keys:
		base_out[key] = float(base[key])

	var mods_out: Array = []
	var ordered := _mods.duplicate()
	ordered.sort_custom(_order_less)
	for m in ordered:
		mods_out.append(m.to_dict())

	return {
		"base": base_out,
		"mods": mods_out,
		"next_seq": _next_seq,
	}


static func from_dict(data: Dictionary):
	var stack := new(data.get("base", {}))
	for entry in data.get("mods", []):
		stack._mods.append(Modifier.from_dict(entry))
	stack._next_seq = int(data.get("next_seq", stack._mods.size()))
	return stack
