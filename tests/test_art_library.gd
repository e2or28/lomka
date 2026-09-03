extends "res://tests/framework/test_case.gd"
## Класс: поведение. Стережёт инструмент художественного теста, а не игру:
## сломается — Егор потеряет круги «нарисовал — посмотрел», но не забег.
##
## Горячая замена спрайтов. Проверяется без окна: чтение PNG идёт мимо
## движковой отрисовки, и отследить перечитку можно по самой текстуре.

const ArtLibrary = preload("res://game/art_library.gd")
const WorldView = preload("res://game/world_view.gd")
const Room = preload("res://sim/room.gd")

const DIR := "user://test_art"


func title() -> String:
	return "конвейер арта"


func _fresh_library():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var library := ArtLibrary.new()
	library.art_dir = DIR
	return library


func _write_png(name: String, size: int, color: Color) -> void:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.save_png("%s/%s.png" % [DIR, name])


func _remove(name: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.png" % [DIR, name]))


func _test_missing_sprite_is_not_a_crash() -> bool:
	var library = _fresh_library()
	_remove("nothing_here")
	check(not library.has("nothing_here"), "несуществующий спрайт считается существующим")
	eq(library.get_texture("nothing_here"), null,
		"отсутствующий спрайт вернул не null — стенд должен рисовать заглушку, а не падать")
	return true


func _test_loads_png_without_import() -> bool:
	var library = _fresh_library()
	_write_png("probe", 16, Color(1, 0, 0, 1))

	var texture := library.get_texture("probe")
	check(texture != null, "PNG не прочитался в обход импорта движка")
	if texture == null:
		return true
	eq(texture.get_size(), Vector2(16, 16), "размер спрайта прочитался не тот")

	_remove("probe")
	return true


func _test_refresh_picks_up_changes() -> bool:
	var library = _fresh_library()
	_write_png("changing", 8, Color(0, 1, 0, 1))
	var before := library.get_texture("changing")
	check(before != null, "спрайт не загрузился с первого раза")
	if before == null:
		return true
	eq(before.get_size(), Vector2(8, 8), "исходный размер не тот")

	# Отметка времени в файловой системе — секундная, поэтому подменяем
	# содержимое и заставляем перечитать явно: refresh проверяет метку,
	# reload_all перечитывает безусловно.
	_write_png("changing", 24, Color(0, 0, 1, 1))
	eq(library.reload_all(), 1, "перечиталось не одно изображение")

	var after := library.get_texture("changing")
	check(after != null, "спрайт не перечитался")
	if after != null:
		eq(after.get_size(), Vector2(24, 24), "стенд показал бы старую версию спрайта")

	_remove("changing")
	return true


func _test_refresh_ignores_untouched() -> bool:
	var library = _fresh_library()
	_write_png("stable", 12, Color(1, 1, 0, 1))
	library.get_texture("stable")
	eq(library.refresh(), PackedStringArray(),
		"refresh сообщил об изменении файла, которого никто не трогал")
	_remove("stable")
	return true


func _test_document_briefcase_is_integrated() -> bool:
	var image := Image.new()
	var err := image.load("res://art/folder.png")
	eq(err, OK, "финальный портфель не загрузился")
	if err != OK:
		return true
	eq(image.get_width(), 42, "ширина портфеля разошлась с утверждённой")
	eq(image.get_height(), 34, "высота портфеля разошлась с утверждённой")
	eq(image.get_format(), Image.FORMAT_RGBA8, "портфель записан без RGBA")
	return true


## Художник перерисует комнату, файл сменит размер, а константа в
## представлении останется прежней — и пол уедет относительно невидимых
## границ незаметно для глаза.
func _test_room_background_matches_the_inset() -> bool:
	var image := Image.new()
	var err := image.load("res://art/room_start.png")
	eq(err, OK, "фон комнаты не загрузился")
	if err != OK:
		return true

	# Тип не пишется: у статической фабрики его нет, см. «Ловушки» в CLAUDE.md
	var room = Room.dev_room()
	var inset := WorldView.ROOM_INSET
	check(inset.x > 0.0 and inset.y > 0.0, "отступ стен нулевой — фон сядет по холсту")
	check(image.get_width() >= inset.x + room.bounds.size.x,
		"нарисованного пола не хватает на ширину комнаты: %d против %d" % [
			image.get_width(), int(inset.x + room.bounds.size.x)])
	check(image.get_height() >= inset.y + room.bounds.size.y,
		"нарисованного пола не хватает на высоту комнаты: %d против %d" % [
			image.get_height(), int(inset.y + room.bounds.size.y)])
	return true


func _test_room_background_fits_the_window() -> bool:
	var image := Image.new()
	if image.load("res://art/room_start.png") != OK:
		return true
	var window := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)))
	check(image.get_width() <= window.x,
		"фон шире окна стенда: %d против %d" % [image.get_width(), window.x])
	check(image.get_height() <= window.y,
		"фон выше окна стенда: %d против %d" % [image.get_height(), window.y])
	return true
