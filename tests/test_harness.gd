extends "res://tests/framework/test_case.gd"
## Класс: инвариант. Пустой тестовый файл не должен давать зелёный прогон.

const TestCase = preload("res://tests/framework/test_case.gd")


func title() -> String:
	return "защита харнесса"


func _test_empty_suite_is_rejected() -> bool:
	var empty := TestCase.new()
	empty.run()
	check(not empty.failures.is_empty(), "файл без тестовых методов принят за успех")
	return true
