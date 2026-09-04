extends CanvasLayer
## Отладочный оверлей: 1 показания, 2 ползунки. Всё состояние симуляции
## видно прямо в игре, без открытого редактора.
##
## Ползунки правят базовые статы занятых слотов: ощущение управления
## крутится руками, а не подбирается формулой. Свёрнуты по умолчанию и на
## своей клавише: держать их открытыми нужно минуты в час, а закрывают они
## треть комнаты.

signal stat_changed(stat: String, value: float)

## Потолки подняты до мгновенного отклика: при скорости 260 разгон 30000
## набирает её за полтика.
const KNOBS := [
	{"stat": "move_speed", "label": "скорость", "min": 40.0, "max": 700.0, "step": 5.0},
	{"stat": "acceleration", "label": "разгон", "min": 200.0, "max": 30000.0, "step": 100.0},
	{"stat": "friction", "label": "торможение", "min": 200.0, "max": 40000.0, "step": 100.0},
]

## Подсказка данными: завёл действие — дописал строку, и оно сразу видно
## на экране. Списки, которые надо синхронизировать руками с кодом, живут
## ровно до второй правки.
const CONTROLS := [
	["WASD", "идти"],
	["стрелки", "стрелять"],
	["E", "подобрать оружие с пола"],
]

const STAND_KEYS := [
	["1", "оверлей и хитбоксы"],
	["2", "ползунки статов"],
	["3", "сверка масштаба"],
	["4", "перечитать art/"],
	["Shift+1..9", "поставить монстра перед собой"],
	["0", "убрать всех врагов"],
	["Tab", "добавить слот игрока"],
	["Q", "сменить оружие на месте"],
	["R", "сброс комнаты"],
	["Esc", "выход"],
]

const KEY_COLOR := Color(0.98, 0.87, 0.55)
const TEXT_COLOR := Color(0.86, 0.88, 0.9)
const TITLE_COLOR := Color(0.55, 0.7, 0.6)

## Колонка клавиш одной ширины на оба блока: иначе описания начинаются на
## разном отступе, потому что сетки считают ширину каждая по своим строкам.
const KEY_COLUMN := 78.0

var _readout: Label = null
var _legend: VBoxContainer = null
var _panel: VBoxContainer = null
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}


func _ready() -> void:
	layer = 10

	_readout = Label.new()
	_readout.position = Vector2(12, 10)
	_readout.add_theme_font_size_override("font_size", 12)
	_readout.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	add_child(_readout)

	# Подложка: светлый пол съедает серый текст, и подсказка перестаёт
	# читаться ровно там, где нужна — посреди комнаты.
	var backdrop := PanelContainer.new()
	backdrop.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	backdrop.offset_left += 12
	backdrop.offset_right += 12
	backdrop.offset_top -= 12
	backdrop.offset_bottom -= 12
	# Иначе список растёт вниз от нижнего края и уходит за экран целиком.
	backdrop.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.74)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	backdrop.add_theme_stylebox_override("panel", style)
	add_child(backdrop)

	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 1)
	backdrop.add_child(_legend)

	_legend.add_child(_legend_title("УПРАВЛЕНИЕ"))
	_legend.add_child(_legend_rows(CONTROLS))
	_legend.add_child(_legend_title("СТЕНД"))
	_legend.add_child(_legend_rows(STAND_KEYS))

	_panel = VBoxContainer.new()
	_panel.position = Vector2(12, 344)
	_panel.custom_minimum_size = Vector2(240, 0)
	_panel.visible = false
	add_child(_panel)

	for knob in KNOBS:
		_add_knob(knob)


func _legend_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", TITLE_COLOR)
	# Воздух над заголовком, а не между строками: иначе блоки слипаются.
	label.custom_minimum_size.y = 22
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


## Сеткой, а не пробелами в одной строке: шрифт не моноширинный, и
## колонки из пробелов разъезжаются на первой же длинной клавише.
func _legend_rows(rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 1)
	for row in rows:
		var key := _legend_cell(row[0], KEY_COLOR)
		key.custom_minimum_size.x = KEY_COLUMN
		grid.add_child(key)
		grid.add_child(_legend_cell(row[1], TEXT_COLOR))
	return grid


func _legend_cell(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	return label


func _add_knob(knob: Dictionary) -> void:
	var stat: String = knob["stat"]

	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_panel.add_child(caption)
	_value_labels[stat] = caption

	var slider := HSlider.new()
	slider.min_value = knob["min"]
	slider.max_value = knob["max"]
	slider.step = knob.get("step", 10.0)
	slider.custom_minimum_size = Vector2(240, 16)
	slider.value_changed.connect(func(value: float) -> void:
		_refresh_all_captions()
		stat_changed.emit(stat, value))
	_panel.add_child(slider)
	_sliders[stat] = slider


## «разгон 9000» ни о чём не говорит, «29 мс до полной скорости» — говорит.
func _refresh_caption(stat: String, value: float) -> void:
	for knob in KNOBS:
		if knob["stat"] != stat:
			continue
		var text := "%s  %.0f" % [knob["label"], value]
		if stat != "move_speed" and value > 0.0:
			var speed: float = _sliders["move_speed"].value if _sliders.has("move_speed") else 0.0
			if speed > 0.0:
				text += "   (%.0f мс)" % (speed / value * 1000.0)
		_value_labels[stat].text = text
		return


func _refresh_all_captions() -> void:
	for knob in KNOBS:
		var stat: String = knob["stat"]
		if _sliders.has(stat):
			_refresh_caption(stat, _sliders[stat].value)


## Без сигналов: иначе стенд при старте перезапишет статы умолчаниями.
func sync_from_stats(stats: Dictionary) -> void:
	for stat in _sliders.keys():
		var slider: HSlider = _sliders[stat]
		slider.set_value_no_signal(float(stats.get(stat, slider.min_value)))
	_refresh_all_captions()


func set_text(text: String) -> void:
	_readout.text = text


func toggle_knobs() -> void:
	_panel.visible = not _panel.visible
