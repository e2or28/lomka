extends SceneTree
## Пересобрать эталонный сейв. Запуск — tools/gen_fixture.sh.
##
## Гонять только осознанно: пересборка фикстуры means «я согласен, что формат
## изменился». Если тест круговорота покраснел, а формат менять не собирался
## — чинить код, а не пересобирать эталон.

const ReferenceRun = preload("res://tests/framework/reference_run.gd")
const SaveGame = preload("res://sim/save/save_game.gd")

const FIXTURE_PATH := "res://tests/fixtures/save_format_%d.bin"


func _initialize() -> void:
	var path := FIXTURE_PATH % SaveGame.FORMAT
	var state := ReferenceRun.build()
	var err := SaveGame.save_to_file(state, path)
	if err != OK:
		push_error("Фикстура не записалась: %d" % err)
		quit(1)
		return
	var bytes := SaveGame.to_bytes(state)
	print("Эталонный сейв пересобран")
	print("  файл:     %s" % path)
	print("  формат:   %d" % SaveGame.FORMAT)
	print("  байт:     %d" % bytes.size())
	print("  отпечаток: %d" % state.state_hash())
	quit(0)


func _process(_delta: float) -> bool:
	return true
