extends Node2D
## Экран сверки масштаба, F1: спрайт рядом с силуэтом игрока, дверным
## проёмом и клеткой комнаты — не в том масштабе видно сразу, а не через
## двадцать спрайтов.
##
## Числа — заглушки, уточняются по итогам художественного теста на M1.

const TILE := 32
const PLAYER_SIZE := Vector2(24, 28)
const DOOR := Vector2(48, 64)

var enabled := false


func _draw() -> void:
	if not enabled:
		return

	var view := get_viewport_rect().size

	var grid := Color(1, 1, 1, 0.08)
	var x := 0.0
	while x < view.x:
		draw_line(Vector2(x, 0), Vector2(x, view.y), grid, 1.0)
		x += TILE
	var y := 0.0
	while y < view.y:
		draw_line(Vector2(0, y), Vector2(view.x, y), grid, 1.0)
		y += TILE

	var base_y := view.y - TILE * 2
	_silhouette(Vector2(TILE * 2, base_y), PLAYER_SIZE, Color(0.4, 0.9, 0.5, 0.55), "игрок")
	_silhouette(Vector2(TILE * 5, base_y), DOOR, Color(0.9, 0.7, 0.3, 0.45), "дверь")
	_silhouette(Vector2(TILE * 9, base_y), Vector2(TILE, TILE), Color(0.5, 0.7, 1.0, 0.45), "клетка")


func _silhouette(anchor: Vector2, size: Vector2, color: Color, label: String) -> void:
	var rect := Rect2(anchor - Vector2(size.x * 0.5, size.y), size)
	draw_rect(rect, color, true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.9), false, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, anchor + Vector2(-size.x * 0.5, 14), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
