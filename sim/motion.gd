extends RefCounted
## Движение: чистая математика, без узлов и без кадров. Разгон, торможение
## и потолок скорости идут через стек модификаторов статами acceleration,
## friction и move_speed (правило 4) — предмет на ускорение работает сам.

const Schemas = preload("res://sim/data/schemas.gd")

## Заглушка: числа подбираются на стенде ползунками.
const PLACEHOLDER_STATS := {
	"acceleration": 9000.0,
	"friction": 18000.0,
	"move_speed": 260.0,
}


## move_input — от -1 до 1 по каждой оси.
static func step_velocity(velocity: Vector2, move_input: Vector2, stats: Dictionary, delta: float) -> Vector2:
	var input := move_input
	# Диагональ не должна быть быстрее прямой: сумма осей даёт длину 1.41.
	if input.length_squared() > 1.0:
		input = input.normalized()

	var target := input * float(stats.get("move_speed", 0.0))
	var rate := float(stats.get("acceleration", 0.0)) if input != Vector2.ZERO else float(stats.get("friction", 0.0))
	return velocity.move_toward(target, rate * delta)


static func step_position(position: Vector2, velocity: Vector2, delta: float) -> Vector2:
	return position + velocity * delta
