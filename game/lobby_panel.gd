extends CanvasLayer

const Session = preload("res://game/network_session.gd")

var session
var panel: Control
var open_button: Button
var name_input: LineEdit
var address_input: LineEdit
var port_input: SpinBox
var roster: Label
var status: Label
var host_button: Button
var join_button: Button
var ready_button: Button
var start_button: Button
var leave_button: Button
var volume: HSlider
var _was_running := false

signal volume_changed(value: float)

func _ready() -> void:
	layer = 12
	open_button = Button.new()
	open_button.text = "Играть с друзьями"
	open_button.position = Vector2(310, 20)
	open_button.size = Vector2(175, 34)
	open_button.pressed.connect(toggle)
	add_child(open_button)
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0.018, 0.024, 0.022, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(510, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = "СОВМЕСТНАЯ СМЕНА"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "До четырёх игроков · один создаёт, остальные подключаются"
	subtitle.add_theme_font_size_override("font_size", 14)
	box.add_child(subtitle)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Твоё имя"
	name_input.text = "Игрок"
	name_input.max_length = 24
	box.add_child(name_input)
	var address_row := HBoxContainer.new()
	box.add_child(address_row)
	address_input = LineEdit.new()
	address_input.placeholder_text = "Адрес ведущего"
	address_input.text = "127.0.0.1"
	address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_row.add_child(address_input)
	port_input = SpinBox.new()
	port_input.min_value = 1024
	port_input.max_value = 65535
	port_input.value = Session.PORT
	port_input.prefix = "Порт "
	address_row.add_child(port_input)
	var row := HBoxContainer.new()
	box.add_child(row)
	host_button = _button(row, "Создать комнату", func(): session.host(name_input.text, int(port_input.value)))
	join_button = _button(row, "Подключиться", func(): session.join(address_input.text, name_input.text, int(port_input.value)))
	roster = Label.new()
	roster.custom_minimum_size.y = 104
	box.add_child(roster)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	ready_button = _button(controls, "Готов", _toggle_ready)
	start_button = _button(controls, "Начать смену", func(): session.start())
	leave_button = _button(controls, "Выйти из комнаты", func(): session.leave())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(510, 72)
	status.text = "В одной сети используй адрес компьютера ведущего. Для двух окон на этом компьютере подходит 127.0.0.1."
	box.add_child(status)
	var volume_label := Label.new()
	volume_label.text = "Громкость эффектов"
	box.add_child(volume_label)
	volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.value = 55
	volume.value_changed.connect(func(value): volume_changed.emit(value / 100.0))
	box.add_child(volume)
	_button(box, "Вернуться в игру", func(): panel.hide())
	session.lobby_changed.connect(refresh)
	session.notice.connect(func(message):
		status.text = message
		if not session.running: panel.show()
	)
	panel.hide()
	refresh()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible: refresh()

func is_open() -> bool:
	return panel != null and panel.visible

func _toggle_ready() -> void:
	var id: int = session.multiplayer.get_unique_id()
	if session.members.has(id): session.set_ready(not bool(session.members[id].ready))

func refresh() -> void:
	if roster == null: return
	if session.running and not _was_running: panel.hide()
	_was_running = session.running
	open_button.text = "Комната · %d/4" % session.members.size() if session.active else "Играть с друзьями"
	host_button.disabled = session.active
	join_button.disabled = session.active
	name_input.editable = not session.active
	address_input.editable = not session.active
	port_input.editable = not session.active
	leave_button.disabled = not session.active
	ready_button.disabled = not session.active or session.running
	start_button.disabled = not session.can_start()
	var lines := PackedStringArray()
	var ids: Array = session.members.keys()
	ids.sort()
	for id in ids:
		var member: Dictionary = session.members[id]
		lines.append("%s%s  ·  %s" % [member.name, " (ведущий)" if int(id) == 1 else "", "готов" if member.ready else "ждём готовности"])
	roster.text = "В комнате пока никого нет." if lines.is_empty() else "\n".join(lines)
	if session.active and session.members.has(session.multiplayer.get_unique_id()):
		ready_button.text = "Не готов" if session.members[session.multiplayer.get_unique_id()].ready else "Готов"
