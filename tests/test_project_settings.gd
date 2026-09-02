extends "res://tests/framework/test_case.gd"
## Класс: инвариант. Каждая проверка ниже соответствует строчке в
## docs/DECISIONS.md; менять её значит менять решение.
##
## Настройки проекта против принятых решений.
##
## Проверяется действующее значение через ProjectSettings, а не наличие
## строки в project.godot. Настройка, равная заводской, в файл не пишется —
## движок выбрасывает её при каждом своём сохранении, и следить за
## присутствием строки значит гоняться за тем, как движок разложил файл.
##
## Здесь ловится настоящая регрессия: рендерер переключили, тик уплыл,
## главная сцена потерялась. Однажды это уже случилось молча.

const InputMapDef = preload("res://tools/input_map.gd")
const SimTick = preload("res://sim/tick.gd")


func title() -> String:
	return "настройки проекта"


## Forward+ из docs/DECISIONS.md: в 2D разницы с Mobile нет, выбор по риску —
## это десктопный дефолт и родной Metal на маке.
func _test_renderer_is_forward_plus() -> bool:
	eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "forward_plus",
		"рендерер не Forward+ — решение из DECISIONS.md нарушено")
	eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "forward_plus",
		"мобильный профиль рендерера разошёлся с основным")
	return true


## Тик симуляции фиксирован: считает хост, клиент шлёт ввод. Плавающий шаг
## сделал бы сверку состояния невоспроизводимой.
func _test_physics_tick_matches_simulation() -> bool:
	var ticks: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	eq(ticks, 60, "тик физики уплыл от шестидесяти")
	almost_eq(SimTick.DELTA, 1.0 / float(ticks),
		"шаг симуляции разошёлся с тиком физики — стенд считает не то, что тесты", 1e-9)
	return true


func _test_main_scene_exists() -> bool:
	var scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	check(scene != "", "главная сцена не задана — запускать нечего")
	if scene != "":
		check(ResourceLoader.exists(scene), "главная сцена '%s' не существует" % scene)
	return true


func _test_project_is_named() -> bool:
	eq(ProjectSettings.get_setting("application/config/name"), "Ломка", "проект переименован")
	return true


## Мёртвая зона в карте ввода намеренно почти нулевая: настоящая зона
## круговая и живёт в коде. Если сюда вернут 0.25, круговая зона будет
## считаться по уже обрезанным осям и перестанет работать.
func _test_engine_deadzone_stays_low() -> bool:
	check(InputMapDef.DEADZONE <= 0.1,
		"движковая мёртвая зона %.2f великовата — круговую зону не посчитать по обрезанным осям" % InputMapDef.DEADZONE)
	var applied := InputMap.action_get_deadzone(InputMapDef.action_name(0, "move_up"))
	almost_eq(applied, InputMapDef.DEADZONE, "мёртвая зона в project.godot разошлась с таблицей", 1e-6)
	return true
