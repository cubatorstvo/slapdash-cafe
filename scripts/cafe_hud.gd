extends CanvasLayer
const CafeStyle = preload("res://scripts/cafe_theme.gd")
const Data = preload("res://scripts/cookbook_data.gd")
signal office_requested
signal resume_requested
var recipe_panel: PanelContainer
var recipe_text: Label
var recipe_content: VBoxContainer
var recipe_scroll: ScrollContainer
var recipe_stamp := ""
var bottom: PanelContainer
var journey: Label
var visit_status: Label
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
var toast: Label
var toast_tween: Tween
var event_feed_panel: PanelContainer
var event_feed_text: Label

func _ready() -> void:
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = CafeStyle.make()
	var top := _panel(root)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 26
	top.offset_right = -26
	top.offset_top = 22
	top.offset_bottom = 150
	var row := HBoxContainer.new()
	top.add_child(row)
	row.add_theme_constant_override("separation", 24)
	var brand := VBoxContainer.new()
	row.add_child(brand)
	_label(brand,"SLAPDASH",22,CafeStyle.GOLD)
	_label(brand,"C A F E",12,CafeStyle.MINT)
	var order := VBoxContainer.new()
	row.add_child(order)
	order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal = _label(order,"",20)
	clone_status = _label(order,"",14,CafeStyle.MINT)
	journey = _label(order,"",15,CafeStyle.CREAM)
	journey.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journey.max_lines_visible = 2
	clock = _label(row,"",18,CafeStyle.GOLD)
	var office_button := Button.new()
	row.add_child(office_button)
	office_button.text = "Кафе"
	office_button.hide()
	office_button.pressed.connect(func(): office_requested.emit())
	progress = ProgressBar.new()
	order.add_child(progress)
	progress.hide()
	event_feed_panel=_panel(root)
	event_feed_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	event_feed_panel.offset_left=26
	event_feed_panel.offset_right=560
	event_feed_panel.offset_top=164
	event_feed_panel.offset_bottom=270
	event_feed_text=_label(event_feed_panel,"",14,CafeStyle.CREAM)
	event_feed_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	event_feed_text.max_lines_visible=4
	event_feed_panel.hide()
	recipe_panel = _panel(root)
	recipe_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	recipe_panel.offset_left = -346
	recipe_panel.offset_right = -26
	recipe_panel.offset_top = 164
	recipe_panel.offset_bottom = 164
	recipe_panel.custom_minimum_size = Vector2(320, 0)
	recipe_scroll = ScrollContainer.new()
	recipe_panel.add_child(recipe_scroll)
	recipe_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	recipe_scroll.custom_minimum_size = Vector2(300, 0)
	recipe_content = VBoxContainer.new()
	recipe_scroll.add_child(recipe_content)
	recipe_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_content.add_theme_constant_override("separation", 8)
	recipe_text = Label.new()
	root.add_child(recipe_text)
	recipe_text.hide()
	recipe_panel.hide()
	bottom = _panel(root)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 120
	bottom.offset_right = -120
	bottom.offset_top = -90
	bottom.offset_bottom = -16
	var column := VBoxContainer.new()
	bottom.add_child(column)
	controls = _label(column,"",16)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	supplies = _label(column,"",14,CafeStyle.MINT)
	supplies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice = _label(root,"",16,CafeStyle.GOLD)
	notice.hide()
	crosshair = _label(root,"·",32)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -8
	crosshair.offset_top = -22
	prompt = _label(root,"",17)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.offset_left = -410
	prompt.offset_right = 410
	prompt.offset_top = 42
	prompt.offset_bottom = 80
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_constant_override("outline_size",5)
	prompt.add_theme_color_override("font_outline_color",CafeStyle.INK)
	visit_status = _label(root,"",15,CafeStyle.MINT)
	visit_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	visit_status.offset_left=130; visit_status.offset_right=-130
	visit_status.offset_top=-122; visit_status.offset_bottom=-96
	visit_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast = _label(root,"",24,CafeStyle.GOLD)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -390
	toast.offset_right = 390
	toast.offset_top = -155
	toast.offset_bottom = -112
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size",6)
	toast.add_theme_color_override("font_outline_color",CafeStyle.INK)
	toast.modulate.a = 0
	pause_panel = _panel(root)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -240
	pause_panel.offset_right = 240
	pause_panel.offset_top = -120
	pause_panel.offset_bottom = 120
	var pause := VBoxContainer.new()
	pause_panel.add_child(pause)
	pause.add_theme_constant_override("separation",20)
	_label(pause,"Небольшой перерыв",26,CafeStyle.GOLD)
	_label(pause,"Кофе подождёт.",18)
	var resume := Button.new()
	pause.add_child(resume)
	resume.text = "Вернуться в кафе"
	resume.pressed.connect(func(): resume_requested.emit())
	pause_panel.hide()

func show_chef_request(order: Dictionary) -> void:
	var text: String = preload("res://scripts/chef_orders.gd").special_request(order)
	recipe_panel.visible = not text.is_empty()
	if text.is_empty() or text == recipe_stamp: return
	recipe_stamp = text
	for child in recipe_content.get_children(): recipe_content.remove_child(child); child.queue_free()
	_label(recipe_content, "Пожелание гостя", 14, CafeStyle.GOLD)
	var label := _label(recipe_content, text, 19)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 268
	recipe_scroll.custom_minimum_size.y = 90

func recipe_panel_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for child in recipe_content.get_children():
		if child is Label: parts.append(child.text)
		elif child is HBoxContainer:
			for nested in child.get_children():
				if nested is Label: parts.append(nested.text)
	return " ".join(parts)

func set_event_feed(lines: Array) -> void:
	if lines.is_empty():
		event_feed_panel.hide()
		return
	event_feed_text.text="\n".join(lines)
	event_feed_panel.show()

func show_toast(message: String) -> void:
	if toast_tween != null: toast_tween.kill()
	toast.text = message
	toast.modulate.a = 1
	toast_tween = create_tween()
	toast_tween.tween_interval(1.5)
	toast_tween.tween_property(toast,"modulate:a",0.0,0.5)

func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := CafeStyle.box(Color(0.055,0.115,0.12,0.92),16,16)
	style.border_color = Color(0.8,0.72,0.5,0.18)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	return panel

func _label(parent: Node, value: String, size: int, color := CafeStyle.CREAM) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label
