extends RefCounted
## Схема и валидатор. Правило 5 из docs/PLAN.md.
##
## Контент — обычные словари, а не классы: словарь сериализуется без
## переходника (правило 8), диффится в гите построчно и не тянет за собой
## редакторский формат ресурсов. Дисциплину держит не тип, а схема плюс
## валидатор, падающий на любом расхождении.
##
## Схема — словарь «поле -> описание». Описание понимает ключи:
##   type            Variant.Type, обязателен
##   required        bool, по умолчанию true
##   default         значение для необязательного поля
##   min, max        границы для чисел
##   values          допустимый набор значений
##   element_type    тип элемента массива
##   element_schema  схема элемента массива словарей
##   value_type      тип значения в словаре
##   keys            допустимый набор ключей словаря
##
## Неизвестное поле в данных — ошибка, а не игнор: опечатка в имени стата
## иначе всплывёт балансом, разъехавшимся на ровном месте.

const ID_PATTERN := "^[a-z][a-z0-9_]*$"

static var _id_regex: RegEx = null


static func _id_ok(text: String) -> bool:
	if _id_regex == null:
		_id_regex = RegEx.new()
		_id_regex.compile(ID_PATTERN)
	return _id_regex.search(text) != null


static func _type_name(t: int) -> String:
	match t:
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		_: return "тип #%d" % t


static func _check_type(value: Variant, want: int) -> bool:
	var got := typeof(value)
	if got == want:
		return true
	# int там, где ждут float, — допустим: 1 и 1.0 в данных одно и то же.
	return want == TYPE_FLOAT and got == TYPE_INT


static func _check_value(path: String, value: Variant, spec: Dictionary, errors: PackedStringArray) -> void:
	var want: int = spec["type"]
	if not _check_type(value, want):
		errors.append("%s: ожидался %s, получен %s" % [path, _type_name(want), _type_name(typeof(value))])
		return

	if spec.get("id", false) and not _id_ok(value):
		errors.append("%s: '%s' не подходит под %s" % [path, value, ID_PATTERN])

	if spec.has("min") and float(value) < float(spec["min"]):
		errors.append("%s: %s меньше минимума %s" % [path, value, spec["min"]])
	if spec.has("max") and float(value) > float(spec["max"]):
		errors.append("%s: %s больше максимума %s" % [path, value, spec["max"]])
	if spec.has("values") and not (value in spec["values"]):
		errors.append("%s: '%s' не входит в %s" % [path, value, spec["values"]])

	if want == TYPE_ARRAY:
		var index := 0
		for element in value:
			var element_path := "%s[%d]" % [path, index]
			if spec.has("element_schema"):
				_check_dict(element_path, element, spec["element_schema"], errors)
			elif spec.has("element_type"):
				if not _check_type(element, spec["element_type"]):
					errors.append("%s: ожидался %s, получен %s" % [
						element_path, _type_name(spec["element_type"]), _type_name(typeof(element))])
			index += 1

	if want == TYPE_DICTIONARY:
		for key in value.keys():
			var key_path := "%s.%s" % [path, key]
			if spec.has("keys") and not (key in spec["keys"]):
				errors.append("%s: неизвестный ключ '%s'" % [path, key])
				continue
			if spec.has("value_type") and not _check_type(value[key], spec["value_type"]):
				errors.append("%s: ожидался %s, получен %s" % [
					key_path, _type_name(spec["value_type"]), _type_name(typeof(value[key]))])


static func _check_dict(path: String, data: Variant, schema: Dictionary, errors: PackedStringArray) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("%s: ожидался Dictionary, получен %s" % [path, _type_name(typeof(data))])
		return

	for field in schema.keys():
		var spec: Dictionary = schema[field]
		# Тип выводится явно: field приходит из keys() как Variant, и
		# тернарник с ним не даёт вывести тип.
		var field_path: String = str(field)
		if path != "":
			field_path = path + "." + str(field)
		if data.has(field):
			_check_value(field_path, data[field], spec, errors)
		elif spec.get("required", true):
			errors.append("%s: обязательное поле отсутствует" % field_path)

	for field in data.keys():
		if not schema.has(field):
			var where := path if path != "" else "запись"
			errors.append("%s: неизвестное поле '%s'" % [where, field])


## Список ошибок. Пустой — данные валидны.
static func validate(data: Variant, schema: Dictionary, label: String = "") -> PackedStringArray:
	var errors := PackedStringArray()
	_check_dict(label, data, schema, errors)
	return errors


## То же, но падает. Правило 5: валидатор обязан ронять, а не жаловаться.
static func validate_or_fail(data: Variant, schema: Dictionary, label: String = "") -> bool:
	var errors := validate(data, schema, label)
	if errors.is_empty():
		return true
	for e in errors:
		push_error("Схема: " + e)
	assert(false, "Данные не прошли схему: " + ", ".join(errors))
	return false


## Проставить значения по умолчанию для отсутствующих необязательных полей.
static func with_defaults(data: Dictionary, schema: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	for field in schema.keys():
		var spec: Dictionary = schema[field]
		if not out.has(field) and spec.has("default"):
			var value: Variant = spec["default"]
			out[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return out
