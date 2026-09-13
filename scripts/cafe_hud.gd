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
	top.offset_bottom = 92
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
	clock = _label(row,"",18,CafeStyle.GOLD)
	var office_button := Button.new()
	row.add_child(office_button)
	office_button.text = "Кафе"
	office_button.hide()
	office_button.pressed.connect(func(): office_requested.emit())
	progress = ProgressBar.new()
	order.add_child(progress)
	progress.hide()
	recipe_panel = _panel(root)
	recipe_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	recipe_panel.offset_left = -346
	recipe_panel.offset_right = -26
	recipe_panel.offset_top = 110
	recipe_panel.offset_bottom = 110
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

func show_recipe(report: Dictionary, dish: String) -> void:
	show_production_recipe(report, dish, 0.0)

func show_production_recipe(report: Dictionary, dish: String, duration: float) -> void:
	recipe_panel.show()
	var stamp := "%s:%s:%.3f" % [dish, JSON.stringify([report.get("components",[]),report.grade,report.get("style_count",0),report.get("order",{})]), duration]
	if stamp == recipe_stamp: return
	recipe_stamp = stamp
	for child in recipe_content.get_children(): recipe_content.remove_child(child); child.queue_free()
	var heading := HBoxContainer.new()
	recipe_content.add_child(heading)
	var icon := TextureRect.new()
	heading.add_child(icon)
	icon.texture = Data.ICONS[dish]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(42,42)
	var name := _label(heading, Data.title(dish), 14, CafeStyle.GOLD)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grade := _label(heading, str(report.get("grade", "")), 30, CafeStyle.MINT if str(report.get("grade", "")) in ["S","A"] else CafeStyle.GOLD)
	grade.tooltip_text = "Оценка лучшей поданной или съеденной порции"
	grade.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(recipe_content, "Запись клона · %.1f с" % duration if duration>0 else "Текущий заказ · "+str(report.get("order",{}).get("title","Стандартный рецепт")), 14, CafeStyle.GOLD)
	if report.get("style_count", 0) > 0:
		_label(recipe_content, "Ловкая подача · +20%", 15, CafeStyle.GOLD)
	for component in report.get("components", []):
		_label(recipe_content, ("✓  " if component.served else "○  ") + component.name, 18, CafeStyle.MINT if component.served else CafeStyle.CREAM)
		for line in component.lines:
			var detail := _label(recipe_content, str(line), 14, Color("c5d2c8"))
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size.x = 268
		_label(recipe_content, "", 2)
	recipe_scroll.custom_minimum_size.y = mini(recipe_content.get_combined_minimum_size().y + 8, 360)

func recipe_panel_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for child in recipe_content.get_children():
		if child is Label: parts.append(child.text)
		elif child is HBoxContainer:
			for nested in child.get_children():
				if nested is Label: parts.append(nested.text)
	return " ".join(parts)

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
