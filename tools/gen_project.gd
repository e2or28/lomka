extends SceneTree
## Сборка project.godot кодом. Запуск — tools/gen_project.sh.
##
## Почему не через GUI: карта ввода на четверых — это 48 действий и под сотню
## привязок. Собранные кликами, они не проверяются, не диффятся и разъезжаются
## при первом же переименовании действия. Здесь же вся карта — таблица в
## tools/input_map.gd, а этот скрипт только переносит её в настройки.
##
## Скрипт переписывает project.godot целиком: настройки, которых он не
## касается, движок сохраняет как есть, а секцию [input] со слотами p1–p4 он
## считает своей и пересоздаёт. Ручные правки этой секции будут стёрты — так
## и задумано.

const InputMapDef = preload("res://tools/input_map.gd")

## Настройки, за которые отвечает этот скрипт.
const SETTINGS := {
	"application/config/name": "Ломка",
	"application/config/description":
		"Кооперативный рогалик с видом сверху. Закрытый рукотворный мир, случайное наполнение, органы вместо валюты.",

	# Пока геймплея нет, запускается стенд разработчика. Это не главная сцена
	# игры, а окно в симуляцию: тела слотов, ползунки статов, сверка масштаба
	# спрайтов. Подробности — game/dev_sandbox.gd.
	"application/run/main_scene": "res://game/dev_sandbox.tscn",

	# Размер окна стенда. Настоящее разрешение и режим растяжения решаются
	# после художественного теста на M1: для низкого разрешения понадобится
	# маленький вьюпорт с целочисленным масштабированием, а каким именно —
	# зависит от того, в каком масштабе окажется удобно рисовать.
	"display/window/size/viewport_width": 1280,
	"display/window/size/viewport_height": 720,

	# Forward+ (docs/DECISIONS.md). В 2D разницы с Mobile нет — отличия целиком
	# в 3D, поэтому выбор по риску: Forward+ это десктопный дефолт и родной
	# Metal на маке, тогда как Compatibility идёт через устаревший OpenGL.
	"rendering/renderer/rendering_method": "forward_plus",
	"rendering/renderer/rendering_method.mobile": "forward_plus",

	# Фиксированный тик симуляции. Считает хост (правило 1), клиент шлёт ввод;
	# плавающий шаг сделал бы сверку состояния невоспроизводимой.
	"physics/common/physics_ticks_per_second": 60,
}

## Слоты игроков этот скрипт считает своими: перед записью старые действия
## p1–p4 стираются, иначе переименованное действие останется висеть навсегда.
const OWNED_ACTION_PATTERN := "^input/p[1-9][0-9]*_"


func _initialize() -> void:
	var erased := _erase_owned_actions()

	for key in SETTINGS.keys():
		_force_setting(key, SETTINGS[key])

	var actions := InputMapDef.build()
	var action_names := actions.keys()
	action_names.sort()
	for name in action_names:
		ProjectSettings.set_setting("input/" + name, actions[name])

	var err := ProjectSettings.save()
	if err != OK:
		push_error("Не записать project.godot: %d" % err)
		quit(1)
		return

	print("project.godot собран")
	print("  настроек:  %d" % SETTINGS.size())
	print("  рендерер:  %s" % SETTINGS["rendering/renderer/rendering_method"])
	print("  слотов:    %d" % InputMapDef.PLAYERS)
	print("  действий:  %d (%d на слот), стёрто прежних: %d" % [
		action_names.size(), InputMapDef.ACTIONS.size(), erased])
	quit(0)


## Настройка, равная заводскому значению, в файл не пишется — движок считает
## её умолчанием. Для рендерера это неприемлемо: решение принято, оно должно
## быть видно в файле, а не подразумеваться. Сдвиг initial value заставляет
## движок считать значение изменённым и записать его.
func _force_setting(key: String, value: Variant) -> void:
	ProjectSettings.set_setting(key, value)
	ProjectSettings.set_initial_value(key, null)
	ProjectSettings.set_setting(key, value)


func _erase_owned_actions() -> int:
	var regex := RegEx.new()
	regex.compile(OWNED_ACTION_PATTERN)
	var doomed: Array[String] = []
	for property in ProjectSettings.get_property_list():
		var key: String = property["name"]
		if regex.search(key) != null:
			doomed.append(key)
	for key in doomed:
		ProjectSettings.clear(key)
	return doomed.size()
