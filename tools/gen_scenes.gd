extends SceneTree
## Сборка сцен кодом. Запуск — tools/gen_scenes.sh.
##
## Сцена стенда состоит из одного узла со скриптом: всё содержимое строится
## в _ready(). Так .tscn остаётся в три строки и не воюет с гитом, а вся
## структура видна в коде, а не в дереве редактора.
##
## Формат .tscn пишет сам движок через PackedScene — писать его текстом на
## память значит рано или поздно ошибиться в номере формата.

const SANDBOX_PATH := "res://game/dev_sandbox.tscn"


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "DevSandbox"
	root.set_script(load("res://game/dev_sandbox.gd"))

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Сцена не упаковалась: %d" % err)
		quit(1)
		return

	err = ResourceSaver.save(packed, SANDBOX_PATH)
	if err != OK:
		push_error("Сцена не записалась: %d" % err)
		quit(1)
		return

	# Узел создан вручную и в дерево не попал — освобождать тоже вручную,
	# иначе движок ругается утечкой на выходе.
	root.free()

	print("Сцены собраны")
	print("  %s" % SANDBOX_PATH)
	quit(0)


func _process(_delta: float) -> bool:
	return true
