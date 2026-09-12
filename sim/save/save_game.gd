extends RefCounted
## Сейв: заголовок, байты, файл (правило 8).
##
## Формат — var_to_bytes, не JSON (теряет типы int/float) и не ResourceSaver
## (формат меняется вместе с версией движка). Байтовая устойчивость держится
## на том, что ключи в словаре Godot идут в порядке вставки — состояние
## собирается в каноническом порядке, и порядок сборки есть порядок байтов.
##
## Старые версии FORMAT не читаются и не мигрируются: забегов на них никто
## не начинал. С первого выпущенного билда так уже будет нельзя.

const RunState = preload("res://sim/run_state.gd")

const MAGIC := "LOMKA"
const FORMAT := 16


static func to_bytes(state: RunState) -> PackedByteArray:
	var payload := {
		"format": FORMAT,
		"magic": MAGIC,
		"state": state.to_dict(),
	}
	return var_to_bytes(payload)


static func from_bytes(bytes: PackedByteArray):
	var payload: Variant = bytes_to_var(bytes)
	if typeof(payload) != TYPE_DICTIONARY:
		push_error("Сейв повреждён: ожидался Dictionary")
		return null
	if payload.get("magic", "") != MAGIC:
		push_error("Это не сейв Ломки: заголовок '%s'" % payload.get("magic", ""))
		return null
	var format := int(payload.get("format", 0))
	if format != FORMAT:
		push_error("Версия сейва %d, поддерживается %d" % [format, FORMAT])
		return null
	return RunState.from_dict(payload.get("state", {}))


static func save_to_file(state: RunState, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("Не открыть сейв на запись '%s': %d" % [path, err])
		return err
	file.store_buffer(to_bytes(state))
	file.close()
	return OK


static func load_from_file(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не открыть сейв на чтение '%s': %d" % [path, FileAccess.get_open_error()])
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return from_bytes(bytes)
