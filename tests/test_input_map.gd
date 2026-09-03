extends "res://tests/framework/test_case.gd"
## Класс: инвариант. Стережёт совпадение генератора с тем, что он
## сгенерировал: покраснел — почти всегда забыт tools/gen_project.sh.
##
## Карта ввода в project.godot против таблицы в tools/input_map.gd.
##
## Проверки собирают расхождения в список и падают один раз, а не поштучным
## assert на каждое из 48 действий: иначе поломка даёт полсотни одинаковых
## строк, в которых не видно сути.

const InputMapDef = preload("res://tools/input_map.gd")

const OWNED_PATTERN := "^p[0-9]+_"


func title() -> String:
	return "карта ввода"


func _test_all_actions_present() -> bool:
	var missing := PackedStringArray()
	for player in InputMapDef.PLAYERS:
		for action in InputMapDef.ACTIONS:
			var name := InputMapDef.action_name(player, action)
			if not InputMap.has_action(name):
				missing.append(name)
	check(missing.is_empty(),
		"в project.godot нет действий (пересобери tools/gen_project.sh): " + ", ".join(missing))
	return true


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
	var drifted := PackedStringArray()
	for player in InputMapDef.PLAYERS:
		for action in InputMapDef.ACTIONS:
			var name := InputMapDef.action_name(player, action)
			if not InputMap.has_action(name):
				continue
			var in_file := InputMap.action_get_events(name).size()
			var in_table: int = InputMapDef.events_for(player, action).size()
			if in_file != in_table:
				drifted.append("%s (%d против %d)" % [name, in_file, in_table])
	check(drifted.is_empty(),
		"в project.godot не столько привязок, сколько в таблице: " + ", ".join(drifted))
	return true


func _test_deadzone_applied() -> bool:
	var drifted := PackedStringArray()
	for player in InputMapDef.PLAYERS:
		var name := InputMapDef.action_name(player, "move_up")
		if InputMap.has_action(name) and absf(InputMap.action_get_deadzone(name) - InputMapDef.DEADZONE) > 1e-6:
			drifted.append(name)
	check(drifted.is_empty(), "мёртвая зона разошлась с таблицей у: " + ", ".join(drifted))
	return true


func _test_devices_are_separated() -> bool:
	var wrong := PackedStringArray()
	for player in InputMapDef.PLAYERS:
		for action in InputMapDef.ACTIONS:
			var name := InputMapDef.action_name(player, action)
			if not InputMap.has_action(name):
				continue
			for event in InputMap.action_get_events(name):
				if (event is InputEventKey or event is InputEventMouseButton) and player != 0:
					wrong.append("%s: клавиатура или мышь не у первого слота" % name)
				elif (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device != player:
					wrong.append("%s: геймпад устройства %d" % [name, event.device])
	check(wrong.is_empty(), "устройства перепутаны: " + ", ".join(wrong))
	return true


func _test_every_slot_can_play() -> bool:
	var unusable := PackedStringArray()
	for player in InputMapDef.PLAYERS:
		for action in ["move_up", "move_left", "aim_up", "fire", "interact", "harvest", "skill"]:
			var name := InputMapDef.action_name(player, action)
			if not InputMap.has_action(name) or InputMap.action_get_events(name).is_empty():
				unusable.append(name)
	check(unusable.is_empty(), "слотам нечем играть: " + ", ".join(unusable))
	return true
