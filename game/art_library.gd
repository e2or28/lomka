extends RefCounted
## Спрайты из art/ в обход импорта движка: PNG читается прямо с диска через
## Image.load_from_file — сохранил файл, нажал 4, увидел. Обычный путь
## через .import требует открытого редактора, который на 8 ГБ дорог.
##
## Инструмент художественного теста, не боевой конвейер: к M5 спрайты
## переедут в assets/ обычным импортом.

const DEFAULT_ART_DIR := "res://art"

## Не константа: тест подставляет свой каталог.
var art_dir: String = DEFAULT_ART_DIR

var _textures: Dictionary = {}
var _stamps: Dictionary = {}


func path_for(name: String) -> String:
	return "%s/%s.png" % [art_dir, name]


func has(name: String) -> bool:
	return FileAccess.file_exists(path_for(name))


## null, если файла нет — стенд рисует заглушку, а не падает.
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


func reload_all() -> int:
	var names := _textures.keys()
	_textures.clear()
	_stamps.clear()
	var loaded := 0
	for name in names:
		if _load(name) != null:
			loaded += 1
	return loaded
