extends "res://tests/framework/test_case.gd"
## Куда смотрит персонаж на профильных кадрах.
##
## Отрисовку тестом не проверить, а вот исходные данные — можно, и именно
## они здесь были прочитаны неверно. Я определил сторону взгляда по картинке
## на глаз, ошибся, и персонаж пошёл спиной вперёд: зеркало применялось не
## к той стороне.
##
## Сторона определяется по спрайту: в профиль кожа лица лежит с одной
## стороны головы, волосы затылка с другой. Если художник пришлёт зеркальный
## набор, этот тест покраснеет раньше, чем кто-то запустит игру.

## Профильные кадры нарисованы лицом вправо. Отсюда правило отрисовки:
## отражается движение влево, а вправо персонаж идёт как нарисован.
const SPRITE_FACES_RIGHT := true

const FRAMES: Array[String] = [
	"player_side_stand",
	"player_side_walk_1", "player_side_walk_2", "player_side_walk_3",
	"player_side_walk_4", "player_side_walk_5", "player_side_walk_6",
]


func title() -> String:
	return "направление взгляда"


func _load(name: String) -> Image:
	var path := "res://art/%s.png" % name
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return image


## Центры кожи и волос в верхней части силуэта. Возвращает [кожа, волосы],
## -1 если пикселей такого рода не нашлось.
func _face_centres(image: Image) -> Array:
	var width := image.get_width()
	var height := image.get_height()

	var top := height
	var bottom := 0
	for y in height:
		for x in width:
			if image.get_pixel(x, y).a > 0.03:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	if top > bottom:
		return [-1.0, -1.0]

	var head_bottom := top + (bottom - top) / 4
	var skin_sum := 0.0
	var skin_count := 0
	var hair_sum := 0.0
	var hair_count := 0

	for y in range(top, head_bottom + 1):
		for x in width:
			var c := image.get_pixel(x, y)
			if c.a <= 0.03:
				continue
			# Кожа: тёплая и светлая. Волосы: тёмно-коричневые.
			if c.r > 0.58 and c.r > c.g + 0.12 and c.g > c.b:
				skin_sum += x
				skin_count += 1
			elif c.r < 0.51 and c.r > c.b and c.g < 0.39:
				hair_sum += x
				hair_count += 1

	var skin: float = skin_sum / skin_count if skin_count > 0 else -1.0
	var hair: float = hair_sum / hair_count if hair_count > 0 else -1.0
	return [skin, hair]


func _test_frames_exist() -> bool:
	var missing := PackedStringArray()
	for name in FRAMES:
		if _load(name) == null:
			missing.append(name)
	check(missing.is_empty(), "нет кадров ходьбы: " + ", ".join(missing))
	return true


## Главная проверка: перепутанная сторона — это персонаж, идущий спиной.
func _test_every_frame_faces_the_same_way() -> bool:
	var wrong := PackedStringArray()
	for name in FRAMES:
		var image := _load(name)
		if image == null:
			continue
		var centres := _face_centres(image)
		if centres[0] < 0.0 or centres[1] < 0.0:
			wrong.append("%s: не нашлось кожи или волос" % name)
			continue
		var faces_right: bool = centres[0] > centres[1]
		if faces_right != SPRITE_FACES_RIGHT:
			wrong.append("%s: кожа %.1f, волосы %.1f" % [name, centres[0], centres[1]])
	check(wrong.is_empty(),
		"кадры смотрят не в ту сторону, что заявлено в SPRITE_FACES_RIGHT — " +
		"зеркало применится не туда и персонаж пойдёт спиной: " + ", ".join(wrong))
	return true


## Лицо и затылок должны заметно расходиться. Если центры сошлись, значит
## определение стороны держится на шуме и однажды перевернётся само.
func _test_direction_is_unambiguous() -> bool:
	var weak := PackedStringArray()
	for name in FRAMES:
		var image := _load(name)
		if image == null:
			continue
		var centres := _face_centres(image)
		if centres[0] < 0.0 or centres[1] < 0.0:
			continue
		if absf(centres[0] - centres[1]) < 3.0:
			weak.append("%s (%.1f)" % [name, absf(centres[0] - centres[1])])
	check(weak.is_empty(), "сторона взгляда определяется неуверенно: " + ", ".join(weak))
	return true
