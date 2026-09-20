extends CanvasLayer
## Shared cafe ledger, accessed from the physical cafe computer.
const LabPolicy = preload("res://scripts/laboratory_progression.gd")
const Lounge = preload("res://scripts/lounge_progression.gd")
const P = preload("res://scripts/cafe_progression.gd")
const Style = preload("res://scripts/cafe_theme.gd")
const Definition = preload("res://scripts/station_definition.gd")
const Expansion = preload("res://scripts/cafe_expansion_layout.gd")
const Insights = preload("res://scripts/cafe_insights.gd")
const TrainingDragRow = preload("res://scripts/ui/training_drag_row.gd")
var game: Node3D
var panel: PanelContainer
var content: VBoxContainer
var scroll: ScrollContainer
var heading: Label
var status: Label
var timer: Label
var tab := "overview"
var stamp := ""
var selections := {}
var confirm_reset := false
var confirm_delete_masterclass := -1
var group_selected_stations: Array=[]
var group_pending_assignment: Dictionary={}
var group_command_serial:=1
var course_editor: Dictionary={}
var course_editor_message: String=""
var course_group_order: Array=[]
var course_command_serial:=1
var group_selected_groups: Array=[]
var lab_branch := "formula"
var lab_target := 2
var lab_reserve := 150
var visit_live_status: Label
var lab_live_status: Label
var scale_type := "counter"
var scale_slots: Array=[]
var scale_equipment: Array=[]
var send_installers := false
var stats_focus: Dictionary={}
var course_focus_id:=0
var groups_mode:="overview"
var group_expanded: Dictionary={}
var training_type_filter:=""
var training_scope_stations: Array=[]
var training_library_selection: Array=[]
var training_library_anchor:=-1
var training_library_rows: Dictionary={}
var training_queue_selection: Array=[]
var training_queue_anchor:=-1
var training_queue_rows: Dictionary={}
var training_course_expanded: Dictionary={}
var training_preview_expanded:=false
var navigation: Dictionary = {}
var shop_category: String = "equipment"
var shop_station_id: int = 1
var details_open: Dictionary = {}
var delivery_labels: Array[Dictionary] = []
var stats_feed_limit: int = 12
var last_page: String = ""
const PAGE_NAMES: Dictionary = {"overview":"Обзор кафе", "groups":"Столы и обучение", "stations":"Интернет-магазин", "videos":"Мастер-классы", "laboratory":"Лаборатория", "lounge":"Комната отдыха", "stats":"Статистика", "star":"Звёзды", "settings":"Сохранение и помощь"}


func _ready() -> void:
	layer = 17
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 28
	panel.offset_right = -28
	panel.offset_top = 32
	panel.offset_bottom = -32
	panel.theme = Style.make()
	panel.theme.default_font_size = 16
	panel.theme.set_color("font_disabled_color", "Button", Color("9ba9a3"))
	panel.theme.set_color("font_color", "CheckBox", Style.CREAM)
	panel.theme.set_color("font_disabled_color", "CheckBox", Color("9ba9a3"))
	panel.add_theme_stylebox_override("panel", Style.box(Color("172e30"), 18, 18))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var brand := label(top, "ТЯП-ЛЯП / КАФЕ", 22)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "Вернуться в кафе · Esc", close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 208
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 5)
	side_scroll.add_child(side)
	for entry in [["overview","Обзор кафе"],["groups","Столы и обучение"],["stations","Интернет-магазин"],["videos","Мастер-классы"],["laboratory","Лаборатория"],["lounge","Комната отдыха"],["star","Звёзды"],["stats","Статистика"],["settings","Сохранение и помощь"]]:
		var key: String = entry[0]
		var nav := button(side, entry[1], func(): navigate(key))
		nav.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.toggle_mode = true
		navigation[key] = nav
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	body.add_child(main)
	heading = label(main, "Обзор кафе", 26)
	status = label(main, "", 15)
	status.add_theme_color_override("font_color", Style.MINT)
	timer = label(main, "", 16)
	timer.add_theme_color_override("font_color", Style.GOLD)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	panel.hide()

func navigate(page: String) -> void:
	tab = "stations" if page in ["deliveries", "decor", "night"] else page
	stamp = ""
	rebuild()

func open_shop(category: String) -> void:
	shop_category = category
	navigate("stations")

func _fold(parent: Node, key: String, title: String) -> VBoxContainer:
	var expanded: bool = bool(details_open.get(key, false))
	var toggle := button(parent, ("▾ " if expanded else "▸ ") + title, func(): details_open[key] = not expanded; rebuild())
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not expanded: return null
	return _section_card(parent)

func label(parent: Node, text: String, size := 17) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD
	if parent is HBoxContainer: node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent is HFlowContainer: node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.add_theme_font_size_override("font_size", size)
	parent.add_child(node)
	return node

func button(parent: Node, text: String, callback: Callable, enabled := true, disabled_reason := "") -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(100, 40)
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.tooltip_text = disabled_reason if not enabled and not disabled_reason.is_empty() else text
	if parent is HFlowContainer: node.custom_minimum_size.x = maxf(100.0, float(text.length()) * 8.5 + 26.0)
	node.disabled = not enabled
	node.pressed.connect(func():
		if is_instance_valid(game.feedback): game.feedback.play_ui("click")
		callback.call())
	parent.add_child(node)
	return node

func metric(parent: Node,text: String,tooltip: String,callback := Callable()) -> Control:
	var node: Control
	if callback.is_valid(): node=button(parent,text,callback)
	else: node=label(parent,text,16)
	node.tooltip_text=tooltip
	return node

func opened() -> bool: return panel.visible
func open(page := "overview") -> void:
	tab = "stations" if page in ["deliveries", "decor", "night"] else page
	lab_target=int(game.service.progress.lab_production.target)
	lab_reserve=int(game.service.progress.lab_production.reserve)
	game.menu.close()
	game.cookbook.close()
	game.session.suspend_input()
	confirm_reset = false
	confirm_delete_masterclass = -1
	group_pending_assignment={}
	course_editor={}
	course_editor_message=""
	course_group_order=[]
	group_selected_stations=[]
	group_selected_groups=[]
	stats_focus={}
	course_focus_id=0
	groups_mode="overview"
	group_expanded={}
	training_type_filter=""
	training_scope_stations=[]
	training_library_selection=[]
	training_library_anchor=-1
	training_library_rows={}
	training_queue_selection=[]
	training_queue_anchor=-1
	training_queue_rows={}
	training_course_expanded={}
	training_preview_expanded=false
	details_open.clear()
	last_page = ""
	panel.show()
	stamp = ""
	rebuild()
	game.sync_mouse_mode()

func close() -> void:
	panel.hide()
	game.sync_mouse_mode()

func send(action: Dictionary, dismiss := false) -> void:
	if dismiss: close()
	game.session.request_action(action)
	stamp = ""

func set_group_station_selected(id: int,on: bool) -> void:
	if on and id not in group_selected_stations: group_selected_stations.append(id)
	elif not on: group_selected_stations.erase(id)
	group_selected_stations.sort()
	group_pending_assignment={}
	if not course_editor.is_empty(): _sync_course_group_order()
	stamp=""
	rebuild()

func select_group_stations(ids: Array) -> void:
	group_selected_stations=ids.duplicate()
	group_selected_stations.sort()
	group_pending_assignment={}
	if not course_editor.is_empty(): _sync_course_group_order()
	stamp=""
	rebuild()

func stage_group_assignment(record_id: int) -> void:
	var command: String="office:%d:%d:%d:%d"%[game.service.progress.day,int(game.service.training_queue.next_course_id),group_command_serial,record_id]
	group_command_serial+=1
	group_pending_assignment={"record":record_id,"stations":group_selected_stations.duplicate(),"command":command}
	stamp=""
	rebuild()

func course_editor_open(record_id := 0,edit_course_id := 0) -> void:
	var previous_selection: Array=group_selected_stations.duplicate()
	course_editor={"open":true,"records":[],"mode":"together","editing":edit_course_id,"type_id":""}
	course_editor_message=""
	course_group_order=[]
	training_scope_stations=previous_selection
	if edit_course_id>0:
		var view: Dictionary=game.service.training_queue.course_view(edit_course_id)
		if view.is_empty():
			course_editor_message="Обучение не найдено."
		else:
			course_editor.mode="together"
			course_editor.editing=edit_course_id
			training_scope_stations=[]
			for assignment in view.get("assignments",[]):
				var rid: int=int(assignment.get("record_id",0))
				if rid>0: _course_editor_add_record_internal(rid)
				for raw_id in assignment.get("station_ids",[]):
					var sid: int=int(raw_id)
					if sid not in training_scope_stations: training_scope_stations.append(sid)
			training_scope_stations.sort()
			group_selected_stations=training_scope_stations.duplicate()
			course_group_order=view.get("group_order",[]).duplicate()
	elif not previous_selection.is_empty():
		group_selected_stations=previous_selection
		training_scope_stations=previous_selection.duplicate()
	if record_id>0:
		_course_editor_add_record_internal(record_id)
		var record: Dictionary=game.service.masterclass_by_id(record_id)
		if not record.is_empty():
			training_type_filter=str(record.get("source_type",""))
	if training_type_filter.is_empty() and not training_scope_stations.is_empty():
		var first_station=game.service.by_id(int(training_scope_stations[0]))
		if first_station!=null: training_type_filter=str(first_station.type_id)
	if not training_type_filter.is_empty(): course_editor.type_id=training_type_filter
	_mark_training_intro_mass_seen()
	groups_mode="training"
	tab="groups"
	stamp=""
	rebuild()

func _mark_training_intro_mass_seen() -> void:
	if game.service.progress.stars<1 or bool(game.service.progress.training_intro_mass_seen): return
	var type_id: String=str(course_editor.get("type_id",""))
	if type_id.is_empty() and not group_selected_stations.is_empty():
		var selected=game.service.by_id(int(group_selected_stations[0]))
		if selected!=null: type_id=str(selected.type_id)
	if type_id.is_empty(): return
	var compatible:=0
	for station in game.service.stations:
		if station.manual_station or station.masterclass_station or str(station.type_id)!=type_id: continue
		compatible+=1
	if compatible>=2:
		game.service.progress.training_intro_mass_seen=true
		game.service.progress.revision+=1

func course_editor_to_chef() -> void:
	close()
	game.hud.notice.text="Шеф-станция: E → МАСТЕР-КЛАСС → выбери блюдо и сохрани запись в видеотеку."

func open_problem_group(stations: Array,course_id := 0) -> void:
	stats_focus={}
	group_selected_stations=stations.duplicate()
	group_selected_stations.sort()
	training_scope_stations=group_selected_stations.duplicate()
	course_focus_id=course_id
	groups_mode="training" if course_id>0 else "overview"
	tab="groups"
	stamp=""
	rebuild()

func open_problem_page(page: String) -> void:
	stats_focus={}
	course_focus_id=0
	tab=page
	stamp=""
	rebuild()

func course_editor_close() -> void:
	course_editor={}
	course_editor_message=""
	course_group_order=[]
	stamp=""
	rebuild()

func _course_editor_add_record_internal(record_id: int) -> bool:
	var record: Dictionary=game.service.masterclass_by_id(record_id)
	if record.is_empty():
		course_editor_message="Запись не найдена."
		return false
	var record_type: String=str(record.get("source_type",""))
	var current_type: String=str(course_editor.get("type_id",""))
	if not current_type.is_empty() and current_type!=record_type:
		course_editor_message="Эта запись относится к другой кухне. Переключи тип кухни в очереди."
		return false
	course_editor.type_id=record_type
	var records: Array=course_editor.get("records",[])
	var dish: String=str(record.get("dish",""))
	for index in range(records.size()):
		var existing: Dictionary=game.service.masterclass_by_id(int(records[index]))
		if str(existing.get("dish",""))==dish:
			records[index]=record_id
			course_editor.records=records
			course_editor_message="Версия блюда заменена на «%s»."%str(record.get("name","Запись"))
			return true
	records.append(record_id)
	course_editor.records=records
	course_editor_message=""
	return true

func course_editor_add_record(record_id: int) -> void:
	if course_editor.is_empty(): course_editor={"open":true,"records":[],"mode":"together","editing":0,"type_id":""}
	_course_editor_add_record_internal(record_id)
	stamp=""
	rebuild()

func course_editor_remove_record(index: int) -> void:
	var records: Array=course_editor.get("records",[])
	if index>=0 and index<records.size(): records.remove_at(index)
	course_editor.records=records
	if records.is_empty(): course_editor.type_id=""
	course_editor_message=""
	stamp=""
	rebuild()

func course_editor_move_record(index: int,delta: int) -> void:
	var records: Array=course_editor.get("records",[])
	var target: int=index+delta
	if index<0 or index>=records.size() or target<0 or target>=records.size(): return
	var value=records[index]
	records[index]=records[target]
	records[target]=value
	course_editor.records=records
	stamp=""
	rebuild()

func course_editor_set_mode(mode: String) -> void:
	if mode in ["together","by_groups"]:
		course_editor.mode=mode
		if mode=="by_groups": _sync_course_group_order()
	stamp=""
	rebuild()

func _course_group_id_for_station(station_id: int) -> String:
	return game.service.group_id_for_station(station_id)

func _sync_course_group_order() -> void:
	var valid: Array=[]
	var source_ids: Array=training_scope_stations if groups_mode=="training" and not training_scope_stations.is_empty() else group_selected_stations
	for raw_id in source_ids:
		var group_id: String=_course_group_id_for_station(int(raw_id))
		if not group_id.is_empty() and group_id not in valid: valid.append(group_id)
	var next: Array=[]
	for group_id in course_group_order:
		if group_id in valid and group_id not in next: next.append(group_id)
	for group_id in valid:
		if group_id not in next: next.append(group_id)
	course_group_order=next

func course_editor_select_group(group_id: String,on: bool) -> void:
	var group: Dictionary=game.service.table_group_by_id(group_id)
	if group.is_empty(): return
	if on:
		for raw_id in group.stations:
			var station_id: int=int(raw_id)
			if station_id not in group_selected_stations: group_selected_stations.append(station_id)
		if group_id not in course_group_order: course_group_order.append(group_id)
	else:
		for raw_id in group.stations: group_selected_stations.erase(int(raw_id))
		course_group_order.erase(group_id)
	group_selected_stations.sort()
	_sync_course_group_order()
	stamp=""
	rebuild()

func course_editor_select_all_compatible() -> void:
	var type_id: String=str(course_editor.get("type_id",""))
	if type_id.is_empty(): return
	group_selected_stations=[]
	for station in game.service.stations:
		if station.manual_station or station.masterclass_station or station.type_id!=type_id: continue
		group_selected_stations.append(station.station_id)
	group_selected_stations.sort()
	_sync_course_group_order()
	stamp=""
	rebuild()

func course_editor_move_group(group_id: String,delta: int) -> void:
	_sync_course_group_order()
	var index: int=course_group_order.find(group_id)
	var target: int=index+delta
	if index<0 or target<0 or target>=course_group_order.size(): return
	var value=course_group_order[index]
	course_group_order[index]=course_group_order[target]
	course_group_order[target]=value
	stamp=""
	rebuild()

func course_editor_assignments() -> Array:
	var result: Array=[]
	for raw_record_id in course_editor.get("records",[]):
		result.append({"record_id":int(raw_record_id),"station_ids":group_selected_stations.duplicate()})
	return result

func course_editor_submit() -> void:
	var assignments:=course_editor_assignments()
	var preview: Dictionary=game.service.training_course_preview(assignments,str(course_editor.get("mode","together")),course_group_order)
	if not str(preview.get("error","")).is_empty():
		course_editor_message=str(preview.error)
		stamp=""
		rebuild()
		return
	var editing: int=int(course_editor.get("editing",0))
	var payload: Dictionary={"assignments":assignments,"mode":str(course_editor.get("mode","together")),"group_order":course_group_order.duplicate()}
	if editing>0:
		payload.action="training_course_edit"
		payload.course=editing
	else:
		payload.action="training_course_confirm"
		payload.command="office-course:%d:%d:%d"%[game.service.progress.day,int(game.service.training_queue.next_course_id),course_command_serial]
		course_command_serial+=1
	game.hud.notice.text=""
	send(payload)
	var notice: String=str(game.hud.notice.text)
	if notice=="Обучение добавлено в очередь.":
		course_editor={}
		course_editor_message=""
		course_group_order=[]
	else:
		course_editor_message=notice if not notice.is_empty() else "Изменение очереди не подтверждено. Проверь актуальное состояние."
	stamp=""
	rebuild()

func set_group_selected(id: String,on: bool) -> void:
	set_group_all_selected(id,on)

func set_scale_type(value: String) -> void:
	scale_type=value
	scale_slots=[]
	scale_equipment=[]
	stamp=""
	rebuild()

func toggle_scale_slot(id: int,on: bool) -> void:
	if on and id not in scale_slots: scale_slots.append(id)
	elif not on: scale_slots.erase(id)
	scale_slots.sort()
	stamp=""
	rebuild()

func toggle_scale_equipment(id: String,on: bool) -> void:
	if on and id not in scale_equipment: scale_equipment.append(id)
	elif not on: scale_equipment.erase(id)
	scale_equipment.sort()
	stamp=""
	rebuild()

func _process(_delta: float) -> void:
	if game == null or not is_instance_valid(game.service) or not opened(): return
	_refresh_delivery_labels()
	var progress = game.service.progress
	status.text = "Деньги: %d    Популярность: %d    Звёзды: %d / 5    Гости: %s" % [progress.cash, progress.popularity, progress.stars, "приходят" if game.service.open_for_business else "приём закрыт"]
	timer.text = "%s · %d:%02d" % ["Личный показ" if progress.phase == "showcase" else progress.inspection_name(), ceili(progress.remaining) / 60, ceili(progress.remaining) % 60] if progress.phase in ["showcase", "service"] else ""
	timer.visible = not timer.text.is_empty()
	if tab=="laboratory" and is_instance_valid(lab_live_status):
		var nursery=game.laboratory.nursery
		var calibration=game.laboratory.calibrator
		var occupied:=0
		for pot in progress.lab_pots:
			if pot.phase!="empty": occupied+=1
		lab_live_status.text="Занято горшков: %d/%d · свободных клонов: %d\n%s"%[occupied,LabPolicy.pot_count(progress),progress.free_clones,"Кресло: "+str(calibration.state.get("notice","")) if calibration.busy() else "Кресло свободно"]
	if tab=="overview" and is_instance_valid(visit_live_status): visit_live_status.text=game.service.Visits.status(progress)
	var next := "%s:%d:%d:%s:%s" % [tab, progress.revision, game.service.served, str(game.service.open_for_business), str(game.service.any_training())]
	if stamp != next:
		stamp = next
		rebuild()

func rebuild() -> void:
	var offset: int = scroll.scroll_vertical if last_page == tab else 0
	last_page = tab
	heading.text = str(PAGE_NAMES.get(tab, "Интернет-магазин"))
	for key in navigation:
		navigation[key].set_pressed_no_signal(key == tab)
	delivery_labels.clear()
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	var service = game.service
	var progress = service.progress
	var host: bool = not game.session.is_guest()
	if not host: label(content,"Покупки подтверждает хозяин кафе. Коробки можно распаковывать вместе.",15)
	match tab:
		"overview":
			overview_page(host)
		"settings":
			settings_page(host)
		"stats":
			stats_page()
		"stations", "decor", "night", "deliveries":
			shop_page(host)
		"videos":
			videos_page(host)
		"groups":
			if groups_mode=="training": training_workspace_page(host)
			else: groups_overview_page(host)
		"laboratory":
			laboratory_page()
		"lounge":
			lounge_page()
		"star":
			var star_title := "ПЕРВАЯ ЗВЕЗДА · дегустация" if progress.stars==0 else "ВТОРАЯ ЗВЕЗДА · делегация" if progress.stars==1 else "ТРЕТЬЯ ЗВЕЗДА · Большой обед" if progress.stars==2 else "ЧЕТВЁРТАЯ ЗВЕЗДА · Три волны" if progress.stars==3 else "ПЯТАЯ ЗВЕЗДА · День пяти звёзд" if progress.stars==4 else "КАФЕ · 5★"
			label(content,star_title,23)
			if not progress.result.is_empty(): label(content,progress.result)
			if progress.stars==4:
				for requirement in progress.star_requirements(service.stations,service.served): label(content,("✓ " if requirement.done else "○ ")+requirement.text)
				label(content,"Финальная смена: три последовательные фазы — общий наплыв, критики и общая кульминация. Все игроки используют один и тот же поток; кооператив отдельно не масштабируется.",15)
				button(content,"Начать «День пяти звёзд»",func():send({"action":"banquet"},true),host and progress.can_attempt(service.stations,service.served) and not service.any_training() and not service.Visits.busy(progress))
			elif progress.stars>=5:
				label(content,"Основная кампания завершена.")
			else:
				for requirement in progress.star_requirements(service.stations,service.served): label(content,("✓ " if requirement.done else "○ ")+requirement.text)
				if progress.stars==0:
					label(content,"Один дегустатор, три стандартных блюда B или лучше. Ошибку можно повторить бесплатно. Перед проверкой установи сковороду, соус, бокал и кувшин.")
				elif progress.stars==1:
					label(content,"Девять гостей за четыре минуты: трое требуют личного заказа шефа. Нужно 8 подач и 6 оценок B или выше.")
				elif progress.stars==2:
					label(content,"Большой обед: 14 гостей за четыре минуты. Три заказа готовит шеф, остальной поток идёт к трём производственным станциям. Нужно 11 подач и 8 оценок B или выше.")
					label(content,"Мощность можно получить разными путями: короткими записями, более быстрыми клонами, хорошим отдыхом или просто стабильной работой всех трёх линий.",15)
				else:
					label(content,"Три волны: 18 гостей за пять минут. Смешанный поток → бургерный пик → общий финал. Три заказа остаются шефу; нужно 15 подач и 11 оценок B или выше.")
					label(content,"Главное новое узкое место — одна жарочная поверхность на котлету и булку. Хорошая запись распределяет её между двумя ролями без конфликтов.",15)
				var invite_text := "Пригласить дегустатора" if progress.stars==0 else "Пригласить делегацию" if progress.stars==1 else "Начать Большой обед" if progress.stars==2 else "Начать испытание «Три волны»"
				button(content,invite_text,func():send({"action":"banquet"},true),host and progress.can_attempt(service.stations,service.served) and not service.any_training() and not service.Visits.busy(progress))
			if progress.busy(): button(content,"Прервать проверку",func():send({"action":"cancel_banquet"}),host)
	scroll.set_deferred("scroll_vertical", offset)



func _section_card(parent: Node,color := Color("294647")) -> VBoxContainer:
	var panel_card:=PanelContainer.new()
	panel_card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel_card.add_theme_stylebox_override("panel",Style.box(color,12,14))
	parent.add_child(panel_card)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",7)
	panel_card.add_child(box)
	return box

func _group_workers(group: Dictionary) -> Dictionary:
	var assigned:=0
	var capacity:=0
	for raw_id in group.get("stations",[]):
		var station: Node3D=game.service.by_id(int(raw_id))
		if station==null: continue
		capacity+=station.role_count()
		assigned+=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
	return {"assigned":assigned,"capacity":capacity}

func _group_equipment_issue_count(group: Dictionary) -> int:
	var count:=0
	for raw_id in group.get("stations",[]):
		var station: Node3D=game.service.by_id(int(raw_id))
		if station==null: continue
		for raw_dish in station.recipes.keys():
			var dish:=str(raw_dish)
			if station.dish_active(dish) and not station.missing_recipe_equipment(dish).is_empty():
				count+=1
	return count

func toggle_group_expanded(group_id: String) -> void:
	group_expanded[group_id]=not bool(group_expanded.get(group_id,false))
	stamp=""
	rebuild()

func set_group_all_selected(group_id: String,on: bool) -> void:
	var group: Dictionary=game.service.table_group_by_id(group_id)
	if group.is_empty(): return
	if on and group_id not in group_selected_groups: group_selected_groups.append(group_id)
	elif not on: group_selected_groups.erase(group_id)
	for raw_id in group.stations:
		var id:=int(raw_id)
		if on and id not in group_selected_stations: group_selected_stations.append(id)
		elif not on: group_selected_stations.erase(id)
	group_selected_stations.sort()
	stamp=""
	rebuild()

func clear_group_selection() -> void:
	group_selected_stations.clear()
	group_selected_groups.clear()
	stamp=""
	rebuild()

func group_selected_now() -> void:
	if group_selected_stations.size()<2 or _selected_group_types().size()!=1: return
	send({"action":"group_create","stations":group_selected_stations.duplicate()})
	clear_group_selection()

func ungroup_selected_now() -> void:
	if group_selected_groups.is_empty(): return
	send({"action":"group_dissolve","groups":group_selected_groups.duplicate()})
	clear_group_selection()

func _selected_group_types() -> Array:
	var result: Array=[]
	for raw_id in group_selected_stations:
		var station: Node3D=game.service.by_id(int(raw_id))
		if station!=null and station.type_id not in result: result.append(station.type_id)
	result.sort()
	return result

func open_training_workspace() -> void:
	training_scope_stations=group_selected_stations.duplicate()
	training_scope_stations.sort()
	var types:=_training_scope_types()
	if training_scope_stations.is_empty() or types.size()!=1: return
	training_type_filter=str(types[0])
	course_editor={}
	course_editor_message=""
	training_library_selection=[]
	training_queue_selection=[]
	training_library_anchor=-1
	training_queue_anchor=-1
	groups_mode="training"
	stamp=""
	rebuild()

func back_to_groups_overview() -> void:
	groups_mode="overview"
	training_library_selection=[]
	training_queue_selection=[]
	stamp=""
	rebuild()

func groups_overview_page(host: bool) -> void:
	var service=game.service
	label(content,"СТОЛЫ И ГРУППЫ",23)
	label(content,"Столы остаются отдельными, пока ты сам их не сгруппируешь. Группа выбирается целиком.",15)

	var selection:=_section_card(content,Color("244143"))
	var selection_row:=HFlowContainer.new()
	selection.add_child(selection_row)
	var selected_count:=group_selected_stations.size()
	var selection_label:=label(selection_row,"Ничего не выбрано" if selected_count==0 else "Выбрано столов: %d"%selected_count,17)
	selection_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var selected_types:=_selected_group_types()
	var group_enabled:=host and selected_count>=2 and selected_types.size()==1
	var group_reason: String="Управлять группами может хозяин кафе." if not host else "Выбери минимум два стола." if selected_count<2 else "Можно группировать только столы одного типа." if selected_types.size()!=1 else ""
	button(selection_row,"Сгруппировать",group_selected_now,group_enabled,group_reason)
	var ungroup_enabled:=host and not group_selected_groups.is_empty()
	var ungroup_reason: String="Управлять группами может хозяин кафе." if not host else "В выборе нет группы. Выбери группу целиком." if group_selected_groups.is_empty() else ""
	button(selection_row,"Разгруппировать",ungroup_selected_now,ungroup_enabled,ungroup_reason)
	var training_enabled:=host and selected_count>0 and selected_types.size()==1
	var training_reason: String="Обучение запускает хозяин кафе." if not host else "Выбери хотя бы один стол." if selected_count==0 else "Для одного обучения выбери столы только одного типа." if selected_types.size()!=1 else ""
	button(selection_row,"Обучение",open_training_workspace,training_enabled,training_reason)

	if is_instance_valid(service.staff_training) and service.staff_training.is_active():
		var training_record: Dictionary=service.masterclass_by_id(service.staff_training.record_id)
		var live:=_section_card(content,Color("334b43"))
		label(live,"СЕЙЧАС ИДЁТ ОБУЧЕНИЕ",14)
		label(live,"%s · %s · %d столов"%[str(training_record.get("name",service.staff_training.record.get("name","Запись"))),service.staff_training.phase_label(),service.staff_training.station_ids.size()],17)

	var ungrouped: Array=[]
	for station in service.stations:
		if station.manual_station or station.masterclass_station: continue
		if service.group_id_for_station(station.station_id).is_empty(): ungrouped.append(station)
	if not ungrouped.is_empty():
		label(content,"ОТДЕЛЬНЫЕ СТОЛЫ",15)
		for station in ungrouped:
			var card:=_section_card(content,Color("294647"))
			var row:=HBoxContainer.new()
			card.add_child(row)
			var pick:=CheckBox.new()
			pick.button_pressed=station.station_id in group_selected_stations
			pick.disabled=not host
			pick.toggled.connect(func(on):set_group_station_selected(station.station_id,on))
			row.add_child(pick)
			var staff_now: int=station.role_count() if station.staffed<0 else station.staffed
			var state_text: String="обучение" if not station.group_training_state.is_empty() else "готов"
			var title:=label(row,"Стол %d · %s · работники %d/%d · %s"%[station.station_id,str(Definition.TYPES.get(station.type_id,{}).get("title",station.type_id)),staff_now,station.role_count(),state_text],15)
			title.size_flags_horizontal=Control.SIZE_EXPAND_FILL

	if not service.table_groups().is_empty(): label(content,"ГРУППЫ",15)
	for group in service.table_groups():
		var group_id:=str(group.id)
		var card:=_section_card(content,Color("294647"))
		var header:=HBoxContainer.new()
		card.add_child(header)
		var pick:=CheckBox.new()
		pick.button_pressed=group_id in group_selected_groups
		pick.disabled=not host
		pick.tooltip_text="Выбрать группу целиком"
		pick.toggled.connect(func(on):set_group_all_selected(group_id,on))
		header.add_child(pick)
		var expanded:=bool(group_expanded.get(group_id,false))
		var expand:=Button.new()
		expand.text="▾" if expanded else "▸"
		expand.custom_minimum_size=Vector2(38,36)
		expand.pressed.connect(func():toggle_group_expanded(group_id))
		header.add_child(expand)
		var title_box:=VBoxContainer.new()
		title_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		header.add_child(title_box)
		var workers:=_group_workers(group)
		var performance: Dictionary=service.group_performance(group)
		var total_orders: int=int(performance.orders_completed)+int(performance.losses)
		var pct:=Insights.completion_percent(int(performance.orders_completed),total_orders)
		label(title_box,str(group.name),18)
		var issue_count:=_group_equipment_issue_count(group)
		var subtitle: String="%s · %d столов · работники %d/%d · выполнено %.0f%%"%[str(Definition.TYPES.get(str(group.type_id),{}).get("title",group.type_id)),group.stations.size(),int(workers.assigned),int(workers.capacity),pct]
		if issue_count>0: subtitle+=" · ⚠ оснащение %d"%issue_count
		label(title_box,subtitle,13)

		if not expanded: continue
		label(card,"Порций: %d · доход: %d"%[int(performance.portions_served),int(performance.revenue)],15)
		var active_names: Array=[]
		for dish in group.active_dishes: active_names.append(str(Definition.DISHES.get(str(dish),str(dish))))
		label(card,"Активное меню: "+(", ".join(active_names) if not active_names.is_empty() else "пусто"),14)
		label(card,"СТОЛЫ",14)
		for raw_id in group.stations:
			var station_id:=int(raw_id)
			var station: Node3D=service.by_id(station_id)
			if station==null: continue
			var station_stats: Dictionary=service.analytics.stations.get(str(station_id),{})
			var staff_now: int=station.role_count() if station.staffed<0 else station.staffed
			var state_text: String="обучение: "+station.group_training_state if not station.group_training_state.is_empty() else "готов"
			label(card,"Стол %d · %d/%d работников · %s · %d заказов · %d порций · доход %d"%[station_id,staff_now,station.role_count(),state_text,int(station_stats.get("orders_completed",0)),int(station_stats.get("portions_served",0)),int(station_stats.get("revenue",0))],14)

		label(card,"МЕНЮ И СОСТОЯНИЕ ОБУЧЕНИЯ",14)
		for raw_dish in group.dishes:
			var dish_id:=str(raw_dish)
			var dish_row:=HBoxContainer.new()
			card.add_child(dish_row)
			var active_toggle:=CheckBox.new()
			active_toggle.text=str(Definition.DISHES.get(dish_id,dish_id))
			active_toggle.button_pressed=dish_id in group.active_dishes
			active_toggle.disabled=not host
			active_toggle.toggled.connect(func(on):send({"action":"group_active","group":group_id,"dish":dish_id,"enabled":on}))
			dish_row.add_child(active_toggle)
			var summary: Dictionary=service.group_dish_summary(group_id,dish_id)
			var dish_status:=label(dish_row,"%d/%d освоили"%[int(summary.get("mastered",0)),int(summary.get("total",group.stations.size()))],13)
			dish_status.size_flags_horizontal=Control.SIZE_EXPAND_FILL

		var rename_row:=HBoxContainer.new()
		card.add_child(rename_row)
		var group_edit:=LineEdit.new()
		group_edit.text=str(group.name)
		group_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		group_edit.editable=host
		rename_row.add_child(group_edit)
		button(rename_row,"Переименовать",func():send({"action":"group_rename","group":group_id,"name":group_edit.text}),host)

func _training_scope_types() -> Array:
	var result: Array=[]
	for raw_id in training_scope_stations:
		var station: Node3D=game.service.by_id(int(raw_id))
		if station!=null and station.type_id not in result: result.append(station.type_id)
	result.sort()
	return result

func _training_target_stations() -> Array:
	var result: Array=[]
	for raw_id in training_scope_stations:
		var station: Node3D=game.service.by_id(int(raw_id))
		if station!=null and str(station.type_id)==training_type_filter: result.append(station.station_id)
	result.sort()
	return result

func set_training_type_filter(type_id: String) -> void:
	if training_type_filter==type_id: return
	training_type_filter=type_id
	training_library_selection=[]
	training_queue_selection=[]
	training_library_anchor=-1
	training_queue_anchor=-1
	course_editor={}
	course_editor_message=""
	stamp=""
	rebuild()

func _training_library_ids() -> Array:
	var result: Array=[]
	for record in game.service.masterclasses:
		if bool(record.get("archived",false)): continue
		if str(record.get("source_type",""))==training_type_filter: result.append(int(record.get("id",0)))
	return result

func _training_library_click(meta: Dictionary,ctrl: bool,shift: bool) -> void:
	var record_id:=int(meta.get("record_id",0))
	var ids:=_training_library_ids()
	var index:=ids.find(record_id)
	if index<0: return
	if shift and training_library_anchor>=0 and training_library_anchor<ids.size():
		if not ctrl: training_library_selection=[]
		var a:=mini(training_library_anchor,index)
		var b:=maxi(training_library_anchor,index)
		for i in range(a,b+1):
			if ids[i] not in training_library_selection: training_library_selection.append(ids[i])
	elif ctrl:
		if record_id in training_library_selection: training_library_selection.erase(record_id)
		else: training_library_selection.append(record_id)
		training_library_anchor=index
	else:
		training_library_selection=[record_id]
		training_library_anchor=index
	_training_refresh_selection_styles()

func _queue_key(course_id: int,index: int) -> String:
	return "%d:%d"%[course_id,index]

func _queue_key_course(key: String) -> int:
	var parts:=key.split(":")
	return int(parts[0]) if parts.size()>=2 else -999

func _queue_key_index(key: String) -> int:
	var parts:=key.split(":")
	return int(parts[1]) if parts.size()>=2 else -1

func _training_queue_click(meta: Dictionary,ctrl: bool,shift: bool) -> void:
	if not bool(meta.get("selectable",true)): return
	var course_id:=int(meta.get("course_id",0))
	var index:=int(meta.get("index",-1))
	if index<0: return
	var key:=_queue_key(course_id,index)
	var current_course: int=_queue_key_course(str(training_queue_selection[0])) if not training_queue_selection.is_empty() else course_id
	if current_course!=course_id:
		training_queue_selection=[]
		training_queue_anchor=-1
	if shift and training_queue_anchor>=0:
		if not ctrl: training_queue_selection=[]
		var a:=mini(training_queue_anchor,index)
		var b:=maxi(training_queue_anchor,index)
		for i in range(a,b+1):
			var range_key:=_queue_key(course_id,i)
			if range_key not in training_queue_selection: training_queue_selection.append(range_key)
	elif ctrl:
		if key in training_queue_selection: training_queue_selection.erase(key)
		else: training_queue_selection.append(key)
		training_queue_anchor=index
	else:
		training_queue_selection=[key]
		training_queue_anchor=index
	_training_refresh_selection_styles()

func _training_refresh_selection_styles() -> void:
	for raw_id in training_library_rows:
		var record_id:=int(raw_id)
		var row: Variant=training_library_rows[raw_id]
		if not is_instance_valid(row): continue
		var selected:=record_id in training_library_selection
		row.set_selected(selected)
		var drag_ids: Array=training_library_selection.duplicate() if selected and not training_library_selection.is_empty() else [record_id]
		row.drag_payload={"kind":"masterclass_records","record_ids":drag_ids,"count":drag_ids.size()}
	for raw_key in training_queue_rows:
		var key:=str(raw_key)
		var row: Variant=training_queue_rows[raw_key]
		if not is_instance_valid(row): continue
		var selected:=key in training_queue_selection
		row.set_selected(selected)
		var course_id:=_queue_key_course(key)
		var indices: Array=[]
		if selected:
			for selected_key in training_queue_selection:
				if _queue_key_course(str(selected_key))==course_id: indices.append(_queue_key_index(str(selected_key)))
		if indices.is_empty(): indices=[_queue_key_index(key)]
		indices.sort()
		if bool(row.meta.get("draggable",true)):
			row.drag_payload={"kind":"queue_lessons","course_id":course_id,"indices":indices,"count":indices.size()}
		else:
			row.drag_payload={}

func _training_make_drag_row(parent: Node,meta: Dictionary,title: String,subtitle: String,payload: Dictionary,selected: bool,queue_key := "") -> Variant:
	var row=TrainingDragRow.new()
	parent.add_child(row)
	row.setup(meta,title,subtitle,payload)
	row.set_selected(selected)
	if str(meta.get("zone",""))=="library": row.drop_enabled=false
	row.row_clicked.connect(func(value,ctrl,shift):
		if str(value.get("zone",""))=="library": _training_library_click(value,ctrl,shift)
		else: _training_queue_click(value,ctrl,shift))
	row.row_dropped.connect(func(data,target,after):_training_drop(data,target,after))
	if str(meta.get("zone",""))=="library": training_library_rows[int(meta.record_id)]=row
	elif not queue_key.is_empty(): training_queue_rows[queue_key]=row
	return row

func _draft_record_ids() -> Array:
	return course_editor.get("records",[]).duplicate() if not course_editor.is_empty() else []

func _ensure_draft() -> void:
	if not course_editor.is_empty(): return
	course_editor={"open":true,"records":[],"mode":"together","editing":0,"type_id":training_type_filter}
	course_editor_message=""
	course_group_order=[]

func _record_dish(record_id: int) -> String:
	var record: Dictionary=game.service.masterclass_by_id(record_id)
	return str(record.get("dish",""))

func _insert_record_ids(existing: Array,new_ids: Array,index: int) -> Array:
	var result:=existing.duplicate()
	var clean_new: Array=[]
	for raw_id in new_ids:
		var record_id:=int(raw_id)
		var dish:=_record_dish(record_id)
		if dish.is_empty(): continue
		for pos in range(result.size()-1,-1,-1):
			if _record_dish(int(result[pos]))==dish:
				if pos<index: index-=1
				result.remove_at(pos)
		if record_id not in clean_new: clean_new.append(record_id)
	index=clampi(index,0,result.size())
	for offset in range(clean_new.size()): result.insert(index+offset,clean_new[offset])
	return result

func training_add_selected_to_draft() -> void:
	if training_library_selection.is_empty(): return
	var selected_records:=training_library_selection.duplicate()
	var existing: Dictionary=_editable_schedule_course(training_type_filter)
	if not existing.is_empty():
		var ids:=_insert_record_ids(_course_record_ids(existing),selected_records,_course_record_ids(existing).size())
		_send_course_edit(existing,_assignments_with_records(existing,ids,_training_target_stations()))
		training_library_selection=[]
		stamp=""
		rebuild()
		return
	_ensure_draft()
	course_editor.records=selected_records
	course_editor.type_id=training_type_filter
	training_library_selection=[]
	training_submit_draft()

func _course_record_ids(course: Dictionary) -> Array:
	var result: Array=[]
	for assignment in course.get("assignments",[]): result.append(int(assignment.get("record_id",0)))
	return result

func _course_station_ids(course: Dictionary) -> Array:
	var result: Array=[]
	for assignment in course.get("assignments",[]):
		for raw_id in assignment.get("station_ids",[]):
			var id:=int(raw_id)
			if id not in result: result.append(id)
	result.sort()
	return result

func _course_type_id(course: Dictionary) -> String:
	for assignment in course.get("assignments",[]):
		var record: Dictionary=game.service.masterclass_by_id(int(assignment.get("record_id",0)))
		if not record.is_empty(): return str(record.get("source_type",""))
	return ""

func _editable_schedule_course(type_id: String) -> Dictionary:
	var views: Array=game.service.training_course_views()
	for index in range(views.size()-1,-1,-1):
		var view: Dictionary=views[index]
		if bool(view.get("editable",false)) and _course_type_id(view)==type_id: return view
	return {}

func _assignments_with_records(course: Dictionary,record_ids: Array,new_station_ids: Array=[]) -> Array:
	var existing_by_id: Dictionary={}
	for assignment in course.get("assignments",[]): existing_by_id[int(assignment.get("record_id",0))]=assignment.duplicate(true)
	var default_ids:=new_station_ids.duplicate()
	if default_ids.is_empty(): default_ids=_course_station_ids(course)
	var result: Array=[]
	for raw_id in record_ids:
		var record_id:=int(raw_id)
		if existing_by_id.has(record_id): result.append(existing_by_id[record_id].duplicate(true))
		else: result.append({"record_id":record_id,"station_ids":default_ids.duplicate()})
	return result

func _send_course_edit(course: Dictionary,assignments: Array) -> void:
	send({"action":"training_course_edit","course":int(course.id),"assignments":assignments,"mode":"together","group_order":[]})

func _training_reorder_course(course_id: int,indices: Array,target_index: int) -> void:
	var course: Dictionary=game.service.training_queue.course_view(course_id)
	if course.is_empty() or not bool(course.get("editable",false)): return
	var ids:=_course_record_ids(course)
	var selected: Array=[]
	var sorted:=indices.duplicate()
	sorted.sort()
	for raw_index in sorted:
		var index:=int(raw_index)
		if index>=0 and index<ids.size(): selected.append(ids[index])
	for i in range(sorted.size()-1,-1,-1):
		var index:=int(sorted[i])
		if index>=0 and index<ids.size():
			if index<target_index: target_index-=1
			ids.remove_at(index)
	target_index=clampi(target_index,0,ids.size())
	for offset in range(selected.size()): ids.insert(target_index+offset,selected[offset])
	_send_course_edit(course,_assignments_with_records(course,ids))
	training_queue_selection=[]
	stamp=""

func _training_insert_library_into_course(course_id: int,record_ids: Array,target_index: int) -> void:
	var course: Dictionary=game.service.training_queue.course_view(course_id)
	if course.is_empty() or not bool(course.get("editable",false)): return
	var ids:=_insert_record_ids(_course_record_ids(course),record_ids,target_index)
	_send_course_edit(course,_assignments_with_records(course,ids))
	training_library_selection=[]
	stamp=""

func _training_move_between_courses(source_id: int,indices: Array,target_id: int,target_index: int) -> void:
	var source: Dictionary=game.service.training_queue.course_view(source_id)
	var target: Dictionary=game.service.training_queue.course_view(target_id)
	if source.is_empty() or target.is_empty() or not bool(source.get("editable",false)) or not bool(target.get("editable",false)): return
	var source_assignments: Array=source.get("assignments",[]).duplicate(true)
	var sorted:=indices.duplicate()
	sorted.sort()
	var moving_ids: Array=[]
	for raw_index in sorted:
		var index:=int(raw_index)
		if index>=0 and index<source_assignments.size(): moving_ids.append(int(source_assignments[index].get("record_id",0)))
	for i in range(sorted.size()-1,-1,-1):
		var index:=int(sorted[i])
		if index>=0 and index<source_assignments.size(): source_assignments.remove_at(index)
	var target_ids:=_insert_record_ids(_course_record_ids(target),moving_ids,target_index)
	if source_assignments.is_empty(): send({"action":"training_cancel_course","course":source_id})
	else: _send_course_edit(source,source_assignments)
	_send_course_edit(target,_assignments_with_records(target,target_ids))
	training_queue_selection=[]
	stamp=""

func _training_move_course_to_draft(source_id: int,indices: Array,target_index: int) -> void:
	var source: Dictionary=game.service.training_queue.course_view(source_id)
	if source.is_empty() or not bool(source.get("editable",false)): return
	var source_assignments: Array=source.get("assignments",[]).duplicate(true)
	var sorted:=indices.duplicate()
	sorted.sort()
	var moving_ids: Array=[]
	for raw_index in sorted:
		var index:=int(raw_index)
		if index>=0 and index<source_assignments.size(): moving_ids.append(int(source_assignments[index].get("record_id",0)))
	for i in range(sorted.size()-1,-1,-1):
		var index:=int(sorted[i])
		if index>=0 and index<source_assignments.size(): source_assignments.remove_at(index)
	_ensure_draft()
	course_editor.records=_insert_record_ids(_draft_record_ids(),moving_ids,target_index)
	course_editor.type_id=training_type_filter
	if source_assignments.is_empty(): send({"action":"training_cancel_course","course":source_id})
	else: _send_course_edit(source,source_assignments)
	training_queue_selection=[]
	stamp=""
	rebuild()

func _training_move_draft_to_course(indices: Array,target_id: int,target_index: int) -> void:
	var ids:=_draft_record_ids()
	var sorted:=indices.duplicate()
	sorted.sort()
	var moving: Array=[]
	for raw_index in sorted:
		var index:=int(raw_index)
		if index>=0 and index<ids.size(): moving.append(ids[index])
	for i in range(sorted.size()-1,-1,-1):
		var index:=int(sorted[i])
		if index>=0 and index<ids.size(): ids.remove_at(index)
	course_editor.records=ids
	_training_insert_library_into_course(target_id,moving,target_index)
	stamp=""
	rebuild()

func _training_drop(data: Variant,target: Dictionary,after: bool) -> void:
	if not data is Dictionary: return
	var zone:=str(target.get("zone",""))
	var target_course:=int(target.get("course_id",0))
	var target_index:=int(target.get("index",0))+(1 if after else 0)
	var kind:=str(data.get("kind",""))
	if zone=="draft":
		if kind=="masterclass_records":
			_ensure_draft()
			course_editor.records=_insert_record_ids(_draft_record_ids(),data.get("record_ids",[]),target_index)
			course_editor.type_id=training_type_filter
			training_library_selection=[]
			training_submit_draft()
		elif kind=="queue_lessons":
			var source_id:=int(data.get("course_id",0))
			var indices: Array=data.get("indices",[]).duplicate()
			if source_id==0:
				var ids:=_draft_record_ids()
				var selected: Array=[]
				var sorted:=indices.duplicate(); sorted.sort()
				for raw_index in sorted:
					var index:=int(raw_index)
					if index>=0 and index<ids.size(): selected.append(ids[index])
				for i in range(sorted.size()-1,-1,-1):
					var index:=int(sorted[i])
					if index>=0 and index<ids.size():
						if index<target_index: target_index-=1
						ids.remove_at(index)
				target_index=clampi(target_index,0,ids.size())
				for offset in range(selected.size()): ids.insert(target_index+offset,selected[offset])
				course_editor.records=ids
				training_queue_selection=[]
				stamp=""
				rebuild()
			else: _training_move_course_to_draft(source_id,indices,target_index)
	elif zone=="course":
		if kind=="masterclass_records": _training_insert_library_into_course(target_course,data.get("record_ids",[]),target_index)
		elif kind=="queue_lessons":
			var source_id:=int(data.get("course_id",0))
			var indices: Array=data.get("indices",[]).duplicate()
			if source_id==target_course: _training_reorder_course(target_course,indices,target_index)
			elif source_id==0: _training_move_draft_to_course(indices,target_course,target_index)
			else: _training_move_between_courses(source_id,indices,target_course,target_index)

func training_remove_queue_selection() -> void:
	if training_queue_selection.is_empty(): return
	var course_id:=_queue_key_course(str(training_queue_selection[0]))
	var indices: Array=[]
	for key in training_queue_selection:
		if _queue_key_course(str(key))==course_id: indices.append(_queue_key_index(str(key)))
	indices.sort()
	if course_id==0:
		var ids:=_draft_record_ids()
		for i in range(indices.size()-1,-1,-1):
			var index:=int(indices[i])
			if index>=0 and index<ids.size(): ids.remove_at(index)
		course_editor.records=ids
	else:
		var course: Dictionary=game.service.training_queue.course_view(course_id)
		if not course.is_empty() and bool(course.get("editable",false)):
			var assignments: Array=course.get("assignments",[]).duplicate(true)
			for i in range(indices.size()-1,-1,-1):
				var index:=int(indices[i])
				if index>=0 and index<assignments.size(): assignments.remove_at(index)
			if assignments.is_empty(): send({"action":"training_cancel_course","course":course_id})
			else: _send_course_edit(course,assignments)
	training_queue_selection=[]
	stamp=""
	rebuild()

func _draft_assignments() -> Array:
	var targets:=_training_target_stations()
	var result: Array=[]
	for raw_record_id in _draft_record_ids(): result.append({"record_id":int(raw_record_id),"station_ids":targets.duplicate()})
	return result

func training_submit_draft() -> void:
	if course_editor.is_empty() or _draft_record_ids().is_empty(): return
	var assignments:=_draft_assignments()
	var preview: Dictionary=game.service.training_course_preview(assignments,"together",[])
	if not str(preview.get("error","")).is_empty():
		course_editor_message=str(preview.error)
		stamp=""
		rebuild()
		return
	var editing:=int(course_editor.get("editing",0))
	game.hud.notice.text=""
	if editing>0:
		send({"action":"training_course_edit","course":editing,"assignments":assignments,"mode":"together","group_order":[]})
	else:
		var existing: Dictionary=_editable_schedule_course(training_type_filter)
		if not existing.is_empty():
			var ids:=_insert_record_ids(_course_record_ids(existing),_draft_record_ids(),_course_record_ids(existing).size())
			_send_course_edit(existing,_assignments_with_records(existing,ids,_training_target_stations()))
		else:
			var command: String="office-schedule:%d:%d:%d"%[game.service.progress.day,int(game.service.training_queue.next_course_id),course_command_serial]
			course_command_serial+=1
			send({"action":"training_course_confirm","assignments":assignments,"mode":"together","group_order":[],"command":command})
	var notice:=str(game.hud.notice.text)
	if notice in ["Обучение добавлено в очередь.","Очередь обучения обновлена."]:
		course_editor={}
		course_editor_message=""
		course_group_order=[]
		training_queue_selection=[]
		training_library_selection=[]
	else:
		course_editor_message=notice if not notice.is_empty() else "Изменение не принято. Проверь актуальное очередь."
	stamp=""
	rebuild()

func toggle_training_course_expanded(course_id: int) -> void:
	training_course_expanded[course_id]=not bool(training_course_expanded.get(course_id,false))
	stamp=""
	rebuild()

func toggle_training_preview() -> void:
	training_preview_expanded=not training_preview_expanded
	stamp=""
	rebuild()

func _schedule_entry_status(course: Dictionary,record_id: int) -> String:
	var total:=0
	var completed:=0
	var running:=false
	var wait_reason: String=""
	for batch in course.get("batches",[]):
		for lesson in batch.get("lessons",[]):
			if int(lesson.get("record_id",0))!=record_id: continue
			total+=1
			var state:=str(lesson.get("state",""))
			if state in ["completed","superseded"]: completed+=1
			if state=="active" or str(batch.get("state","")) in ["draining","gathering","watching","returning"]: running=true
			if wait_reason.is_empty() and not str(batch.get("blocked_reason","")).is_empty(): wait_reason=str(batch.blocked_reason)
	if total<=0: return str(course.get("state","в очереди"))
	if completed>=total: return "готово"
	if running: return "идёт · партия %d/%d"%[mini(total,completed+1),total]
	if not wait_reason.is_empty(): return "ждёт: %s · %d/%d"%[wait_reason,completed,total]
	return "в очереди · %d/%d партий"%[completed,total]

func _training_library_panel(parent: Node,host: bool) -> void:
	var service=game.service
	var box:=_section_card(parent,Color("253f41"))
	label(box,"МАСТЕР-КЛАССЫ",18)
	label(box,"Ctrl — добавить к выбору · Shift — диапазон · перетащи выбранные записи вправо.",13)
	training_library_rows={}
	var ids:=_training_library_ids()
	if ids.is_empty():
		label(box,"Для этого типа кухни пока нет сохранённых мастер-классов.",14)
	else:
		for raw_id in ids:
			var record_id:=int(raw_id)
			var record: Dictionary=service.masterclass_by_id(record_id)
			var dish:=str(record.get("dish",""))
			var quality: Dictionary=record.get("quality",{})
			var effect: Dictionary=record.get("effectiveness",{})
			var subtitle: String="%s · качество %s · %s · фильм %.1f с"%[str(record.get("name","Запись")),str(quality.get("grade","D")),str(effect.get("label","Обычная")),float(record.get("highlight_duration",0.0))]
			_training_make_drag_row(box,{"zone":"library","record_id":record_id},str(Definition.DISHES.get(dish,dish)),subtitle,{"kind":"masterclass_records","record_ids":[record_id],"count":1},record_id in training_library_selection)
	if not training_library_selection.is_empty():
		button(box,"Добавить в очередь →",training_add_selected_to_draft,host)

func _training_drop_tail(parent: Node,zone: String,course_id: int,index: int,text_value: String) -> void:
	var target=TrainingDragRow.new()
	parent.add_child(target)
	target.setup({"zone":zone,"course_id":course_id,"index":index},text_value,"Перетащи сюда")
	target.drag_payload={}
	target.row_dropped.connect(func(data,meta,after):_training_drop(data,meta,after))

func _training_existing_course_card(parent: Node,course: Dictionary,host: bool) -> void:
	var service=game.service
	var course_id:=int(course.id)
	var course_type:=_course_type_id(course)
	var can_edit_course: bool=bool(course.get("editable",false)) and course_type==training_type_filter
	var current_targets:=_training_target_stations()
	for index in range(course.assignments.size()):
		var assignment: Dictionary=course.assignments[index]
		var record_id:=int(assignment.get("record_id",0))
		var record: Dictionary=service.masterclass_by_id(record_id)
		var key:=_queue_key(course_id,index)
		var station_ids: Array=assignment.get("station_ids",[]).duplicate()
		station_ids.sort()
		var table_text:=", ".join(station_ids.map(func(id):return str(int(id))))
		var title_text: String="%s, столы %s"%[str(Definition.DISHES.get(str(assignment.get("dish","")),str(assignment.get("dish","")))),table_text]
		var payload: Dictionary={"kind":"queue_lessons","course_id":course_id,"indices":[index],"count":1} if can_edit_course else {}
		var row: Variant=_training_make_drag_row(parent,{"zone":"course","course_id":course_id,"index":index,"record_id":record_id,"draggable":can_edit_course,"selectable":can_edit_course},title_text,"",payload,key in training_queue_selection,key)
		var relevant:=station_ids.any(func(id):return int(id) in current_targets)
		row.set_context_highlight(relevant)
		row.drop_enabled=can_edit_course
	if str(course.get("state",""))=="active":
		button(parent,"Отменить текущее обучение",func():send({"action":"training_cancel_course","course":course_id}),host)

func _training_schedule_panel(parent: Node,host: bool) -> void:
	var box:=_section_card(parent,Color("203b3c"))
	var top:=HBoxContainer.new()
	box.add_child(top)
	var heading_label:=label(top,"ОЧЕРЕДЬ ОБУЧЕНИЯ",18)
	heading_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if not training_queue_selection.is_empty(): button(top,"Убрать выбранные",training_remove_queue_selection,host)
	label(box,"Перетащи мастер-класс в очередь. Порядок меняется перетаскиванием прямо здесь.",13)
	training_queue_rows={}
	var views: Array=game.service.training_course_views()
	if views.is_empty(): label(box,"Очередь пуста.",14)
	else:
		for course in views: _training_existing_course_card(box,course,host)
	var editable: Dictionary=_editable_schedule_course(training_type_filter)
	if editable.is_empty():
		_training_drop_tail(box,"draft",0,0,"Перетащи мастер-класс в очередь")
	else:
		_training_drop_tail(box,"course",int(editable.id),editable.get("assignments",[]).size(),"В конец очереди")

func training_workspace_page(host: bool) -> void:
	var service=game.service
	var top:=HBoxContainer.new()
	content.add_child(top)
	button(top,"← Столы и группы",back_to_groups_overview)
	var title:=label(top,"ОБУЧЕНИЕ",23)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if training_scope_stations.is_empty() or _training_scope_types().size()!=1:
		label(content,"Сначала выбери столы одного типа.",17)
		return
	var targets:=_training_target_stations()
	var assigned_workers:=0
	var worker_capacity:=0
	for raw_id in targets:
		var station: Node3D=service.by_id(int(raw_id))
		if station==null: continue
		worker_capacity+=station.role_count()
		assigned_workers+=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
	label(content,"%d столов · работников %d/%d · один общий заход на каждый мастер-класс."%[targets.size(),assigned_workers,worker_capacity],14)
	var columns:=BoxContainer.new()
	columns.vertical = get_viewport().get_visible_rect().size.x < 1100
	columns.add_theme_constant_override("separation",12)
	columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	var left:=VBoxContainer.new()
	left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio=0.42
	columns.add_child(left)
	var right:=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio=0.58
	columns.add_child(right)
	_training_library_panel(left,host)
	_training_schedule_panel(right,host)
	_training_refresh_selection_styles()

func set_stats_focus(value: Dictionary)->void:
	stats_focus=value.duplicate(true)
	stamp=""
	rebuild()

func stats_page()->void:
	var service=game.service
	var stats: Dictionary=service.order_stats
	label(content,"ЛЕНТА И СТАТИСТИКА",23)
	var arrived: int=int(stats.orders_arrived)
	var completed: int=int(stats.orders_completed)
	var completion: float=Insights.completion_percent(completed,arrived)
	metric(content,"Гости · пришло %d · обслужено %d · ушло %d"%[service.guests_arrived,service.served,service.missed],"Гость считается один раз независимо от числа порций.")
	metric(content,"Заказы · %d из %d выполнено · %.0f%% · частично %d · не выполнено %d"%[completed,arrived,completion,int(stats.orders_partial),int(stats.orders_failed)],"Один гость с десятью порциями — один заказ. Нажми причины ниже, чтобы увидеть блюда, группы и столы.")
	metric(content,"Порции · %d из %d выдано · %.0f%% · не получено %d"%[int(stats.portions_served),int(stats.portions_ordered),Insights.completion_percent(int(stats.portions_served),int(stats.portions_ordered)),int(stats.portions_unserved)],"Порции считаются фактически: заказ ×10 добавляет десять заказанных порций.")
	metric(content,"Доход · %d"%service.revenue,"Сумма всех однажды принятых порций и завершённых одно-порционных заказов.")
	var bottleneck: Dictionary=service.top_bottleneck()
	if not bottleneck.is_empty():
		label(content,"НАБЛЮДАЕМОЕ УЗКОЕ МЕСТО",19)
		label(content,"%s · %d случаев\n%s"%[bottleneck.label,bottleneck.count,bottleneck.suggestion],16)

	label(content,"ОСНОВНЫЕ ПРИЧИНЫ ПОТЕРЬ",19)
	if service.analytics.losses.is_empty(): label(content,"Пока нет зарегистрированных потерь.",15)
	else:
		var reasons: Array=service.analytics.losses.keys()
		reasons.sort_custom(func(a,b):return int(service.analytics.losses[a])>int(service.analytics.losses[b]))
		for reason in reasons:
			var count: int=int(service.analytics.losses[reason])
			var pct: float=0.0 if service.missed<=0 else float(count)/float(service.missed)*100.0
			var node:=button(content,"%s · %d · %.0f%%"%[Insights.reason_label(str(reason)),count,pct],func():set_stats_focus({"reason":str(reason)}))
			node.tooltip_text=Insights.suggestion(str(reason))

	label(content,"СИСТЕМНАЯ ЛЕНТА",19)
	if service.analytics.feed.is_empty(): label(content,"Событий пока нет. Потери, обучение и сборщики появятся здесь.",15)
	for entry in service.analytics.feed.slice(0, stats_feed_limit):
		var source: String="[ИГРОК · %s] "%str(entry.get("source_name","Повар")) if str(entry.get("source","system"))=="player" else "[СИСТЕМА] "
		var text: String=source+service.feed_text(entry)
		var event_button:=button(content,text,func():set_stats_focus(entry))
		var reason: String=str(entry.get("reason",""))
		var tip: String="Нажми, чтобы открыть связанное блюдо, группу и столы."
		if not reason.is_empty(): tip+="\n"+Insights.suggestion(reason)
		event_button.tooltip_text=tip

	if service.analytics.feed.size() > stats_feed_limit:
		button(content,"Показать ещё события",func():stats_feed_limit += 12;rebuild())
	if not stats_focus.is_empty():
		label(content,"ПОДРОБНОСТИ",20)
		var reason: String=str(stats_focus.get("reason",""))
		var dish: String=str(stats_focus.get("dish",""))
		if not dish.is_empty(): label(content,"Блюдо: "+str(Definition.DISHES.get(dish,dish)),17)
		if not reason.is_empty(): label(content,"Причина: %s\nРекомендация: %s"%[Insights.reason_label(reason),Insights.suggestion(reason)],16)
		var group_id: String=str(stats_focus.get("group",""))
		if not group_id.is_empty():
			var group: Dictionary=service.table_group_by_id(group_id)
			var historical_name: String=str(stats_focus.get("group_name",group_id))
			label(content,"Группа: "+(str(group.get("name",historical_name)) if not group.is_empty() else historical_name)+" · ID "+group_id,16)
		var stations: Array=stats_focus.get("stations",[]) if stats_focus.get("stations",[]) is Array else []
		if not stations.is_empty():
			label(content,"Столы: "+", ".join(stations.map(func(id):return str(id))),16)
			for raw_id in stations:
				var station_id: int=int(raw_id)
				var station=service.by_id(station_id)
				if station==null: continue
				var details: String="Стол %d · %s"%[station_id,service.station_group_status(station_id,dish) if not dish.is_empty() else "активен"]
				if not dish.is_empty():
					details+=" · запись: "+service.source_label(station_id,dish)
					var source_data: Dictionary=service._method_source(station,dish)
					var record: Dictionary=service.masterclass_by_id(int(source_data.get("id",0)))
					if not record.is_empty(): details+=" · %.1f с · %s"%[float(record.get("duration",0.0)),str(record.get("effectiveness",{}).get("label","Обычная"))]
				label(content,details,14)
		if stations.is_empty() and not reason.is_empty():
			for detail in service.analytics.loss_details.values():
				if str(detail.get("reason",""))!=reason: continue
				var scenario: Dictionary=detail
				var scenario_button:=button(content,"%s · %d случаев · столы %s"%[Definition.DISHES.get(str(detail.get("dish","")),str(detail.get("dish",""))),int(detail.get("count",0)),", ".join(detail.get("stations",[]).map(func(id):return str(id)))],func():set_stats_focus(scenario))
				scenario_button.tooltip_text="Открыть связанное блюдо, группу, столы и назначенный мастер-класс."
		var linked_course:=0
		if not stations.is_empty() and not dish.is_empty() and is_instance_valid(service.training_queue):
			linked_course=service.training_queue.linked_course_id(stations,dish)
		if linked_course>0:
			button(content,"Открыть связанное обучение #%d"%linked_course,func():open_problem_group(stations,linked_course))
		elif not stations.is_empty():
			button(content,"Открыть связанные столы в группах",func():open_problem_group(stations))
		if reason=="equipment":
			button(content,"Перейти к оснащению и покупкам",func():open_problem_page("stations"))
		elif reason=="workers":
			button(content,"Перейти к выращиванию работников",func():open_problem_page("laboratory"))
		elif reason=="no_station":
			button(content,"Перейти к покупке производственного стола",func():open_problem_page("stations"))
		button(content,"Закрыть подробности",func():set_stats_focus({}))

func shop_button(item: String, station_id: int, installed := false) -> void:
	var p = game.service.progress
	var spec: Dictionary = game.shop.ITEMS[item]
	var gate: int = int(spec.get("star", 0))
	var reason: String = ""
	if p.stars < gate: reason = "Нужна звезда %d" % gate
	elif spec.kind == "lab_upgrade": reason = LabPolicy.error(p, item)
	elif spec.kind == "lounge": reason = Lounge.item_error(p, spec)
	elif spec.kind == "station" and not game.shop.type_available(item): reason = "Сначала расширь зал"
	_product_row(content, item, station_id, installed, reason)

func bundle_controls(station: Node3D, catalog: Array) -> void:
	var id: int = station.station_id
	if not selections.has(id): selections[id] = []
	var total: int = 0
	for item in catalog:
		var spec: Dictionary = game.shop.ITEMS[item]
		var installed: bool = item in station.equipment or item in station.upgrades
		var reason: String = "Нужна звезда %d" % int(spec.get("star", 0)) if game.service.progress.stars < int(spec.get("star", 0)) else ""
		var unavailable: bool = installed or not _item_parcel(item, id).is_empty() or not reason.is_empty()
		if unavailable: selections[id].erase(item)
		var row := _product_row(content, item, id, installed, reason, true)
		var check := CheckBox.new()
		check.custom_minimum_size = Vector2(36, 36)
		check.tooltip_text = "Добавить в комплект: " + str(spec.name)
		row.add_child(check)
		row.move_child(check, 0)
		check.disabled = unavailable or game.session.is_guest()
		check.button_pressed = item in selections[id]
		if check.button_pressed: total += int(spec.price)
		check.toggled.connect(func(on):
			if on: selections[id].append(item)
			else: selections[id].erase(item)
			rebuild())
	if total > 0:
		button(content, "Заказать выбранное · %d" % total, func(): send({"action":"buy_bundle", "station":id, "items":selections[id].duplicate(), "installers":send_installers}), game.service.progress.cash >= total and not game.service.progress.busy() and not game.session.is_guest())

func lounge_page() -> void:
	var p=game.service.progress
	var forecast:=Lounge.report(p,game.evening.workers().size())
	var host: bool=not game.session.is_guest()
	label(content,"КОМНАТА ОТДЫХА · "+str(Lounge.STAGES[p.lounge_tier].name),23)
	label(content,"Сегодня: +%d%% к темпу всех клонов. Завтра: +%d%%."%[roundi((p.rest_multiplier-1.0)*100),roundi(float(forecast.bonus)*100)],20)
	label(content,"Мест: %d · клонов: %d · уют: +%d%%. Бонус делится на всю команду, максимум +30%%. Если мест не хватает, общий бонус меньше."%[forecast.places,forecast.workers,roundi(float(forecast.comfort)*100)])
	label(content,"На ночь каждый выбирает одно развлечение. Кровать шефов общая; смешные места сна клонов на темп не влияют. Покупки начнут помогать со следующего утра.",15)
	button(content,"Выбрать мебель и улучшения →",func():open_shop("lounge"))
	button(content,"Расширить помещение →",func():open_shop("rooms"),p.lounge_tier<2)
	var furniture := _fold(content, "lounge-owned", "Установленная мебель · %d" % p.lounge_items.size())
	if furniture != null:
		if p.lounge_items.is_empty(): label(furniture, "Мебель пока не установлена.", 16)
		for id in p.lounge_items: label(furniture, str(Lounge.GOODS[id].name) + (" · улучшено" if id in p.lounge_upgrades else ""), 16)

func lounge_button(item: String, _spec: Dictionary, installed: bool) -> void:
	shop_button(item, 0, installed)

func laboratory_page() -> void:
	var p=game.service.progress
	var host: bool=not game.session.is_guest()
	label(content,"БИОЛАБОРАТОРИЯ · "+str(LabPolicy.STAGES[p.lab_tier].name),23)
	label(content,"Рабочая формула: %d%% · версия %d · предел оборудования: %d%%"%[roundi(p.lab_formula_tempo*100),p.lab_formula_version,roundi(LabPolicy.formula_range(p).y*100)],20)
	lab_live_status=label(content,"")
	button(content,"Оборудование лаборатории →",func():open_shop("lab"))
	var branches:=HFlowContainer.new(); content.add_child(branches)
	for entry in [["formula","Формула"],["growing","Выращивание"],["calibration","Рекалибровка"]]:
		var key: String=entry[0]
		button(branches,("✓ " if lab_branch==key else "")+str(entry[1]),func():lab_branch=key;rebuild())
	match lab_branch:
		"formula":
			label(content,"Собери стол, создай раствор и отнеси образец в микроскоп. Лучшая формула сохраняется сразу. Эксперимент — 20; риск порчи действует при падении ниже зелёной зоны.",16)

		"growing":
			label(content,"Земля → капля (60) → вода → рост → удобрение в рот → рост → извлечение. Готовые этапы спокойно ждут. Темп фиксируется при добавлении капли.",16)
			label(content,"Горшков: %d · скорость выращивания: %d%% · по %d с на каждый этап"%[LabPolicy.pot_count(p),roundi(LabPolicy.growth_speed(p)*100),ceili(75.0/LabPolicy.growth_speed(p))],18)
		"calibration":
			label(content,"Кресло открывается с первой звездой. Нажимай в ритм шести импульсов: хорошее прохождение даёт весь изученный предел, слабое сохраняет прежний темп. Попытка — 10.",16)
			label(content,"Автоматика берёт отстающих по одному после завершения заказа, постепенно повышает темп и возвращает на прежнюю станцию. Приготовление на этой станции ждёт сотрудника.",16)
	if "lab_production" in p.lab_upgrades or "lab_cal_auto" in p.lab_upgrades:
		label(content,"АВТОМАТИКА И ОБЩИЙ ДЕНЕЖНЫЙ РЕЗЕРВ",20)
		var row:=HFlowContainer.new(); content.add_child(row)
		label(row,"Запас свободных клонов:")
		var target_spin:=SpinBox.new(); row.add_child(target_spin); target_spin.min_value=0; target_spin.max_value=20; target_spin.value=lab_target; target_spin.editable=host
		target_spin.value_changed.connect(func(value):lab_target=int(value))
		label(row,"Оставлять денег:")
		var reserve_spin:=SpinBox.new(); row.add_child(reserve_spin); reserve_spin.min_value=0; reserve_spin.max_value=100000; reserve_spin.step=10; reserve_spin.value=lab_reserve; reserve_spin.editable=host
		reserve_spin.value_changed.connect(func(value):lab_reserve=int(value))
		button(content,"Сохранить запас и резерв",func():send({"action":"lab_production_config","enabled":p.lab_production.enabled,"target":lab_target,"reserve":lab_reserve}),host)
		if "lab_production" in p.lab_upgrades:
			button(content,"Выключить автовыпуск" if p.lab_production.enabled else "Включить автовыпуск",func():send({"action":"lab_production_config","enabled":not p.lab_production.enabled,"target":lab_target,"reserve":lab_reserve}),host)
		if "lab_cal_auto" in p.lab_upgrades:
			button(content,"Выключить авторекалибровку" if p.lab_auto_calibration else "Включить авторекалибровку",func():send({"action":"lab_cal_auto","enabled":not p.lab_auto_calibration}),host)
		label(content,"Выпуск учитывает свободные места на станциях, запас и уже посаженных клонов. Резерв ограничивает расходы автовыпуска и автоматического кресла. Автокресло работает днём; растения продолжают расти вечером.",15)

func visit_card() -> void:
	var service=game.service
	var p=service.progress
	var phase:=str(p.visit.get("phase",""))
	if phase.is_empty() or phase=="declined": return
	var host: bool=not game.session.is_guest()
	var data: Dictionary=service.Visits.spec(p)
	label(content,"ДОБРОВОЛЬНЫЙ ВИЗИТ",20)
	visit_live_status=label(content,service.Visits.status(p),17)
	if phase=="offered":
		label(content,"Четыре стандартных заказа лично шефу, все на A или S." if p.visit.kind=="critics" else "Шесть заказов выполняют клоны по принятым записям; минимум пять оценок B или лучше. Личные показы в зачёт не входят.",16)
		label(content,"После принятия: минута на подготовку и четыре минуты на обслуживание. Бонус: %d денег и %d популярности, плюс обычная оплата блюд."%[data.cash,data.popularity],16)
		label(content,"Предложение ждёт без срока. Если сегодня осталось меньше пяти минут, визит назначится на завтра. При неудаче бонуса нет; деньги за поданные блюда сохраняются.",15)
		var id: int=p.visit.id
		button(content,"Принять визит",func():send({"action":"visit_accept","id":id}),host and not p.busy() and p.shift in ["morning","open"] and service.Visits.eligible(service,str(p.visit.kind)))
		button(content,"Пропустить предложение",func():send({"action":"visit_decline","id":id}),host)
	elif service.Visits.busy(p):
		label(content,"Проверку на звезду можно начать после завершения или отмены визита. Закрытие смены завершает начавшийся визит.",15)
		var id: int=p.visit.id
		button(content,"Отменить визит",func():send({"action":"visit_cancel","id":id}),host)
	else:
		label(content,"Следующее предложение появится не раньше дня %d. Можно продолжать развитие кафе."%p.visit_next_day,15)



func _shop_batch(host: bool) -> void:
	var service = game.service
	var progress = service.progress
	label(content, "Новые столы", 21)
	label(content, "Выбери тип кухни, места и оснащение. Каждый стол приедет отдельным комплектом.", 15)
	var type_row:=HFlowContainer.new(); content.add_child(type_row)
	for type_id in ["counter","kitchen","grill_kitchen","solyanka_kitchen"]:
		var chosen_type: String=type_id
		var available: bool=game.shop.type_available(type_id)
		button(type_row,("✓ " if scale_type==type_id else "")+Definition.TYPES[type_id].title,func():set_scale_type(chosen_type),host and available)
	if not game.shop.type_available(scale_type): scale_type="counter"
	label(content,"1. Выбери свободные места",18)
	var free_slots: Array=Expansion.free_slot_ids(service)
	for section in Expansion.SECTION_ROWS:
		var row:=HFlowContainer.new(); content.add_child(row)
		label(row,str(section.name),15)
		for slot_index in section.slots:
			var station_id: int=int(slot_index)+1
			var free: bool=station_id in free_slots and _station_parcel(station_id).is_empty()
			if not free: scale_slots.erase(station_id)
			var check:=CheckBox.new(); row.add_child(check)
			check.text="Место %d"%station_id+(" · занято" if not free else "")
			check.button_pressed=free and station_id in scale_slots
			check.disabled=not host or not free
			check.toggled.connect(func(on):toggle_scale_slot(station_id,on))
	label(content,"2. Оснащение каждого стола",18)
	for item in game.shop.equipment_catalog(scale_type):
		var spec: Dictionary=game.shop.ITEMS[item]
		var available: bool=progress.stars>=int(spec.get("star",0))
		if not available: scale_equipment.erase(item)
		var check:=CheckBox.new(); content.add_child(check)
		check.text=str(spec.name)+" · %d"%int(spec.price)+(" · звезда %d"%int(spec.get("star",0)) if not available else "")
		check.button_pressed=available and item in scale_equipment
		check.disabled=not host or not available
		var equip_id: String=item
		check.toggled.connect(func(on):toggle_scale_equipment(equip_id,on))
	var unit_price: int=int(game.shop.ITEMS[scale_type].price)
	for item in scale_equipment: unit_price+=int(game.shop.ITEMS[item].price)
	var total_price: int=unit_price*scale_slots.size()
	label(content,"Выбрано мест: %d · цена одного комплекта: %d · итого: %d%s"%[scale_slots.size(),unit_price,total_price," · сборщики +0" if send_installers else ""],18)
	button(content,"Заказать выбранные комплекты",func():send({"action":"buy_station_batch","type":scale_type,"stations":scale_slots.duplicate(),"equipment":scale_equipment.duplicate(),"group":"","installers":send_installers}),host and not scale_slots.is_empty() and progress.cash>=total_price and not progress.busy())

func overview_page(host: bool) -> void:
	var service = game.service
	var p = service.progress
	var goal: Dictionary = preload("res://scripts/cafe_journey.gd").current(p, service.stations, service.served, service.open_for_business, service)
	var card := _section_card(content, Color("304943"))
	label(card, "СЛЕДУЮЩИЙ ШАГ · " + str(goal.chapter), 14)
	label(card, str(goal.title), 22)
	label(card, str(goal.detail), 16)
	var actions := HFlowContainer.new()
	card.add_child(actions)
	button(actions, "Закончить смену" if service.open_for_business else "Открыть кафе", func():send({"action":"business"},true), host and not p.busy() and p.shift in ["morning","open"])
	button(actions, "Условия следующей звезды →", func():navigate("star"))
	label(content, "За смену", 20)
	label(content, "Гости обслужены: %d · ушли: %d · доход: %d" % [service.served, service.missed, service.revenue], 17)
	label(content, "Свободные клоны: %d · заказы в магазине: %d" % [p.free_clones, p.deliveries.size()], 16)
	var bottleneck: Dictionary = service.top_bottleneck()
	if not bottleneck.is_empty():
		var problem := _section_card(content, Color("4b4235"))
		label(problem, str(bottleneck.label), 18)
		label(problem, str(bottleneck.suggestion), 16)
		button(problem, "Разобраться →", func():navigate("stats"))
	visit_card()

func settings_page(host: bool) -> void:
	button(content, "Сохранить кафе", func():send({"action":"save"}), host)
	var marker_toggle := CheckBox.new()
	content.add_child(marker_toggle)
	marker_toggle.text = "Показывать ориентир следующего шага"
	marker_toggle.button_pressed = game.journey_markers
	marker_toggle.toggled.connect(func(on):game.journey_markers=on)
	var help := _fold(content, "pc-help", "Как устроено кафе")
	if help != null:
		label(help, "Готовь и записывай мастер-классы за столом Шефа. В разделе «Столы и обучение» выбери столы и открой очередь обучения.", 16)
		label(help, "Столы и оснащение покупаются в интернет-магазине, клоны выращиваются в лаборатории. Статус заказа указан рядом с товаром. Доставленную коробку установи на отмеченное место или дождись сборщика.", 16)
		label(help, "После закрытия смены все игроки ложатся в общую Шеф-кровать. Установленная мебель улучшает отдых клонов со следующего утра.", 16)
	var testing := _fold(content, "pc-playtest", "Инструменты плейтеста")
	if testing != null:
		button(testing, "Открыть папку плейтеста", func():OS.shell_open(ProjectSettings.globalize_path(game.telemetry.folder)))
		label(testing, "F8 — скучно · F9 — непонятно · F10 — прикольно. Отметки сохраняются локально.", 15)
	var reset := _fold(content, "pc-reset", "Новое прохождение…")
	if reset != null:
		label(reset, "Начать кафе заново с потерей текущего прогресса.", 16)
		if confirm_reset:
			button(reset, "Начать заново — подтвердить", func():send({"action":"new_cafe"},true), host and not game.service.any_training() and not game.service.progress.busy())
			button(reset, "Отмена", func():confirm_reset=false;rebuild())
		else: button(reset, "Сбросить прогресс…", func():confirm_reset=true;rebuild(), host)

func videos_page(host: bool) -> void:
	var service = game.service
	var has_tv: bool = "television" in service.progress.lounge_items
	label(content, "Сохранённые способы приготовления. Добавляй их в обучение или смотри на телевизоре комнаты отдыха.", 16)
	if service.masterclasses.is_empty():
		label(content, "Пока нет мастер-классов. Запиши первое блюдо за столом Шефа.", 18)
		return
	for record in service.masterclasses:
		var id: int = int(record.get("id", 0))
		var card := _section_card(content)
		label(card, str(record.get("name", "Запись")), 19)
		label(card, "%s · качество %s · %.1f с" % [Definition.DISHES.get(str(record.get("dish","")),str(record.get("dish",""))), str(record.get("quality",{}).get("grade","D")), float(record.get("duration",0.0))], 15)
		var actions := HFlowContainer.new()
		card.add_child(actions)
		button(actions, "Добавить в обучение →", func():course_editor_open(id), host)
		var watch := button(actions, "Смотреть на ТВ", func():send({"action":"masterclass_watch","id":id},true), has_tv and float(record.get("highlight_duration",0.0))>0.0)
		if not has_tv: watch.tooltip_text = "Сначала установи телевизор: Интернет-магазин → Мебель."
		var detail := _fold(card, "record-%d" % id, "Подробности и название")
		if detail == null: continue
		label(detail, str(record.get("effectiveness",{}).get("explanation","")), 15)
		if bool(record.get("archived",false)): label(detail, "Архивная запись", 15)
		var edit := LineEdit.new()
		edit.text = str(record.get("name",""))
		edit.editable = host
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.add_child(edit)
		var edits := HFlowContainer.new()
		detail.add_child(edits)
		button(edits, "Переименовать", func():send({"action":"masterclass_rename","id":id,"name":edit.text}), host)
		if confirm_delete_masterclass == id:
			button(edits, "Подтвердить удаление", func():send({"action":"masterclass_delete","id":id});confirm_delete_masterclass=-1, host)
			button(edits, "Отмена", func():confirm_delete_masterclass=-1;rebuild())
		else: button(edits, "Удалить…", func():confirm_delete_masterclass=id;rebuild(), host)

func _equipment_purchase_counts(station: Node3D) -> Dictionary:
	var available := 0
	var locked := 0
	var station_id: int = station.station_id
	for item in game.shop.equipment_catalog(station.type_id):
		var spec: Dictionary = game.shop.ITEMS[item]
		if game.service.progress.stars < int(spec.get("star", 0)):
			locked += 1
		elif item not in station.equipment and item not in station.upgrades and _item_parcel(item, station_id).is_empty():
			available += 1
	return {"available":available, "locked":locked}

func _equipment_picker_text(station: Node3D) -> String:
	var title: String = ("Шеф" if station.manual_station else "Стол %d" % station.station_id) + " · " + str(Definition.TYPES.get(station.type_id,{}).get("title",station.type_id))
	var counts: Dictionary = _equipment_purchase_counts(station)
	return "%s    К покупке: %d · закрыто: %d" % [title, int(counts.available), int(counts.locked)]

func shop_page(host: bool) -> void:
	var categories := HFlowContainer.new()
	categories.add_theme_constant_override("h_separation", 6)
	content.add_child(categories)
	for entry in [["equipment","Оснащение"],["tables","Новые столы"],["rooms","Расширения"],["lab","Лаборатория"],["lounge","Мебель"],["decor","Декор"]]:
		var key: String = entry[0]
		var choice := button(categories, str(entry[1]), func():shop_category=key;scroll.scroll_vertical=0;rebuild())
		choice.toggle_mode = true
		choice.set_pressed_no_signal(shop_category == key)
	var installer := CheckBox.new()
	installer.text = "Сборка при доставке · бесплатно"
	installer.tooltip_text = "Сборщики устанавливают столы, кухонное оснащение и мебель. Остальные коробки устанавливай вручную."
	installer.button_pressed = send_installers
	installer.disabled = not host
	installer.toggled.connect(func(on):send_installers=on)
	content.add_child(installer)
	match shop_category:
		"equipment":
			label(content, "Оснащение стола", 21)
			var picker := OptionButton.new()
			picker.custom_minimum_size.y = 42
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content.add_child(picker)
			var selected_index: int = 0
			for station in game.service.stations:
				var id: int = station.station_id
				picker.add_item(_equipment_picker_text(station), id)
				if id == shop_station_id: selected_index = picker.item_count - 1
			if picker.item_count == 0:
				label(content, "Сначала установи стол из категории «Новые столы».", 16)
				return
			picker.select(selected_index)
			shop_station_id = picker.get_item_id(selected_index)
			picker.item_selected.connect(func(index):shop_station_id=picker.get_item_id(index);rebuild())
			var station = game.service.by_id(shop_station_id)
			label(content, "Отметь нужные предметы и закажи одним комплектом.", 15)
			bundle_controls(station, game.shop.equipment_catalog(station.type_id))
		"tables": _shop_tables(host)
		"rooms": _shop_rooms(host)
		"lab":
			label(content, "Оборудование лаборатории", 21)
			var branches := HFlowContainer.new()
			content.add_child(branches)
			for entry in [["formula","Формула"],["growing","Выращивание"],["calibration","Рекалибровка"]]:
				var branch: String = str(entry[0])
				var choose := button(branches, str(entry[1]), func():lab_branch=branch;rebuild())
				choose.toggle_mode = true
				choose.set_pressed_no_signal(lab_branch == branch)
			if lab_branch == "formula":
				for i in range(3): shop_button("lab_%d" % i, 0, i < game.service.progress.lab_stage)
			for id in LabPolicy.ITEMS:
				if str(LabPolicy.ITEMS[id].branch) == lab_branch: shop_button(id, 0, id in game.service.progress.lab_upgrades)
		"lounge":
			label(content, "Мебель и улучшения", 21)
			for id in Lounge.GOODS:
				shop_button("rest_"+id, 0, id in game.service.progress.lounge_items)
				if id in game.service.progress.lounge_items and float(Lounge.GOODS[id].quality)>0:
					shop_button("rest_upgrade_"+id, 0, id in game.service.progress.lounge_upgrades)
		"decor":
			label(content, "Декор кафе", 21)
			for item in ["sign","plants","lights"]: shop_button(item, 0, item in game.service.progress.decorations or (item=="lights" and game.service.progress.garland_owned))
	_refresh_delivery_labels()

func _shop_rooms(host: bool) -> void:
	var p = game.service.progress
	label(content, "Расширение помещений", 21)
	for spec in [
		{"name":"Зал", "kind":"expansion", "owned":p.expanded, "price":180, "star":2},
		{"name":"Специализированный сектор", "kind":"specialty_expansion", "owned":p.specialized_expanded, "price":p.SPECIALTY_EXPANSION_PRICE, "star":3},
		{"name":"Сектор оркестрации", "kind":"orchestration_expansion", "owned":p.orchestration_expanded, "price":p.ORCHESTRATION_EXPANSION_PRICE, "star":4}]:
		_expansion_row(spec, host, false)
	if p.lab_tier<2:
		var next: Dictionary = LabPolicy.STAGES[p.lab_tier+1]
		_expansion_row({"name":"Лаборатория · "+str(next.name),"kind":"lab_expansion","owned":false,"price":next.price,"star":next.star}, host, true)
	else: label(content,"Лаборатория полностью расширена",16)
	if p.lounge_tier<2:
		var next: Dictionary = Lounge.STAGES[p.lounge_tier+1]
		_expansion_row({"name":"Отдых · "+str(next.name),"kind":"lounge_expansion","owned":false,"price":next.price,"star":next.star}, host, true)
	else: label(content,"Комната отдыха полностью расширена",16)

func _expansion_row(spec: Dictionary, host: bool, sleep_gate: bool) -> void:
	var p = game.service.progress
	var card := _section_card(content)
	var row := HBoxContainer.new()
	card.add_child(row)
	label(row, str(spec.name), 17)
	var reason: String = "Открыто" if bool(spec.owned) else "Нужна звезда %d"%int(spec.star) if p.stars<int(spec.star) else "Дождись пробуждения игроков" if sleep_gate and not game.session.sleeping_peers.is_empty() else "Заверши проверку" if p.busy() else "Не хватает %d"%(int(spec.price)-p.cash) if p.cash<int(spec.price) else ""
	var action := button(row, "Открыто" if spec.owned else "Расширить · %d"%int(spec.price), func():send({"action":"buy","kind":str(spec.kind)}), host and reason.is_empty())
	action.custom_minimum_size.x = 200
	if not reason.is_empty() and not spec.owned: label(card,reason,14)

func _station_parcel(station_id: int) -> Dictionary:
	for parcel in game.service.progress.deliveries:
		if int(parcel.get("station",0)) == station_id: return parcel
	return {}

func _item_parcel(item: String, station_id: int) -> Dictionary:
	for parcel in game.service.progress.deliveries:
		if int(parcel.get("station",0)) == station_id and item in parcel.get("items",[parcel.get("item","")]): return parcel
	return {}

func _parcel_status(parcel: Dictionary) -> String:
	if float(parcel.get("remaining",0.0)) > 0.0: return "Доставляется"
	var job: Dictionary = game.shop.installer_job_for_delivery(int(parcel.get("id",0)))
	var phase: String = str(job.get("phase",parcel.get("installer_state","")))
	if phase == "installing": return "Устанавливается"
	return "Ожидает установки"

func _delivery_tooltip(parcel: Dictionary) -> String:
	var parts: Array[String] = []
	if float(parcel.get("remaining",0.0)) > 0: parts.append("До прибытия: %d с"%ceili(float(parcel.remaining)))
	elif int(parcel.get("owner",0)) > 0: parts.append("Коробку несёт игрок к месту установки.")
	elif bool(parcel.get("installer",false)):
		var job: Dictionary = game.shop.installer_job_for_delivery(int(parcel.get("id",0)))
		var phase: String = str(job.get("phase",parcel.get("installer_state","")))
		parts.append("Сборщик устанавливает заказ." if phase=="installing" else "Сборщик ждёт освобождения места." if phase=="waiting" else "Сборщик идёт с заказом к месту установки.")
	else: parts.append("Забери коробку у входа и установи на отмеченное место.")
	var note: String = game.shop.parcel_plan_note(parcel)
	if not note.is_empty(): parts.append(note)
	return "\n".join(parts)

func _product_row(parent: Node, item: String, station_id: int, installed: bool, reason: String, selection := false) -> HBoxContainer:
	var p = game.service.progress
	var spec: Dictionary = game.shop.ITEMS[item]
	var parcel: Dictionary = _item_parcel(item, station_id)
	var card := _section_card(parent)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var title := label(row, str(spec.name), 17)
	title.tooltip_text = str(spec.name)
	var state := label(row, "", 15)
	state.custom_minimum_size.x = 205
	state.size_flags_horizontal = Control.SIZE_FILL
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var state_text: String = "Установлено" if installed else reason if not reason.is_empty() else "%d"%int(spec.price)
	state.text = _parcel_status(parcel) if not parcel.is_empty() else state_text
	state.add_theme_color_override("font_color", Style.GOLD if not parcel.is_empty() else Style.MINT if installed else Style.CREAM)
	delivery_labels.append({"label":state,"item":item,"station":station_id,"fallback":state_text})
	if not selection and not installed and parcel.is_empty():
		var enabled: bool = not installed and parcel.is_empty() and reason.is_empty() and p.cash>=int(spec.price) and not p.busy() and not game.session.is_guest()
		var buy := button(row, "Купить · %d"%int(spec.price), func():send({"action":"buy","kind":"item","item":item,"station":station_id,"installers":send_installers}), enabled)
		buy.custom_minimum_size.x = 155
		if not enabled: buy.tooltip_text = "Покупки доступны хозяину кафе" if game.session.is_guest() else "Уже установлено" if installed else _delivery_tooltip(parcel) if not parcel.is_empty() else reason if not reason.is_empty() else "Заверши проверку" if p.busy() else "Не хватает %d"%(int(spec.price)-p.cash)
	return row

func _refresh_delivery_labels() -> void:
	for entry in delivery_labels:
		var node: Label = entry.label
		if not is_instance_valid(node): continue
		var parcel: Dictionary = game.shop.parcel_by_id(int(entry.parcel_id)) if entry.has("parcel_id") else _item_parcel(str(entry.item),int(entry.station))
		node.text = str(entry.fallback) if parcel.is_empty() else _parcel_status(parcel)
		node.tooltip_text = "" if parcel.is_empty() else _delivery_tooltip(parcel)

func _pending_table_rows() -> void:
	for parcel in game.service.progress.deliveries:
		var item: String = str(parcel.get("item",""))
		if str(game.shop.ITEMS.get(item,{}).get("kind","")) != "station" or int(parcel.get("station",0))<=Expansion.BASE_SLOT_COUNT: continue
		var card := _section_card(content)
		var row := HBoxContainer.new()
		card.add_child(row)
		label(row, "%s · место %d"%[game.shop.parcel_name(parcel),int(parcel.station)], 16)
		var state := label(row, _parcel_status(parcel), 15)
		state.custom_minimum_size.x = 205
		state.size_flags_horizontal = Control.SIZE_FILL
		state.add_theme_color_override("font_color", Style.GOLD)
		delivery_labels.append({"label":state,"parcel_id":int(parcel.id),"fallback":"Установлено"})

func _shop_tables(host: bool) -> void:
	label(content, "Столы основного зала", 21)
	label(content, "Стол и оснащение покупаются отдельно. Работников можно вырастить в лаборатории.", 15)
	for entry in [[2,"counter"],[3,"counter"],[4,"kitchen"],[5,"grill_kitchen"],[6,"solyanka_kitchen"]]:
		var id: int = int(entry[0])
		var item: String = str(entry[1])
		var spec: Dictionary = game.shop.ITEMS[item]
		var reason: String = ""
		if game.service.progress.stars<int(spec.get("star",0)): reason="Нужна звезда %d"%int(spec.get("star",0))
		elif not game.shop.type_available(item): reason="Сначала расширь зал"
		elif id==3 and game.service.by_id(2)==null and _station_parcel(2).is_empty(): reason="Сначала закажи стол 2"
		var row := _product_row(content,item,id,game.service.by_id(id)!=null,reason)
		var name_label: Label = row.get_child(0)
		name_label.text = "Стол %d · %s"%[id,str(spec.name)]
	var extras := _fold(content,"shop-batch","Дополнительные секции · заказать несколько столов")
	if extras != null:
		var outer: VBoxContainer = content
		content = extras
		_shop_batch(host)
		content = outer
	_pending_table_rows()
