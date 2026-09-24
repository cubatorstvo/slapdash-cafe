extends Control
const CafeStyle = preload("res://scripts/cafe_theme.gd")
const Data = preload("res://scripts/cookbook_data.gd")
signal chosen(page)
signal closed
var column: VBoxContainer
var note: Label
var stamp := ""
var allowed_pages: Array = Data.ORDER.duplicate()
var page_side := 0

func configure(side: int) -> void:
	page_side = -1 if side < 0 else 1

func _ready() -> void:
	theme = CafeStyle.make(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := get_node("Paper") as ColorRect
	paper.color = Color("f3e6c8") if page_side < 0 else Color("f8efd6")
	column = get_node("Margin/Hold/Column") as VBoxContainer
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	note = get_node("Margin/Hold/Note") as Label
	note.add_theme_color_override("font_color", Color("5a6b62"))
	note.add_theme_font_size_override("font_size", 22)

func set_allowed_pages(values: Array) -> void:
	var next := values.duplicate()
	if next == allowed_pages: return
	allowed_pages = next
	stamp = ""

func show_page(page: String, model = null) -> void:
	var safe_page := page if page == "index" or page in allowed_pages else "index"
	var key := "%s:%s:%s:%d" % [safe_page, JSON.stringify(Data.components(safe_page, model)) if safe_page != "index" else "index", str(allowed_pages), page_side]
	if key == stamp: return
	stamp = key
	for child in column.get_children(): column.remove_child(child); child.queue_free()
	note.text = ""
	if page_side < 0: _left(safe_page, model)
	else: _right(safe_page, model)

func find_button(text: String) -> Button:
	for child in column.get_children():
		if child is Button and str(child.text) == text: return child
	for child in column.get_children():
		if child is Button and str(child.text).contains(text): return child
	return null

func _left(page: String, model) -> void:
	_label("SLAPDASH / КУХОННЫЕ ЗАМЕТКИ", 16, Color("6d7f78"))
	if page == "index":
		_label("Поварская книга", 42)
		_label("Открыто рецептов: %d" % allowed_pages.size(), 24, Color("6d7f78"))
		_button("Закрыть", closed.emit, 28, 58)
		return
	_label(Data.title(page), 40)
	var art := TextureRect.new()
	column.add_child(art)
	art.texture = Data.ICONS[page]
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(150, 84)
	var parts := _side_components(page, model, -1)
	if not parts.is_empty():
		_label("Компоненты", 24, Color("6d7f78"))
		for component in parts: _component(component)
	_nav()

func _right(page: String, model) -> void:
	if page == "index":
		_label("Сегодня в меню", 28)
		for key in allowed_pages:
			var entry := _button(Data.title(key), chosen.emit.bind(key), 31, 68)
			entry.icon = Data.ICONS[key]
			entry.expand_icon = true
			entry.add_theme_constant_override("icon_max_width", 44)
			entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		return
	_label("Что должно получиться", 26)
	var parts := _side_components(page, model, 1)
	for component in parts: _component(component)
	_nav()

func _side_components(page: String, model, side: int) -> Array:
	var components: Array = Data.components(page, model)
	if components.size() <= 1: return [] if side < 0 else components
	var split := int(ceili(float(components.size()) / 2.0))
	return components.slice(0, split) if side < 0 else components.slice(split, components.size())

func _component(component: Dictionary) -> void:
	var head := HBoxContainer.new()
	column.add_child(head)
	head.add_theme_constant_override("separation", 8)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mark := Label.new()
	head.add_child(mark)
	mark.text = "✓" if bool(component.get("served", false)) else "○"
	mark.add_theme_font_size_override("font_size", 34)
	mark.add_theme_color_override("font_color", Color("3d8f74") if bool(component.get("served", false)) else Color("8a9690"))
	var title := Label.new()
	head.add_child(title)
	title.text = str(component.get("name", "Компонент"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", CafeStyle.INK)
	var lines: Array = component.get("lines", [])
	var details: Array = component.get("details", [])
	for i in range(lines.size()):
		var row := _label(str(lines[i]), 29)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var detail := str(details[i]) if i < details.size() else ""
		row.mouse_entered.connect(func(): note.text = detail)
		row.mouse_exited.connect(func():
			if note.text == detail: note.text = ""
		)

func _nav() -> void:
	_button("Содержание", chosen.emit.bind("index"), 26, 54)
	_button("Закрыть", closed.emit, 26, 54)

func _label(text: String, size := 32, color := CafeStyle.INK) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = 560
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	column.add_child(node)
	return node

func _button(text: String, callback: Callable, font := 28, height := 58) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(callback)
	node.add_theme_font_size_override("font_size", font)
	node.custom_minimum_size.y = height
	node.clip_text = true
	column.add_child(node)
	return node
