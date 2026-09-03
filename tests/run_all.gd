extends SceneTree
## Харнесс headless-тестов. Запуск: tools/test.sh
##
## Последняя строка вывода — сентинел, по которому tools/test.sh отличает
## успех от запуска, умершего на разборе скрипта: Godot в этом случае
## выходит с нулём.
##
## Сторож в _process нужен потому, что ошибка скрипта обрывает функцию, в
## которой случилась — если это _initialize, quit() не вызовется никогда,
## и headless-цикл будет крутиться вечно без вывода и без конца.

const TESTS_DIR := "res://tests"
const PREFIX := "test_"
const SENTINEL_OK := "ВСЕ ТЕСТЫ ПРОЙДЕНЫ"
const SENTINEL_FAIL := "ЕСТЬ ПАДЕНИЯ"

var _finished := false


func _initialize() -> void:
	var paths := _discover()
	if paths.is_empty():
		print("Не найдено ни одного теста в %s/%s*.gd" % [TESTS_DIR, PREFIX])
		print(SENTINEL_FAIL)
		_finish(1)
		return

	var total_checks := 0
	var failed_files := 0
	var failures: PackedStringArray = []

	print("Тесты: %d файл(ов)\n" % paths.size())

	for path in paths:
		# Скрипт с ошибкой разбора всё равно возвращается объектом — просто
		# неспособным породить экземпляр.
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			failed_files += 1
			failures.append("%s: скрипт не загрузился" % path)
			print("  ПАДЕНИЕ  %s — скрипт не загрузился (ошибка разбора выше)" % path)
			continue

		var test: RefCounted = script.new()
		if test == null:
			failed_files += 1
			failures.append("%s: экземпляр теста не создался" % path)
			print("  ПАДЕНИЕ  %s — экземпляр теста не создался" % path)
			continue

		var name: String = test.title()
		test.run()
		total_checks += test.checks

		if test.failures.is_empty():
			print("  ok       %-24s %d проверок" % [name, test.checks])
		else:
			failed_files += 1
			print("  ПАДЕНИЕ  %-24s %d проверок, %d не прошло" % [name, test.checks, test.failures.size()])
			for f in test.failures:
				failures.append("%s: %s" % [name, f])
				print("             · %s" % f)

	print("")
	if failed_files == 0:
		print("%s: %d файл(ов), %d проверок" % [SENTINEL_OK, paths.size(), total_checks])
		_finish(0)
		return

	print("%s: %d из %d файлов, %d проверок не прошло" % [
		SENTINEL_FAIL, failed_files, paths.size(), failures.size()])
	_finish(1)


func _finish(code: int) -> void:
	_finished = true
	quit(code)


## Доходит сюда, только если _initialize оборвался: при нормальном ходе
## quit() уже остановил цикл.
func _process(_delta: float) -> bool:
	if not _finished:
		_finished = true
		print("")
		print("%s: харнесс оборвался, не дойдя до конца — ищи ошибку скрипта выше" % SENTINEL_FAIL)
		quit(1)
	return true


func _discover() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		push_error("Не открыть каталог тестов %s" % TESTS_DIR)
		return found
	for file_name in dir.get_files():
		if file_name.begins_with(PREFIX) and file_name.ends_with(".gd"):
			found.append("%s/%s" % [TESTS_DIR, file_name])
	found.sort()
	return found
