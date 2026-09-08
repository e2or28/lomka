extends RefCounted
## Стек модификаторов (правило 4). Итог пересчитывается целиком из базы и
## всего стека, поэтому снятие предмета не требует помнить, что именно он
## прибавил.
##
## Порядок применения строго детерминирован: сначала все ADD, потом MUL,
## потом SET; внутри фазы — по номеру добавления. Иначе накопление float
## разойдётся между хостом и клиентом.

const Modifier = preload("res://sim/core/modifier.gd")

var base: Dictionary = {}

var _mods: Array[Modifier] = []
var _next_seq: int = 0


func _init(base_stats: Dictionary = {}) -> void:
	base = base_stats.duplicate(true)


## Номер присваивается здесь: вызывающий код не может подменить порядок.
func add(mod: Modifier) -> Modifier:
	mod.seq = _next_seq
	_next_seq += 1
	_mods.append(mod)
	return mod


func size() -> int:
	return _mods.size()


func modifiers() -> Array[Modifier]:
	return _mods.duplicate()


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


## Ключи упорядочены — от этого зависят байты сейва.
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
