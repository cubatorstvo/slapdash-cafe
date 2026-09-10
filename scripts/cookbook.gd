extends CanvasLayer
const CafeStyle = preload("res://scripts/cafe_theme.gd")
const Data = preload("res://scripts/cookbook_data.gd")
signal changed
var opened := false
var recipe := "index"
var book: PanelContainer
var left: VBoxContainer
var right: VBoxContainer
var physical: Node3D
var game: Node3D

func _ready() -> void:
	layer = 12
	book = PanelContainer.new()
	add_child(book)
	book.theme = CafeStyle.make(true)
	book.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	book.offset_left = -490
	book.offset_right = 490
	book.offset_top = -285
	book.offset_bottom = 265
	var cover := CafeStyle.box(Color("924d42"), 18, 12)
	cover.shadow_color = Color(0,0,0,0.45)
	cover.shadow_size = 20
	book.add_theme_stylebox_override("panel", cover)
	var spread := HBoxContainer.new()
	book.add_child(spread)
	spread.add_theme_constant_override("separation", 3)
	for side in range(2):
		var paper := PanelContainer.new()
		spread.add_child(paper)
		paper.custom_minimum_size.x = 475
		paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		paper.add_theme_stylebox_override("panel", CafeStyle.box(Color("f1e5c9") if side == 0 else Color("f8efd9"), 8, 28))
		var col := VBoxContainer.new()
		paper.add_child(col)
		col.add_theme_constant_override("separation", 12)
		if side == 0: left = col
		else: right = col
	book.hide()

func attach(owner_game: Node3D) -> void:
	game = owner_game
	physical = preload("res://scripts/book_prop.gd").new()
	game.camera.add_child(physical)
	physical.position = Vector3(0, -0.48, -0.8)
	physical.rotation.x = 0.18
	for side in [-1,1]:
		preload("res://scripts/props.gd").ball(physical, 0.07, Vector3(side*0.49, 0.01, 0.18), Color("e8b893"))

func toggle() -> void:
	if opened: close(); return
	var station: Node3D = game.local_station()
	if station != null and station.training.phase == "recording":
		recipe = station.training.dish
		game.session.send_input(station, {}, {"drop": true})
	else: recipe = "index"
	opened = true
	book.show()
	rebuild()
	physical.set_reading(true, recipe)
	changed.emit()
	game.sync_mouse_mode()

func close() -> void:
	if not opened: return
	opened = false
	book.hide()
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
	parent.add_child(node)
	return node

func button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func rebuild() -> void:
	for col in [left,right]:
		for child in col.get_children(): col.remove_child(child); child.queue_free()
	label(left, "SLAPDASH  /  КУХОННЫЕ ЗАМЕТКИ", 14)
	label(left, "Поварская\nкнига" if recipe == "index" else Data.Definition.DISHES[recipe], 32)
	if recipe == "index":
		label(left, "Хорошая еда.\nСомнительные методы.", 22)
		label(left, "Выбери блюдо справа.\nСпособ приготовления — за тобой.", 18)
		label(right, "Сегодня в меню", 26)
		for key in Data.ICONS:
			var entry := button(right, Data.Definition.DISHES[key], select.bind(key))
			entry.icon = Data.ICONS[key]
			entry.expand_icon = true
			entry.add_theme_constant_override("icon_max_width", 44)
			entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		var art := TextureRect.new()
		left.add_child(art)
		art.texture = Data.ICONS[recipe]
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(200,180)
		button(left, "← Все блюда", select.bind("index"))
		label(right, "Что должно получиться", 25)
		for note in Data.NOTES[recipe]:
			var line := label(right, "•  " + note[0], 18)
			line.mouse_filter = Control.MOUSE_FILTER_STOP
			line.tooltip_text = note[1]
		label(right, "Наведи на требование, чтобы узнать подробности.", 14)
	var spacer := Control.new()
	left.add_child(spacer)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button(left, "Закрыть книгу   ·   B / Esc", close)
	var help := label(right, "B — книга · ЛКМ — взять / положить\nПКМ — действие · Колесо — высота\nShift + мышь — точное движение\nЗвонок на стойке — закончить показ", 15)
	help.tooltip_text = "Книга занимает обе руки. Во время показа чтение тоже запоминается бригадой."
