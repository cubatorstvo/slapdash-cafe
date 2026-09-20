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
var group_merge_choices: Dictionary={}
var group_merge_active: Array=[]
var group_merge_active_initialized:=false
var lab_branch := "formula"
var lab_target := 2
var lab_reserve := 150
var visit_live_status: Label
var lab_live_status: Label
var scale_type := "counter"
var scale_slots: Array=[]
var scale_equipment: Array=[]
var scale_group := ""
var send_installers := false
var stats_focus: Dictionary={}
var course_focus_id:=0
var groups_mode:="overview"
var group_expanded: Dictionary={}
var group_management_open:=false
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

func _ready() -> void:
	layer = 17
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 100
	panel.offset_right = -100
	panel.offset_top = 164
	panel.offset_bottom = -40
	panel.theme = Style.make()
	panel.add_theme_stylebox_override("panel", Style.box(Color("203b3c"), 20, 22))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	heading = label(top, "МОЁ КАФЕ", 26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "Вернуться · Esc", close)
	status = label(column, "", 18)
	timer = label(column, "", 19)
	timer.add_theme_color_override("font_color", Style.GOLD)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for entry in [["overview","Кафе"],["stats","Лента / статистика"],["stations","Интернет-магазин"],["videos","Видеотека"],["groups","Группы столов"],["laboratory","Лаборатория"],["lounge","Комната отдыха"],["deliveries","Доставки"],["star","Звёзды"]]:
		var key: String = entry[0]
		button(tabs, entry[1], func(): tab = key; stamp = ""; rebuild())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	panel.hide()

func label(parent: Node, text: String, size := 17) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	parent.add_child(node)
	return node

func button(parent: Node, text: String, callback: Callable, enabled := true) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 44
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
	tab = page
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
	group_merge_choices={}
	group_merge_active=[]
	group_merge_active_initialized=false
	stats_focus={}
	course_focus_id=0
	groups_mode="overview"
	group_expanded={}
	group_management_open=false
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
			course_editor_message="Курс не найден."
		else:
			course_editor.mode=str(view.get("mode","together"))
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
		if not record.is_empty(): training_type_filter=str(record.get("source_type",""))
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
		course_editor_message="Эта запись относится к другой кухне. Сформируй для неё отдельный курс."
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
	if mode in ["together","by_groups"]: course_editor.mode=mode
	stamp=""
	rebuild()

func _course_group_id_for_station(station_id: int) -> String:
	return game.service.group_id_for_station(station_id)

func _sync_course_group_order() -> void:
	var valid: Array=[]
	for raw_id in group_selected_stations:
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
	if notice=="Курс поставлен в очередь.":
		course_editor={}
		course_editor_message=""
		course_group_order=[]
	else:
		course_editor_message=notice if not notice.is_empty() else "Курс не подтверждён. Проверь актуальный предпросмотр."
	stamp=""
	rebuild()

func set_group_selected(id: String,on: bool) -> void:
	if on and id not in group_selected_groups: group_selected_groups.append(id)
	elif not on: group_selected_groups.erase(id)
	group_merge_choices={}
	group_merge_active=[]
	group_merge_active_initialized=false
	stamp=""
	rebuild()

func set_merge_choice(dish: String,record_id: int) -> void:
	group_merge_choices[dish]=record_id
	stamp=""
	rebuild()

func set_merge_active(dish: String,on: bool) -> void:
	group_merge_active_initialized=true
	if on and dish not in group_merge_active: group_merge_active.append(dish)
	elif not on: group_merge_active.erase(dish)
	stamp=""
	rebuild()

func set_scale_type(value: String) -> void:
	scale_type=value
	scale_slots=[]
	scale_equipment=[]
	scale_group=""
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
	var progress = game.service.progress
	status.text = "Деньги: %d    Популярность: %d    Звёзды: %d / 5    Гости: %s" % [progress.cash, progress.popularity, progress.stars, "приходят" if game.service.open_for_business else "приём закрыт"]
	timer.text = "%s · %d:%02d" % ["Личный показ" if progress.phase == "showcase" else progress.inspection_name(), ceili(progress.remaining) / 60, ceili(progress.remaining) % 60] if progress.phase in ["showcase", "service"] else ""
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
	var offset := scroll.scroll_vertical
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	var service = game.service
	var progress = service.progress
	var host: bool = not game.session.is_guest()
	if not host: label(content,"Покупки подтверждает хозяин кафе. Коробки можно распаковывать вместе.",15)
	match tab:
		"overview":
			var goal: Dictionary=preload("res://scripts/cafe_journey.gd").current(progress,service.stations,service.served,service.open_for_business,service)
			label(content,str(goal.chapter),16)
			label(content,str(goal.title),22)
			label(content,str(goal.detail),17)
			var marker_toggle:=CheckBox.new(); content.add_child(marker_toggle)
			marker_toggle.text="Показывать ориентир следующего шага"
			marker_toggle.button_pressed=game.journey_markers
			marker_toggle.toggled.connect(func(on):game.journey_markers=on)
			button(content,"Закончить смену" if service.open_for_business else "Открыть кафе",func():send({"action":"business"},true),host and not progress.busy() and progress.shift in ["morning","open"])
			label(content,"Личная стойка — твои заказы. Купленное оборудование приедет ко входу: забери коробку и установи на отмеченное место.")
			label(content,"Свободных клонов: %d. Стол, оборудование и работник приобретаются отдельно.\nПосле первой звезды: эксперимент — 20, микроскоп сохраняет формулу, посадка — 60. Вырасти клона, прими запись блюда и дождись его первого заказа."%progress.free_clones)
			label(content,"Ночью посетителей нет. Все игроки ложатся в общую Шеф-кровать, чтобы начать новый день. Доставки и обустройство доступны днём тоже.")
			label(content,"ОБСЛУЖИВАНИЕ",19)
			label(content,"Гости: пришло %d · обслужено %d · ушло %d"%[service.guests_arrived,service.served,service.missed],15)
			label(content,"Заказы: завершено %d · частично %d · не выполнено %d"%[int(service.order_stats.orders_completed),int(service.order_stats.orders_partial),int(service.order_stats.orders_failed)],15)
			label(content,"Порции: заказано %d · выдано %d · не получено %d"%[int(service.order_stats.portions_ordered),int(service.order_stats.portions_served),int(service.order_stats.portions_unserved)],15)
			var completion: float=Insights.completion_percent(int(service.order_stats.orders_completed),int(service.order_stats.orders_arrived))
			label(content,"%d из %d заказов выполнено · %.0f%% · доход %d"%[int(service.order_stats.orders_completed),int(service.order_stats.orders_arrived),completion,service.revenue],16)
			var bottleneck: Dictionary=service.top_bottleneck()
			if not bottleneck.is_empty(): label(content,"Сейчас мешает: %s (%d). %s"%[bottleneck.label,bottleneck.count,bottleneck.suggestion],15)
			button(content,"Открыть ленту и подробную статистику",func():tab="stats";stamp="";rebuild())
			if progress.journey_auto_served>0:
				label(content,"Другие пути развития: повысить формулу в лаборатории или улучшить прогноз отдыха. Выбирай то, что сейчас полезнее твоему кафе.",15)
				button(content,"Формулы и выращивание",func():tab="laboratory";stamp="";rebuild())
				button(content,"Комната отдыха и прогноз бонуса",func():tab="lounge";stamp="";rebuild())
			visit_card()
			button(content,"Сохранить кафе",func():send({"action":"save"}),host)
			button(content,"Папка плейтеста",func():OS.shell_open(ProjectSettings.globalize_path(game.telemetry.folder)))
			label(content,"Отметки для плейтеста: F8 — скучно, F9 — непонятно, F10 — прикольно. События пишутся локально.",15)
			if confirm_reset:
				button(content,"Подтвердить новое прохождение",func():send({"action":"new_cafe"},true),host and not service.any_training() and not progress.busy())
			else: button(content,"Новое прохождение…",func():confirm_reset=true;rebuild())
		"stats":
			stats_page()
		"stations", "decor", "night":
			label(content,"ТЯП-ЛЯП МАРКЕТ · доставка в коробках",23)
			label(content,"Цена указана за комплект. Выбери станцию; коробка покажет её место установки. Продукты на станции возобновляются на каждый заказ.",15)
			for station in service.stations:
				label(content,"ТВОЯ СТОЙКА" if station.manual_station else "СТАНЦИЯ %d" % station.station_id,20)
				var catalog: Array = ["sauce","plates","cup","pan","jug","sauce_ramp"] if station.type_id=="counter" else ["grill_kit","assembly_kit"] if station.type_id=="grill_kitchen" else ["fire_kit","stir_kit","salt_kit"] if station.type_id=="solyanka_kitchen" else ["meat_kit","pasta_kit"]
				if progress.stars<1:
					for item in catalog: shop_button(item,station.station_id,item in station.equipment or item in station.upgrades)
				else: bundle_controls(station,catalog)
			label(content,"МАСШТАБИРОВАНИЕ · ПОДГОТОВЛЕННЫЕ СЕКЦИИ",20)
			label(content,"Новые секции дают 14 дополнительных мест. Всего есть 20 слотов: 1 шеф-станция + максимум 19 производственных мест. Один выбранный комплект = одна коробка на конкретное место.",15)
			var type_row:=HBoxContainer.new(); content.add_child(type_row)
			for type_id in ["counter","kitchen","grill_kitchen","solyanka_kitchen"]:
				var chosen_type: String=type_id
				var available: bool=game.shop.type_available(type_id)
				button(type_row,("✓ " if scale_type==type_id else "")+Definition.TYPES[type_id].title,func():set_scale_type(chosen_type),host and available)
			if not game.shop.type_available(scale_type): scale_type="counter"
			label(content,"МЕСТА УСТАНОВКИ",17)
			var free_slots: Array=Expansion.free_slot_ids(service)
			for section in Expansion.SECTION_ROWS:
				var row:=HBoxContainer.new(); content.add_child(row)
				label(row,str(section.name),15)
				for slot_index in section.slots:
					var station_id: int=int(slot_index)+1
					var free: bool=station_id in free_slots and not game.shop.pending(scale_type,station_id)
					if not free: scale_slots.erase(station_id)
					var check:=CheckBox.new(); row.add_child(check)
					check.text=str(station_id)+(" · занято" if not free else "")
					check.button_pressed=free and station_id in scale_slots
					check.disabled=not host or not free
					check.toggled.connect(func(on):toggle_scale_slot(station_id,on))
			label(content,"ОСНАЩЕНИЕ КАЖДОЙ КОРОБКИ",17)
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
			label(content,"ГРУППА И УЧЕБНЫЙ ПЛАН",17)
			button(content,("✓ " if scale_group.is_empty() else "")+"Без группы",func():scale_group="";stamp="";rebuild(),host)
			for group in service.table_groups():
				if str(group.type)!=scale_type: continue
				var group_id: String=str(group.id)
				button(content,("✓ " if scale_group==group_id else "")+str(group.name),func():scale_group=group_id;stamp="";rebuild(),host)
			var installer_toggle:=CheckBox.new(); content.add_child(installer_toggle)
			installer_toggle.text="Прислать сборщиков · бесплатно"
			installer_toggle.button_pressed=send_installers
			installer_toggle.disabled=not host
			installer_toggle.toggled.connect(func(on):send_installers=on;stamp="";rebuild())
			var unit_price: int=int(game.shop.ITEMS[scale_type].price)
			for item in scale_equipment: unit_price+=int(game.shop.ITEMS[item].price)
			var total_price: int=unit_price*scale_slots.size()
			label(content,"Выбрано мест: %d · цена одного комплекта: %d · итого: %d%s"%[scale_slots.size(),unit_price,total_price," · сборщики +0" if send_installers else ""],18)
			if not scale_group.is_empty():
				var plan: Dictionary=game.shop.group_training_plan(scale_group,scale_type)
				label(content,"Учебный план: "+(", ".join(plan.keys().map(func(dish):return Definition.DISHES.get(str(dish),str(dish)))) if not plan.is_empty() else "у группы нет доступных фильмов"),15)
			button(content,"Заказать выбранные комплекты",func():send({"action":"buy_station_batch","type":scale_type,"stations":scale_slots.duplicate(),"equipment":scale_equipment.duplicate(),"group":scale_group,"installers":send_installers}),host and not scale_slots.is_empty() and progress.cash>=total_price and not progress.busy())
			label(content,"РАСШИРЕНИЕ КУХНИ",20)
			shop_button("counter",0,service.by_id(2)!=null and service.by_id(3)!=null)
			button(content,"Расширение зала · 180",func():send({"action":"buy","kind":"expansion"}),host and progress.stars>=2 and not progress.expanded and progress.cash>=180)
			shop_button("kitchen",0,service.by_id(4)!=null)
			label(content,"СПЕЦИАЛИЗАЦИЯ",20)
			button(content,"Открыть специализированный сектор · %d"%progress.SPECIALTY_EXPANSION_PRICE,func():send({"action":"buy","kind":"specialty_expansion"}),host and progress.stars>=3 and not progress.specialized_expanded and progress.cash>=progress.SPECIALTY_EXPANSION_PRICE)
			shop_button("grill_kitchen",0,service.by_id(5)!=null)
			button(content,"Открыть сектор оркестрации · %d"%progress.ORCHESTRATION_EXPANSION_PRICE,func():send({"action":"buy","kind":"orchestration_expansion"}),host and progress.stars>=4 and not progress.orchestration_expanded and progress.cash>=progress.ORCHESTRATION_EXPANSION_PRICE)
			shop_button("solyanka_kitchen",0,service.by_id(6)!=null)
			label(content,"ЛАБОРАТОРИЯ",20)
			for i in range(3): shop_button("lab_%d"%i,0,i<progress.lab_stage)
			button(content,"Формулы, выращивание и рекалибровка →",func():tab="laboratory";stamp="";rebuild())
			label(content,"ОБУСТРОЙСТВО",20)
			for item in ["sign","plants","lights"]: shop_button(item,0,item in progress.decorations or (item=="lights" and progress.garland_owned))
		"videos":
			label(content,"ВИДЕОТЕКА МАСТЕР-КЛАССОВ",23)
			label(content,"Хайлайты собраны из реальных кадров принятого приготовления и идут ровно 30% исходного времени. Запуск происходит на телевизоре комнаты отдыха.",15)
			var has_tv: bool="television" in progress.lounge_items
			if not has_tv: label(content,"Для просмотра установи телевизор в комнате отдыха.",15)
			if service.masterclasses.is_empty(): label(content,"Пока нет записей. Проведи мастер-класс у шеф-станции.")
			for record in service.masterclasses:
				var id: int=int(record.get("id",0))
				var quality: Dictionary=record.get("quality",{})
				var effect: Dictionary=record.get("effectiveness",{})
				label(content,str(record.get("name","Запись")),20)
				label(content,"%s · %.1f с · фильм %.1f с · качество %s · эффектность: %s"%[Definition.DISHES.get(str(record.get("dish","")),str(record.get("dish",""))),float(record.get("duration",0.0)),float(record.get("highlight_duration",0.0)),str(quality.get("grade","D")),str(effect.get("label","Обычная"))],16)
				button(content,"Посмотреть хайлайты на телевизоре",func():send({"action":"masterclass_watch","id":id},true),has_tv and float(record.get("highlight_duration",0.0))>0.0)
				button(content,"Добавить в курс",func():course_editor_open(id),host)
				label(content,str(effect.get("explanation","Аккуратное приготовление.")),14)
				if bool(record.get("archived",false)): label(content,"Архивная запись из прежнего рабочего способа · стол %d"%int(record.get("source_station",0)),14)
				var row:=HBoxContainer.new(); content.add_child(row)
				var edit:=LineEdit.new(); row.add_child(edit); edit.text=str(record.get("name","")); edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL; edit.editable=host
				button(row,"Переименовать",func():send({"action":"masterclass_rename","id":id,"name":edit.text}),host)
				if confirm_delete_masterclass==id:
					button(row,"Подтвердить удаление",func():send({"action":"masterclass_delete","id":id});confirm_delete_masterclass=-1,host)
					button(row,"Отмена",func():confirm_delete_masterclass=-1;stamp="";rebuild(),host)
				else:
					button(row,"Удалить…",func():confirm_delete_masterclass=id;stamp="";rebuild(),host)
		"groups":
			if groups_mode=="training": training_workspace_page(host)
			else: groups_overview_page(host)
		"laboratory":
			laboratory_page()
		"lounge":
			lounge_page()
		"deliveries":
			label(content,"ДОСТАВКИ",23)
			if progress.deliveries.is_empty() and progress.delivery_history.is_empty(): label(content,"Доставок пока нет.")
			for parcel in progress.deliveries:
				var state := "В пути" if parcel.remaining>0 else ("Сборщик несёт" if parcel.get("installer_state","")=="walking" else "Сборщик ждёт" if parcel.get("installer_state","")=="waiting" else "Сборщик устанавливает" if parcel.get("installer_state","")=="installing" else "Сборщик назначен") if bool(parcel.get("installer",false)) else "Несёт игрок" if parcel.owner>0 else "Доставлено · ждёт ручной установки"
				var method: String="сборщик" if bool(parcel.get("installer",false)) else "вручную"
				label(content,game.shop.parcel_name(parcel)+" · "+method+" · "+state+(" · место %d"%parcel.station if parcel.station>0 else ""))
				var plan_note: String=game.shop.parcel_plan_note(parcel)
				if not plan_note.is_empty(): label(content,plan_note,14)
			if not progress.delivery_history.is_empty():
				label(content,"ЗАВЕРШЕНО",19)
				for completed in progress.delivery_history:
					var method: String="сборщик" if bool(completed.get("installer",false)) else "вручную"
					var completed_name: String=game.shop.parcel_name(completed)
					label(content,"%s · %s · установка завершена%s"%[completed_name,method," · место %d"%int(completed.get("station",0)) if int(completed.get("station",0))>0 else ""],14)
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
	scroll.scroll_vertical = offset



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
	for raw_id in group.stations:
		var id:=int(raw_id)
		if on and id not in group_selected_stations: group_selected_stations.append(id)
		elif not on: group_selected_stations.erase(id)
	group_selected_stations.sort()
	stamp=""
	rebuild()

func clear_group_selection() -> void:
	group_selected_stations.clear()
	stamp=""
	rebuild()

func _selected_group_types() -> Array:
	var result: Array=[]
	for raw_id in group_selected_stations:
		var station: Node3D=game.service.by_id(int(raw_id))
		if station!=null and station.type_id not in result: result.append(station.type_id)
	result.sort()
	return result

func open_training_workspace() -> void:
	training_scope_stations=group_selected_stations.duplicate()
	if training_scope_stations.is_empty():
		for station in game.service.stations:
			if station.manual_station or station.masterclass_station: continue
			training_scope_stations.append(station.station_id)
	training_scope_stations.sort()
	var types:=_training_scope_types()
	training_type_filter=str(types[0]) if not types.is_empty() else ""
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
	label(content,"ГРУППЫ СТОЛОВ",23)
	label(content,"Выбери группу целиком или отдельные столы. Здесь только состояние производства; обучение открывается отдельным экраном.",15)

	var selection:=_section_card(content,Color("244143"))
	var selection_row:=HBoxContainer.new()
	selection.add_child(selection_row)
	var selected_count:=group_selected_stations.size()
	var selection_text: String="Ничего не выбрано" if selected_count==0 else "Выбрано столов: %d"%selected_count
	var selection_label:=label(selection_row,selection_text,17)
	selection_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if selected_count>0:
		var selected_types:=_selected_group_types()
		var type_names: Array=[]
		for type_id in selected_types: type_names.append(str(Definition.TYPES.get(str(type_id),{}).get("title",str(type_id))))
		label(selection,"Типы: "+", ".join(type_names),13)
		button(selection_row,"Обучение · %d столов →"%selected_count,open_training_workspace,host)
		button(selection_row,"Снять выбор",clear_group_selection,host)
	else:
		button(selection_row,"Очередь обучения →",open_training_workspace,host)

	if is_instance_valid(service.staff_training) and service.staff_training.is_active():
		var training_record: Dictionary=service.masterclass_by_id(service.staff_training.record_id)
		var live:=_section_card(content,Color("334b43"))
		label(live,"СЕЙЧАС ИДЁТ ОБУЧЕНИЕ",14)
		label(live,"%s · %s · %d столов"%[str(training_record.get("name",service.staff_training.record.get("name","Запись"))),service.staff_training.phase_label(),service.staff_training.station_ids.size()],17)

	for group in service.table_groups():
		var group_id:=str(group.id)
		var card:=_section_card(content,Color("294647"))
		var header:=HBoxContainer.new()
		card.add_child(header)
		var all_selected: bool=not group.stations.is_empty() and group.stations.all(func(id):return int(id) in group_selected_stations)
		var selected_here: int=group.stations.filter(func(id):return int(id) in group_selected_stations).size()
		var pick:=CheckBox.new()
		pick.button_pressed=all_selected
		pick.disabled=not host
		pick.tooltip_text="Выбрать все столы этой группы"
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
		label(title_box,"%s"%str(group.name),18)
		var subtitle: String="%s · %d столов · работники %d/%d · заказы %.0f%%"%[str(Definition.TYPES.get(str(group.type_id),{}).get("title",group.type_id)),group.stations.size(),int(workers.assigned),int(workers.capacity),pct]
		label(title_box,subtitle,13)
		var issue_count:=_group_equipment_issue_count(group)
		var right_text: String="%d порций · доход %d"%[int(performance.portions_served),int(performance.revenue)]
		if issue_count>0: right_text+=" · ⚠ %d"%issue_count
		if selected_here>0 and not all_selected: right_text+=" · выбрано %d/%d"%[selected_here,group.stations.size()]
		label(header,right_text,13)

		if not expanded: continue

		var active_names: Array=[]
		for dish in group.active_dishes: active_names.append(str(Definition.DISHES.get(str(dish),str(dish))))
		label(card,"Активное меню: "+(", ".join(active_names) if not active_names.is_empty() else "пусто"),14)

		label(card,"СТОЛЫ",14)
		for raw_id in group.stations:
			var station_id:=int(raw_id)
			var station: Node3D=service.by_id(station_id)
			if station==null: continue
			var station_row:=HBoxContainer.new()
			card.add_child(station_row)
			var station_pick:=CheckBox.new()
			station_pick.button_pressed=station_id in group_selected_stations
			station_pick.disabled=not host
			station_pick.toggled.connect(func(on):set_group_station_selected(station_id,on))
			station_row.add_child(station_pick)
			var station_stats: Dictionary=service.analytics.stations.get(str(station_id),{})
			var staff_now: int=station.role_count() if station.staffed<0 else station.staffed
			var state_text: String="обучение: "+station.group_training_state if not station.group_training_state.is_empty() else "готов"
			var missing_count:=0
			for raw_dish in station.recipes.keys():
				if not station.missing_recipe_equipment(str(raw_dish)).is_empty(): missing_count+=1
			if missing_count>0: state_text="⚠ нет оснащения для %d блюд"%missing_count
			var station_label:=label(station_row,"Стол %d · %d/%d работников · %s"%[station_id,staff_now,station.role_count(),state_text],14)
			station_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			label(station_row,"%d заказов · %d порций · %d"%[int(station_stats.get("orders_completed",0)),int(station_stats.get("portions_served",0)),int(station_stats.get("revenue",0))],13)

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
			var dish_status:=label(dish_row,"%d/%d освоили · %s"%[int(summary.get("mastered",0)),int(summary.get("total",group.stations.size())),str(summary.get("desired","не назначено"))],13)
			dish_status.size_flags_horizontal=Control.SIZE_EXPAND_FILL

		var rename_row:=HBoxContainer.new()
		card.add_child(rename_row)
		var group_edit:=LineEdit.new()
		group_edit.text=str(group.name)
		group_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		group_edit.editable=host
		rename_row.add_child(group_edit)
		button(rename_row,"Переименовать",func():send({"action":"group_rename","group":group_id,"name":group_edit.text}),host)
		var selected_ids: Array=group.stations.filter(func(id):return int(id) in group_selected_stations)
		if not selected_ids.is_empty() and selected_ids.size()<group.stations.size():
			button(card,"Отделить выбранные столы в новую группу",func():send({"action":"group_split","group":group_id,"stations":selected_ids.duplicate()}),host)

	var manage_text: String="▾ Управление группами" if group_management_open else "▸ Управление группами"
	button(content,manage_text,func():group_management_open=not group_management_open;stamp="";rebuild(),host)
	if group_management_open: _group_management_page(host)

func _group_management_page(host: bool) -> void:
	var service=game.service
	var box:=_section_card(content,Color("263f40"))
	label(box,"СТРУКТУРА ГРУПП",18)
	label(box,"Редкие операции спрятаны здесь, чтобы не мешать ежедневной работе.",13)
	if not group_selected_stations.is_empty():
		button(box,"Создать отдельную группу из выбранных столов",func():send({"action":"group_create","stations":group_selected_stations.duplicate()}),host)
	label(box,"Объединить существующие группы",15)
	for group in service.table_groups():
		var group_id:=str(group.id)
		var check:=CheckBox.new()
		check.text="%s · %s · %d столов"%[str(group.name),str(Definition.TYPES.get(str(group.type_id),{}).get("title",group.type_id)),group.stations.size()]
		check.button_pressed=group_id in group_selected_groups
		check.disabled=not host
		check.toggled.connect(func(on):set_group_selected(group_id,on))
		box.add_child(check)
	if group_selected_groups.size()<2:
		label(box,"Выбери минимум две группы одного типа кухни.",13)
		return
	var merge_preview: Dictionary=service.preview_group_merge(group_selected_groups)
	if merge_preview.is_empty():
		label(box,"Эти группы относятся к разным типам кухни.",14)
		return
	var type_id:=str(merge_preview.type_id)
	if not group_merge_active_initialized:
		group_merge_active_initialized=true
		for selected_group_id in group_selected_groups:
			var selected_group: Dictionary=service.table_group_by_id(str(selected_group_id))
			for dish in selected_group.active_dishes:
				if dish not in group_merge_active: group_merge_active.append(dish)
	label(box,"Активное меню объединённой группы",14)
	for raw_dish in Definition.TYPES[type_id].dishes:
		var dish_id:=str(raw_dish)
		var toggle:=CheckBox.new()
		toggle.text=str(Definition.DISHES.get(dish_id,dish_id))
		toggle.button_pressed=dish_id in group_merge_active
		toggle.disabled=not host
		toggle.toggled.connect(func(on):set_merge_active(dish_id,on))
		box.add_child(toggle)
	for raw_dish in merge_preview.differences:
		var dish_id:=str(raw_dish)
		label(box,"Для «%s» планы различаются:"%str(Definition.DISHES.get(dish_id,dish_id)),14)
		for raw_record_id in merge_preview.differences[raw_dish]:
			var record_id:=int(raw_record_id)
			if record_id<=0: continue
			var record: Dictionary=service.masterclass_by_id(record_id)
			button(box,("✓ " if int(group_merge_choices.get(dish_id,0))==record_id else "")+str(record.get("name","Запись #%d"%record_id)),func():set_merge_choice(dish_id,record_id),host)
	var ready:=true
	for raw_dish in merge_preview.differences:
		if int(group_merge_choices.get(str(raw_dish),0))<=0: ready=false
	button(box,"Объединить группы",func():send({"action":"group_merge","groups":group_selected_groups.duplicate(),"choices":group_merge_choices.duplicate(true),"active":group_merge_active.duplicate()}),host and ready)

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
	_ensure_draft()
	course_editor.records=_insert_record_ids(_draft_record_ids(),training_library_selection,_draft_record_ids().size())
	course_editor.type_id=training_type_filter
	training_queue_selection=[]
	stamp=""
	rebuild()

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
	send({"action":"training_course_edit","course":int(course.id),"assignments":assignments,"mode":str(course.mode),"group_order":course.get("group_order",[]).duplicate()})

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
			stamp=""
			rebuild()
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
	var preview: Dictionary=game.service.training_course_preview(assignments,str(course_editor.get("mode","together")),course_group_order)
	if not str(preview.get("error","")).is_empty():
		course_editor_message=str(preview.error)
		stamp=""
		rebuild()
		return
	var editing:=int(course_editor.get("editing",0))
	game.hud.notice.text=""
	if editing>0:
		send({"action":"training_course_edit","course":editing,"assignments":assignments,"mode":str(course_editor.get("mode","together")),"group_order":course_group_order.duplicate()})
	else:
		var command: String="office-course:%d:%d:%d"%[game.service.progress.day,int(game.service.training_queue.next_course_id),course_command_serial]
		course_command_serial+=1
		send({"action":"training_course_confirm","assignments":assignments,"mode":str(course_editor.get("mode","together")),"group_order":course_group_order.duplicate(),"command":command})
	var notice:=str(game.hud.notice.text)
	if notice=="Курс поставлен в очередь.":
		course_editor={}
		course_editor_message=""
		course_group_order=[]
		training_queue_selection=[]
	else:
		course_editor_message=notice if not notice.is_empty() else "Курс не подтверждён. Проверь актуальное расписание."
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
		button(box,"Добавить выбранные в новый курс →",training_add_selected_to_draft,host)

func _training_drop_tail(parent: Node,zone: String,course_id: int,index: int,text_value: String) -> void:
	var target=TrainingDragRow.new()
	parent.add_child(target)
	target.setup({"zone":zone,"course_id":course_id,"index":index},text_value,"Перетащи сюда")
	target.drag_payload={}
	target.row_dropped.connect(func(data,meta,after):_training_drop(data,meta,after))

func _training_draft_card(parent: Node,host: bool) -> void:
	var service=game.service
	var box:=_section_card(parent,Color("30494a"))
	var records:=_draft_record_ids()
	var editing:=int(course_editor.get("editing",0)) if not course_editor.is_empty() else 0
	label(box,"РЕДАКТИРОВАНИЕ КУРСА #%d"%editing if editing>0 else "НОВЫЙ КУРС",17)
	var targets:=_training_target_stations()
	label(box,"%d столов · %s"%[targets.size(),str(Definition.TYPES.get(training_type_filter,{}).get("title",training_type_filter))],13)
	if records.is_empty():
		_training_drop_tail(box,"draft",0,0,"Перетащи сюда одно или несколько блюд")
	else:
		for index in range(records.size()):
			var record_id:=int(records[index])
			var record: Dictionary=service.masterclass_by_id(record_id)
			var key:=_queue_key(0,index)
			var subtitle: String=str(record.get("name","Запись"))+" · фильм %.1f с"%float(record.get("highlight_duration",0.0))
			_training_make_drag_row(box,{"zone":"draft","course_id":0,"index":index,"record_id":record_id},str(Definition.DISHES.get(str(record.get("dish","")),str(record.get("dish","")))),subtitle,{"kind":"queue_lessons","course_id":0,"indices":[index],"count":1},key in training_queue_selection,key)
		_training_drop_tail(box,"draft",0,records.size(),"В конец курса")
		var mode_row:=HBoxContainer.new()
		box.add_child(mode_row)
		label(mode_row,"Запуск:",13)
		button(mode_row,("✓ " if str(course_editor.get("mode","together"))=="together" else "")+"Вместе",func():course_editor_set_mode("together"),host)
		button(mode_row,("✓ " if str(course_editor.get("mode","together"))=="by_groups" else "")+"По группам",func():course_editor_set_mode("by_groups"),host)
		var preview:=service.training_course_preview(_draft_assignments(),str(course_editor.get("mode","together")),course_group_order)
		var error:=str(preview.get("error",""))
		if not error.is_empty():
			label(box,error,13)
		else:
			var warning_count:=0
			for lesson in preview.lessons: warning_count+=lesson.get("equipment_issues",[]).size()
			var summary: String="%d сотрудников · фильмы %.1f с · одновременно уйдёт до %d"%[int(preview.employees),float(preview.film_total),int(preview.simultaneous_out)]
			if warning_count>0: summary+=" · ⚠ оснащение: %d"%warning_count
			label(box,summary,13)
			button(box,"▾ Подробности" if training_preview_expanded else "▸ Подробности",toggle_training_preview)
			if training_preview_expanded:
				for lesson in preview.lessons:
					label(box,"%s · освоили %d/%d · %.1f с"%[Definition.DISHES.get(str(lesson.dish),str(lesson.dish)),int(lesson.mastered),int(lesson.selected),float(lesson.film)],13)
					for issue in lesson.get("equipment_issues",[]):
						label(box,"⚠ Стол %d после обучения: нет %s"%[int(issue.get("station",0)),service.equipment_names(issue.get("missing",[]))],12)
			button(box,"Сохранить изменения" if editing>0 else "Поставить в очередь",training_submit_draft,host)
	if not course_editor_message.is_empty(): label(box,course_editor_message,13)

func _training_existing_course_card(parent: Node,course: Dictionary,host: bool) -> void:
	var service=game.service
	var course_id:=int(course.id)
	var box:=_section_card(parent,Color("294647"))
	var header:=HBoxContainer.new()
	box.add_child(header)
	var expanded:=bool(training_course_expanded.get(course_id,course_id==course_focus_id or str(course.state) in ["gathering","watching","returning"]))
	var expand:=Button.new()
	expand.text="▾" if expanded else "▸"
	expand.custom_minimum_size=Vector2(38,36)
	expand.pressed.connect(func():toggle_training_course_expanded(course_id))
	header.add_child(expand)
	var mode_label: String="вместе" if str(course.mode)=="together" else "по группам"
	var station_ids:=_course_station_ids(course)
	var title:=label(header,"Курс #%d · %d уроков · %d столов"%[course_id,course.assignments.size(),station_ids.size()],16)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label(header,"%s · %s"%[mode_label,str(course.state)],13)
	if not expanded: return
	for index in range(course.assignments.size()):
		var assignment: Dictionary=course.assignments[index]
		var record_id:=int(assignment.get("record_id",0))
		var record: Dictionary=service.masterclass_by_id(record_id)
		var key:=_queue_key(course_id,index)
		var subtitle: String=str(record.get("name",assignment.get("name","Запись")))+" · столы "+", ".join(assignment.get("station_ids",[]).map(func(id):return str(id)))
		var payload: Dictionary={"kind":"queue_lessons","course_id":course_id,"indices":[index],"count":1} if bool(course.editable) else {}
		var row: Variant=_training_make_drag_row(box,{"zone":"course","course_id":course_id,"index":index,"record_id":record_id,"draggable":bool(course.editable)},str(Definition.DISHES.get(str(assignment.get("dish","")),str(assignment.get("dish","")))),subtitle,payload,key in training_queue_selection,key)
		row.drop_enabled=bool(course.editable)
	if bool(course.editable):
		_training_drop_tail(box,"course",course_id,course.assignments.size(),"Добавить в конец курса")
		var action_row:=HBoxContainer.new()
		box.add_child(action_row)
		button(action_row,"Настройки курса",func():course_editor_open(0,course_id),host)
		button(action_row,"Отменить курс",func():send({"action":"training_cancel_course","course":course_id}),host)
	for batch in course.batches:
		if str(batch.get("blocked_reason","")).is_empty(): continue
		label(box,"⚠ Ждёт: "+str(batch.blocked_reason),13)

func _training_schedule_panel(parent: Node,host: bool) -> void:
	var box:=_section_card(parent,Color("203b3c"))
	var top:=HBoxContainer.new()
	box.add_child(top)
	var heading_label:=label(top,"РАСПИСАНИЕ",18)
	heading_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if not training_queue_selection.is_empty(): button(top,"Убрать выбранные",training_remove_queue_selection,host)
	training_queue_rows={}
	_training_draft_card(box,host)
	var views: Array=game.service.training_course_views()
	if views.is_empty(): label(box,"Очередь пуста.",14)
	else:
		label(box,"ТЕКУЩАЯ ОЧЕРЕДЬ",14)
		for course in views: _training_existing_course_card(box,course,host)
	var suspended_found:=false
	for group in game.service.table_groups():
		for item in group.curriculum:
			var dish:=str(item.get("dish_id",""))
			for raw_id in group.stations:
				var station_id:=int(raw_id)
				if not game.service.training_queue.assignment_suspended(station_id,dish): continue
				if not suspended_found:
					label(box,"ПРИОСТАНОВЛЕНО",14)
					suspended_found=true
				var desired: Dictionary=game.service.desired_source(str(group.id),dish)
				var row:=HBoxContainer.new()
				box.add_child(row)
				var paused:=label(row,"Стол %d · %s · %s"%[station_id,Definition.DISHES.get(dish,dish),str(desired.get("name","Запись"))],13)
				paused.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				button(row,"Продолжить",func():send({"action":"training_resume","station":station_id,"dish":dish}),host)

func training_workspace_page(host: bool) -> void:
	var service=game.service
	var top:=HBoxContainer.new()
	content.add_child(top)
	button(top,"← Группы столов",back_to_groups_overview)
	var title:=label(top,"ОБУЧЕНИЕ",23)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var scope_count:=training_scope_stations.size()
	label(content,("Выбрано производственных столов: %d."%scope_count if not group_selected_stations.is_empty() else "Показаны все производственные столы: %d."%scope_count)+" Расписание меняет только обучение; состав групп остаётся прежним.",14)
	if training_scope_stations.is_empty():
		label(content,"Сначала вернись к группам и выбери хотя бы один стол.",17)
		return
	var types:=_training_scope_types()
	if training_type_filter.is_empty() and not types.is_empty(): training_type_filter=str(types[0])
	if types.size()>1:
		var type_row:=HBoxContainer.new()
		content.add_child(type_row)
		label(type_row,"Тип кухни:",14)
		for raw_type in types:
			var type_id:=str(raw_type)
			button(type_row,("✓ " if type_id==training_type_filter else "")+str(Definition.TYPES.get(type_id,{}).get("title",type_id)),func():set_training_type_filter(type_id),host)
	var targets:=_training_target_stations()
	var assigned_workers:=0
	var worker_capacity:=0
	for raw_id in targets:
		var station: Node3D=service.by_id(int(raw_id))
		if station==null: continue
		worker_capacity+=station.role_count()
		assigned_workers+=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
	label(content,"%s · %d столов · работников %d/%d · столы %s"%[str(Definition.TYPES.get(training_type_filter,{}).get("title",training_type_filter)),targets.size(),assigned_workers,worker_capacity,", ".join(targets.map(func(id):return str(id)))],14)

	var columns:=HBoxContainer.new()
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

func course_editor_page(host: bool) -> void:
	var service=game.service
	label(content,"ЕДИНЫЙ РЕДАКТОР КУРСА",20)
	if course_editor.is_empty():
		if group_selected_stations.is_empty():
			label(content,"Отметь столы или выбери целую группу выше, затем составь курс. Из видеотеки сюда можно открыть редактор уже с выбранной записью.",14)
			return
		label(content,"Выбраны столы: "+", ".join(group_selected_stations.map(func(id):return str(id))),15)
		button(content,"Составить курс из выбранных столов",func():course_editor_open(),host)
		return
	var type_id: String=str(course_editor.get("type_id",""))
	if type_id.is_empty() and not group_selected_stations.is_empty():
		var first_station=service.by_id(int(group_selected_stations[0]))
		if first_station!=null:
			type_id=str(first_station.type_id)
			course_editor.type_id=type_id
	if not course_editor_message.is_empty(): label(content,course_editor_message,15)
	label(content,"Кухня: "+(str(Definition.TYPES.get(type_id,{}).get("title",type_id)) if not type_id.is_empty() else "выбери столы"),17)
	var scale: Dictionary=service.production_scale_summary()
	label(content,"Масштаб кафе: %d/%d производственных мест · работников %d (%d на столах + %d свободных)"%[int(scale.places),int(scale.max_places),int(scale.workers),int(scale.assigned_workers),int(scale.free_workers)],14)
	if not type_id.is_empty():
		button(content,"Выбрать все совместимые столы",course_editor_select_all_compatible,host)
		label(content,"ГРУППЫ И СТОЛЫ",16)
		for group in service.table_groups():
			if str(group.type_id)!=type_id: continue
			var group_id: String=str(group.id)
			var all_selected: bool=not group.stations.is_empty() and group.stations.all(func(id):return int(id) in group_selected_stations)
			var group_toggle:=CheckBox.new(); content.add_child(group_toggle)
			group_toggle.text="%s · столы %s"%[str(group.name),", ".join(group.stations.map(func(id):return str(id)))]
			group_toggle.button_pressed=all_selected
			group_toggle.disabled=not host
			group_toggle.toggled.connect(func(on):course_editor_select_group(group_id,on))
		for station in service.stations:
			if station.manual_station or station.masterclass_station or station.type_id!=type_id: continue
			var station_id: int=station.station_id
			var station_toggle:=CheckBox.new(); content.add_child(station_toggle)
			station_toggle.text="Стол %d · работников %d/%d"%[station_id,station.staffed if station.staffed>=0 else station.role_count(),station.role_count()]
			station_toggle.button_pressed=station_id in group_selected_stations
			station_toggle.disabled=not host
			station_toggle.toggled.connect(func(on):set_group_station_selected(station_id,on))
	if not group_selected_stations.is_empty():
		label(content,"Выбрано: %d производственных мест"%group_selected_stations.size(),15)
	label(content,"УРОКИ КУРСА",17)
	var records: Array=course_editor.get("records",[])
	if records.is_empty(): label(content,"Добавь хотя бы одну запись. Для одного блюда в курсе хранится только одна версия.",14)
	for index in range(records.size()):
		var record_id: int=int(records[index])
		var record: Dictionary=service.masterclass_by_id(record_id)
		var row:=HBoxContainer.new(); content.add_child(row)
		label(row,"%d. %s · %s"%[index+1,Definition.DISHES.get(str(record.get("dish","")),str(record.get("dish",""))),str(record.get("name","Запись"))],15).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button(row,"↑",func():course_editor_move_record(index,-1),host and index>0)
		button(row,"↓",func():course_editor_move_record(index,1),host and index<records.size()-1)
		button(row,"Убрать",func():course_editor_remove_record(index),host)
	if not type_id.is_empty():
		button(content,"Снять новый мастер-класс на шеф-станции",course_editor_to_chef,host)
		label(content,"ДОСТУПНЫЕ ЗАПИСИ",16)
		for record in service.masterclasses:
			if str(record.get("source_type",""))!=type_id: continue
			var record_id: int=int(record.get("id",0))
			var dish: String=str(record.get("dish",""))
			var exact:=0
			for raw_id in group_selected_stations:
				var station=service.by_id(int(raw_id))
				if station!=null and station.recipes.has(dish) and int(station.method_sources.get(dish,{}).get("id",0))==record_id: exact+=1
			var chosen_same_dish: bool=false
			for chosen_id in records:
				var chosen_record: Dictionary=service.masterclass_by_id(int(chosen_id))
				if str(chosen_record.get("dish",""))==dish: chosen_same_dish=true
			var quality: Dictionary=record.get("quality",{})
			var effect: Dictionary=record.get("effectiveness",{})
			var text: String="%s · %s · %s · %s · %.1f с → фильм %.1f с · освоили %d/%d"%[Definition.DISHES.get(dish,dish),str(record.get("name","Запись")),str(quality.get("grade","D")),str(effect.get("label","Обычная")),float(record.get("duration",0.0)),float(record.get("highlight_duration",0.0)),exact,group_selected_stations.size()]
			var row:=HBoxContainer.new(); content.add_child(row)
			label(row,text,14).size_flags_horizontal=Control.SIZE_EXPAND_FILL
			button(row,"Заменить версию" if chosen_same_dish else "Добавить урок",func():course_editor_add_record(record_id),host)
	label(content,"СПОСОБ ОТПРАВКИ",17)
	var mode_row:=HBoxContainer.new(); content.add_child(mode_row)
	button(mode_row,("✓ " if str(course_editor.get("mode","together"))=="together" else "")+"Вместе",func():course_editor_set_mode("together"),host)
	button(mode_row,("✓ " if str(course_editor.get("mode","together"))=="by_groups" else "")+"По группам",func():course_editor_set_mode("by_groups"),host)
	if str(course_editor.get("mode","together"))=="by_groups":
		_sync_course_group_order()
		label(content,"ПОРЯДОК ПАРТИЙ",16)
		for index in range(course_group_order.size()):
			var group_id: String=str(course_group_order[index])
			var group: Dictionary=service.table_group_by_id(group_id)
			var row:=HBoxContainer.new(); content.add_child(row)
			label(row,"%d. %s"%[index+1,str(group.get("name",group_id))],15).size_flags_horizontal=Control.SIZE_EXPAND_FILL
			button(row,"↑",func():course_editor_move_group(group_id,-1),host and index>0)
			button(row,"↓",func():course_editor_move_group(group_id,1),host and index<course_group_order.size()-1)
	label(content,"ПРЕДПРОСМОТР",17)
	var assignments:=course_editor_assignments()
	var preview: Dictionary=service.training_course_preview(assignments,str(course_editor.get("mode","together")),course_group_order) if not assignments.is_empty() and not group_selected_stations.is_empty() else {"error":"Выбери столы и добавь уроки."}
	var preview_error: String=str(preview.get("error",""))
	if not preview_error.is_empty():
		label(content,preview_error,15)
	else:
		label(content,"Столов: %d · сотрудников: %d · одновременно уйдёт до %d · фильмы: %.1f с"%[int(preview.places),int(preview.employees),int(preview.simultaneous_out),float(preview.film_total)],16)
		label(content,"Время фильмов указано отдельно. Дорога, сбор и ожидание уже принятого заказа зависят от текущего состояния кафе.",14)
		for lesson in preview.lessons:
			label(content,"%s · %s · освоили %d/%d · фильм %.1f с"%[Definition.DISHES.get(str(lesson.dish),str(lesson.dish)),str(lesson.name),int(lesson.mastered),int(lesson.selected),float(lesson.film)],14)
			for issue in lesson.get("equipment_issues",[]):
				label(content,"⚠ Стол %d после обучения не сможет готовить: нет %s"%[int(issue.get("station",0)),service.equipment_names(issue.get("missing",[]))],13)
		for batch_index in range(preview.batches.size()):
			var batch: Dictionary=preview.batches[batch_index]
			var readiness: String="готова" if bool(batch.ready) else "ждёт: "+str(batch.blocked_reason)
			var group_text: String=" · "+str(batch.get("name","")) if not str(batch.get("name","")).is_empty() else ""
			label(content,"Партия %d%s · столы %s · %s"%[batch_index+1,group_text,", ".join(batch.stations.map(func(id):return str(id))),readiness],14)
		label(content,"ИЗМЕНЕНИЯ ГРУПП И ПЛАНОВ",16)
		for projected in preview.groups:
			var intersects: bool=projected.stations.any(func(id):return int(id) in group_selected_stations)
			if not intersects: continue
			var plan_parts: Array=[]
			for item in projected.curriculum:
				var planned: Dictionary=service.masterclass_by_id(int(item.get("record_id",0)))
				plan_parts.append("%s → %s"%[Definition.DISHES.get(str(item.get("dish_id","")),str(item.get("dish_id",""))),str(planned.get("name","Запись #%d"%int(item.get("record_id",0))))])
			label(content,"%s · ID %s · столы %s · %s"%[str(projected.name),str(projected.id),", ".join(projected.stations.map(func(id):return str(id))),", ".join(plan_parts) if not plan_parts.is_empty() else "план пуст"],14)
	var submit_text: String="Сохранить изменения курса" if int(course_editor.get("editing",0))>0 else "Поставить курс в очередь"
	button(content,submit_text,course_editor_submit,host and preview_error.is_empty())
	button(content,"Закрыть редактор",course_editor_close)

func training_queue_page(host: bool) -> void:
	var service=game.service
	label(content,"ОЧЕРЕДЬ ОБУЧЕНИЯ",20)
	var views: Array=service.training_course_views()
	if views.is_empty(): label(content,"Ожидающих и активных курсов нет.",14)
	for course in views:
		var mode_label: String="Вместе" if str(course.mode)=="together" else "По группам"
		var auto_label: String=" · автоматически по плану" if bool(course.get("automatic",false)) else ""
		var linked_prefix: String="→ СВЯЗАННЫЙ " if int(course.id)==course_focus_id else ""
		label(content,"%sКурс #%d · %s · %s%s"%[linked_prefix,int(course.id),mode_label,str(course.state),auto_label],17)
		for assignment in course.assignments:
			label(content,"  %s · %s · столы %s"%[Definition.DISHES.get(str(assignment.dish),str(assignment.dish)),str(assignment.name),", ".join(assignment.station_ids.map(func(id):return str(id)))],14)
		if bool(course.editable): button(content,"Редактировать ожидающий курс",func():course_editor_open(0,int(course.id)),host)
		button(content,"Отменить оставшийся курс #%d"%int(course.id),func():send({"action":"training_cancel_course","course":int(course.id)}),host and str(course.state) not in ["completed","cancelled"])
		for batch in course.batches:
			var reason: String=" · "+str(batch.blocked_reason) if not str(batch.blocked_reason).is_empty() else ""
			label(content,"  Партия #%d · %s · столы %s%s"%[int(batch.id),str(batch.state),", ".join(batch.stations.map(func(id):return str(id))),reason],14)
			if str(batch.state) not in ["completed","cancelled"]:
				button(content,"Отменить оставшуюся партию #%d"%int(batch.id),func():send({"action":"training_cancel_batch","batch":int(batch.id)}),host)
			for lesson in batch.lessons:
				label(content,"    Урок #%d · %s · %s · %s"%[int(lesson.id),Definition.DISHES.get(str(lesson.dish),str(lesson.dish)),str(lesson.name),str(lesson.state)],13)
				if str(lesson.state) not in ["completed","cancelled","superseded"]:
					button(content,"Отменить урок #%d · %s"%[int(lesson.id),str(lesson.name)],func():send({"action":"training_cancel_lesson","lesson":int(lesson.id)}),host)
	var suspended_found:=false
	for group in service.table_groups():
		for item in group.curriculum:
			var dish: String=str(item.get("dish_id",""))
			for raw_id in group.stations:
				var station_id: int=int(raw_id)
				if not service.training_queue.assignment_suspended(station_id,dish): continue
				if not suspended_found:
					label(content,"ПРИОСТАНОВЛЕННЫЕ НАЗНАЧЕНИЯ",17)
					suspended_found=true
				var desired: Dictionary=service.desired_source(str(group.id),dish)
				label(content,"Стол %d · %s · назначено %s · обучение отменено"%[station_id,Definition.DISHES.get(dish,dish),str(desired.get("name","Запись"))],14)
				button(content,"Продолжить обучение · стол %d"%station_id,func():send({"action":"training_resume","station":station_id,"dish":dish}),host)

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
	for entry in service.analytics.feed:
		var source: String="[ИГРОК · %s] "%str(entry.get("source_name","Повар")) if str(entry.get("source","system"))=="player" else "[СИСТЕМА] "
		var text: String=source+service.feed_text(entry)
		var event_button:=button(content,text,func():set_stats_focus(entry))
		var reason: String=str(entry.get("reason",""))
		var tip: String="Нажми, чтобы открыть связанное блюдо, группу и столы."
		if not reason.is_empty(): tip+="\n"+Insights.suggestion(reason)
		event_button.tooltip_text=tip

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
			button(content,"Открыть связанный курс #%d"%linked_course,func():open_problem_group(stations,linked_course))
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
	var waiting: bool = game.shop.pending(item,station_id)
	var gate: int = int(spec.get("star",0))
	var prerequisite: bool = spec.kind!="lab_upgrade" or LabPolicy.error(p,item).is_empty()
	var suffix := " · установлено" if installed else " · доставка заказана" if waiting else " · звезда %d"%gate if p.stars<gate else " · %d"%spec.price
	if not prerequisite: suffix=" · сначала лаборатория / усилитель"
	button(content,spec.name+suffix,func():send({"action":"buy","kind":"item","item":item,"station":station_id,"installers":send_installers}),not game.session.is_guest() and not installed and not waiting and prerequisite and p.stars>=gate and p.cash>=spec.price and not p.busy())

func bundle_controls(station: Node3D, catalog: Array) -> void:
	var id: int=station.station_id
	if not selections.has(id): selections[id]=[]
	var total := 0
	for item in catalog:
		var spec: Dictionary=game.shop.ITEMS[item]
		var unavailable: bool=item in station.equipment or item in station.upgrades or game.shop.pending(item,id) or game.service.progress.stars<int(spec.get("star",0))
		if unavailable: selections[id].erase(item)
		var check := CheckBox.new(); content.add_child(check)
		check.text=spec.name+" · %d"%spec.price+(" · установлено / недоступно" if unavailable else "")
		check.disabled=unavailable or game.session.is_guest()
		check.button_pressed=item in selections[id]
		if check.button_pressed: total+=int(spec.price)
		check.toggled.connect(func(on):
			if on: selections[id].append(item)
			else: selections[id].erase(item)
			rebuild())
	button(content,"Заказать комплект · %d"%total,func():send({"action":"buy_bundle","station":id,"items":selections[id].duplicate(),"installers":send_installers}),total>0 and game.service.progress.cash>=total and not game.service.progress.busy() and not game.session.is_guest())

func lounge_page() -> void:
	var p=game.service.progress
	var forecast:=Lounge.report(p,game.evening.workers().size())
	var host: bool=not game.session.is_guest()
	var installer_toggle:=CheckBox.new(); content.add_child(installer_toggle)
	installer_toggle.text="Прислать сборщика для новых предметов · бесплатно"
	installer_toggle.button_pressed=send_installers
	installer_toggle.disabled=not host
	installer_toggle.toggled.connect(func(on):send_installers=on;stamp="";rebuild())
	label(content,"КОМНАТА ОТДЫХА · "+str(Lounge.STAGES[p.lounge_tier].name),23)
	label(content,"Сегодня: +%d%% к темпу всех клонов. Завтра: +%d%%."%[roundi((p.rest_multiplier-1.0)*100),roundi(float(forecast.bonus)*100)],20)
	label(content,"Мест: %d · клонов: %d · уют: +%d%%. Бонус делится на всю команду, максимум +30%%. Если мест не хватает, общий бонус меньше."%[forecast.places,forecast.workers,roundi(float(forecast.comfort)*100)])
	label(content,"На ночь каждый выбирает одно развлечение. Кровать шефов общая; смешные места сна клонов на темп не влияют. Покупки начнут помогать со следующего утра.",15)
	if p.lounge_tier<2:
		var next: Dictionary=Lounge.STAGES[p.lounge_tier+1]
		var suffix: String=" · нужна звезда %d"%next.star if p.stars<int(next.star) else " · %d"%next.price
		button(content,"Расширить: "+str(next.name)+suffix,func():send({"action":"buy","kind":"lounge_expansion"}),host and p.stars>=int(next.star) and p.cash>=int(next.price) and not p.busy() and game.session.sleeping_peers.is_empty())
	label(content,"МЕБЕЛЬ И УЮТ · доставка в коробках",20)
	for id in Lounge.GOODS:
		var spec: Dictionary=game.shop.ITEMS["rest_"+id]
		lounge_button("rest_"+id,spec,id in p.lounge_items)
		if id in p.lounge_items and float(Lounge.GOODS[id].quality)>0:
			lounge_button("rest_upgrade_"+id,game.shop.ITEMS["rest_upgrade_"+id],id in p.lounge_upgrades)

func lounge_button(item: String, spec: Dictionary, installed: bool) -> void:
	var p=game.service.progress
	var error:=Lounge.item_error(p,spec)
	var waiting: bool=game.shop.pending(item,0)
	var suffix: String=" · установлено" if installed else " · в доставке" if waiting else " · "+error if not error.is_empty() else " · %d"%spec.price
	button(content,str(spec.name)+suffix,func():send({"action":"buy","kind":"item","item":item,"station":0,"installers":send_installers}),not game.session.is_guest() and error.is_empty() and not waiting and p.cash>=int(spec.price) and not p.busy())

func laboratory_page() -> void:
	var p=game.service.progress
	var host: bool=not game.session.is_guest()
	label(content,"БИОЛАБОРАТОРИЯ · "+str(LabPolicy.STAGES[p.lab_tier].name),23)
	label(content,"Рабочая формула: %d%% · версия %d · предел оборудования: %d%%"%[roundi(p.lab_formula_tempo*100),p.lab_formula_version,roundi(LabPolicy.formula_range(p).y*100)],20)
	lab_live_status=label(content,"")
	if p.lab_tier<2:
		var next: Dictionary=LabPolicy.STAGES[p.lab_tier+1]
		button(content,"Расширить: "+str(next.name)+" · %d · звезда %d"%[next.price,next.star],func():send({"action":"buy","kind":"lab_expansion"}),host and p.cash>=int(next.price) and p.stars>=int(next.star) and not p.busy() and game.session.sleeping_peers.is_empty())
	var branches:=HBoxContainer.new(); content.add_child(branches)
	for entry in [["formula","Формула"],["growing","Выращивание"],["calibration","Рекалибровка"]]:
		var key: String=entry[0]
		button(branches,str(entry[1]),func():lab_branch=key;rebuild())
	match lab_branch:
		"formula":
			label(content,"Собери стол, создай раствор и отнеси образец в микроскоп. Лучшая формула сохраняется сразу. Эксперимент — 20; риск порчи действует при падении ниже зелёной зоны.",16)
			for i in range(3): shop_button("lab_%d"%i,0,i<p.lab_stage)
		"growing":
			label(content,"Земля → капля (60) → вода → рост → удобрение в рот → рост → извлечение. Готовые этапы спокойно ждут. Темп фиксируется при добавлении капли.",16)
			label(content,"Горшков: %d · скорость выращивания: %d%% · по %d с на каждый этап"%[LabPolicy.pot_count(p),roundi(LabPolicy.growth_speed(p)*100),ceili(75.0/LabPolicy.growth_speed(p))],18)
		"calibration":
			label(content,"Кресло открывается с первой звездой. Нажимай в ритм шести импульсов: хорошее прохождение даёт весь изученный предел, слабое сохраняет прежний темп. Попытка — 10.",16)
			label(content,"Автоматика берёт отстающих по одному после завершения заказа, постепенно повышает темп и возвращает на прежнюю станцию. Приготовление на этой станции ждёт сотрудника.",16)
	for id in LabPolicy.ITEMS:
		if LabPolicy.ITEMS[id].branch!=lab_branch: continue
		var spec: Dictionary=game.shop.ITEMS[id]
		var error:=LabPolicy.error(p,id)
		var waiting: bool=game.shop.pending(id,0)
		var suffix: String=" · установлено" if id in p.lab_upgrades else " · в доставке" if waiting else " · "+error if not error.is_empty() else " · %d"%spec.price
		var item: String=id
		button(content,str(spec.name)+suffix,func():send({"action":"buy","kind":"item","item":item,"station":0}),host and error.is_empty() and not waiting and p.cash>=int(spec.price) and not p.busy())
	if "lab_production" in p.lab_upgrades or "lab_cal_auto" in p.lab_upgrades:
		label(content,"АВТОМАТИКА И ОБЩИЙ ДЕНЕЖНЫЙ РЕЗЕРВ",20)
		var row:=HBoxContainer.new(); content.add_child(row)
		label(row,"Свободных клонов:")
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
