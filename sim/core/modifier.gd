extends RefCounted
## Одна запись в стеке модификаторов. Правило 4 из docs/PLAN.md.
##
## Модификатор не пишет стат, а описывает, что с ним сделать. Кто положил —
## помнится в source, чтобы снять всё от предмета одним вызовом при потере.

enum Op { ADD, MUL, SET }

var id: String = ""
var source: String = ""
var stat: String = ""
var op: Op = Op.ADD
var value: float = 0.0

## Порядковый номер добавления в стек. Вместе с op даёт строгий полный
## порядок применения: без него сортировка по одному op оставляет ничьи,
## а порядок сложения float между хостом и клиентом разойдётся.
var seq: int = 0


static func make(p_stat: String, p_op: Op, p_value: float, p_source: String = "", p_id: String = ""):
	var m := new()
	m.stat = p_stat
	m.op = p_op
	m.value = p_value
	m.source = p_source
	m.id = p_id
	return m


func to_dict() -> Dictionary:
	return {
		"id": id,
		"op": int(op),
		"seq": seq,
		"source": source,
		"stat": stat,
		"value": value,
	}


static func from_dict(data: Dictionary):
	var m := new()
	m.id = data.get("id", "")
	m.op = data.get("op", Op.ADD) as Op
	m.seq = int(data.get("seq", 0))
	m.source = data.get("source", "")
	m.stat = data.get("stat", "")
	m.value = float(data.get("value", 0.0))
	return m
