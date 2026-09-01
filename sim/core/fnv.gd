extends RefCounted
## FNV-1a, 64 бита. Своя реализация намеренно — правило 3 из docs/PLAN.md:
## встроенный String.hash() не обязан совпадать между версиями движка и
## платформами, а сид забега обязан, иначе хост и клиент разъедутся.
##
## Godot-специфика: int в GDScript знаковый 64-битный, умножение переполняется
## по модулю 2^64 молча — ровно та арифметика, которая нужна FNV. Смещение
## 0xcbf29ce484222325 не влезает в знаковый литерал и записано знаковым
## эквивалентом; на битах это то же число.
##
## Сверено с эталонными векторами: "" -> 0xcbf29ce484222325,
## "a" -> 0xaf63dc4c8601ec8c, "foobar" -> 0x85944171f73967e8.

const OFFSET_BASIS := -3750763034362895579  # 0xcbf29ce484222325
const PRIME := 1099511628211                # 0x100000001b3


static func hash_bytes(bytes: PackedByteArray) -> int:
	var h := OFFSET_BASIS
	for b in bytes:
		h ^= b
		h *= PRIME
	return h


static func hash_string(text: String) -> int:
	return hash_bytes(text.to_utf8_buffer())
