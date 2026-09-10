extends CanvasLayer
const CafeStyle = preload("res://scripts/cafe_theme.gd")
const Data = preload("res://scripts/cookbook_data.gd")
signal changed
var opened := false
var recipe := "index"
var overlay: ColorRect
var book: PanelContainer
var left_grip: Control
var right_grip: Control
var left: VBoxContainer
var right: VBoxContainer
var physical: Node3D
var game: Node3D

func _ready() -> void:
	layer = 12
	overlay = ColorRect.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.09, 0.1, 0.35)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.hide()
	left_grip = _grip(false)
	right_grip = _grip(true)
	book = PanelContainer.new()
	add_child(book)
	book.theme = CafeStyle.make(true)
	book.set_anchors_preset(Control.PRESET_CENTER)
	book.anchor_left = 0.5
	book.anchor_right = 0.5
	book.anchor_top = 0.5
	book.anchor_bottom = 0.5
	_layout_book()
	book.mouse_filter = Control.MOUSE_FILTER_STOP
	var cover := CafeStyle.box(Color("7a3d38"), 18, 10)
	cover.shadow_color = Color(0, 0, 0, 0.45)
	cover.shadow_size = 18
	cover.border_color = Color("d7a45a")
	cover.set_border_width_all(2)
	book.add_theme_stylebox_override("panel", cover)
	var spread := HBoxContainer.new()
	book.add_child(spread)
	spread.add_theme_constant_override("separation", 4)
	for side in range(2):
		var paper := PanelContainer.new()
		spread.add_child(paper)
		paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
		paper.add_theme_stylebox_override("panel", CafeStyle.box(Color("f3e6c8") if side == 0 else Color("f8efd6"), 8, 22))
		var scroll := ScrollContainer.new()
		paper.add_child(scroll)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var col := VBoxContainer.new()
		scroll.add_child(col)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 10)
		if side == 0: left = col
		else: right = col
	book.hide()
	get_viewport().size_changed.connect(_layout_book)

func _grip(flip: bool) -> Control:
	var grip := Control.new()
	add_child(grip)
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip.set_anchors_preset(Control.PRESET_CENTER)
	grip.z_index = 1
	var palm := _shade(grip, Color("e8b893"), 26)
	palm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palm.offset_left = 8
	palm.offset_right = -6
	palm.offset_top = 28
	palm.offset_bottom = -4
	for i in range(4):
		var finger := _shade(grip, Color("e0ad86"), 10)
		finger.anchor_left = 0.12 + i * 0.20
		finger.anchor_right = 0.28 + i * 0.20
		finger.anchor_top = 0.04
		finger.anchor_bottom = 0.46
		finger.offset_left = 0
		finger.offset_right = 0
		finger.offset_top = 0
		finger.offset_bottom = 0
	if flip: grip.scale = Vector2(-1, 1)
	grip.hide()
	return grip

func _shade(parent: Control, color: Color, radius: int) -> Panel:
	var panel := Panel.new()
	parent.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.82)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.12, 0.06, 0.04, 0.28)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _layout_book() -> void:
	var view := get_viewport().get_visible_rect().size
	var width: float = clampf(view.x * 0.78, 720, 1040)
	var height: float = clampf(view.y * 0.68, 430, 620)
	book.offset_left = -width * 0.5
	book.offset_right = width * 0.5
	book.offset_top = -height * 0.5
	book.offset_bottom = height * 0.5
	var hand_w: float = clampf(width * 0.11, 72, 110)
	var hand_h: float = clampf(height * 0.18, 78, 120)
	for grip in [left_grip, right_grip]:
		if grip == null: continue
		grip.offset_top = book.offset_bottom - hand_h * 0.45
		grip.offset_bottom = grip.offset_top + hand_h
		grip.pivot_offset = Vector2(hand_w * 0.5, hand_h * 0.5)
	left_grip.offset_left = book.offset_left - hand_w * 0.55
	left_grip.offset_right = left_grip.offset_left + hand_w
	right_grip.offset_left = book.offset_right - hand_w * 0.45
	right_grip.offset_right = right_grip.offset_left + hand_w

func attach(owner_game: Node3D) -> void:
	game = owner_game
	physical = preload("res://scripts/book_prop.gd").new()
	game.camera.add_child(physical)
	physical.pose_in_hands(true)

func toggle() -> void:
	if opened: close(); return
	var station: Node3D = game.local_station()
	if station != null and station.training.phase == "recording":
		recipe = station.training.dish
		game.session.send_input(station, {}, {"drop": true})
	else: recipe = "index"
	opened = true
	overlay.show()
	book.show()
	left_grip.show()
	right_grip.show()
	_layout_book()
	rebuild()
	physical.set_reading(true, recipe)
	changed.emit()
	game.sync_mouse_mode()

func close() -> void:
	if not opened: return
	opened = false
	overlay.hide()
	book.hide()
	left_grip.hide()
	right_grip.hide()
	physical.set_reading(false, recipe)
	changed.emit()
	game.sync_mouse_mode()

func select(value: String) -> void:
	recipe = Data.page(value)
	rebuild()
	physical.set_reading(true, recipe)
	changed.emit()

func label(parent: Node, text: String, size := 18) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", CafeStyle.INK)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

func button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func rebuild() -> void:
	for col in [left, right]:
		for child in col.get_children(): col.remove_child(child); child.queue_free()
	label(left, "SLAPDASH  /  КУХОННЫЕ ЗАМЕТКИ", 13)
	label(left, "Поварская книга" if recipe == "index" else Data.Definition.DISHES[recipe], 30)
	if recipe == "index":
		label(left, "Хорошая еда.\nСомнительные методы.", 20)
		label(left, "Выбери блюдо справа. Способ приготовления — за тобой.", 17)
		label(right, "Сегодня в меню", 24)
		for key in Data.ICONS:
			var entry := button(right, Data.Definition.DISHES[key], select.bind(key))
			entry.icon = Data.ICONS[key]
			entry.expand_icon = true
			entry.add_theme_constant_override("icon_max_width", 48)
			entry.custom_minimum_size.y = 52
			entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		var art := TextureRect.new()
		left.add_child(art)
		art.texture = Data.ICONS[recipe]
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(180, 160)
		button(left, "← Все блюда", select.bind("index"))
		label(right, "Что должно получиться", 23)
		for note in Data.NOTES[recipe]:
			var line := label(right, "•  " + note[0], 17)
			line.mouse_filter = Control.MOUSE_FILTER_STOP
			line.tooltip_text = note[1]
		label(right, "Наведи на требование, чтобы узнать подробности.", 13)
	var spacer := Control.new()
	left.add_child(spacer)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button(left, "Закрыть книгу   ·   B / Esc", close)
	var help := label(right, "B — книга · ЛКМ — взять / положить\nПКМ — действие · Колесо — высота\nShift + мышь — точное движение\nЗвонок на стойке — закончить показ", 14)
	help.tooltip_text = "Книга занимает обе руки. Во время показа чтение тоже запоминается бригадой."
