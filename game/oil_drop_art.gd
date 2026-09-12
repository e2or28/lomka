extends RefCounted
## Нефть в полёте. Капля вытянута по скорости, дрожит на лету и волочит
## хвост; от хвоста отрываются мелкие брызги. Ничего из этого не попадает
## в симуляцию: попадание считает радиус снаряда, а не нарисованный силуэт.

const RADIUS := 11.0
const SKIN := Color(0.82, 0.51, 0.19)
const CORE := Color(0.06, 0.045, 0.04)
const TAIL := Color(0.18, 0.12, 0.05, 0.65)


## Вытянутость вдоль полёта и сжатие поперёк: объём капли сохраняется,
## поэтому поперечный размер — обратный продольному.
static func stretch(age: float) -> Vector2:
	var settle := smoothstep(0.0, 0.14, age)
	var along := 1.0 + settle * 0.34 + sin(age * TAU * 3.1) * 0.05 * settle
	return Vector2(along, 1.0 / along)


## Поперечное подрагивание. В момент выпуска нулевое: капля выходит из
## ствола ровно по линии выстрела, иначе первый кадр разойдётся с дулом.
static func wobble(age: float) -> float:
	return sin(age * TAU * 2.7) * 2.2 * smoothstep(0.0, 0.2, age)


## Длина хвоста растёт до предела: он тянется за каплей, а не удлиняется
## бесконечно вместе с дальностью.
static func tail_length(age: float) -> float:
	return 19.0 + 9.0 * smoothstep(0.0, 0.45, age) + sin(age * TAU * 4.3) * 1.5


## Оторвавшаяся капля: смещение назад и вбок плюс её радиус. Возвращает
## пустой размер, пока брызг не родился.
static func speck(age: float, index: int) -> Vector3:
	var born := 0.12 + index * 0.17
	if age < born:
		return Vector3.ZERO
	var life: float = fmod(age - born, 0.62) / 0.62
	var back := tail_length(age) * (0.55 + life * 0.75)
	var side := sin((index + 1) * 2.4 + age * 5.0) * (2.0 + life * 5.0)
	return Vector3(-back, side, (1.0 - life) * 3.1)


## Эллипс полигоном, а не draw_circle с трансформацией: канва уже повёрнута
## по скорости снаряда вызывающим кодом, а draw_set_transform не
## вкладывается — он затёр бы этот поворот.
static func blob(view: Node2D, center: Vector2, radius: float, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		points.append(center + Vector2(cos(a) * radius * size.x, sin(a) * radius * size.y))
	view.draw_colored_polygon(points, color)


static func draw(view: Node2D, age: float) -> void:
	var size := stretch(age)
	var shift := wobble(age)
	var length := tail_length(age)
	view.draw_line(Vector2(-length, shift * 0.4), Vector2(0, shift), TAIL, 12.0 * size.y)
	for i in 3:
		var s := speck(age, i)
		if s.z <= 0.0:
			continue
		view.draw_circle(Vector2(s.x, s.y + shift * 0.3), s.z, Color(TAIL, 0.5))
	var center := Vector2(0, shift)
	blob(view, center, RADIUS, size, SKIN)
	blob(view, center, 8.0, size, CORE)
	blob(view, center + Vector2(2, -3), 2.5, size, Color(0.58, 0.43, 0.24))


## Всплеск: нефть не искрит, как пуля или папка, а разлетается каплями и
## оседает пятном. Индекс задаёт каплю, progress — общий ход всплеска.
## Возвращает смещение от точки попадания и радиус капли.
static func splash_drop(index: int, progress: float, direction: Vector2) -> Vector3:
	var spread := direction.angle() + PI + (index - 4.5) * 0.36
	var reach := 14.0 + (index % 3) * 11.0
	var flight := smoothstep(0.0, 0.8, progress)
	var at := Vector2.RIGHT.rotated(spread) * reach * (0.35 + flight * 1.9)
	# Капля тяжёлая: разлетевшись, она проседает к полу, а не гаснет в воздухе.
	at.y += flight * flight * 15.0
	return Vector3(at.x, at.y, maxf(0.0, (5.4 - (index % 3) * 1.1) * (1.0 - progress)))


static func splash(view: Node2D, at: Vector2, direction: Vector2, progress: float) -> void:
	var fade := 1.0 - progress
	var pool := smoothstep(0.0, 0.55, progress) * 23.0
	# Первый миг — корона от удара тяжёлой капли. Тёмная, а не оранжевая:
	# дерутся на песке, и подсветка цвета самой нефти на нём терялась.
	var crown := 1.0 - smoothstep(0.0, 0.32, progress)
	if crown > 0.0:
		blob(view, at, 9.0 + crown * 14.0, Vector2(1.0, 0.62), Color(CORE, crown * 0.6))
	view.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-pool, 2), at + Vector2(-pool * 0.6, 5),
		at + Vector2(pool * 0.6, 5), at + Vector2(pool, 2),
		at + Vector2(pool * 0.5, -1), at + Vector2(-pool * 0.5, -1)]),
		Color(CORE, fade * 0.75))
	for i in 10:
		var drop := splash_drop(i, progress, direction)
		if drop.z <= 0.0:
			continue
		blob(view, at + Vector2(drop.x, drop.y), drop.z, Vector2.ONE,
			Color(SKIN if i % 4 == 0 else CORE, fade))


## Взрыв бочки: огненный шар, вырастающий и опадающий в чёрный дым.
## Нефть горит грязно, поэтому пламя быстро уходит в копоть, а не гаснет
## чистой вспышкой.
static func blast(view: Node2D, at: Vector2, progress: float, radius: float) -> void:
	var grow := smoothstep(0.0, 0.35, progress)
	var fade := 1.0 - smoothstep(0.45, 1.0, progress)
	var soot := smoothstep(0.2, 0.9, progress)
	blob(view, at, radius * (0.35 + grow * 0.75), Vector2(1.0, 0.78),
		Color(0.07, 0.06, 0.06, fade * 0.72))
	blob(view, at, radius * (0.2 + grow * 0.52), Vector2(1.0, 0.82),
		Color(1.0, 0.55, 0.14).lerp(Color(0.22, 0.18, 0.16), soot) * Color(1, 1, 1, fade))
	blob(view, at - Vector2(0, radius * grow * 0.3), radius * (0.1 + grow * 0.26), Vector2.ONE,
		Color(1.0, 0.88, 0.5, fade * (1.0 - soot)))
	for i in 10:
		var drop := splash_drop(i, progress, Vector2.DOWN)
		if drop.z <= 0.0:
			continue
		blob(view, at + Vector2(drop.x, drop.y) * 1.7, drop.z * 1.4, Vector2.ONE,
			Color(CORE, fade))
