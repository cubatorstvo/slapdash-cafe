extends CanvasLayer
## FPS overlay and explicit teaching selection.
signal resume_requested
signal training_requested(dish: String, clone_id: int, slot: int)
signal teaching_closed
var teaching_panel: PanelContainer
var dish_choice: OptionButton
var clone_choice: OptionButton
var slot_choice: OptionButton
var recipe_description: Label
var roster: Array = []
var assignments: Array = []
const Model = preload("res://scripts/cooking_model.gd")
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
	_label(timing, "Fast <15с   Medium ≤60с   Slow >60с", 14)
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
	notice = _label(column, "Подойди к золотой стойке и нажми E. Клон напротив учится твоим движениям.", 16, Color("f2c578"))
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
	_build_teaching_menu(root)

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

func _build_teaching_menu(root: Control) -> void:
	teaching_panel = _panel(root)
	teaching_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	teaching_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	teaching_panel.offset_left = -360
	teaching_panel.offset_right = 360
	teaching_panel.offset_top = -250
	teaching_panel.offset_bottom = 250
	var content := VBoxContainer.new()
	teaching_panel.add_child(content)
	content.add_theme_constant_override("separation", 12)
	_label(content, "ПОКАЖИ КАК", 28, Color("f2c578"))
	_label(content, "Выбери сотрудника, блюдо и его рабочую стойку.", 18)
	clone_choice = OptionButton.new()
	content.add_child(clone_choice)
	clone_choice.custom_minimum_size.y = 42
	dish_choice = OptionButton.new()
	content.add_child(dish_choice)
	dish_choice.custom_minimum_size.y = 42
	slot_choice = OptionButton.new()
	content.add_child(slot_choice)
	for index in range(3): slot_choice.add_item("Рабочая стойка %d" % (index + 1))
	recipe_description = _label(content, "", 17)
	recipe_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recipe_description.custom_minimum_size = Vector2(660, 130)
	var start := Button.new()
	content.add_child(start)
	start.text = "Начать показ"
	start.custom_minimum_size.y = 45
	start.pressed.connect(func(): training_requested.emit(Model.DISHES.keys()[dish_choice.selected], int(roster[clone_choice.selected].id), slot_choice.selected))
	var close := Button.new()
	content.add_child(close)
	close.text = "Назад · Esc"
	close.pressed.connect(func(): teaching_closed.emit())
	clone_choice.item_selected.connect(_select_clone)
	dish_choice.item_selected.connect(func(_index): _describe_recipe())
	teaching_panel.hide()

func show_teaching(clones: Array, assigned: Array, selected_id: int, recipe: String) -> void:
	roster = clones
	assignments = assigned
	clone_choice.clear()
	var selection := 0
	for index in range(clones.size()):
		clone_choice.add_item("%s — знает блюд: %d/3" % [clones[index].name, clones[index].get("known", clones[index].recipes.keys()).size()])
		if clones[index].id == selected_id: selection = index
	clone_choice.select(selection)
	dish_choice.clear()
	for key in Model.DISHES: dish_choice.add_item(Model.DISHES[key])
	dish_choice.select(maxi(0, Model.DISHES.keys().find(recipe)))
	_select_clone(selection)
	teaching_panel.show()

func _select_clone(index: int) -> void:
	var slot := assignments.find(int(roster[index].id))
	if slot < 0: slot = assignments.find(-1)
	slot_choice.select(maxi(0, slot))
	_describe_recipe()

func _describe_recipe() -> void:
	var recipe: String = Model.DISHES.keys()[dish_choice.selected]
	var clone: Dictionary = roster[clone_choice.selected]
	var status := "Этому блюду клон ещё не обучен."
	if clone.recipes.has(recipe):
		var duration: float = clone.recipes[recipe].duration
		status = "Есть запись: %s · %.1f с. Успешный показ заменит её." % [Model.pace(duration), duration]
	var instructions := {
		"wine": "Наполни стакан до 225 мл. Кувшин или тряпка — способ выбираешь ты.",
		"potato": "ЛКМ — взять сковороду. ПКМ + мышь — наклонять. Обжарь 6 сторон, затем положи картошку на тарелку. Упавшую можно поднять и вернуть.",
		"sausage": "Обмакни сосиску в соус и положи на тарелку. ПКМ держит её вертикально. Резкое движение плашмя грозит побегом; у стола её можно катить."}
	recipe_description.text = status + "\n\n" + instructions[recipe] + "\n\nВыбранная стойка прервёт обслуживание на время показа."
