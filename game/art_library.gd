extends RefCounted
## Спрайты из art/ в обход импорта движка.
##
## Обычный путь — положить PNG в проект, дать редактору его импортировать,
## перезапустить игру. Три шага и открытый редактор, который на 8 ГБ стоит
## дороже всего остального.
##
## Здесь PNG читается с диска напрямую через Image.load_from_file. Никакого
## .import, никакого редактора: сохранил файл в графическом редакторе —
## нажал F5 в игре — увидел. Цена — фильтрация и импорт-настройки задаются
## руками, но для низкого разрешения нужен ровно nearest, и он здесь есть.
##
## Это инструмент художественного теста, не боевой конвейер. К M5, когда
## спрайтов станут сотни, они переедут в assets/ обычным импортом.

const DEFAULT_ART_DIR := "res://art"

## Не константа: тест подставляет свой каталог, а стенд позже сможет
## смотреть в папку конкретного художественного теста.
var art_dir: String = DEFAULT_ART_DIR

var _textures: Dictionary = {}
var _stamps: Dictionary = {}


func path_for(name: String) -> String:
	return "%s/%s.png" % [art_dir, name]


func has(name: String) -> bool:
	return FileAccess.file_exists(path_for(name))


## Текстура по имени файла без расширения. null, если файла нет — стенд
## в этом случае рисует заглушку, а не падает.
func get_texture(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	return _load(name)


func _load(name: String) -> Texture2D:
	var path := path_for(name)
	if not FileAccess.file_exists(path):
		return null

	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		push_error("Не прочитать спрайт '%s': %d" % [path, err])
		return null

	var texture := ImageTexture.create_from_image(image)
	_textures[name] = texture
	_stamps[name] = FileAccess.get_modified_time(path)
	return texture


## Перечитать всё, что изменилось на диске. Возвращает список обновлённых
## имён, чтобы стенд мог сказать об этом на экране.
func refresh() -> PackedStringArray:
	var changed := PackedStringArray()
	for name in _textures.keys():
		var path := path_for(name)
		if not FileAccess.file_exists(path):
			continue
		if FileAccess.get_modified_time(path) != _stamps.get(name, 0):
			_textures.erase(name)
			if _load(name) != null:
				changed.append(name)
	return changed


## Забыть всё и перечитать с нуля — на случай, если изменился набор файлов.
func reload_all() -> int:
	var names := _textures.keys()
	_textures.clear()
	_stamps.clear()
	var loaded := 0
	for name in names:
		if _load(name) != null:
			loaded += 1
	return loaded
