extends CanvasLayer
const CafeStyle = preload("res://scripts/cafe_theme.gd")
signal command_requested(action: Dictionary)
signal network_requested(action: String, address: String, port: int, player_name: String)
signal steam_requested(action: String)
signal closed
var panel: PanelContainer
var net_panel: PanelContainer
var training_box: VBoxContainer
var selected_station := 0
var recipe_choice: OptionButton
var assignments: Array = []
var summary_text: Label
var game: Node3D
var net_status: Label
var address: LineEdit
var player_name: LineEdit
var port: SpinBox

func _ready() -> void:
	layer = 15
	panel = _panel(760, 620)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	training_box = _column(scroll)
	training_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.hide()
	var box: VBoxContainer
	net_panel = _panel(620, 650)
	box = _column(net_panel)
	_label(box, "ИГРАТЬ С ДРУЗЬЯМИ", 23)
	_button(box, "Пригласить друга через Steam", func(): steam_requested.emit("invite"))
	_button(box, "Создать Steam-кафе", func(): steam_requested.emit("host"))
	_label(box, "Shift+Tab → друзья → пригласить в игру", 17)
	_label(box, "Прямое подключение по IP (для локальной проверки)", 15)
	player_name = LineEdit.new()
	player_name.text = "Повар"
	player_name.placeholder_text = "Имя игрока"
	box.add_child(player_name)
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "IP хоста"
	box.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = 27666
	box.add_child(port)
	_button(box, "Создать сессию", func(): network_requested.emit("host", address.text, int(port.value), player_name.text))
	_button(box, "Подключиться", func(): network_requested.emit("join", address.text, int(port.value), player_name.text))
	_button(box, "Отключиться", func(): network_requested.emit("leave", "", 0, ""))
	net_status = _label(box, "Steam: проверяю подключение…")
	net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_status.custom_minimum_size = Vector2(540, 62)
	_button(box, "Вернуться в кафе", close)
	net_panel.hide()

func _panel(width: float, height: float) -> PanelContainer:
	var result := PanelContainer.new()
	add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result.offset_left = -width / 2
	result.offset_right = width / 2
	result.offset_top = -height / 2
	result.offset_bottom = height / 2
	result.theme = CafeStyle.make()
	var style := CafeStyle.box(Color("213b3c"), 20, 24)
	style.bg_color = Color("203b43")
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	result.add_theme_stylebox_override("panel", style)
	return result

func _column(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	parent.add_child(box)
	return box

func _label(parent: Control, value: String, size := 17) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Control, value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 42
	button.pressed.connect(func():
		if game != null and is_instance_valid(game.feedback): game.feedback.play_ui("click")
		callback.call())
	parent.add_child(button)

func close() -> void:
	panel.hide()
	net_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func opened() -> bool: return panel.visible or net_panel.visible

func rebuild() -> void:
	for child in training_box.get_children():
		training_box.remove_child(child)
		child.queue_free()
	assignments.clear()

func show_station(station: Node3D) -> void:
	selected_station = station.station_id
	rebuild()
	if not station.ready_crew():
		_label(training_box,"Нет бригады: %d/%d. Создай клонов в лаборатории."%[station.staffed,station.role_count()],22)
		_button(training_box,"Вернуться",close)
		panel.show(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		return
	var run = station.training
	var showcase: bool = game.service.is_showcase(station)
	_label(training_box, "СТАНЦИЯ %d · %s" % [station.station_id, station.Definition.TYPES[station.type_id].title], 23)
	var names := PackedStringArray()
	for member in station.crew: names.append(member.name)
	if not station.manual_station: _label(training_box, "Бригада: " + ", ".join(names) if station.ready_crew() else "Нужны клоны: %d/%d · создай в лаборатории"%[station.staffed,station.role_count()], 16)
	if station.manual_station and not run.active():
		var dish: String = game.service.manual_order(station)
		_label(training_box, "Твоя стойка · готовь лично", 23)
		if dish.is_empty():
			_label(training_box, "Заказов пока нет. Можно потренироваться бесплатно.")
			for recipe in station.dishes():
				var key: String = recipe
				_button(training_box, station.Definition.DISHES[key], func(): command_requested.emit({"action": "manual", "station": selected_station, "dish": key}))
		else:
			_label(training_box, station.Definition.DISHES[dish], 20)
			if not station.customer_order.is_empty():
				_label(training_box, preload("res://scripts/chef_orders.gd").requirements(station.customer_order))
				_label(training_box, "Оплата ×%.1f"%float(station.customer_order.get("premium",1)),16)
			_button(training_box, "Приготовить заказ", func(): command_requested.emit({"action": "manual", "station": selected_station, "dish": dish}))
		_button(training_box, "Вернуться", close)
		panel.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if not run.active():
		recipe_choice = OptionButton.new()
		training_box.add_child(recipe_choice)
		for dish in station.dishes(): recipe_choice.add_item(station.Definition.DISHES[dish])
		summary_text = _label(training_box, "")
		summary_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_text.custom_minimum_size = Vector2(680, 90)
		recipe_choice.item_selected.connect(func(_i): describe(station))
		describe(station)
		_button(training_box, "Обучить здесь", func(): command_requested.emit({"action": "open", "station": selected_station, "dish": station.dishes()[recipe_choice.selected]}))
	else:
		_label(training_box, station.Definition.DISHES[run.dish], 20)
		var report: Dictionary = station.model.quality()
		_label(training_box, "Качество блюда: %s" % report.grade, 17)
		if report.get("style_count", 0) > 0: _label(training_box, "Ловкая подача · эффектность +20%", 17)
		if run.phase == "review":
			var details := PackedStringArray()
			for criterion in report.criteria: details.append(criterion.label)
			var criteria_label := _label(training_box, " · ".join(details), 15)
			criteria_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var information := _label(training_box, run.info, 16)
		information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if run.lead != game.session.local_id():
			_label(training_box, "Показом управляет другой игрок.")
		elif run.phase == "confirm_finish":
			_button(training_box, "Продолжить готовку · положить на подачу", func(): send("resume"))
			_button(training_box, "Подать как есть", func(): send("confirm_finish"))
		elif run.phase == "review":
			_label(training_box, "Показ: %.1f с." % (run.tick / 60.0))
			_button(training_box, "Сохранить показ", func(): send("keep"))
			_button(training_box, "Попробовать ещё раз", func(): send("retake"))
		elif run.phase == "ready":
			var lengths: Array = station.remote_summary.get("lengths", []) if game.session.is_guest() else run.summary().lengths
			var groups: Array = station.remote_summary.get("groups", []) if game.session.is_guest() else run.summary().groups
			for role in range(station.role_count()):
				var seconds: float = lengths[role] / 60.0 if role < lengths.size() else 0
				var row := HBoxContainer.new()
				training_box.add_child(row)
				row.add_theme_constant_override("separation", 10)
				if seconds > 0:
					var icon := TextureRect.new()
					row.add_child(icon)
					icon.texture = preload("res://assets/ui/record.svg")
					icon.custom_minimum_size = Vector2(28, 28)
					icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon.tooltip_text = "● — бригада уже знает эту роль. Рядом — длительность рабочего показа в секундах."
				var role_label := _label(row, "%s · %s" % [station.Definition.TYPES[station.type_id].roles[role], "запись %.1f с" % seconds if seconds > 0 else "ещё нет записи"], 16)
				role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if seconds > 0: role_label.tooltip_text = "Сохранённый дубль этой роли. Замена связанной роли очистит связанный черновик."
				var selector := OptionButton.new()
				training_box.add_child(selector)
				selector.add_item("Повар повторяет / роль пока пустая", 0)
				selector.add_item("Я — записываю роль", game.session.local_id())
				for id in game.session.members:
					if id != game.session.local_id(): selector.add_item(str(game.session.members[id]), id)
				assignments.append(selector)
			var first := lengths.find(0)
			assignments[maxi(0, first)].select(1)
			var help := _label(training_box, "Красные зоны воспроизводят свои дубли. Живые роли могут пользоваться зонами друг друга.", 15)
			help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if groups.size() > 1 and groups[0] >= 0 and groups[0] == groups[1]:
				var warning := _label(training_box, "Роли записаны вместе: замена одной очистит связанный черновик второй. Прежний рабочий рецепт останется до принятия нового.", 15)
				warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_button(training_box, "Начать показ", start_pass)
			if not showcase: _button(training_box, "Обучить бригаду · вернуться к заказам", func(): send("accept"))
			else: _label(training_box, "Личный показ инспектору. Звонок подаёт блюдо; рабочая запись бригады сохранится.")
			var old_time: float = station.recipes.get(run.dish, {}).get("duration", 0)
			_label(training_box, "Рабочая запись: %.1f с. Черновик: %.1f с." % [old_time, (lengths.max() / 60.0) if not lengths.is_empty() else 0.0], 15)
		if run.lead == game.session.local_id(): _button(training_box, "Прервать проверку" if showcase else "Закончить обучение", func(): send("cancel"))
	if run.phase != "confirm_finish": _button(training_box, "Закрыть меню · Esc", close)
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func describe(station: Node3D) -> void:
	var dish: String = station.dishes()[recipe_choice.selected]
	summary_text.text = preload("res://scripts/cookbook_data.gd").summary(dish)
	if station.recipes.has(dish):
		summary_text.text += "\n\n●  %.1f с" % station.recipes[dish].duration
		summary_text.tooltip_text = "● — бригада знает блюдо. Рядом указана длительность рабочего показа."
	else:
		summary_text.tooltip_text = "Рецепт и подсказки — в поварской книге (B)."
	if station.state == "cooking": summary_text.text += "\nОбучение начнётся после текущего заказа."

func send(action: String) -> void:
	command_requested.emit({"action": action, "station": selected_station})

func start_pass() -> void:
	var roles: Array = []
	for selector in assignments: roles.append(selector.get_selected_id())
	command_requested.emit({"action": "pass", "station": selected_station, "participants": roles})
