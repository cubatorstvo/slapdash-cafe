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
var equipment_warning: Label
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
	var root := get_node("Root") as Control
	root.theme = CafeStyle.make()
	goal = get_node("Root/Top/Row/Order/Goal") as Label
	clone_status = get_node("Root/Top/Row/Order/CloneStatus") as Label
	clone_status.add_theme_color_override("font_color", CafeStyle.MINT)
	equipment_warning = get_node("Root/Top/Row/Order/EquipmentWarning") as Label
	equipment_warning.add_theme_color_override("font_color", Color("f0b06b"))
	journey = get_node("Root/Top/Row/Order/Journey") as Label
	journey.add_theme_color_override("font_color", CafeStyle.CREAM)
	clock = get_node("Root/Top/Row/Clock") as Label
	clock.add_theme_color_override("font_color", CafeStyle.GOLD)
	var office_button := get_node("Root/Top/Row/CafeButton") as Button
	office_button.pressed.connect(func(): office_requested.emit())
	progress = get_node("Root/Top/Row/Order/Progress") as ProgressBar
	event_feed_panel = get_node("Root/EventFeed") as PanelContainer
	event_feed_text = get_node("Root/EventFeed/Text") as Label
	event_feed_text.add_theme_color_override("font_color", CafeStyle.CREAM)
	recipe_panel = get_node("Root/RecipePanel") as PanelContainer
	recipe_scroll = get_node("Root/RecipePanel/Scroll") as ScrollContainer
	recipe_content = get_node("Root/RecipePanel/Scroll/Content") as VBoxContainer
	recipe_text = get_node("Root/RecipeText") as Label
	bottom = get_node("Root/Bottom") as PanelContainer
	controls = get_node("Root/Bottom/Column/Controls") as Label
	supplies = get_node("Root/Bottom/Column/Supplies") as Label
	supplies.add_theme_color_override("font_color", CafeStyle.MINT)
	notice = get_node("Root/Notice") as Label
	notice.add_theme_color_override("font_color", CafeStyle.GOLD)
	crosshair = get_node("Root/Crosshair") as Label
	prompt = get_node("Root/Prompt") as Label
	prompt.add_theme_constant_override("outline_size", 5)
	prompt.add_theme_color_override("font_outline_color", CafeStyle.INK)
	visit_status = get_node("Root/VisitStatus") as Label
	visit_status.add_theme_color_override("font_color", CafeStyle.MINT)
	toast = get_node("Root/Toast") as Label
	toast.add_theme_color_override("font_color", CafeStyle.GOLD)
	toast.add_theme_constant_override("outline_size", 6)
	toast.add_theme_color_override("font_outline_color", CafeStyle.INK)
	pause_panel = get_node("Root/PausePanel") as PanelContainer
	var resume := get_node("Root/PausePanel/Pause/Resume") as Button
	resume.pressed.connect(func(): resume_requested.emit())

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

func _label(parent: Node, value: String, size: int, color := CafeStyle.CREAM) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label
