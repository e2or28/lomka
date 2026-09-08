extends RefCounted

# Начало брюк на исходных кадрах; пол у всех на y=174. Независимый импорт
# по росту выровнял макушку и стопы, но оставил гуляющий пояс.
const SIDE_WAIST := [104, 110, 111, 115, 113, 112]
const COLT_WAIST := [104, 102, 104, 104, 98, 98]
const FLOOR := 174


static func waist(frame: String) -> int:
	if frame.begins_with("player_colt_walk_"):
		return COLT_WAIST[clampi(frame.get_slice("_", 3).to_int() - 1, 0, 5)]
	if frame.begins_with("player_side_walk_"):
		return SIDE_WAIST[clampi(frame.get_slice("_", 3).to_int() - 1, 0, 5)]
	return 112


static func apply(body: Image, legs: Image, frame: String, gait: String) -> void:
	var target_y := waist(frame)
	var source_y := waist(gait)
	var target_span := _span(body, target_y)
	var source_span := _span(legs, source_y)
	var mask := _leg_mask(legs, source_y, roundi((source_span.x + source_span.y) * 0.5))
	var shift := (target_span.x + target_span.y - source_span.x - source_span.y) * 0.5
	for y in range(target_y, body.get_height()):
		for x in body.get_width():
			body.set_pixel(x, y, Color.TRANSPARENT)
	for y in range(target_y, FLOOR + 1):
		var sy := roundi(remap(y, target_y, FLOOR, source_y, FLOOR))
		# Первые строки соединяют пояс без ступеньки; ниже сохраняется ширина шага.
		var blend := smoothstep(target_y, target_y + 16, y)
		for x in body.get_width():
			var fitted := remap(x, target_span.x, target_span.y, source_span.x, source_span.y)
			var sx := roundi(lerpf(fitted, x - shift, blend))
			if sx < 0 or sx >= legs.get_width():
				continue
			if not mask[sy * legs.get_width() + sx]:
				continue
			body.set_pixel(x, y, legs.get_pixel(sx, sy))


static func _span(image: Image, y: int) -> Vector2:
	var left := 0
	var best := Vector2.ZERO
	for x in image.get_width():
		var c := image.get_pixel(x, y)
		if c.a <= 0.5 or c.r >= 0.4:
			left = x + 1
		elif x - left > best.y - best.x:
			best = Vector2(left, x)
	return Vector2(best.x, maxf(best.x + 1, best.y))


# Берём связный силуэт брюк и ботинок. Дальняя кисть со своим чёрным
# контуром иначе приезжает из кадра ходьбы поверх постоянной руки.
static func _leg_mask(image: Image, top: int, center: int) -> PackedByteArray:
	var width := image.get_width()
	var mask := PackedByteArray()
	mask.resize(width * image.get_height())
	var queue: Array[Vector2i] = [Vector2i(center, top)]
	var cursor := 0
	while cursor < queue.size():
		var p := queue[cursor]
		cursor += 1
		if p.x < 0 or p.x >= width or p.y < top or p.y > FLOOR:
			continue
		var index := p.y * width + p.x
		if mask[index]:
			continue
		var c := image.get_pixelv(p)
		if c.a <= 0.03 or (c.r > 0.4 and c.r > c.g * 1.2):
			continue
		mask[index] = 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(p + direction)
	return mask
