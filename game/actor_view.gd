extends Node2D
## Тело игрока на экране. Знает о симуляции ровно одно — где слот стоит.
##
## Обратной связи нет: представление не решает ничего (правило 1) и не
## лезет в симуляцию (правило 2). Выкинуть этот файл целиком можно в любой
## момент, симуляция не заметит.

const BOX := Vector2(24, 28)

const SLOT_COLORS: Array[Color] = [
	Color(0.45, 0.85, 0.55),
	Color(0.95, 0.65, 0.35),
	Color(0.55, 0.7, 0.98),
	Color(0.9, 0.55, 0.8),
]

var slot_index := 0
var texture: Texture2D = null
var aim := Vector2.ZERO
var downed := false
var firing := false


func _draw() -> void:
	var color: Color = SLOT_COLORS[slot_index % SLOT_COLORS.size()]
	if downed:
		color = color.darkened(0.55)

	if texture != null:
		# Спрайт из art/: nearest, чтобы низкое разрешение не мылилось.
		var size := texture.get_size()
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false,
			Color.WHITE if not downed else Color(0.5, 0.5, 0.55))
	else:
		# Заглушка, пока спрайта нет. Так и должно выглядеть до арт-теста.
		draw_rect(Rect2(-BOX * 0.5, BOX), color, true)
		draw_rect(Rect2(-BOX * 0.5, BOX), color.lightened(0.4), false, 1.0)

	# Направление прицела — единственное, что подсказывает, куда смотрит тело
	if aim != Vector2.ZERO:
		var length := 26.0 if not firing else 34.0
		draw_line(Vector2.ZERO, aim.normalized() * length,
			Color(1, 1, 1, 0.85 if firing else 0.45), 2.0)

	# Номер слота, чтобы не путаться, когда воткнуто четыре геймпада
	draw_string(ThemeDB.fallback_font, Vector2(-4, -BOX.y * 0.5 - 6),
		"p%d" % (slot_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1, 1, 1, 0.7))
