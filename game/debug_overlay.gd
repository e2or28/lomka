extends CanvasLayer
## Отладочный оверлей: F3. Всё состояние симуляции видно прямо в игре, без
## открытого редактора.
##
## Ползунки правят базовые статы занятых слотов: ощущение управления
## крутится руками, а не подбирается формулой.

signal stat_changed(stat: String, value: float)

## Потолки подняты до мгновенного отклика: при скорости 260 разгон 30000
## набирает её за полтика.
const KNOBS := [
	{"stat": "move_speed", "label": "скорость", "min": 40.0, "max": 700.0, "step": 5.0},
	{"stat": "acceleration", "label": "разгон", "min": 200.0, "max": 30000.0, "step": 100.0},
	{"stat": "friction", "label": "торможение", "min": 200.0, "max": 40000.0, "step": 100.0},
]

var _readout: Label = null
var _hint: Label = null
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

	_panel = VBoxContainer.new()
	_panel.position = Vector2(12, 200)
	_panel.custom_minimum_size = Vector2(240, 0)
	add_child(_panel)

	for knob in KNOBS:
		_add_knob(knob)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_hint.text = "F1 масштаб · F3 оверлей и хитбоксы · F5 art/ · Tab слот · Q оружие · R сброс · Esc · стрелки стреляют"
	_panel.add_child(_hint)


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
