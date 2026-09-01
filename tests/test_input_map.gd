extends "res://tests/framework/test_case.gd"
## Карта ввода в project.godot против таблицы в tools/input_map.gd.
##
## Смысл теста — не проверить движок, а поймать рассинхрон: карта собирается
## генератором, и стоит поправить таблицу, забыв про tools/gen_project.sh,
## как project.godot остаётся вчерашним. Молча: игра запустится, просто
## новое действие ни на что не назначено.

const InputMapDef = preload("res://tools/input_map.gd")

const OWNED_PATTERN := "^p[0-9]+_"


func title() -> String:
	return "карта ввода"


func _test_all_actions_present() -> bool:
	for player in InputMapDef.PLAYERS:
		for action in InputMapDef.ACTIONS:
			var name := InputMapDef.action_name(player, action)
			check(InputMap.has_action(name), "действия '%s' нет в project.godot" % name)
	return true


## Лишних действий быть не должно тоже: переименованное действие,
## оставшееся в файле, продолжает срабатывать.
func _test_no_stale_actions() -> bool:
	var regex := RegEx.new()
	regex.compile(OWNED_PATTERN)
	var found := 0
	for action in InputMap.get_actions():
		if regex.search(str(action)) != null:
			found += 1
	eq(found, InputMapDef.PLAYERS * InputMapDef.ACTIONS.size(),
		"в project.godot не то число действий со слотами — не пересобран после правки таблицы?")
	return true


func _test_bindings_match_table() -> bool:
	for player in InputMapDef.PLAYERS:
		for action in InputMapDef.ACTIONS:
			var name := InputMapDef.action_name(player, action)
			if not InputMap.has_action(name):
				continue
			eq(InputMap.action_get_events(name).size(), InputMapDef.events_for(player, action).size(),
				"у '%s' в project.godot не столько привязок, сколько в таблице" % name)
	return true


func _test_deadzone_applied() -> bool:
	for player in InputMapDef.PLAYERS:
		var name := InputMapDef.action_name(player, "move_up")
		if InputMap.has_action(name):
			almost_eq(InputMap.action_get_deadzone(name), InputMapDef.DEADZONE,
				"мёртвая зона '%s' разошлась с таблицей" % name, 1e-6)
	return true


## Клавиатура и мышь — только у первого слота, геймпад — у своего устройства.
## Если это разъедется, второй игрок будет ходить от клавиатуры первого.
func _test_devices_are_separated() -> bool:
	for player in InputMapDef.PLAYERS:
		for action in InputMapDef.ACTIONS:
			var name := InputMapDef.action_name(player, action)
			if not InputMap.has_action(name):
				continue
			for event in InputMap.action_get_events(name):
				if event is InputEventKey or event is InputEventMouseButton:
					eq(player, 0, "клавиатура или мышь назначена не первому слоту: '%s'" % name)
				elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
					eq(event.device, player, "у '%s' геймпад чужого устройства" % name)
	return true


## Каждому слоту должно достаться движение, прицел и огонь — иначе он не
## играет, а стоит.
func _test_every_slot_can_play() -> bool:
	for player in InputMapDef.PLAYERS:
		for action in ["move_up", "move_left", "aim_up", "fire", "interact", "harvest", "skill"]:
			var name := InputMapDef.action_name(player, action)
			check(InputMap.has_action(name) and not InputMap.action_get_events(name).is_empty(),
				"слоту p%d нечем сделать '%s'" % [player + 1, action])
	return true
