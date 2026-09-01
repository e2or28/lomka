extends RefCounted
## Движение: чистая математика, без узлов и без кадров.
##
## Здесь живёт «ощущение управления» — разгон, торможение, потолок скорости.
## Настраивается статами acceleration, friction и move_speed, то есть идёт
## через стек модификаторов (правило 4), а не жёстко зашито. Значит предмет
## на ускорение работает сам, а стенд может крутить те же числа ползунками.
##
## Числа подбирает Егор руками на стенде. Здесь только форма кривой.

const Schemas = preload("res://sim/data/schemas.gd")

## Заглушка, а не решение: числа подбираются на стенде ползунками.
##
## Первая правка по живому отклику — «слишком мягко». Разгон был 92 мс до
## полной скорости, стало 29 мс: с места тело идёт почти мгновенно, инерция
## на глаз пропадает. Торможение вдвое резче разгона — так остановка не
## тянется, а движение всё равно не выглядит роботным.
const PLACEHOLDER_STATS := {
	"acceleration": 9000.0,
	"friction": 18000.0,
	"move_speed": 260.0,
}


## Новая скорость через тик. move_input — от -1 до 1 по каждой оси.
static func step_velocity(velocity: Vector2, move_input: Vector2, stats: Dictionary, delta: float) -> Vector2:
	var input := move_input
	# Диагональ не должна быть быстрее прямой: на клавиатуре сумма осей
	# даёт длину 1.41, и наискосок игрок ходил бы на 41% шустрее.
	if input.length_squared() > 1.0:
		input = input.normalized()

	var target := input * float(stats.get("move_speed", 0.0))
	var rate := float(stats.get("acceleration", 0.0)) if input != Vector2.ZERO else float(stats.get("friction", 0.0))
	return velocity.move_toward(target, rate * delta)


static func step_position(position: Vector2, velocity: Vector2, delta: float) -> Vector2:
	return position + velocity * delta
