extends SceneTree
## Сборка project.godot кодом. Запуск — tools/gen_project.sh.
##
## Карта ввода на четверых — 48 действий и под сотню привязок; собранные
## кликами, они не диффятся и разъезжаются при переименовании. Вся карта —
## таблица в tools/input_map.gd, скрипт только переносит её в настройки.
##
## Секцию [input] со слотами p1–p4 скрипт считает своей и пересоздаёт;
## ручные правки в ней будут стёрты — так и задумано. Остальные настройки
## движок сохраняет как есть.

const InputMapDef = preload("res://tools/input_map.gd")

const SETTINGS := {
	"application/config/name": "Ломка",
	"application/config/description":
		"Кооперативный рогалик с видом сверху. Закрытый рукотворный мир, случайное наполнение, органы вместо валюты.",
	"application/run/main_scene": "res://game/dev_sandbox.tscn",

	# Подогнан под нарисованную комнату: пол 1160x640 плюс стены — 1370x850,
	# в прежние 1280x720 стены не помещались.
	"display/window/size/viewport_width": 1400,
	"display/window/size/viewport_height": 880,

	# Forward+, не Compatibility: на macOS тот идёт через устаревший OpenGL,
	# а не родной Metal.
	"rendering/renderer/rendering_method": "forward_plus",
	"rendering/renderer/rendering_method.mobile": "forward_plus",

	"physics/common/physics_ticks_per_second": 60,
}

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


## Настройка, равная заводскому значению, в файл не попадёт: движок считает
## её умолчанием и выбрасывает при каждом сохранении. Трюк со сдвигом
## initial value не помогает — он переживает только первый запуск, а потом
## движок пересохраняет файл и строку всё равно теряет. Защита —
## tests/test_project_settings.gd, читающий действующее значение из
## ProjectSettings, а не из файла.
func _force_setting(key: String, value: Variant) -> void:
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
