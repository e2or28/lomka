extends "res://tests/framework/test_case.gd"
## Горячая замена спрайтов.
##
## Это инструмент художественного теста на M1: главный открытый вопрос
## проекта решается тем, сколько кругов «нарисовал — посмотрел» Егор успеет
## сделать за два вечера. Если круг требует импорта в редакторе и
## перезапуска, кругов будет вдвое меньше.
##
## Проверяется без окна: чтение PNG идёт мимо движковой отрисовки, и
## отследить, перечитался ли файл, можно по самой текстуре.

const ArtLibrary = preload("res://game/art_library.gd")

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
	eq(texture.get_size(), Vector2i(16, 16), "размер спрайта прочитался не тот")

	_remove("probe")
	return true


## Главное свойство: сохранил файл в графическом редакторе — увидел в игре.
func _test_refresh_picks_up_changes() -> bool:
	var library = _fresh_library()
	_write_png("changing", 8, Color(0, 1, 0, 1))
	var before := library.get_texture("changing")
	check(before != null, "спрайт не загрузился с первого раза")
	if before == null:
		return true
	eq(before.get_size(), Vector2i(8, 8), "исходный размер не тот")

	# Отметка времени в файловой системе — секундная, поэтому подменяем
	# содержимое и заставляем перечитать явно: refresh проверяет метку,
	# reload_all перечитывает безусловно.
	_write_png("changing", 24, Color(0, 0, 1, 1))
	eq(library.reload_all(), 1, "перечиталось не одно изображение")

	var after := library.get_texture("changing")
	check(after != null, "спрайт не перечитался")
	if after != null:
		eq(after.get_size(), Vector2i(24, 24), "стенд показал бы старую версию спрайта")

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
