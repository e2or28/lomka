extends RefCounted
## База для теста. Тест — файл tests/test_*.gd, наследующий этот класс,
## определяющий title() и один или несколько методов вида
##
##   func _test_что_проверяем() -> bool:
##       ...
##       return true
##
## Проверки не бросают исключений (в GDScript их нет) и не останавливают
## тест: один упавший assert не должен прятать остальные девять.
##
## Почему методы обязаны возвращать true. Ошибка скрипта в GDScript обрывает
## ту функцию, в которой случилась, и молча возвращает управление вызвавшему.
## Тест, упавший на обращении к null, иначе отчитался бы как пройденный — с
## нулём проверок и зелёной строкой. Оборванный вызов возвращает не true, и
## это единственный надёжный признак, что метод не дошёл до конца. Забытый
## return true даёт то же самое: громкое падение, а не тихий успех.
##
## Список методов собирается интроспекцией, а не руками: диспетчер, который
## надо дописывать при каждом новом методе, рано или поздно про один забудут,
## и проверка просто перестанет гоняться.

var failures: PackedStringArray = []
var checks: int = 0


func title() -> String:
	return "без имени"


func case_names() -> PackedStringArray:
	var names := PackedStringArray()
	for method in get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("_test_") and not names.has(method_name):
			names.append(method_name)
	names.sort()
	return names


func run() -> void:
	for case_name in case_names():
		var before := checks
		var completed: Variant = call(case_name)
		if completed != true:
			fail("%s: не дошёл до конца — ошибка скрипта выше либо забыт `return true`" % case_name)
		elif checks == before:
			fail("%s: не сделал ни одной проверки" % case_name)


func fail(message: String) -> void:
	failures.append(message)


func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		fail(message)
	return condition


func eq(actual: Variant, expected: Variant, message: String) -> bool:
	checks += 1
	if actual == expected:
		return true
	fail("%s: ожидалось %s, получено %s" % [message, expected, actual])
	return false


func ne(actual: Variant, unexpected: Variant, message: String) -> bool:
	checks += 1
	if actual != unexpected:
		return true
	fail("%s: значение не должно было совпасть с %s" % [message, unexpected])
	return false


func almost_eq(actual: float, expected: float, message: String, epsilon: float = 1e-9) -> bool:
	checks += 1
	if absf(actual - expected) <= epsilon:
		return true
	fail("%s: ожидалось %f, получено %f" % [message, expected, actual])
	return false


## Побайтовое сравнение. Отдельным методом, потому что при расхождении важно
## увидеть, где именно разъехалось, а не только что разъехалось.
func bytes_eq(actual: PackedByteArray, expected: PackedByteArray, message: String) -> bool:
	checks += 1
	if actual == expected:
		return true
	if actual.size() != expected.size():
		fail("%s: длина %d против %d" % [message, actual.size(), expected.size()])
		return false
	for i in actual.size():
		if actual[i] != expected[i]:
			fail("%s: первое расхождение на байте %d (%d против %d)" % [message, i, actual[i], expected[i]])
			return false
	return false


func no_errors(errors: PackedStringArray, message: String) -> bool:
	checks += 1
	if errors.is_empty():
		return true
	fail("%s: %s" % [message, ", ".join(errors)])
	return false


func has_error(errors: PackedStringArray, fragment: String, message: String) -> bool:
	checks += 1
	for e in errors:
		if e.contains(fragment):
			return true
	fail("%s: среди ошибок нет ничего про '%s' (есть: %s)" % [message, fragment, ", ".join(errors)])
	return false
