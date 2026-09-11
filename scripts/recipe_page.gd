extends Control
const CafeStyle = preload("res://scripts/cafe_theme.gd")
const Data = preload("res://scripts/cookbook_data.gd")
signal chosen(page)
signal closed
var column: VBoxContainer
var note: Label
var stamp := ""

func _ready() -> void:
	theme = CafeStyle.make(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := ColorRect.new()
	add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.color = Color("f3e6c8") if name.ends_with("L") else Color("f8efd6")
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	var hold := VBoxContainer.new()
	margin.add_child(hold)
	hold.add_theme_constant_override("separation", 8)
	column = VBoxContainer.new()
	hold.add_child(column)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	note = Label.new()
	hold.add_child(note)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 26)
	note.add_theme_color_override("font_color", Color("5a6b62"))
	note.custom_minimum_size = Vector2(560, 72)

func show_page(page: String, model = null) -> void:
	var key := "%s:%s" % [page, JSON.stringify(Data.components(page, model)) if page != "index" else "index"]
	if key == stamp: return
	stamp = key
	for child in column.get_children(): column.remove_child(child); child.queue_free()
	note.text = ""
	if name.ends_with("L"): _left(page, model)
	else: _right(page, model)

func find_button(text: String) -> Button:
	for child in column.get_children():
		if child is Button and str(child.text) == text: return child
	for child in column.get_children():
		if child is Button and str(child.text).contains(text): return child
	return null

func _left(page: String, _model) -> void:
	_label("SLAPDASH / КУХОННЫЕ ЗАМЕТКИ", 16, Color("6d7f78"))
	if page == "index":
		_label("Поварская книга", 44)
		_button("Закрыть", closed.emit, 30, 64)
	else:
		_label(Data.title(page), 44)
		var art := TextureRect.new()
		column.add_child(art)
		art.texture = Data.ICONS[page]
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(180, 110)
		_button("Содержание", chosen.emit.bind("index"), 30, 64)
		_button("Закрыть", closed.emit, 30, 64)

func _right(page: String, model) -> void:
	if page == "index":
		_label("Сегодня в меню", 28)
		for key in Data.ORDER:
			var entry := _button(Data.title(key), chosen.emit.bind(key), 34, 76)
			entry.icon = Data.ICONS[key]
			entry.expand_icon = true
			entry.add_theme_constant_override("icon_max_width", 48)
			entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		_label("Что должно получиться", 28)
		for component in Data.components(page, model):
			var head := HBoxContainer.new()
			column.add_child(head)
			head.add_theme_constant_override("separation", 10)
			head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var mark := Label.new()
			head.add_child(mark)
			mark.text = "✓" if component.served else "○"
			mark.add_theme_font_size_override("font_size", 42)
			mark.add_theme_color_override("font_color", Color("3d8f74") if component.served else Color("8a9690"))
			var title := Label.new()
			head.add_child(title)
			title.text = component.name
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.add_theme_font_size_override("font_size", 42)
			title.add_theme_color_override("font_color", CafeStyle.INK)
			for i in range(component.lines.size()):
				var row := _label(component.lines[i], 38)
				row.mouse_filter = Control.MOUSE_FILTER_STOP
				row.mouse_entered.connect(func(): note.text = component.details[i])
				row.mouse_exited.connect(func(): if note.text == component.details[i]: note.text = "")

func _label(text: String, size := 38, color := CafeStyle.INK) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = 560
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	column.add_child(node)
	return node

func _button(text: String, callback: Callable, font := 30, height := 64) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(callback)
	node.add_theme_font_size_override("font_size", font)
	node.custom_minimum_size.y = height
	node.clip_text = true
	column.add_child(node)
	return node
