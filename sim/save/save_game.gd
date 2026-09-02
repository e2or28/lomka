extends RefCounted
## Сейв: заголовок, байты, файл. Правило 8 и «сохранение на каждом уровне»
## из docs/DECISIONS.md.
##
## Формат — var_to_bytes по состоянию забега. Не JSON: JSON теряет типы,
## int возвращается float, и круговорот перестаёт быть побайтовым. Не
## ResourceSaver: он пишет то, что понимает редактор, и формат меняется
## вместе с версией движка.
##
## Байтовая устойчивость держится на том, что состояние собирается в словари
## в каноническом порядке ключей — ключи в словаре Godot идут в порядке
## вставки, поэтому порядок сборки и есть порядок байтов.
##
## Риск из docs/PLAN.md: ошибки сериализации не падают, а проявляются как
## «после загрузки что-то не так». Отсюда тест-круговорот в tests/.
##
## Версия 2: тела переехали из слотов в акторов, появились снаряды и комната.
## Версия 3: у тела появилось оружие, боевые статы уехали из персонажа в него.
## Версия 4: снаряд летел по дуге — вместо таймера жизни высота и
## вертикальная скорость.
## Версия 5: дуга убрана, снаряд идёт по прямой и кувыркается в конце.
## Версия 6: у снаряда появился вид — папка из чемодана, пуля из кольта.
## Старые версии не читаются — забегов на них никто не начинал, писать
## миграцию не для кого. С первого выпущенного билда так уже нельзя.

const RunState = preload("res://sim/run_state.gd")

const MAGIC := "LOMKA"
const FORMAT := 6


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
