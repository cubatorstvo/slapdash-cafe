extends CanvasLayer
## FPS overlay and explicit teaching selection.
signal resume_requested
var recipe_panel: PanelContainer
var recipe_text: Label
var bottom: PanelContainer
var goal: Label
var clock: Label
var clone_status: Label
var supplies: Label
var controls: Label
var prompt: Label
var notice: Label
var crosshair: Label
var progress: ProgressBar
var pause_panel: PanelContainer

func _ready() -> void:
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("f5ead7"))
	root.theme = theme
	var top := _panel(root)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	top.offset_bottom = 96
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 35)
	top.add_child(row)
	var brand := VBoxContainer.new()
	row.add_child(brand)
	_label(brand, "SLAPDASH CAFE", 24, Color("f2c578"))
	clone_status = _label(brand, "Клон ждёт показа", 16, Color("85cfb9"))
	var order := VBoxContainer.new()
	order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(order)
	goal = _label(order, "", 20)
	progress = ProgressBar.new()
	order.add_child(progress)
	progress.max_value = 100
	progress.show_percentage = false
	progress.custom_minimum_size.y = 7
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ce6b78")
	fill.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("fill", fill)
	var timing := VBoxContainer.new()
	row.add_child(timing)
	clock = _label(timing, "", 21, Color("f2c578"))
	_label(timing, "Время записанного исполнения", 14)
	recipe_panel = _panel(root)
	recipe_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	recipe_panel.position = Vector2(20, 118)
	recipe_text = _label(recipe_panel, "", 16)
	recipe_panel.hide()
	bottom = _panel(root)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -136
	bottom.offset_bottom = -16
	var column := VBoxContainer.new()
	bottom.add_child(column)
	column.add_theme_constant_override("separation", 6)
	supplies = _label(column, "", 16)
	controls = _label(column, "", 16)
	notice = _label(column, "Подойди к рабочей станции и нажми E. Бригада уже на месте.", 16, Color("f2c578"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crosshair = _label(root, "·", 32, Color("ffffff"))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -12
	crosshair.offset_right = 12
	crosshair.offset_top = -22
	crosshair.offset_bottom = 22
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = _label(root, "", 19, Color("ffe1a0"))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.offset_left = -430
	prompt.offset_right = 430
	prompt.offset_top = 34
	prompt.offset_bottom = 94
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_constant_override("outline_size", 6)
	prompt.add_theme_color_override("font_outline_color", Color("132b31"))
	pause_panel = _panel(root)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -250
	pause_panel.offset_right = 250
	pause_panel.offset_top = -120
	pause_panel.offset_bottom = 120
	var pause_content := VBoxContainer.new()
	pause_panel.add_child(pause_content)
	pause_content.add_theme_constant_override("separation", 18)
	_label(pause_content, "ПАУЗА", 28, Color("f2c578"))
	_label(pause_content, "Кафе и обучение остановлены.\nEsc — вернуться в игру.", 18)
	var resume := Button.new()
	pause_content.add_child(resume)
	resume.text = "Продолжить"
	resume.custom_minimum_size.y = 45
	resume.pressed.connect(func(): resume_requested.emit())
	pause_panel.hide()


func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.12, 0.15, 0.93)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(parent: Node, value: String, size: int, color := Color("e4e4d5")) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
