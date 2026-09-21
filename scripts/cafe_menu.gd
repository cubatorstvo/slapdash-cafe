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
var masterclass_setup_dish := ""
var masterclass_setup_equipment: Array=[]
var summary_text: Label
var game: Node3D
var net_status: Label
var address: LineEdit
var player_name: LineEdit
var port: SpinBox

func _ready() -> void:
	layer = 15
	var root := get_node("Root") as Control
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = CafeStyle.make()
	panel = get_node("Root/MenuPanel") as PanelContainer
	training_box = get_node("Root/MenuPanel/Scroll/TrainingBox") as VBoxContainer
	net_panel = get_node("Root/NetworkPanel") as PanelContainer
	player_name = get_node("Root/NetworkPanel/Column/PlayerName") as LineEdit
	address = get_node("Root/NetworkPanel/Column/DirectAddress") as LineEdit
	port = get_node("Root/NetworkPanel/Column/Port") as SpinBox
	net_status = get_node("Root/NetworkPanel/Column/NetworkStatus") as Label
	(get_node("Root/NetworkPanel/Column/Invite") as Button).pressed.connect(func(): steam_requested.emit("invite"))
	(get_node("Root/NetworkPanel/Column/SteamHost") as Button).pressed.connect(func(): steam_requested.emit("host"))
	(get_node("Root/NetworkPanel/Column/Create") as Button).pressed.connect(func(): network_requested.emit("host", address.text, int(port.value), player_name.text))
	(get_node("Root/NetworkPanel/Column/Join") as Button).pressed.connect(func(): network_requested.emit("join", address.text, int(port.value), player_name.text))
	(get_node("Root/NetworkPanel/Column/Leave") as Button).pressed.connect(func(): network_requested.emit("leave", "", 0, ""))
	(get_node("Root/NetworkPanel/Column/Back") as Button).pressed.connect(close)

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
	if station.state=="serving":
		_label(training_box,"Гость забирает заказ",22)
		_button(training_box,"Вернуться",close)
		panel.show(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		return
	if not station.ready_crew():
		_label(training_box,("Сотрудник на перекалибровке в лаборатории" if game.laboratory.calibrator.reserves_station(station.station_id) else "Новый работник идёт к станции") if game.laboratory.reserves_station(station.station_id) else "Нет бригады: %d/%d. Создай клонов в лаборатории."%[station.staffed,station.role_count()],22)
		_button(training_box,"Вернуться",close)
		panel.show(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		return
	var run = station.training
	var showcase: bool = game.service.is_showcase(station)
	_label(training_box, ("ШЕФ-СТАНЦИЯ · МАСТЕР-КЛАСС · %s"%station.Definition.TYPES[station.type_id].title) if station.masterclass_station else "СТАНЦИЯ %d · %s" % [station.station_id, station.Definition.TYPES[station.type_id].title], 23)
	var names := PackedStringArray()
	for role in range(station.crew.size()): names.append(station.crew_name(role))
	if not station.manual_station: _label(training_box, "Бригада: " + ", ".join(names) if station.ready_crew() else "Нужны клоны: %d/%d · создай в лаборатории"%[station.staffed,station.role_count()], 16)
	if not station.manual_station and station.ready_crew(): _label(training_box,"Темп бригады: %d%% · по самому медленному"%roundi(station.crew_tempo()*100),16)
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
				var wish: String = preload("res://scripts/chef_orders.gd").special_request(station.customer_order)
				if not wish.is_empty(): _label(training_box, wish)
				_label(training_box, "Оплата ×%.1f"%float(station.customer_order.get("premium",1)),16)
			_button(training_box, "Приготовить заказ", func(): command_requested.emit({"action": "manual", "station": selected_station, "dish": dish}))
		if game.service.progress.stars>=1:
			_label(training_box,"МАСТЕР-КЛАСС",20)
			if not game.service.masterclass_pending.is_empty():
				var pending_dish: String=str(game.service.masterclass_pending.get("dish",""))
				var pending_equipment: Array=game.service.masterclass_pending.get("equipment",[])
				_label(training_box,"После уже принятых заказов начнётся: "+str(station.Definition.DISHES.get(pending_dish,pending_dish))+". Новые личные заказы временно не принимаются.",16)
				if not game.service.masterclass_time_available(): _label(training_box,"Запись начнётся, когда снова будет рабочее время.",14)
				if not pending_equipment.is_empty(): _label(training_box,"Оборудование записи: "+game.service.equipment_names(pending_equipment),14)
			elif not game.service.masterclass_time_available():
				_label(training_box,"Мастер-классы проводятся только в рабочее время.",16)
			elif not masterclass_setup_dish.is_empty():
				var setup_dish: String=masterclass_setup_dish
				var setup_type: String=station.Definition.type_for_dish(setup_dish)
				_label(training_box,str(station.Definition.DISHES.get(setup_dish,setup_dish)),19)
				_label(training_box,"Тип кухни: "+str(station.Definition.TYPES.get(setup_type,{}).get("title",setup_type)),15)
				_label(training_box,"Выбери предметы, которые будут участвовать в этом способе. Запись запомнит именно этот набор; обучать ей можно будет любую кухню того же типа.",14)
				var options: Array=game.service.masterclass_equipment_options(setup_dish)
				for option in options:
					var equipment_id: String=str(option.id)
					var toggle:=CheckBox.new()
					toggle.text=str(option.name)
					toggle.button_pressed=equipment_id in masterclass_setup_equipment
					toggle.toggled.connect(func(on): toggle_masterclass_equipment(equipment_id,on))
					training_box.add_child(toggle)
				if masterclass_setup_equipment.is_empty():
					_label(training_box,"Выбери хотя бы один доступный предмет.",14)
				else:
					_label(training_box,"Требования будущей записи: "+game.service.equipment_names(masterclass_setup_equipment),14)
					_button(training_box,"Начать запись мастер-класса",submit_masterclass_setup)
				_button(training_box,"Отмена настройки",cancel_masterclass_setup)
			else:
				for option in game.service.masterclass_options():
					var master_dish: String=str(option.dish)
					if bool(option.available):
						_button(training_box,"Провести мастер-класс · "+str(station.Definition.DISHES[master_dish]),func():begin_masterclass_setup(master_dish))
					else:
						_label(training_box,"○ %s — %s"%[station.Definition.DISHES[master_dish],option.reason],14)
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
		if game.service.progress.stars>=1:
			_button(training_box, "Обучение и группа", func(): open_training_group())
		else:
			_label(training_box, "Обучение бригад откроется после первой звезды. Способ готовки записывается только на Шеф-станции как мастер-класс.", 15)
	else:
		_label(training_box, station.Definition.DISHES[run.dish], 20)
		var report: Dictionary = station.model.quality()
		_label(training_box, "Качество блюда: %s" % report.grade, 17)
		var effect: Dictionary=preload("res://scripts/masterclass_library.gd").effectiveness(report)
		_label(training_box,"Эффектность: %s · %s"%[effect.label,effect.explanation],17)
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
			if run.purpose=="masterclass": _button(training_box, "Сохранить мастер-класс в видеотеку", func(): send("accept"))
			elif not showcase: _button(training_box, "Обучить бригаду · вернуться к заказам", func(): send("accept"))
			else: _label(training_box, "Личный показ инспектору. Звонок подаёт блюдо; рабочая запись бригады сохранится.")
			var old_time: float = station.recipes.get(run.dish, {}).get("duration", 0)
			_label(training_box, "Рабочая запись: %.1f с. Черновик: %.1f с." % [old_time, (lengths.max() / 60.0) if not lengths.is_empty() else 0.0], 15)
		if run.lead == game.session.local_id(): _button(training_box, "Прервать проверку" if showcase else "Закончить мастер-класс" if run.purpose=="masterclass" else "Закончить обучение", func(): send("cancel"))
	if run.phase != "confirm_finish": _button(training_box, "Закрыть меню · Esc", close)
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func begin_masterclass_setup(dish: String) -> void:
	masterclass_setup_dish=dish
	masterclass_setup_equipment=game.service.masterclass_default_equipment(dish)
	var station: Node3D=game.service.by_id(selected_station)
	if station!=null: show_station(station)

func toggle_masterclass_equipment(item: String,on: bool) -> void:
	if on and item not in masterclass_setup_equipment: masterclass_setup_equipment.append(item)
	elif not on: masterclass_setup_equipment.erase(item)
	masterclass_setup_equipment.sort()
	var station: Node3D=game.service.by_id(selected_station)
	if station!=null: show_station(station)

func cancel_masterclass_setup() -> void:
	masterclass_setup_dish=""
	masterclass_setup_equipment.clear()
	var station: Node3D=game.service.by_id(selected_station)
	if station!=null: show_station(station)

func submit_masterclass_setup() -> void:
	var dish: String=masterclass_setup_dish
	var equipment: Array=masterclass_setup_equipment.duplicate()
	masterclass_setup_dish=""
	masterclass_setup_equipment.clear()
	command_requested.emit({"action":"masterclass_start","station":selected_station,"dish":dish,"equipment":equipment})
	close()

func open_training_group() -> void:
	var station_id:=selected_station
	close()
	game.office.open("groups")
	game.office.select_group_stations([station_id])
	game.office.course_editor_open()

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
