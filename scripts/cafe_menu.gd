extends "res://scripts/cafe_menu_core.gd"

const DeveloperPresets = preload("res://scripts/developer_presets.gd")

func _feature_visible(feature_id: String) -> bool:
	if game == null or not is_instance_valid(game.service) or game.service.get("feature_access") == null: return false
	return bool(game.service.feature_access.access(feature_id).get("visible", false))

func show_station(station: Node3D) -> void:
	super(station)
	_append_live_training(station)
	_apply_feature_visibility()
	_append_developer_entry()

func _append_live_training(station: Node3D) -> void:
	if not station.manual_station or not _feature_visible("live_training"): return
	var session=game.service.live_training
	if station.training.active() and station.training.purpose=="live_lesson" and station.training.phase=="ready":
		rebuild()
		_label(training_box,"ШЕФ-СТАНЦИЯ · ЛИЧНЫЙ УРОК",23)
		var report: Dictionary=station.model.quality()
		var student_name:=str(game.service.clone_data(int(game.service.live_training.clone_id)).get("name","Клон"))
		_label(training_box,"%s научился: %s · %s"%[student_name,station.Definition.DISHES.get(station.training.dish,station.training.dish),str(report.get("grade","D"))],20)
		_label(training_box,"Принятие заменит только этот личный навык. Если повторить или отменить урок, прежний принятый способ останется у клона.",14)
		_button(training_box,"Принять",func(): send("accept"))
		_button(training_box,"Показать ещё раз",func(): send("retake"))
		_button(training_box,"Отменить урок",func(): send("cancel"))
		_button(training_box,"Закрыть меню · Esc",close)
		return
	if is_instance_valid(session) and session.is_active():
		rebuild()
		_label(training_box,"ШЕФ-СТАНЦИЯ · ЛИЧНЫЙ УРОК",23)
		var student: Dictionary=game.service.clone_data(int(session.clone_id))
		var phase_text: String={"draining":"заканчивает принятый заказ","walking":"идёт к Шефу","ready":"готов смотреть","demonstrating":"смотрит показ","returning":"возвращается к стойке"}.get(str(session.phase),str(session.phase))
		_label(training_box,"%s · %s · %s"%[str(student.get("name","Клон")),station.Definition.DISHES.get(str(session.dish),str(session.dish)),phase_text],18)
		if str(session.phase)=="draining": _label(training_box,"Ученик не бросает уже принятый заказ. Запись движений начнётся только после того, как он придёт к Шефу.",14)
		if str(session.phase)=="ready" and int(session.teacher_peer)==game.session.local_id():
			_button(training_box,"Начать личный показ",func(): command_requested.emit({"action":"live_lesson_begin","station":station.station_id}))
		if int(session.teacher_peer)==game.session.local_id() and str(session.phase)!="returning":
			_button(training_box,"Отменить урок",func(): command_requested.emit({"action":"live_lesson_cancel","station":station.station_id}))
		_button(training_box,"Закрыть меню · Esc",close)
		return
	if station.training.active(): return
	var options: Array=game.service.live_lesson_options()
	if options.is_empty(): return
	_label(training_box,"ЛИЧНОЕ ОБУЧЕНИЕ",20)
	_label(training_box,"Позови конкретного клона к Шефу. Он закончит уже принятый заказ, подойдёт к месту зрителя и запомнит только показ после своего прибытия.",14)
	var dish_selector:=OptionButton.new()
	training_box.add_child(dish_selector)
	for dish in ["sausage","potato","wine"]:
		dish_selector.add_item(station.Definition.DISHES[dish])
		dish_selector.set_item_metadata(dish_selector.item_count-1,dish)
	var clone_selector:=OptionButton.new()
	training_box.add_child(clone_selector)
	for option in options:
		clone_selector.add_item("%s · стойка %d"%[str(option.name),int(option.station_id)],int(option.clone_id))
	_button(training_box,"Позвать на урок",func():
		var dish:=str(dish_selector.get_item_metadata(dish_selector.selected))
		command_requested.emit({"action":"live_lesson_start","station":station.station_id,"dish":dish,"clone_id":clone_selector.get_selected_id()})
		close())

func _apply_feature_visibility() -> void:
	if not is_instance_valid(training_box): return
	var recording := _feature_visible("video_recording")
	var training := _feature_visible("video_training")
	for node in training_box.find_children("*", "Control", true, false):
		var text := ""
		if node is Button: text = (node as Button).text
		elif node is Label: text = (node as Label).text
		if text.is_empty(): continue
		var lowered := text.to_lower()
		if not recording and ("мастер-класс" in lowered or "мастер-классы" in lowered):
			node.hide()
			continue
		if not training and (text == "Обучение и группа" or "обучение бригад" in lowered): node.hide()

func _append_developer_entry() -> void:
	_label(training_box,"DEVELOPER",16)
	_button(training_box,"Выбрать этап игры",open_developer_presets)

func open_developer_presets() -> void:
	rebuild()
	_label(training_box,"DEVELOPER · ЭТАП ИГРЫ",23)
	_label(training_box,"Пресет заменяет текущее сохранение. На каждом этапе деньги = 10 000.",15)
	for stage in range(5):
		_button(training_box,DeveloperPresets.label(stage),_apply_developer_stage.bind(stage))
	_button(training_box,"Отмена",close)
	panel.show()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _apply_developer_stage(stage: int) -> void:
	if game.session.is_guest():
		game.hud.show_toast("Developer-пресеты доступны только хосту.")
		return
	DeveloperPresets.apply(game,stage)
	close()
	game.hud.show_toast("Developer: загружен этап %d ★ · деньги 10 000"%stage)
