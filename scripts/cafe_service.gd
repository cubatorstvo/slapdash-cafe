extends Node3D
const Visits = preload("res://scripts/cafe_visits.gd")
const Station = preload("res://scripts/work_station.gd")
const Definition = preload("res://scripts/station_definition.gd")
const Masterclasses = preload("res://scripts/masterclass_library.gd")
const MasterclassLiveScene = preload("res://scripts/masterclass_live_scene.gd")
const StaffTrainingSession = preload("res://scripts/staff_training_session.gd")
const TrainingQueueController = preload("res://scripts/training_queue_controller.gd")
const Expansion = preload("res://scripts/cafe_expansion_layout.gd")
const Insights = preload("res://scripts/cafe_insights.gd")
const TableGroupRegistry = preload("res://scripts/table_group_registry.gd")
const Person = preload("res://scripts/customer_view.gd")
const STARTER_TYPES := ["counter", "counter", "counter", "kitchen"]
const CHEF_QUEUE_LIMIT := 3
const CHEF_WAIT_LIMIT := 60.0
const SLOT_COUNT := Expansion.SLOT_COUNT
const SLOT_GAP := 0.6
const SLOT_ROW_CENTER_X := 3.0
const SLOT_Z := -1.4
var stations: Array = []
var customers: Array = []
var next_customer_id := 1
var next_order_id := 1
var served := 0
var missed := 0
var revenue := 0
var guests_arrived := 0
var order_stats: Dictionary=blank_order_stats()
var analytics: Dictionary=Insights.blank()
var open_for_business := false
const Progression = preload("res://scripts/cafe_progression.gd")
var progress = Progression.new()
var autosave_clock := 0.0
var banquet_clock := 0.0
var spawn_clock := 3.0
var chef_order_clock := 3.0
var game: Node3D
var rng := RandomNumberGenerator.new()
var masterclasses: Array=[]
var next_masterclass_id := 1
var masterclass_pending: Dictionary={}
var masterclass_station: Node3D
var chef_station_backup: Node3D
var masterclass_live_scene: Node3D
var movie_state: Dictionary={"id":0,"playing":false,"elapsed":0.0,"duration":0.0,"started_by":0}
var remote_movie_record: Dictionary={}
var staff_training: Node3D
var training_queue: Node
var table_group_names: Dictionary={} # v19 migration only
var group_registry=TableGroupRegistry.new()
var suppress_group_autocreate:=false

func blank_order_stats() -> Dictionary:
	return {"orders_arrived":0,"orders_completed":0,"orders_partial":0,"orders_failed":0,"portions_ordered":0,"portions_served":0,"portions_unserved":0}

func _ready() -> void:
	rng.randomize()
	training_queue=TrainingQueueController.new()
	add_child(training_queue)
	training_queue.setup(self)
	staff_training=StaffTrainingSession.new()
	add_child(staff_training)
	staff_training.setup(self)

func slot_position(slot_index: int) -> Vector3:
	return Expansion.position(slot_index)

func starter_layout_positions() -> Array:
	var positions: Array = []
	for slot_index in range(SLOT_COUNT): positions.append(slot_position(slot_index))
	return positions

func initial_stations(sandbox := false) -> void:
	for slot_index in range(STARTER_TYPES.size() if sandbox else 1): add_station(STARTER_TYPES[slot_index], slot_index, not sandbox, not sandbox)

func add_station(type_id: String, slot_index: int, manual := false, bare := false) -> Node3D:
	var station := Station.new()
	station.manual_station = manual
	if bare: station.equipment = []; station.staffed = 0
	station.slot_index = slot_index
	station.station_id = slot_index + 1
	station.type_id = type_id
	station.position = slot_position(slot_index)
	station.rotation.y = PI
	add_child(station)
	stations.append(station)
	if not manual and not suppress_group_autocreate:
		group_registry.ensure_station(station,Definition.TYPES)
		_sync_station_group_intent(station)
	assign_clones()
	return station

func by_id(id: int) -> Node3D:
	for station in stations:
		if station.station_id == id: return station
	return null

func training_for(peer: int) -> Node3D:
	for station in stations:
		if station.training.active() and (station.training.lead == peer or station.training.role_for(peer) >= 0): return station
	return null

func any_training() -> bool:
	if is_instance_valid(training_queue) and int(training_queue.active_batch_id)>0: return true
	if is_instance_valid(staff_training) and staff_training.is_active(): return true
	for station in stations:
		if station.training.active() or station.pending_teacher > 0: return true
	return not masterclass_pending.is_empty()

func masterclass_active() -> bool: return is_instance_valid(masterclass_station)
func masterclass_locked() -> bool: return masterclass_active() or not masterclass_pending.is_empty()

func sync_masterclass_live_scene() -> void:
	var stage: Node3D=by_id(1)
	var should_show: bool=stage!=null and stage.masterclass_station and stage.training.active()
	if should_show and not is_instance_valid(masterclass_live_scene):
		masterclass_live_scene=MasterclassLiveScene.new()
		add_child(masterclass_live_scene)
		masterclass_live_scene.setup(stage)
	elif not should_show and is_instance_valid(masterclass_live_scene):
		masterclass_live_scene.queue_free()
		masterclass_live_scene=null

func stable_chef() -> Node3D:
	return chef_station_backup if is_instance_valid(chef_station_backup) else by_id(1)

func _masterclass_source(dish: String) -> Node3D:
	var type_id: String=Definition.type_for_dish(dish)
	if type_id=="counter": return stable_chef()
	for station in stations:
		if station==masterclass_station or station.manual_station or station.type_id!=type_id: continue
		if Definition.missing_equipment(dish,station.equipment).is_empty(): return station
	return null

func masterclass_access(dish: String) -> Dictionary:
	if dish not in Definition.DISH_ORDER: return {"available":false,"reason":"Неизвестное блюдо."}
	if progress.stars<1: return {"available":false,"reason":"Мастер-классы откроются после первой звезды."}
	var type_id: String=Definition.type_for_dish(dish)
	if type_id=="counter":
		var chef:=stable_chef()
		if chef==null: return {"available":false,"reason":"Шеф-станция недоступна."}
		var missing: Array=Definition.missing_equipment(dish,chef.equipment)
		return {"available":missing.is_empty(),"reason":"" if missing.is_empty() else "На шеф-станции не хватает: "+", ".join(missing),"source_type":type_id}
	var candidates: Array=[]
	for station in stations:
		if station!=masterclass_station and not station.manual_station and station.type_id==type_id: candidates.append(station)
	if candidates.is_empty(): return {"available":false,"reason":"Сначала открой и установи кухню «%s»."%Definition.TYPES[type_id].title,"source_type":type_id}
	for station in candidates:
		if Definition.missing_equipment(dish,station.equipment).is_empty(): return {"available":true,"reason":"","source_type":type_id,"source_station":station.station_id}
	var missing: Array=Definition.missing_equipment(dish,candidates[0].equipment)
	return {"available":false,"reason":"Оснасти кухню: "+", ".join(missing),"source_type":type_id}

func masterclass_options() -> Array:
	var result: Array=[]
	for dish in Definition.DISH_ORDER:
		var access:=masterclass_access(dish)
		result.append({"dish":dish,"available":bool(access.available),"reason":str(access.reason)})
	return result

func request_masterclass(dish: String, peer: int) -> String:
	if progress.busy(): return "Сначала заверши текущую проверку."
	if progress.shift in ["night","closing"]: return "Мастер-класс проводится в рабочее время."
	if masterclass_locked(): return "Мастер-класс уже готовится или идёт."
	if training_for(peer)!=null: return "Сначала заверши текущий показ."
	var access:=masterclass_access(dish)
	if not bool(access.available): return str(access.reason)
	masterclass_pending={"dish":dish,"peer":peer}
	progress.revision+=1
	trace("masterclass_requested",{"dish":dish,"peer":peer})
	feed_player(peer,"masterclass",{"dish":dish})
	_try_begin_masterclass()
	return ""

func _try_begin_masterclass() -> void:
	if masterclass_pending.is_empty() or masterclass_active(): return
	var chef:=by_id(1)
	if chef==null or not chef.manual_station or chef.training.active() or chef.state!="idle" or chef.customer_id>=0 or not chef_queue().is_empty(): return
	var dish: String=str(masterclass_pending.dish)
	var peer: int=int(masterclass_pending.peer)
	var source:=_masterclass_source(dish)
	if source==null:
		masterclass_pending.clear()
		progress.revision+=1
		return
	chef_station_backup=chef
	stations.erase(chef)
	remove_child(chef)
	var stage:=Station.new()
	stage.manual_station=true
	stage.masterclass_station=true
	stage.slot_index=0
	stage.station_id=1
	stage.type_id=Definition.type_for_dish(dish)
	stage.equipment=source.equipment.duplicate()
	stage.upgrades=source.upgrades.duplicate()
	stage.position=slot_position(0)
	stage.rotation.y=PI
	add_child(stage)
	stations.push_front(stage)
	masterclass_station=stage
	masterclass_pending.clear()
	stage.training.open(dish,peer,"masterclass")
	sync_masterclass_live_scene()
	progress.revision+=1
	trace("masterclass_started",{"dish":dish,"peer":peer,"type":stage.type_id})

func finish_masterclass_layout(stage: Node3D) -> void:
	if not masterclass_active() or stage!=masterclass_station: return
	if is_instance_valid(masterclass_live_scene): masterclass_live_scene.queue_free()
	masterclass_live_scene=null
	stations.erase(masterclass_station)
	remove_child(masterclass_station)
	masterclass_station.queue_free()
	masterclass_station=null
	if is_instance_valid(chef_station_backup):
		add_child(chef_station_backup)
		stations.push_front(chef_station_backup)
	chef_station_backup=null
	chef_order_clock=maxf(chef_order_clock,5.0)
	progress.revision+=1

func cancel_masterclass() -> void:
	if not masterclass_active():
		masterclass_pending.clear()
		progress.revision+=1
		return
	var stage:=masterclass_station
	if stage.training.active(): stage.training.close()
	finish_masterclass_layout(stage)

func save_masterclass_from_run(stage: Node3D, dish: String, tracks: Array) -> bool:
	if not masterclass_active() or stage!=masterclass_station or tracks.size()!=stage.role_count(): return false
	for track in tracks:
		if track.is_empty() or track.get("frames",[]).is_empty(): return false
	stage.show_tracks(tracks,stage.Run.duration_ticks(tracks)-1)
	var quality: Dictionary=stage.model.quality()
	var number:=1
	for record in masterclasses:
		if str(record.get("dish",""))==dish and not bool(record.get("archived",false)): number+=1
	var record:=Masterclasses.make_record(next_masterclass_id,dish,stage.type_id,tracks,stage.Run.duration_ticks(tracks)/60.0,quality,Masterclasses.default_name(dish,number))
	next_masterclass_id+=1
	masterclasses.append(record)
	progress.revision+=1
	trace("masterclass_saved",{"id":record.id,"dish":dish,"seconds":record.duration,"grade":quality.grade})
	return true

func masterclass_by_id(id: int) -> Dictionary:
	for record in masterclasses:
		if int(record.get("id",0))==id: return record
	return {}

func rename_masterclass(id: int, value: String) -> String:
	var record:=masterclass_by_id(id)
	if record.is_empty(): return "Запись не найдена."
	var name:=value.strip_edges().left(64)
	if name.is_empty(): return "Название не может быть пустым."
	record.name=name
	if int(remote_movie_record.get("id",0))==id: remote_movie_record.name=name
	if is_instance_valid(training_queue): training_queue.record_renamed(id,name)
	progress.revision+=1
	return ""

func delete_masterclass(id: int) -> String:
	for i in range(masterclasses.size()):
		if int(masterclasses[i].get("id",0))==id:
			masterclasses.remove_at(i)
			progress.revision+=1
			return ""
	return "Запись не найдена."

func masterclass_summaries() -> Array:
	var result: Array=[]
	for record in masterclasses: result.append(Masterclasses.summary(record))
	return result

func start_highlights(id: int, peer: int) -> String:
	if is_instance_valid(staff_training) and staff_training.is_active(): return "Телевизор занят обучением сотрудников."
	if is_instance_valid(training_queue) and training_queue.ready_for_tv(): return "Следующий сеанс — обучение сотрудников."
	if "television" not in progress.lounge_items: return "Сначала установи телевизор в комнате отдыха."
	var record:=masterclass_by_id(id)
	if record.is_empty(): return "Запись не найдена."
	Masterclasses.ensure_highlights(record)
	if float(record.get("highlight_duration",0.0))<=0.0: return "В этой записи нет кадров для фильма."
	movie_state={"id":id,"playing":true,"elapsed":0.0,"duration":float(record.highlight_duration),"started_by":peer}
	remote_movie_record={}
	progress.revision+=1
	trace("highlights_started",{"id":id,"dish":record.dish,"seconds":record.highlight_duration,"peer":peer})
	return ""

func start_training_movie(value: Dictionary) -> void:
	var lesson: Dictionary=value.duplicate(true)
	Masterclasses.ensure_highlights(lesson)
	remote_movie_record=lesson
	movie_state={"id":int(lesson.get("id",0)),"playing":true,"elapsed":0.0,"duration":float(lesson.get("highlight_duration",0.0)),"started_by":0}
	progress.revision+=1

func stop_highlights() -> void:
	movie_state.playing=false
	movie_state.elapsed=float(movie_state.get("duration",0.0))
	progress.revision+=1

func movie_record() -> Dictionary:
	if not remote_movie_record.is_empty() and int(remote_movie_record.get("id",0))==int(movie_state.get("id",0)): return remote_movie_record
	return masterclass_by_id(int(movie_state.get("id",0)))

func movie_snapshot() -> Dictionary:
	return movie_state.duplicate(true)

func apply_movie_snapshot(data: Dictionary) -> void:
	if not data is Dictionary: return
	movie_state={"id":int(data.get("id",0)),"playing":bool(data.get("playing",false)),"elapsed":float(data.get("elapsed",0.0)),"duration":float(data.get("duration",0.0)),"started_by":int(data.get("started_by",0))}

func _method_source(station: Node3D,dish: String,overrides: Dictionary={}) -> Dictionary:
	if overrides.has(station.station_id):
		var override: Dictionary=overrides[station.station_id]
		if str(override.get("dish",""))==dish: return override
	if is_instance_valid(staff_training):
		var pending: Dictionary=staff_training.pending_source(station.station_id,dish)
		if not pending.is_empty(): return pending
	if is_instance_valid(training_queue):
		var queued: Dictionary=training_queue.pending_source(station.station_id,dish)
		if not queued.is_empty(): return queued
	if station.method_sources.has(dish): return station.method_sources[dish].duplicate(true)
	if station.method_plan.has(dish):
		var planned: Dictionary=station.method_plan[dish].duplicate(true)
		planned.planned=true
		return planned
	if station.recipes.has(dish): return {"id":0,"name":"Локальный способ","legacy":true}
	return {}

func request_auto_training_reconcile() -> void:
	if is_instance_valid(training_queue): training_queue.request_auto_reconcile()

func _sync_station_group_intent(station: Node3D) -> void:
	if station==null or station.manual_station or station.masterclass_station: return
	var group: Dictionary=group_registry.for_station(station.station_id)
	if group.is_empty(): return
	station.active_dishes=group.get("active_dishes",[]).duplicate()
	station.active_menu_initialized=true
	var desired: Dictionary={}
	for item in group.get("curriculum",[]):
		var dish:=str(item.get("dish_id",""))
		var record_id:=int(item.get("record_id",0))
		if dish.is_empty() or record_id<=0: continue
		var record:=masterclass_by_id(record_id)
		var previous: Dictionary=station.method_plan.get(dish,{})
		desired[dish]={"id":record_id,"name":str(record.get("name",previous.get("name","Запись #%d"%record_id))),"group":str(group.id),"revision":int(item.get("revision",1))}
	station.method_plan=desired

func _sync_group_intent(group_id: String) -> void:
	var group: Dictionary=group_registry.by_id(group_id)
	if group.is_empty(): return
	for raw_id in group.station_ids: _sync_station_group_intent(by_id(int(raw_id)))
	request_auto_training_reconcile()

func _sync_all_group_intent() -> void:
	for group in group_registry.all(): _sync_group_intent(str(group.id))

func _ensure_groups() -> void:
	for station in stations:
		if station.manual_station or station.masterclass_station: continue
		if group_registry.group_id_for_station(station.station_id).is_empty():
			group_registry.ensure_station(station,Definition.TYPES)
			_sync_station_group_intent(station)

func _public_group(group: Dictionary) -> Dictionary:
	if group.is_empty(): return {}
	return {"id":str(group.id),"name":str(group.name),"type":str(group.type_id),"type_id":str(group.type_id),"stations":group.station_ids.duplicate(),"station_ids":group.station_ids.duplicate(),"dishes":Definition.TYPES[str(group.type_id)].dishes.duplicate(),"active_dishes":group.active_dishes.duplicate(),"curriculum":group.curriculum.duplicate(true),"plan_revision":int(group.plan_revision)}

func group_snapshot() -> Dictionary:
	_ensure_groups()
	return group_registry.snapshot()

func apply_group_snapshot(data: Dictionary) -> bool:
	if not group_registry.restore(data,Definition.TYPES): return false
	_ensure_groups()
	_sync_all_group_intent()
	return true

func table_groups() -> Array:
	_ensure_groups()
	var result: Array=[]
	for group in group_registry.all(): result.append(_public_group(group))
	return result

func table_group_by_id(group_id: String) -> Dictionary:
	_ensure_groups()
	return _public_group(group_registry.by_id(group_id))

func group_for_station(station_id: int) -> Dictionary:
	_ensure_groups()
	return _public_group(group_registry.for_station(station_id))

func group_id_for_station(station_id: int) -> String:
	_ensure_groups()
	return group_registry.group_id_for_station(station_id)

func rename_table_group(group_id: String,value: String) -> String:
	_ensure_groups()
	var error:=group_registry.rename(group_id,value)
	if error.is_empty(): progress.revision+=1
	return error

func _compatible_group_selection(ids: Array) -> Dictionary:
	var unique: Array=[]
	var type_id: String=""
	for raw in ids:
		var station:=by_id(int(raw))
		if station==null or station.manual_station or station.masterclass_station: return {"error":"Выбери производственные столы."}
		if type_id.is_empty(): type_id=station.type_id
		elif station.type_id!=type_id: return {"error":"В одной группе могут быть только столы одной кухни."}
		if station.station_id not in unique: unique.append(station.station_id)
	unique.sort()
	return {"error":"","type_id":type_id,"stations":unique}

func _same_group_intent(a: Dictionary,b: Dictionary) -> bool:
	var active_a: Array=a.get("active_dishes",[]).duplicate()
	var active_b: Array=b.get("active_dishes",[]).duplicate()
	active_a.sort()
	active_b.sort()
	if active_a!=active_b: return false
	var plan_a: Dictionary={}
	var plan_b: Dictionary={}
	for item in a.get("curriculum",[]): plan_a[str(item.get("dish_id",""))]=int(item.get("record_id",0))
	for item in b.get("curriculum",[]): plan_b[str(item.get("dish_id",""))]=int(item.get("record_id",0))
	return plan_a==plan_b

func create_table_group(ids: Array,name := "") -> String:
	_ensure_groups()
	var checked:=_compatible_group_selection(ids)
	if not str(checked.error).is_empty(): return str(checked.error)
	if checked.stations.is_empty(): return "Выбери хотя бы один стол."
	var source_groups: Array=[]
	for raw_id in checked.stations:
		var source_id:=group_registry.group_id_for_station(int(raw_id))
		if not source_id.is_empty() and source_id not in source_groups: source_groups.append(source_id)
	if source_groups.size()>1:
		var base: Dictionary=group_registry.by_id(str(source_groups[0]))
		for source_id in source_groups.slice(1):
			if not _same_group_intent(base,group_registry.by_id(str(source_id))):
				return "У выбранных столов разные планы или активное меню. Сначала раздели нужные части и используй «Объединить группы»."
	var first_group: Dictionary=group_registry.for_station(int(checked.stations[0]))
	var title:=name.strip_edges().left(48)
	if title.is_empty(): title="%s · группа"%Definition.TYPES[str(checked.type_id)].title
	var created:=group_registry.create_group(checked.stations,str(checked.type_id),title,first_group)
	if created.is_empty(): return "Не удалось создать группу."
	_ensure_groups()
	_sync_all_group_intent()
	progress.revision+=1
	return ""

func split_table_group(group_id: String,ids: Array) -> String:
	_ensure_groups()
	var source:=group_registry.by_id(group_id)
	if source.is_empty(): return "Группа не найдена."
	var created:=group_registry.split(group_id,ids)
	if created.is_empty(): return "Для разделения выбери часть столов группы."
	_sync_group_intent(group_id)
	_sync_group_intent(str(created.id))
	progress.revision+=1
	return ""

func set_table_group_members(group_id: String,ids: Array) -> String:
	_ensure_groups()
	var source:=group_registry.by_id(group_id)
	if source.is_empty(): return "Группа не найдена."
	var checked:=_compatible_group_selection(ids)
	if not str(checked.error).is_empty(): return str(checked.error)
	if str(checked.type_id)!=str(source.type_id): return "Новая группа должна состоять из столов той же кухни."
	var error:=group_registry.set_members(group_id,checked.stations,str(source.type_id))
	if not error.is_empty(): return error
	_ensure_groups()
	_sync_all_group_intent()
	progress.revision+=1
	return ""

func preview_group_merge(group_ids: Array) -> Dictionary:
	_ensure_groups()
	return group_registry.preview_merge(group_ids)

func merge_table_groups(group_ids: Array,record_choices: Dictionary={},active_dishes: Variant=null) -> String:
	_ensure_groups()
	var preview:=group_registry.preview_merge(group_ids)
	if preview.is_empty(): return "Выбери минимум две группы одной кухни."
	for dish in preview.get("differences",{}):
		var chosen:=int(record_choices.get(str(dish),0))
		if chosen<=0 or chosen not in preview.differences[dish]: return "Выбери итоговую запись для блюда «%s»."%Definition.DISHES.get(str(dish),str(dish))
		var record:=masterclass_by_id(chosen)
		if record.is_empty() or str(record.get("dish",""))!=str(dish): return "Выбранная запись больше недоступна. Обнови объединение."
	if active_dishes is Array:
		for dish in active_dishes:
			if str(dish) not in Definition.TYPES[str(preview.type_id)].dishes: return "Активное меню содержит блюдо другой кухни."
	var target:=group_registry.merge(group_ids,record_choices,active_dishes)
	if target.is_empty(): return "Не удалось объединить группы."
	_sync_group_intent(str(target.id))
	progress.revision+=1
	return ""

func set_group_dish_active(group_id: String,dish: String,enabled: bool) -> String:
	_ensure_groups()
	var group:=group_registry.by_id(group_id)
	if group.is_empty(): return "Группа не найдена."
	if dish not in Definition.TYPES[str(group.type_id)].dishes: return "Блюдо не относится к этой кухне."
	var error:=group_registry.set_active_dish(group_id,dish,enabled)
	if error.is_empty():
		_sync_group_intent(group_id)
		progress.revision+=1
	return error

func _apply_group_plan(record_id: int,ids: Array) -> Array:
	_ensure_groups()
	var record:=masterclass_by_id(record_id)
	if record.is_empty(): return []
	var affected:=group_registry.apply_plan_to_selection(ids,str(record.dish),record_id)
	for group_id in affected: _sync_group_intent(str(group_id))
	return affected

func preview_table_groups(record_id: int,ids: Array) -> Array:
	_ensure_groups()
	var record:=masterclass_by_id(record_id)
	if record.is_empty(): return table_groups()
	var temp=TableGroupRegistry.new()
	if not temp.restore(group_registry.snapshot(),Definition.TYPES): return table_groups()
	temp.apply_plan_to_selection(ids,str(record.dish),record_id)
	var result: Array=[]
	for group in temp.all(): result.append(_public_group(group))
	return result

func source_label(station_id: int,dish: String) -> String:
	var station:=by_id(station_id)
	if station==null: return "—"
	var source: Dictionary=_method_source(station,dish)
	if source.is_empty(): return "—"
	if bool(source.get("legacy",false)): return "Локальный способ"
	var id: int=int(source.get("id",0))
	var current:=masterclass_by_id(id)
	if not current.is_empty(): return str(current.get("name",source.get("name","Запись")))+(" · запланировано" if bool(source.get("planned",false)) else "")
	return str(source.get("name","Запись"))+" · Запись удалена"

func desired_source(group_id: String,dish: String) -> Dictionary:
	_ensure_groups()
	var group: Dictionary=group_registry.by_id(group_id)
	if group.is_empty(): return {}
	var item: Dictionary=group_registry.plan_record(group,dish)
	if item.is_empty(): return {}
	var record_id:=int(item.record_id)
	var record:=masterclass_by_id(record_id)
	return {"id":record_id,"name":str(record.get("name","Запись #%d"%record_id)),"revision":int(item.revision)}

func desired_source_label(group_id: String,dish: String) -> String:
	var source:=desired_source(group_id,dish)
	if source.is_empty(): return "не назначено"
	return str(source.name) if not masterclass_by_id(int(source.id)).is_empty() else str(source.name)+" · Запись удалена"

func station_group_status(station_id: int,dish: String) -> String:
	var station:=by_id(station_id)
	if station==null: return "нет стола"
	var group: Dictionary=group_registry.for_station(station_id)
	var desired: Dictionary=group_registry.plan_record(group,dish) if not group.is_empty() else {}
	var active: bool=station.dish_active(dish)
	if is_instance_valid(staff_training) and staff_training.targets_station(station_id,dish): return staff_training.phase_label()
	if is_instance_valid(training_queue):
		var queue_state: String=training_queue.station_status(station_id,dish)
		if not queue_state.is_empty(): return queue_state
	var actual: Dictionary=station.method_sources.get(dish,{})
	var desired_mastered: bool=not desired.is_empty() and station.recipes.has(dish) and int(actual.get("id",0))==int(desired.record_id)
	var missing: Array=Definition.missing_equipment(dish,station.equipment)
	if desired_mastered:
		if not missing.is_empty(): return "ждёт оснащение"
		if station.staffed>=0 and station.staffed<station.role_count(): return "нужны сотрудники"
		return "освоено" if active else "освоено · выключено в меню"
	if not desired.is_empty() and masterclass_by_id(int(desired.record_id)).is_empty(): return "нужна действующая запись для нового обучения"
	if not missing.is_empty(): return "ждёт оснащение"
	if station.staffed>=0 and station.staffed<station.role_count(): return "нужны сотрудники"
	if not desired.is_empty():
		if station.recipes.has(dish): return "работает по старому · ожидает переобучения" if active else "старый способ · выключено в меню"
		return "ожидает обучения" if active else "обучение запланировано · блюдо выключено"
	if station.recipes.has(dish): return "освоено" if active else "освоено · выключено в меню"
	return "нет способа" if active else "выключено в меню"

func group_dish_summary(group_id: String,dish: String) -> Dictionary:
	var group:=table_group_by_id(group_id)
	if group.is_empty(): return {}
	var states: Dictionary={}
	var mastered:=0
	for raw_id in group.stations:
		var state:=station_group_status(int(raw_id),dish)
		states[state]=int(states.get(state,0))+1
		if state.begins_with("освоено"): mastered+=1
	return {"desired":desired_source_label(group_id,dish),"mastered":mastered,"total":group.stations.size(),"states":states}

func add_station_to_group(group_id: String,station_id: int) -> String:
	_ensure_groups()
	var group:=group_registry.by_id(group_id)
	var station:=by_id(station_id)
	if group.is_empty() or station==null: return "Группа или стол не найдены."
	if station.type_id!=str(group.type_id): return "Стол относится к другой кухне."
	var ids: Array=group.station_ids.duplicate()
	if station_id not in ids: ids.append(station_id)
	var error:=group_registry.set_members(group_id,ids,str(group.type_id))
	if not error.is_empty(): return error
	_ensure_groups()
	_sync_all_group_intent()
	progress.revision+=1
	return ""

func attach_purchased_station_to_group(station: Node3D,planned_group: String,purchase_snapshot: Dictionary={},legacy_plan: Dictionary={}) -> String:
	if station==null or station.manual_station or station.masterclass_station: return "Стол недоступен."
	if planned_group.is_empty(): return ""
	var current: Dictionary=group_registry.by_id(planned_group)
	if not current.is_empty() and str(current.type_id)==station.type_id:
		return add_station_to_group(planned_group,station.station_id)
	var template: Dictionary={}
	if not purchase_snapshot.is_empty() and str(purchase_snapshot.get("type_id",purchase_snapshot.get("type","")))==station.type_id:
		template={
			"active_dishes":purchase_snapshot.get("active_dishes",[]).duplicate(),
			"curriculum":purchase_snapshot.get("curriculum",[]).duplicate(true),
			"plan_revision":int(purchase_snapshot.get("plan_revision",1))
		}
	elif not legacy_plan.is_empty():
		var curriculum: Array=[]
		var active: Array=[]
		for dish in Definition.TYPES[station.type_id].dishes:
			var raw: Dictionary=legacy_plan.get(str(dish),{}) if legacy_plan.get(str(dish),{}) is Dictionary else {}
			var record_id:=int(raw.get("id",raw.get("record_id",0)))
			if record_id<=0: continue
			curriculum.append({"dish_id":str(dish),"record_id":record_id,"revision":maxi(1,int(raw.get("revision",1)))})
			active.append(str(dish))
		template={"active_dishes":active,"curriculum":curriculum,"plan_revision":1}
	if template.is_empty(): return ""
	var source_name:=str(purchase_snapshot.get("name","Группа заказа")).strip_edges()
	if source_name.is_empty(): source_name="Группа заказа"
	var created:=group_registry.create_group([station.station_id],station.type_id,source_name+" · отдельная",template)
	if created.is_empty(): return "Не удалось восстановить план группы из заказа."
	_sync_group_intent(str(created.id))
	progress.revision+=1
	announce("Группа «%s» была удалена. Стол %d получил отдельную группу с планом из заказа."%[source_name,station.station_id])
	return ""

func compatible_training_station_ids(record_id: int) -> Array:
	var record:=masterclass_by_id(record_id)
	if record.is_empty(): return []
	var result: Array=[]
	for station in stations:
		if station.manual_station or station.masterclass_station: continue
		if station.type_id==str(record.get("source_type","")) and str(record.get("dish","")) in station.dishes(): result.append(station.station_id)
	return result

func training_selection_error(record_id: int,ids: Array) -> String:
	if not is_instance_valid(training_queue): return "Система очереди обучения недоступна."
	var record:=masterclass_by_id(record_id)
	if record.is_empty(): return "Запись не найдена."
	if ids.is_empty(): return "Выбери хотя бы один стол."
	var seen: Array=[]
	for raw_id in ids:
		var id: int=int(raw_id)
		if id in seen: continue
		seen.append(id)
		var station:=by_id(id)
		if station==null or station.manual_station or station.masterclass_station or station.type_id!=str(record.source_type) or str(record.dish) not in station.dishes(): return "В выборе есть несовместимый стол."
	return ""

func training_course_preview(assignments: Array,mode := "together",group_order: Array=[]) -> Dictionary:
	_ensure_groups()
	if mode not in ["together","by_groups"]: return {"error":"Неизвестный режим курса."}
	if assignments.is_empty(): return {"error":"Добавь хотя бы один урок."}
	var type_id: String=""
	var selected: Array=[]
	var lessons: Array=[]
	var seen_dishes: Array=[]
	for raw in assignments:
		if not raw is Dictionary: return {"error":"Некорректный урок."}
		var record_id: int=int(raw.get("record_id",raw.get("record",0)))
		var record: Dictionary=masterclass_by_id(record_id)
		if record.is_empty(): return {"error":"Запись #%d не найдена."%record_id}
		var ids: Array=raw.get("station_ids",raw.get("stations",[])) if raw.get("station_ids",raw.get("stations",[])) is Array else []
		var unique: Array=[]
		for raw_id in ids:
			var station_id: int=int(raw_id)
			if station_id not in unique: unique.append(station_id)
		unique.sort()
		if unique.is_empty(): return {"error":"Выбери хотя бы один стол."}
		var dish: String=str(record.get("dish",""))
		if dish in seen_dishes: return {"error":"В курсе может быть только одна запись на блюдо."}
		seen_dishes.append(dish)
		var record_type: String=str(record.get("source_type",""))
		if type_id.is_empty(): type_id=record_type
		elif type_id!=record_type: return {"error":"Один курс содержит записи только одной кухни."}
		var mastered:=0
		var waiting: Array=[]
		for station_id in unique:
			var station=by_id(station_id)
			if station==null or station.manual_station or station.masterclass_station or station.type_id!=record_type or dish not in station.dishes(): return {"error":"Стол %d несовместим с записью «%s»."%[station_id,str(record.get("name","Запись"))]}
			if station_id not in selected: selected.append(station_id)
			if station.recipes.has(dish) and int(station.method_sources.get(dish,{}).get("id",0))==record_id: mastered+=1
			else: waiting.append(station_id)
		lessons.append({"record_id":record_id,"dish":dish,"name":str(record.get("name","Запись")),"grade":str(record.get("quality",{}).get("grade","D")),"effectiveness":str(record.get("effectiveness",{}).get("label","Обычная")),"duration":float(record.get("duration",0.0)),"film":float(record.get("highlight_duration",0.0)),"mastered":mastered,"selected":unique.size(),"waiting":waiting})
	selected.sort()
	var preferred_station_sets: Array=[]
	for raw_group_id in group_order:
		var source_group: Dictionary=table_group_by_id(str(raw_group_id))
		if source_group.is_empty(): continue
		var subset: Array=[]
		for station_id in source_group.stations:
			if int(station_id) in selected: subset.append(int(station_id))
		if not subset.is_empty(): preferred_station_sets.append(subset)
	var temp=TableGroupRegistry.new()
	if not temp.restore(group_registry.snapshot(),Definition.TYPES): return {"error":"Не удалось построить предпросмотр групп."}
	for lesson in lessons: temp.apply_plan_to_selection(selected,str(lesson.dish),int(lesson.record_id))
	var projected: Array=[]
	for group in temp.all(): projected.append(_public_group(group))
	var employees:=0
	for station_id in selected:
		var station=by_id(int(station_id))
		if station!=null: employees+=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
	var all_needed: Array=[]
	for lesson in lessons:
		for station_id in lesson.waiting:
			if station_id not in all_needed: all_needed.append(station_id)
	all_needed.sort()
	var batch_rows: Array=[]
	if mode=="together":
		var reasons: Array=[]
		if progress.shift!="open": reasons.append("До следующего рабочего дня")
		if progress.busy(): reasons.append("Сначала завершится проверка кафе")
		if "television" not in progress.lounge_items: reasons.append("Нет телевизора")
		elif bool(movie_state.get("playing",false)): reasons.append("Телевизор занят")
		for lesson in lessons:
			for station_id in lesson.waiting:
				var station=by_id(int(station_id))
				var missing: Array=Definition.missing_equipment(str(lesson.dish),station.equipment)
				if not missing.is_empty(): reasons.append("Стол %d: требуется оборудование — %s"%[station_id,", ".join(missing)])
				elif station.staffed>=0 and station.staffed<station.role_count(): reasons.append("Стол %d: нужны сотрудники"%station_id)
				elif not station.ready_crew(): reasons.append("Стол %d: сотрудник занят другой активностью"%station_id)
		batch_rows.append({"stations":all_needed.duplicate(),"blocked_reason":str(reasons[0]) if not reasons.is_empty() else "","ready":reasons.is_empty()})
	else:
		var actual_group_order: Array=[]
		for station_id in selected:
			var group_id: String=temp.group_id_for_station(int(station_id))
			if not group_id.is_empty() and group_id not in actual_group_order: actual_group_order.append(group_id)
		if not preferred_station_sets.is_empty():
			var preferred: Array=[]
			for station_set in preferred_station_sets:
				for station_id in station_set:
					var wanted: String=temp.group_id_for_station(int(station_id))
					if wanted in actual_group_order and wanted not in preferred:
						preferred.append(wanted)
						break
			for group_id in actual_group_order:
				if group_id not in preferred: preferred.append(group_id)
			actual_group_order=preferred
		for group_id in actual_group_order:
			var group: Dictionary=temp.by_id(str(group_id))
			var needed: Array=[]
			var reason: String=""
			for lesson in lessons:
				for station_id in lesson.waiting:
					if station_id not in group.station_ids: continue
					if station_id not in needed: needed.append(station_id)
					var station=by_id(int(station_id))
					var missing: Array=Definition.missing_equipment(str(lesson.dish),station.equipment)
					if reason.is_empty() and not missing.is_empty(): reason="Стол %d: требуется оборудование — %s"%[station_id,", ".join(missing)]
					elif reason.is_empty() and station.staffed>=0 and station.staffed<station.role_count(): reason="Стол %d: нужны сотрудники"%station_id
					elif reason.is_empty() and not station.ready_crew(): reason="Стол %d: сотрудник занят другой активностью"%station_id
			if reason.is_empty() and progress.shift!="open": reason="До следующего рабочего дня"
			if reason.is_empty() and progress.busy(): reason="Сначала завершится проверка кафе"
			if reason.is_empty() and "television" not in progress.lounge_items: reason="Нет телевизора"
			elif reason.is_empty() and bool(movie_state.get("playing",false)): reason="Телевизор занят"
			batch_rows.append({"group":str(group_id),"name":str(group.name),"stations":needed,"blocked_reason":reason,"ready":reason.is_empty()})
	var max_out:=0
	for batch in batch_rows: max_out=maxi(max_out,batch.stations.size())
	var total_film:=0.0
	for lesson in lessons: total_film+=float(lesson.film)
	return {"error":"","type_id":type_id,"stations":selected,"employees":employees,"places":selected.size(),"lessons":lessons,"groups":projected,"batches":batch_rows,"simultaneous_out":max_out,"film_total":total_film,"mode":mode}

func edit_training_course(course_id: int,assignments: Array,mode := "together",peer := 1,group_order: Array=[]) -> String:
	return training_queue.edit_course(course_id,assignments,mode,peer,group_order) if is_instance_valid(training_queue) else "Система очереди обучения недоступна."

func resume_training_assignment(station_id: int,dish: String,peer := 1) -> String:
	return training_queue.resume_assignment(station_id,dish,peer) if is_instance_valid(training_queue) else "Система очереди обучения недоступна."

func training_course_views() -> Array:
	return training_queue.course_views() if is_instance_valid(training_queue) else []

func queue_training_course(assignments: Array,mode := "together",command_id := "",peer := 1,group_order: Array=[]) -> Dictionary:
	if not is_instance_valid(training_queue): return {"error":"Система очереди обучения недоступна.","course_id":0}
	return training_queue.enqueue_course(assignments,str(mode),str(command_id),int(peer),group_order)

func start_group_training(record_id: int,ids: Array,peer := 1,command_id := "") -> String:
	var error:=training_selection_error(record_id,ids)
	if not error.is_empty(): return error
	var unique: Array=[]
	for raw_id in ids:
		var id: int=int(raw_id)
		if id not in unique: unique.append(id)
	unique.sort()
	var result: Dictionary=queue_training_course([{"record_id":record_id,"station_ids":unique}],"together",command_id,peer)
	if not str(result.get("error","")).is_empty(): return str(result.error)
	var record:=masterclass_by_id(record_id)
	trace("group_training_assigned",{"course":int(result.get("course_id",0)),"record":record_id,"dish":record.dish,"stations":unique,"duplicate":bool(result.get("duplicate",false))})
	return ""

func cancel_training_course(course_id: int) -> String:
	return training_queue.cancel_course(course_id) if is_instance_valid(training_queue) else "Система очереди обучения недоступна."

func cancel_training_batch(batch_id: int) -> String:
	return training_queue.cancel_batch(batch_id) if is_instance_valid(training_queue) else "Система очереди обучения недоступна."

func cancel_training_lesson(lesson_id: int) -> String:
	return training_queue.cancel_lesson(lesson_id) if is_instance_valid(training_queue) else "Система очереди обучения недоступна."

func _archive_legacy_recipes() -> void:
	for station in stations:
		if station.manual_station: continue
		for dish in station.recipes:
			var recipe: Dictionary=station.recipes[dish]
			masterclasses.append(Masterclasses.make_record(next_masterclass_id,str(dish),station.type_id,recipe.tracks,float(recipe.duration),recipe.get("quality",{}),Masterclasses.default_name(str(dish),1,true,station.station_id),true,station.station_id))
			next_masterclass_id+=1

func local_recipe_learned(station: Node3D,dish: String) -> void:
	if station==null or station.manual_station or station.masterclass_station or dish not in station.dishes(): return
	_ensure_groups()
	var group_id:=group_registry.group_id_for_station(station.station_id)
	if group_id.is_empty(): return
	# Legacy local teaching is the pre-first-star onboarding path. It makes the newly
	# learned dish usable, while course assignments keep menu state independent.
	group_registry.set_active_dish(group_id,dish,true)
	_sync_group_intent(group_id)

func request_training(station: Node3D, dish: String, peer: int) -> bool:
	if station == null or not station.ready_crew() or station.manual_station or not dish in station.dishes() or progress.busy(): return false
	if station.training.active(): return station.training.lead == peer
	if training_for(peer) != null or station.pending_teacher > 0: return false
	if station.state in ["cooking","serving"]:
		station.pending_teacher = peer
		station.pending_dish = dish
		return true
	station.training.dish = dish
	_attach_customer(station)
	station.training.open(dish, peer)
	return true

func _attach_customer(station: Node3D) -> void:
	for customer in customers:
		if customer.id == station.customer_id and customer.dish == station.training.dish and customer.state not in ["queued","eating","leaving"]:
			station.taster = customer.view
			station.taster_real = true
			customer.state = "training"
			customer.path.clear()
			return
	if station.customer_id >= 0: finish_customer(station.customer_id, false)

func feed_system(kind: String,payload: Dictionary={},amount := 1)->Dictionary:
	var entry:=Insights.push_feed(analytics,kind,payload,amount)
	progress.revision+=1
	return entry

func feed_player(peer: int,kind: String,payload: Dictionary={},amount := 1)->Dictionary:
	var name: String="Повар"
	if game!=null and is_instance_valid(game.session):
		name=str(game.session.members.get(peer,game.session.display_name if peer==1 else "Повар"))
	var entry:=Insights.push_feed(analytics,kind,payload,amount,"player",name)
	progress.revision+=1
	return entry

func feed_text(entry: Dictionary)->String:
	return Insights.event_text(entry,Definition.DISHES)

func group_id_for_stations(ids: Array)->String:
	if ids.is_empty(): return ""
	for group in table_groups():
		var all_inside:=true
		for raw_id in ids:
			if int(raw_id) not in group.stations:
				all_inside=false
				break
		if all_inside: return str(group.id)
	return ""

func problem_context(dish: String)->Dictionary:
	var relevant: Array=[]
	for station in stations:
		if station.manual_station or station.masterclass_station or dish not in station.dishes(): continue
		relevant.append(station)
	if relevant.is_empty(): return {"reason":"no_station","stations":[],"group":""}
	var active: Array=relevant.filter(func(station):return station.dish_active(dish))
	if active.is_empty():
		var ids: Array=relevant.map(func(station):return station.station_id)
		return {"reason":"menu_off","stations":ids,"group":group_id_for_stations(ids)}
	var ready: Array=[]
	for station in active:
		if station.recipes.has(dish) and Definition.missing_equipment(dish,station.equipment).is_empty() and (station.staffed<0 or station.staffed>=station.role_count()) and station.group_training_state.is_empty():
			ready.append(station)
	if not ready.is_empty():
		var ids: Array=ready.map(func(station):return station.station_id)
		if ready.any(func(station):return station.state!="idle" or station.customer_id>=0 or station.pending_teacher>0):
			return {"reason":"busy","stations":ids,"group":group_id_for_stations(ids)}
	for station in active:
		if not station.group_training_state.is_empty() or (is_instance_valid(staff_training) and staff_training.targets_station(station.station_id,dish)):
			var ids: Array=active.map(func(item):return item.station_id)
			return {"reason":"training","stations":ids,"group":group_id_for_stations(ids)}
	for station in active:
		if station.staffed>=0 and station.staffed<station.role_count():
			var ids: Array=active.map(func(item):return item.station_id)
			return {"reason":"workers","stations":ids,"group":group_id_for_stations(ids)}
	for station in active:
		if not Definition.missing_equipment(dish,station.equipment).is_empty():
			var ids: Array=active.map(func(item):return item.station_id)
			return {"reason":"equipment","stations":ids,"group":group_id_for_stations(ids)}
	var ids: Array=active.map(func(item):return item.station_id)
	return {"reason":"unlearned","stations":ids,"group":group_id_for_stations(ids)}

func _analytics_loss(customer: Dictionary,reason: String)->void:
	var normalized: String="unlearned" if reason=="untrained" else reason
	var context: Dictionary=problem_context(str(customer.dish))
	if normalized in ["closing","chef_wait","wait"]: context.reason=normalized
	var group_id: String=str(context.get("group",""))
	var group: Dictionary=table_group_by_id(group_id) if not group_id.is_empty() else {}
	Insights.loss(analytics,str(customer.dish),str(context.reason),int(customer.get("portions_total",1)),int(customer.get("portions_done",0)),context.get("stations",[]),group_id,str(group.get("name",group_id)))

func top_bottleneck()->Dictionary:
	var reason:=Insights.top_reason(analytics)
	return {"reason":reason,"label":Insights.reason_label(reason),"suggestion":Insights.suggestion(reason),"count":int(analytics.losses.get(reason,0))} if not reason.is_empty() else {}

func group_performance(group: Dictionary)->Dictionary:
	var result: Dictionary={"orders_completed":0,"portions_served":0,"revenue":0,"losses":0,"loss_reasons":{},"dishes":{}}
	for raw_id in group.get("stations",[]):
		var row: Dictionary=analytics.stations.get(str(int(raw_id)),{})
		result.orders_completed=int(result.orders_completed)+int(row.get("orders_completed",0))
		result.portions_served=int(result.portions_served)+int(row.get("portions_served",0))
		result.revenue=int(result.revenue)+int(row.get("revenue",0))
		for dish in row.get("dish",{}):
			if not result.dishes.has(dish): result.dishes[dish]={"orders_completed":0,"portions_served":0,"revenue":0}
			var target: Dictionary=result.dishes[dish]
			var detail: Dictionary=row.dish[dish]
			target.orders_completed=int(target.orders_completed)+int(detail.get("orders_completed",0))
			target.portions_served=int(target.portions_served)+int(detail.get("portions_served",0))
			target.revenue=int(target.revenue)+int(detail.get("revenue",0))
	for detail in analytics.loss_details.values():
		if str(detail.get("group",""))!=str(group.get("id","")): continue
		result.losses=int(result.losses)+int(detail.get("count",0))
		var reason: String=str(detail.get("reason",""))
		result.loss_reasons[reason]=int(result.loss_reasons.get(reason,0))+int(detail.get("count",0))
	return result

func portion_count_for_new_order() -> int:
	if progress.stars<2: return 1
	var roll: float=rng.randf()
	if progress.stars==2: return 3 if roll<0.18 else 1
	if progress.stars==3: return 5 if roll<0.10 else 3 if roll<0.30 else 1
	var scale: float=clampf(float(stations.size()-6)/14.0,0.0,1.0)
	if roll<0.08+0.12*scale: return 10
	if roll<0.20+0.15*scale: return 5
	if roll<0.42: return 3
	return 1

func base_price_for(dish: String) -> int:
	return 65 if dish=="meal" else 95 if dish in Progression.ORCHESTRATION_DISHES else 80 if dish in Progression.SPECIALTY_DISHES else 25

func order_wait_limit(portions: int,station: Node3D=null,dish := "") -> float:
	var result: float=18.0+maxi(0,portions-1)*16.0
	if station!=null and station.recipes.has(dish):
		result=maxf(result,float(station.recipes[dish].get("duration",0.0))*float(portions)*1.6+8.0)
	return result

func automatic_station_candidates(dish: String,idle_only := true) -> Array:
	var result: Array=[]
	for station in stations:
		if station.manual_station or station.masterclass_station or not station.dish_active(dish) or not station.ready_crew() or not station.recipes.has(dish): continue
		if idle_only and (station.state!="idle" or station.pending_teacher>0): continue
		result.append(station)
	return result

func auto_queue_point(index: int) -> Vector3:
	return Vector3(-9.7,0,0.2-index*0.9)

func _update_multi_caption(customer: Dictionary) -> void:
	if int(customer.get("portions_total",1))<=1 or customer.state=="leaving": return
	var total: int=int(customer.portions_total)
	var done: int=int(customer.get("portions_done",0))
	var paid: int=int(customer.get("order_paid",0))
	var left: int=maxi(0,ceili(float(customer.get("wait_limit",0.0))-float(customer.get("order_age",0.0))))
	var suffix: String="Очередь к свободному столу" if customer.state=="auto_queue" else "Ожидание"
	customer.view.caption.text="%s ×%d\nГотово %d/%d · +%d\n%s · %d с"%[Definition.DISHES[customer.dish],total,done,total,paid,suffix,left]

func _start_automatic_order(station: Node3D,customer: Dictionary) -> void:
	station.state="cooking"
	station.order_dish=customer.dish
	station.order_tick=0.0
	station.order_tempo=station.crew_tempo()
	station.order_portions_total=int(customer.get("portions_total",1))
	station.order_portions_done=int(customer.get("portions_done",0))
	station.order_paid=int(customer.get("order_paid",0))
	station.reset_model()
	customer.state="cooking"
	customer.automatic_serving=true
	_update_multi_caption(customer)

func _start_pending_teacher(station: Node3D) -> void:
	if station==null or station.pending_teacher<=0 or station.state=="serving": return
	var teacher: int=station.pending_teacher
	station.pending_teacher=0
	station.training.open(station.pending_dish,teacher)

func _release_order_station(station: Node3D,customer_id: int) -> void:
	if station==null or station.customer_id!=customer_id: return
	station.customer_id=-1
	station.state="idle"
	station.order_portions_total=1
	station.order_portions_done=0
	station.order_paid=0
	_start_pending_teacher(station)

func _count_completed_customer(customer: Dictionary,station: Node3D) -> void:
	served+=1
	if station.manual_station:
		progress.manual_served+=1
		if not progress.starter_reward: game.shop.reward_sauce()
		if not customer.dish in progress.tutorial_served: progress.tutorial_served.append(customer.dish)
	elif customer.get("automatic_serving",false):
		progress.journey_auto_served+=1
		if customer.dish=="meal": progress.journey_meals_served+=1
		if progress.stars==2: progress.third_star_auto_served+=1
		if progress.stars==3:
			progress.fourth_star_auto_served+=1
			if customer.dish in Progression.SPECIALTY_DISHES: progress.fourth_star_specialty_served+=1
		if progress.stars==4:
			progress.fifth_star_auto_served+=1
			if customer.dish in Progression.ORCHESTRATION_DISHES: progress.fifth_star_solyanka_served+=1
		if progress.journey_auto_served==1: announce("Первый самостоятельный заработок клона! Теперь можно развивать вторую бригаду, формулу и отдых.")
	progress.record_demand(customer.dish,"served")

func _record_failed_order(customer: Dictionary,reason := "busy") -> void:
	if bool(customer.get("stats_finalized",false)): return
	customer.stats_finalized=true
	order_stats.orders_failed=int(order_stats.orders_failed)+1
	order_stats.portions_unserved=int(order_stats.portions_unserved)+maxi(0,int(customer.get("portions_total",1))-int(customer.get("portions_done",0)))
	missed+=1
	_analytics_loss(customer,reason)
	var legacy_reason: String="busy" if reason in ["busy","chef_wait","closing","wait"] else "untrained"
	progress.record_demand(str(customer.dish),legacy_reason)

func _finish_multi_departure(customer: Dictionary,station: Node3D,reason := "busy") -> void:
	if bool(customer.get("stats_finalized",false)): return
	customer.stats_finalized=true
	var total: int=int(customer.portions_total)
	var done: int=int(customer.get("portions_done",0))
	var remaining: int=maxi(0,total-done)
	if done>0: order_stats.orders_partial=int(order_stats.orders_partial)+1
	else: order_stats.orders_failed=int(order_stats.orders_failed)+1
	order_stats.portions_unserved=int(order_stats.portions_unserved)+remaining
	missed+=1
	_analytics_loss(customer,reason)
	progress.record_demand(str(customer.dish),"busy" if reason in ["busy","wait","closing","chef_wait"] else "untrained")
	_release_order_station(station,int(customer.id))
	customer.state="leaving"
	customer.path=[Vector3(17.4,0,1.65)]
	customer.view.playback_speed=1.0
	customer.view.caption.text="Получено %d/%d · +%d\nОстальное не дождался"%[done,total,int(customer.get("order_paid",0))]
	trace("multi_order_partial",{"dish":customer.dish,"done":done,"total":total,"paid":int(customer.get("order_paid",0))})

func _complete_multi_order(customer: Dictionary,station: Node3D) -> void:
	if bool(customer.get("stats_finalized",false)): return
	customer.stats_finalized=true
	order_stats.orders_completed=int(order_stats.orders_completed)+1
	Insights.complete(analytics,str(customer.dish),station.station_id if station!=null else 0)
	_count_completed_customer(customer,station)
	_release_order_station(station,int(customer.id))
	customer.state="leaving"
	customer.path=[Vector3(17.4,0,1.65)]
	customer.view.playback_speed=1.0
	customer.view.caption.text="%d/%d · +%d\nСпасибо!"%[int(customer.portions_done),int(customer.portions_total),int(customer.order_paid)]
	trace("multi_order_completed",{"dish":customer.dish,"portions":int(customer.portions_total),"paid":int(customer.order_paid)})

func advance_large_order_queue(delta: float) -> void:
	for customer in customers.duplicate():
		if int(customer.get("portions_total",1))<=1 or customer.state=="leaving": continue
		customer.order_age=float(customer.get("order_age",0.0))+delta
		_update_multi_caption(customer)
		if float(customer.order_age)>=float(customer.wait_limit) and customer.state!="portion_eating":
			var timeout_reason: String="wait" if int(customer.get("station",-1))>0 else str(problem_context(str(customer.dish)).reason)
			_finish_multi_departure(customer,by_id(int(customer.get("station",-1))),timeout_reason)
	var line: Array=customers.filter(func(c):return c.state=="auto_queue")
	for i in range(line.size()):
		var customer: Dictionary=line[i]
		if customer.state!="auto_queue": continue
		var candidates: Array=automatic_station_candidates(str(customer.dish),true)
		if not candidates.is_empty():
			assign_customer(candidates[0],customer)
		else:
			var goal:=auto_queue_point(i)
			if customer.view.position.distance_to(goal)>0.05: customer.path=[goal]
			_update_multi_caption(customer)

func advance(delta: float) -> void:
	Insights.tick(analytics,delta)
	if game != null and is_instance_valid(game.shop): game.shop.advance(delta)
	_try_begin_masterclass()
	if bool(movie_state.get("playing",false)):
		movie_state.elapsed=minf(float(movie_state.elapsed)+delta,float(movie_state.duration))
		if float(movie_state.elapsed)>=float(movie_state.duration): movie_state.playing=false
	# Shift closure is resolved before the queue may start another lesson. This makes
	# the boundary between two films deterministic.
	advance_shift(delta)
	if is_instance_valid(training_queue): training_queue.advance(delta)
	if is_instance_valid(staff_training): staff_training.advance(delta)
	if game != null and is_instance_valid(game.laboratory): game.laboratory.advance(delta)
	advance_event(delta)
	Visits.advance(self,delta)
	autosave_clock += delta
	if autosave_clock >= 30.0 and not progress.busy() and not any_training():
		autosave_clock = 0.0
		if game != null: game.save_cafe()
	if open_for_business and not progress.busy():
		if has_automatic_station():
			spawn_clock -= delta
			if spawn_clock <= 0:
				spawn_customer()
				spawn_clock = progress.arrival_interval()
		advance_chef_orders(delta)
	advance_queue(delta)
	advance_large_order_queue(delta)
	for station in stations:
		station.training.advance(delta)
		if station.state != "cooking": continue
		var record: Dictionary = station.recipes[station.order_dish]
		station.order_tick += delta * 60.0 * station.order_tempo
		station.show_tracks(record.tracks, mini(int(station.order_tick), station.Run.duration_ticks(record.tracks)-1))
		if station.type_id == "counter":
			for customer in customers:
				if customer.id == station.customer_id: customer.view.react(station.model.customer_reaction)
		if station.order_tick >= station.Run.duration_ticks(record.tracks):
			var current_customer: Dictionary={}
			for customer in customers:
				if int(customer.id)==int(station.customer_id):
					current_customer=customer
					break
			var portion_number: int=int(current_customer.get("portions_done",0))+1 if not current_customer.is_empty() else 0
			var order_id: int=int(current_customer.get("order_id",0)) if not current_customer.is_empty() else 0
			finish_customer(station.customer_id,true,"",portion_number,order_id)
			_start_pending_teacher(station)
	for index in range(customers.size() - 1, -1, -1):
		var customer: Dictionary = customers[index]
		if customer.state=="portion_eating":
			customer.eat_age+=delta
			customer.view.meal_age=customer.eat_age
			if customer.eat_age>=1.2:
				var table: Node3D=by_id(int(customer.station))
				if int(customer.portions_done)>=int(customer.portions_total): _complete_multi_order(customer,table)
				elif float(customer.order_age)>=float(customer.wait_limit): _finish_multi_departure(customer,table,"wait")
				elif table!=null: _start_automatic_order(table,customer)
			continue
		if customer.state=="eating":
			customer.eat_age+=delta
			customer.view.meal_age=customer.eat_age
			if customer.eat_age>=1.2:
				customer.state="leaving"; customer.path=[Vector3(17.4,0,1.65)]
				var table: Node3D=by_id(customer.station)
				if table!=null and table.customer_id==customer.id:
					table.customer_id=-1; table.state="idle"
					if table.pending_teacher>0:
						var teacher: int=table.pending_teacher; table.pending_teacher=0
						table.training.open(table.pending_dish,teacher)
			continue
		if not customer.path.is_empty():
			if customer.view.walk_to(customer.path[0], delta): customer.path.pop_front()
			continue
		if customer.state == "leaving":
			customer.view.queue_free()
			customers.remove_at(index)
		elif customer.state in ["walking", "waiting"]:
			customer.state="waiting"
			var station: Node3D=by_id(int(customer.station))
			if station==null: continue
			customer.view.rotation.y=station.global_rotation.y+PI
			if station.recipes.has(customer.dish) and not station.manual_station:
				_start_automatic_order(station,customer)
			elif station.manual_station:
				var request_text: String=preload("res://scripts/chef_orders.gd").special_request(station.customer_order)
				if request_text.is_empty(): request_text=Definition.DISHES[customer.dish]
				if customer.get("chef_order",false): request_text+="\nЗаказ шефу · ×%.1f"%float(station.customer_order.get("chef_bonus",1.0))
				customer.view.caption.text=request_text+" · [E] у стойки"
			else:
				customer.wait += delta
				customer.view.caption.text = Definition.DISHES[customer.dish] + "\nПовара ждут твоего показа · [E]"
				if customer.wait >= 14:
					finish_customer(customer.id,false,"unlearned")

func has_automatic_station() -> bool:
	for station in stations:
		if not station.manual_station: return true
	return false

func chef_order_recipe() -> String:
	var personal: Node3D=by_id(1)
	if personal==null or not personal.manual_station: return ""
	var pool: Array=personal.dishes().duplicate()
	if progress.stars==0 and "jug" not in personal.equipment: pool.erase("wine")
	if pool.is_empty(): return ""
	if progress.stars==0 and progress.tutorial_served.size()<3:
		for starter in ["sausage","potato","wine"]:
			if starter in pool and starter not in progress.tutorial_served: return starter
	return str(pool[rng.randi_range(0,pool.size()-1)])

func spawn_chef_customer() -> bool:
	if masterclass_locked(): return false
	if chef_queue().size()>=CHEF_QUEUE_LIMIT: return false
	var recipe:=chef_order_recipe()
	if recipe.is_empty(): return false
	return spawn_customer(recipe,false,true)

func advance_chef_orders(delta: float) -> void:
	if Visits.chef_reserved(progress) or masterclass_locked(): return
	chef_order_clock-=delta
	if chef_order_clock>0: return
	if chef_queue().size()<CHEF_QUEUE_LIMIT: spawn_chef_customer()
	# A full queue deliberately consumes this opportunity too. A new interval starts now,
	# so serving one customer never causes an immediate replacement to appear.
	chef_order_clock=progress.chef_order_delay(rng)

func spawn_customer(recipe := "", banquet := false, chef_guest := false, visit_data: Dictionary = {}, requested_portions := 0) -> bool:
	if customers.size() >= 18: return false
	var organic_order: bool=recipe.is_empty()
	if recipe.is_empty():
		var pool: Array = progress.available_dishes()
		if progress.stars == 0 and by_id(1) != null and "jug" not in by_id(1).equipment: pool.erase("wine")
		recipe = pool[rng.randi_range(0, pool.size() - 1)]
		if progress.stars == 0 and progress.tutorial_served.size() < 3:
			for starter in ["sausage","potato","wine"]:
				if starter in pool and starter not in progress.tutorial_served: recipe = starter; break
	if not recipe in Definition.DISHES: return false
	var portions: int=int(requested_portions)
	if portions<=0:
		portions=portion_count_for_new_order() if organic_order and not banquet and not chef_guest and visit_data.is_empty() else 1
	if portions not in [1,3,5,10]: portions=1
	if banquet or chef_guest or not visit_data.is_empty(): portions=1
	var candidates: Array=[]
	var untrained: Array=[]
	var offered:=false
	for station in stations:
		if not recipe in station.dishes(): continue
		if station.manual_station or not station.dish_active(recipe) or not station.ready_crew(): continue
		if station.recipes.has(recipe): offered=true
		if station.state=="idle" and station.pending_teacher==0:
			if station.recipes.has(recipe): candidates.append(station)
			elif portions==1: untrained.append(station)
	if candidates.is_empty() and portions==1 and not banquet and not chef_guest and visit_data.is_empty(): candidates=untrained
	if chef_guest:
		var personal:=by_id(1)
		candidates=[personal] if personal!=null and personal.manual_station and recipe in personal.dishes() and chef_queue().size()<CHEF_QUEUE_LIMIT else []
	var station: Node3D=null if candidates.is_empty() else candidates[rng.randi_range(0,candidates.size()-1)]
	if station==null and not visit_data.is_empty(): return false
	var problem: Dictionary=problem_context(recipe)
	var queue_large: bool=station==null and portions>1 and str(problem.reason)=="busy" and not banquet and not chef_guest and visit_data.is_empty()
	var person:=Person.new()
	person.color=Color("d6b56b") if banquet else [Color("ae7381"),Color("839fbb"),Color("c6a66b"),Color("91aa78")][next_customer_id%4]
	add_child(person)
	person.position=Vector3(-11.4,0,1.65)
	person.caption.text=Definition.DISHES[recipe]+(" ×%d"%portions if portions>1 else "")
	var data: Dictionary={"id":next_customer_id,"order_id":next_order_id,"view":person,"station":station.station_id if station!=null else -1,"dish":recipe,"state":"walking","wait":0.0,"path":[],"banquet":banquet,"chef_order":chef_guest and not banquet,"portions_total":portions,"portions_done":0,"order_paid":0,"order_age":0.0,"wait_limit":order_wait_limit(portions,station,recipe),"stats_finalized":false}
	next_order_id+=1
	guests_arrived+=1
	order_stats.orders_arrived=int(order_stats.orders_arrived)+1
	order_stats.portions_ordered=int(order_stats.portions_ordered)+portions
	Insights.arrival(analytics,recipe,portions)
	if not visit_data.is_empty():
		data.visit_id=int(visit_data.id); data.visit_slot=int(visit_data.slot); data.visit_kind=str(visit_data.kind)
		data.chef_order=false
		Visits.badge(person,str(visit_data.kind))
	if station==null:
		if queue_large:
			data.state="auto_queue"
			data.path=[auto_queue_point(customers.filter(func(c):return c.state=="auto_queue").size())]
			_update_multi_caption(data)
		else:
			data.state="leaving"
			data.path=[Vector3(-9.6,0,2.6),Vector3(17.4,0,1.65)]
			person.caption.text+="\n"+Insights.reason_label(str(problem.reason))
			_record_failed_order(data,str(problem.reason))
			if banquet: progress.banquet_finished+=1
	else:
		if station.manual_station:
			var order_serial: int=maxi(3,progress.manual_served) if banquet and chef_guest else progress.manual_served
			data.order=preload("res://scripts/chef_orders.gd").choose(recipe,station.equipment,order_serial,rng)
			if chef_guest and not banquet:
				var chef_bonus: float=progress.chef_order_premium()
				data.order.chef_bonus=chef_bonus
				data.order.premium=float(data.order.get("premium",1.0))*chef_bonus
		else: data.order={}
		if not visit_data.is_empty() and station.manual_station: data.order=preload("res://scripts/chef_orders.gd").standard(recipe)
		if station.manual_station and (station.state!="idle" or station.customer_id>=0 or not chef_queue().is_empty()):
			data.state="queued"
			data.path=[queue_point(chef_queue().size())]
			person.caption.text=Definition.DISHES[recipe]+"\nОчередь к шефу"
		else: assign_customer(station,data)
	trace("customer_arrived",{"dish":recipe,"station":data.station,"portions":portions,"order":station.customer_order if station!=null else {}})
	customers.append(data)
	next_customer_id+=1
	return station!=null or queue_large

func finish_customer(id: int, accepted: bool, failure_reason := "", portion_number := 0, expected_order_id := 0) -> void:
	for customer in customers:
		if customer.id!=id or customer.state in ["leaving","eating","portion_eating"]: continue
		if expected_order_id>0 and int(customer.get("order_id",0))!=expected_order_id: return
		if bool(customer.get("stats_finalized",false)): return
		if customer.state=="queued": dismiss_queue(customer,failure_reason if not failure_reason.is_empty() else "busy"); return
		var station: Node3D=by_id(int(customer.get("station",-1)))
		if int(customer.get("portions_total",1))>1:
			if not accepted:
				_finish_multi_departure(customer,station,"busy")
				return
			if station==null: return
			var next_portion: int=int(customer.get("portions_done",0))+1
			if portion_number<=0: portion_number=next_portion
			if portion_number!=next_portion: return
			var report: Dictionary=station.model.quality()
			var paid: bool=bool(report.get("present",false))
			var payment: int=roundi(base_price_for(str(customer.dish))*float(report.get("price_factor",0.0))*float(report.get("style_multiplier",1.0))) if paid else 0
			if not paid:
				trace("multi_portion_rejected",{"dish":customer.dish,"done":int(customer.get("portions_done",0))})
				_start_automatic_order(station,customer)
				return
			customer.portions_done=int(customer.get("portions_done",0))+1
			customer.order_paid=int(customer.get("order_paid",0))+payment
			station.order_portions_done=int(customer.portions_done)
			station.order_paid=int(customer.order_paid)
			order_stats.portions_served=int(order_stats.portions_served)+1
			Insights.portion(analytics,str(customer.dish),station.station_id,payment)
			revenue+=payment
			progress.cash+=payment
			var payload: Array=station.model.take_serving()
			for item in payload: item.from=station.to_global(item.from)
			trace("multi_portion_paid",{"dish":customer.dish,"portion":int(customer.portions_done),"total":int(customer.portions_total),"payment":payment,"paid_total":int(customer.order_paid)})
			_update_multi_caption(customer)
			if not payload.is_empty():
				customer.state="portion_eating"
				customer.eat_age=0.0
				customer.path=[]
				customer.view.begin_meal(payload)
				station.state="serving"
				station.customer_id=customer.id
			else:
				if int(customer.portions_done)>=int(customer.portions_total): _complete_multi_order(customer,station)
				else: _start_automatic_order(station,customer)
			return
		if station==null: return
		var report: Dictionary=station.model.quality()
		var paid:=accepted and bool(report.get("present",false))
		var premium: float=float(station.customer_order.get("premium",1.0)) if station.manual_station else 1.0
		var payment:=roundi(base_price_for(str(customer.dish))*float(report.price_factor)*float(report.style_multiplier)*premium) if paid else 0
		trace("customer_finished",{"dish":customer.dish,"station":station.station_id,"grade":report.grade,"payment":payment,"accepted":paid})
		customer.state="leaving"
		customer.view.playback_speed=1.0
		customer.view.caption.text="%s · +%d\nСпасибо!"%[report.grade,payment] if paid else "Загляну позже"
		if paid and report.get("style_count",0)>0: customer.view.caption.text+="\nЛовкая подача · +20%"
		customer.path=[Vector3(17.4,0,1.65)]
		station.customer_id=-1
		if not station.training.active(): station.state="idle"
		if accepted:
			var payload: Array=station.model.take_serving()
			if not payload.is_empty():
				for item in payload: item.from=station.to_global(item.from)
				customer.state="eating"; customer.eat_age=0.0; customer.path=[]
				customer.view.begin_meal(payload)
				station.state="serving"; station.customer_id=customer.id
		if paid:
			customer.stats_finalized=true
			order_stats.orders_completed=int(order_stats.orders_completed)+1
			order_stats.portions_served=int(order_stats.portions_served)+1
			Insights.portion(analytics,str(customer.dish),station.station_id,payment)
			Insights.complete(analytics,str(customer.dish),station.station_id)
			_count_completed_customer(customer,station)
			revenue+=payment
			progress.cash+=payment
		else:
			var reason: String=str(failure_reason)
			if reason.is_empty(): reason="unlearned" if not station.recipes.has(str(customer.dish)) else "wait"
			_record_failed_order(customer,reason)
		if customer.get("banquet",false):
			progress.banquet_finished+=1
			if paid: progress.banquet_served+=1
			if paid and report.grade in ["B","A","S"]: progress.banquet_good+=1
		Visits.settled(self,customer,paid,str(report.grade))
		return

func purchase(kind: String, id: String, station_id := 0, with_installer := false) -> String:
	if progress.busy(): return "Сначала заверши проверку."
	if kind == "lab_expansion":
		if not game.session.sleeping_peers.is_empty(): return "Сначала все должны встать с кровати."
		return preload("res://scripts/laboratory_progression.gd").expand(progress)
	if kind == "lounge_expansion":
		if not game.session.sleeping_peers.is_empty(): return "Сначала все должны встать с кровати."
		var error: String=preload("res://scripts/lounge_progression.gd").expand(progress)
		if error.is_empty(): trace("lounge_expanded",{"tier":progress.lounge_tier})
		return error
	if kind == "orchestration_expansion":
		if progress.stars < 4: return "Нужна четвёртая звезда."
		if progress.orchestration_expanded: return "Сектор оркестрации уже открыт."
		if progress.cash < Progression.ORCHESTRATION_EXPANSION_PRICE: return "Не хватает денег."
		progress.cash -= Progression.ORCHESTRATION_EXPANSION_PRICE
		progress.orchestration_expanded = true
		progress.revision += 1
		trace("orchestration_expansion")
		return ""
	if kind == "specialty_expansion":
		if progress.stars < 3: return "Нужна третья звезда."
		if progress.specialized_expanded: return "Специализированный сектор уже открыт."
		if progress.cash < Progression.SPECIALTY_EXPANSION_PRICE: return "Не хватает денег."
		progress.cash -= Progression.SPECIALTY_EXPANSION_PRICE
		progress.specialized_expanded = true
		progress.revision += 1
		trace("specialty_expansion")
		return ""
	if kind == "expansion":
		if progress.stars < 2: return "Нужна вторая звезда."
		if progress.expanded: return "Зал уже расширен."
		if progress.cash < Progression.EXPANSION_PRICE: return "Не хватает денег."
		progress.cash -= Progression.EXPANSION_PRICE
		progress.expanded = true
		progress.revision += 1
		trace("expansion")
		return ""
	var item := "sauce_ramp" if kind == "upgrade" else kind if kind in ["counter","kitchen","grill_kitchen","solyanka_kitchen"] else id
	return game.shop.order(item, station_id, with_installer)

func start_banquet(peer: int) -> String:
	if Visits.busy(progress): return "Сначала заверши или отмени добровольный визит в компьютере."
	if not progress.can_attempt(stations, served): return "Подготовь кафе по списку во вкладке «Звёзды»."
	if any_training(): return "Сначала закончи текущие показы."
	progress.return_open = open_for_business
	open_for_business = false
	# Do not wait forever for an unattended personal/untrained counter.
	for customer in customers:
		if customer.state in ["walking","waiting"]: finish_customer(customer.id,false,"closing")
	progress.phase = "preparing"
	progress.event_peer = peer
	progress.result = ""
	progress.banquet_spawned = 0
	progress.banquet_finished = 0
	progress.banquet_served = 0
	progress.banquet_good = 0
	progress.showcase_grade = ""
	progress.orders = progress.inspection_orders()
	progress.revision += 1
	return ""

func is_showcase(station: Node3D) -> bool:
	return progress.phase == "showcase" and station.station_id == 1

func finish_showcase(report: Dictionary) -> void:
	if progress.phase != "showcase": return
	progress.showcase_grade = report.grade
	if not report.present or not report.grade in ["B", "A", "S"]:
		finish_banquet(false, "Личный показ: %s. Инспектор ждёт картофель на B или лучше." % report.grade)
		return
	by_id(1).training.close()
	progress.phase = "service"
	progress.remaining = Progression.BANQUET_SECONDS
	banquet_clock = 2.0
	progress.revision += 1
	announce("Инспектор доволен! Теперь бригады обслуживают девять гостей.")

func advance_event(delta: float) -> void:
	if progress.phase == "tasting": return
	if progress.phase == "preparing":
		for station in stations:
			if station.state != "idle": return
		if progress.stars == 0:
			progress.phase = "tasting"
			progress.tasting_done.clear()
			start_tasting_dish()
			return
		progress.phase = "service"
		progress.remaining = progress.inspection_seconds()
		banquet_clock = 1
		progress.revision += 1
		if progress.stars==4: announce("День пяти звёзд начинается! Сначала общий наплыв, затем критики, затем финальная нагрузка на всё кафе.")
		elif progress.stars==3: announce("Три волны начинаются! Сначала смешанный поток, затем бургерный пик и финальная общая нагрузка.")
		elif progress.stars==2: announce("Большой обед начинается! Три заказа остаются за шефом, остальной поток должен выдержать автоматизированный зал.")
		else: announce("Делегация идёт! Трое гостей хотят личный заказ шефа.")
	elif progress.phase in ["showcase", "service"]:
		progress.remaining = maxf(0.0, progress.remaining - delta)
		if progress.phase == "service":
			banquet_clock -= delta
			if banquet_clock <= 0 and progress.banquet_spawned < progress.orders.size():
				# Guests wait outside for a compatible trained station; the shared deadline keeps throughput meaningful.
				var dish: String = progress.orders[progress.banquet_spawned]
				var chef_guest: bool = progress.banquet_spawned in progress.inspection_chef_indices()
				var available: bool = chef_queue().size()<3 if chef_guest else false
				if not chef_guest:
					for station in stations:
						if station.ready_crew() and not station.manual_station and station.state=="idle" and station.recipes.has(dish): available=true
				if available and spawn_customer(dish,true,chef_guest):
					progress.banquet_spawned += 1
					if progress.stars==4 and progress.banquet_spawned==Progression.FINAL_INSPECTION_PHASE_SIZE:
						announce("Фаза 2/3 · Критики. Теперь поток смещается к сложным блюдам и качеству.")
					elif progress.stars==4 and progress.banquet_spawned==Progression.FINAL_INSPECTION_PHASE_SIZE*2:
						announce("Фаза 3/3 · Общий финал. Все линии и личные заказы шефа работают одновременно.")
					banquet_clock = progress.inspection_spawn_interval(progress.banquet_spawned)
			if progress.banquet_finished >= progress.inspection_guest_count():
				finish_banquet(progress.banquet_served >= progress.inspection_served_target() and progress.banquet_good >= progress.inspection_good_target())
				return
		if progress.remaining <= 0:
			finish_banquet(progress.phase == "service" and progress.banquet_served >= progress.inspection_served_target() and progress.banquet_good >= progress.inspection_good_target(), "Время проверки вышло.")

func finish_banquet(won: bool, reason := "") -> void:
	if not progress.busy(): return
	var attempted_from_star: int = progress.stars
	var served_target: int = progress.inspection_served_target()
	var good_target: int = progress.inspection_good_target()
	var event_name: String = progress.inspection_name()
	# A timed-out order cannot pay or contribute after the result is frozen.
	for customer in customers:
		if customer.get("banquet", false) and customer.state != "leaving": finish_customer(customer.id, false)
	for station in stations:
		if station.training.active(): station.training.close()
	progress.phase = "won" if won else "lost"
	if won and attempted_from_star == 1:
		progress.stars = 2
		progress.cash += 200
		progress.third_star_auto_served = 0
		progress.result = "Вторая звезда! +200. Открыты расширение зала и кухня «Мясо и макароны»."
	elif won and attempted_from_star == 2:
		progress.stars = 3
		progress.cash += Progression.BIG_LUNCH_REWARD
		progress.fourth_star_auto_served = 0
		progress.fourth_star_specialty_served = 0
		progress.result = "Третья звезда! +%d. Открыта специализация: новый сектор и кухня с общей жарочной поверхностью." % Progression.BIG_LUNCH_REWARD
	elif won and attempted_from_star == 3:
		progress.stars = 4
		progress.cash += Progression.FOURTH_STAR_REWARD
		progress.fifth_star_auto_served = 0
		progress.fifth_star_solyanka_served = 0
		progress.result = "Четвёртая звезда! +%d. Открыт сектор оркестрации и кухня «Солянка» на три роли." % Progression.FOURTH_STAR_REWARD
	elif won and attempted_from_star == 4:
		progress.result = "День пяти звёзд завершён успешно. Каркас финальной смены работает; итоговая шкала и выдача 5★ подключаются следующим этапом."
	elif not won and attempted_from_star == 0:
		progress.result = reason + " Можно пригласить дегустатора снова бесплатно."
	else:
		progress.result = "%s %s: обслужено %d/%d, B или выше %d/%d. Подготовься и попробуй снова бесплатно." % [reason, event_name, progress.banquet_served, served_target, progress.banquet_good, good_target]
	open_for_business = progress.return_open
	spawn_clock = progress.arrival_interval()
	chef_order_clock = progress.chef_order_delay(rng)
	progress.revision += 1
	announce(progress.result)
	if game != null: game.save_cafe()

func announce(message: String) -> void:
	if game == null or not is_instance_valid(game.session): return
	game.session.message_to(1, message)
	for id in game.session.members:
		if id != 1: game.session.message_to(id, message)

func refresh_views(delta := 0.016) -> void:
	for station in stations: station.refresh(game.session.local_id(), delta)
	for customer in customers:
		customer.view.watching = customer.state in ["waiting", "cooking", "training"]
		if customer.view.watching:
			var station: Node3D = by_id(customer.station)
			if is_instance_valid(station): station.direct_attention(customer.view)

func _customer_save_entry(customer: Dictionary) -> Dictionary:
	var view: Node3D=customer.view
	var data: Dictionary={
		"id":int(customer.get("id",0)),
		"order_id":int(customer.get("order_id",0)),
		"station":int(customer.get("station",-1)),
		"dish":str(customer.get("dish","")),
		"state":str(customer.get("state","walking")),
		"wait":float(customer.get("wait",0.0)),
		"path":customer.get("path",[]).duplicate(),
		"banquet":bool(customer.get("banquet",false)),
		"chef_order":bool(customer.get("chef_order",false)),
		"portions_total":int(customer.get("portions_total",1)),
		"portions_done":int(customer.get("portions_done",0)),
		"order_paid":int(customer.get("order_paid",0)),
		"order_age":float(customer.get("order_age",0.0)),
		"wait_limit":float(customer.get("wait_limit",0.0)),
		"stats_finalized":bool(customer.get("stats_finalized",false)),
		"eat_age":float(customer.get("eat_age",0.0)),
		"automatic_serving":bool(customer.get("automatic_serving",false)),
		"order":customer.get("order",{}).duplicate(true),
		"position":view.position,
		"yaw":view.rotation.y,
		"color":view.color,
		"meal":view.meal_items.duplicate(true),
		"meal_age":view.meal_age,
		"playback_speed":view.playback_speed,
		"mouth_amount":view.mouth_amount,
		"drinking":view.drinking,
		"drunk_ml":view.drunk_ml,
		"chewing":view.chewing,
		"caption":view.caption.text
	}
	for key in ["visit_id","visit_slot","visit_kind"]:
		if customer.has(key): data[key]=customer[key]
	return data

func _restore_customer(data: Dictionary) -> bool:
	var id:=int(data.get("id",0))
	var order_id:=int(data.get("order_id",0))
	var dish:=str(data.get("dish",""))
	var state:=str(data.get("state","walking"))
	if id<=0 or order_id<=0 or dish not in Definition.DISHES: return false
	if state not in ["walking","waiting","queued","auto_queue","cooking","training","serving","eating","portion_eating","leaving"]: return false
	var person:=Person.new()
	person.color=data.get("color",Color("a66c76"))
	add_child(person)
	person.position=data.get("position",Vector3(-11.4,0,1.65))
	person.rotation.y=float(data.get("yaw",0.0))
	person.playback_speed=float(data.get("playback_speed",1.0))
	person.mouth_amount=float(data.get("mouth_amount",0.0))
	person.drinking=bool(data.get("drinking",false))
	person.drunk_ml=float(data.get("drunk_ml",0.0))
	person.chewing=float(data.get("chewing",0.0))
	person.caption.text=str(data.get("caption",Definition.DISHES[dish]))
	var customer: Dictionary={
		"id":id,"order_id":order_id,"view":person,"station":int(data.get("station",-1)),"dish":dish,"state":state,
		"wait":float(data.get("wait",0.0)),"path":data.get("path",[]).duplicate(),"banquet":bool(data.get("banquet",false)),
		"chef_order":bool(data.get("chef_order",false)),"portions_total":maxi(1,int(data.get("portions_total",1))),
		"portions_done":maxi(0,int(data.get("portions_done",0))),"order_paid":maxi(0,int(data.get("order_paid",0))),
		"order_age":maxf(0.0,float(data.get("order_age",0.0))),"wait_limit":maxf(0.0,float(data.get("wait_limit",0.0))),
		"stats_finalized":bool(data.get("stats_finalized",false)),"eat_age":maxf(0.0,float(data.get("eat_age",0.0))),
		"automatic_serving":bool(data.get("automatic_serving",false)),"order":data.get("order",{}).duplicate(true)
	}
	for key in ["visit_id","visit_slot","visit_kind"]:
		if data.has(key): customer[key]=data[key]
	if data.get("meal",[]) is Array and not data.get("meal",[]).is_empty() and state in ["eating","portion_eating"]:
		person.begin_meal(data.meal)
		person.meal_age=float(data.get("meal_age",customer.eat_age))
		customer.eat_age=float(data.get("eat_age",person.meal_age))
	if customer.has("visit_kind"): Visits.badge(person,str(customer.visit_kind))
	var station:=by_id(int(customer.station))
	if station!=null and station.manual_station and state=="training":
		customer.state="waiting"
		customer.path=[]
		station.state="waiting"
		station.customer_id=id
		station.order_dish=dish
		station.customer_order=customer.order.duplicate(true)
		person.caption.text=(preload("res://scripts/chef_orders.gd").special_request(station.customer_order) if not station.customer_order.is_empty() else Definition.DISHES[dish])+" · [E] у стойки"
	customers.append(customer)
	next_customer_id=maxi(next_customer_id,id+1)
	next_order_id=maxi(next_order_id,order_id+1)
	return true

func _restore_active_customers(saved_customers: Array) -> bool:
	for raw in saved_customers:
		if not raw is Dictionary or not _restore_customer(raw): return false
	for station in stations:
		if station.state!="training" or station.training.active(): continue
		var attached:=false
		for customer in customers:
			if int(customer.get("station",-1))==station.station_id and int(customer.get("id",0))==station.customer_id and str(customer.get("state",""))=="waiting":
				attached=true
				break
		if not attached:
			station.state="idle"
			station.customer_id=-1
			station.customer_order={}
	return true

func save_data() -> Dictionary:
	var entries: Array = []
	var stable_stations: Array=stations.duplicate()
	if masterclass_active() and is_instance_valid(chef_station_backup):
		stable_stations.erase(masterclass_station)
		stable_stations.push_front(chef_station_backup)
	for station in stable_stations:
		var entry: Dictionary = station.save_entry()
		entry.crew = entry.crew.duplicate(true)
		entry.equipment = entry.equipment.duplicate()
		entry.upgrades = entry.upgrades.duplicate()
		entry.recipes = entry.recipes.duplicate()
		entry.drafts = entry.drafts.duplicate()
		entry.method_sources=entry.method_sources.duplicate(true)
		entry.method_plan=entry.method_plan.duplicate(true)
		entry.active_dishes=entry.active_dishes.duplicate()
		entries.append(entry)
	_ensure_groups()
	var saved_customers: Array=[]
	for customer in customers: saved_customers.append(_customer_save_entry(customer))
	return {"format":"station-cafe","version":22,"progression":progress.snapshot(),"stations":entries,"customers":saved_customers,"next_customer_id":next_customer_id,"next_order_id":next_order_id,"served":served,"revenue":revenue,"missed":missed,"guests_arrived":guests_arrived,"order_stats":order_stats.duplicate(true),"analytics":analytics.duplicate(true),"open":open_for_business,"chef_order_clock":chef_order_clock,"masterclasses":masterclasses.duplicate(true),"next_masterclass_id":next_masterclass_id,"table_group_names":table_group_names.duplicate(true),"table_group_registry":group_registry.snapshot(),"training_queue":training_queue.snapshot(),"staff_training":staff_training.snapshot(true),"movie":movie_state.duplicate(true),"remote_movie_record":remote_movie_record.duplicate(true)}

func clear_world() -> void:
	if is_instance_valid(staff_training): staff_training.reset()
	if is_instance_valid(training_queue): training_queue.reset()
	if is_instance_valid(chef_station_backup):
		chef_station_backup.queue_free()
		chef_station_backup=null
	masterclass_station=null
	masterclass_pending.clear()
	if is_instance_valid(masterclass_live_scene): masterclass_live_scene.queue_free()
	masterclass_live_scene=null
	movie_state={"id":0,"playing":false,"elapsed":0.0,"duration":0.0,"started_by":0}
	remote_movie_record={}
	table_group_names.clear()
	group_registry.reset()
	for station in stations:
		remove_child(station)
		station.queue_free()
	for customer in customers:
		remove_child(customer.view)
		customer.view.queue_free()
	stations.clear()
	customers.clear()
	next_customer_id=1
	next_order_id=1
	chef_order_clock=3.0

func _saved_slot(entry: Dictionary, version: int) -> int:
	if version >= 4: return int(entry.get("slot", -1))
	return int(entry.get("id", 0)) - 1

func load_data(data: Dictionary) -> bool:
	var version: int = int(data.get("version", 0))
	if data.get("format") != "station-cafe" or not version in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22] or not data.get("stations") is Array: return false
	if version >= 5 and not data.get("progression") is Dictionary: return false
	if version>=16 and not data.get("table_group_names",{}) is Dictionary: return false
	if version>=18 and not data.get("order_stats",{}) is Dictionary: return false
	if version>=19 and not data.get("analytics",{}) is Dictionary: return false
	if version>=20 and not data.get("table_group_registry",{}) is Dictionary: return false
	if version>=21 and (not data.get("training_queue",{}) is Dictionary or not data.get("staff_training",{}) is Dictionary or not data.get("movie",{}) is Dictionary or not data.get("remote_movie_record",{}) is Dictionary): return false
	if version>=22 and (not data.get("customers",[]) is Array or int(data.get("next_customer_id",0))<=0 or int(data.get("next_order_id",0))<=0): return false
	if version>=22:
		var customer_ids: Array=[]
		var order_ids: Array=[]
		for saved_customer in data.customers:
			if not saved_customer is Dictionary: return false
			var saved_id:=int(saved_customer.get("id",0))
			var saved_order_id:=int(saved_customer.get("order_id",0))
			var saved_station:=int(saved_customer.get("station",-1))
			var saved_total:=int(saved_customer.get("portions_total",1))
			var saved_done:=int(saved_customer.get("portions_done",0))
			if saved_id<=0 or saved_order_id<=0 or saved_id in customer_ids or saved_order_id in order_ids: return false
			if str(saved_customer.get("dish","")) not in Definition.DISHES: return false
			if str(saved_customer.get("state","")) not in ["walking","waiting","queued","auto_queue","cooking","training","serving","eating","portion_eating","leaving"]: return false
			if saved_station<-1 or saved_station>SLOT_COUNT: return false
			if saved_total<1 or saved_done<0 or saved_done>saved_total or int(saved_customer.get("order_paid",0))<0: return false
			if not saved_customer.get("path",[]) is Array or not saved_customer.get("order",{}) is Dictionary or typeof(saved_customer.get("stats_finalized",false))!=TYPE_BOOL: return false
			customer_ids.append(saved_id)
			order_ids.append(saved_order_id)
	var slots: Array = []
	for entry in data.stations:
		if not entry is Dictionary or not entry.get("type", "") in Definition.TYPES: return false
		var slot_index := _saved_slot(entry, version)
		if slot_index < 0 or slot_index >= SLOT_COUNT or slot_index in slots: return false
		slots.append(slot_index)
		if not entry.get("crew") is Array or entry.crew.size() != Definition.TYPES[entry.type].roles.size(): return false
		for member in entry.crew:
			if not member is Dictionary or not member.get("name") is String: return false
		if not entry.get("recipes") is Dictionary or not entry.get("drafts") is Dictionary or not entry.get("upgrades") is Array: return false
		if version>=16 and not entry.get("method_sources",{}) is Dictionary: return false
		if version>=17 and not entry.get("method_plan",{}) is Dictionary: return false
		if version>=20 and (not entry.get("active_dishes",[]) is Array or typeof(entry.get("active_menu_initialized",false))!=TYPE_BOOL): return false
		if version>=22:
			if str(entry.get("state","idle")) not in ["idle","waiting","cooking","serving","training"]: return false
			if not entry.get("customer_order",{}) is Dictionary or not entry.get("order_model",{}) is Dictionary: return false
			if not Station.TeamModel.finite(entry.get("order_tick",0.0)) or not Station.TeamModel.finite(entry.get("order_tempo",1.0)): return false
			if int(entry.get("order_portions_total",1))<1 or int(entry.get("order_portions_done",0))<0 or int(entry.get("order_paid",0))<0: return false
		for collection in [entry.recipes, entry.drafts]:
			for dish in collection:
				if not dish in Definition.TYPES[entry.type].dishes: return false
				if collection == entry.recipes and not collection[dish] is Dictionary: return false
				var tracks = collection[dish].get("tracks", []) if collection == entry.recipes else collection[dish]
				if not valid_tracks(tracks, entry.type): return false
				if collection == entry.recipes:
					if not Station.TeamModel.finite(collection[dish].get("duration")): return false
					for track in tracks:
						if track.is_empty() or track.frames.is_empty(): return false
	if version>=14:
		if not data.get("masterclasses",[]) is Array: return false
		for record in data.get("masterclasses",[]):
			if not Masterclasses.valid(record): return false
	clear_world()
	suppress_group_autocreate=true
	for entry in data.stations:
		var slot_index := _saved_slot(entry, version)
		var station := add_station(entry.type, slot_index, entry.get("manual", false))
		station.staffed = int(entry.get("staffed",station.role_count()))
		station.equipment = entry.get("equipment",station.equipment).duplicate()
		station.apply_equipment()
		station.crew = entry.crew.duplicate(true)
		station.upgrades = entry.upgrades.duplicate(true)
		station.apply_upgrades()
		station.recipes = entry.recipes.duplicate(true)
		station.drafts = entry.drafts.duplicate(true)
		station.method_sources=entry.get("method_sources",{}).duplicate(true)
		station.method_plan=entry.get("method_plan",{}).duplicate(true)
		station.active_dishes=entry.get("active_dishes",[]).duplicate()
		station.active_menu_initialized=bool(entry.get("active_menu_initialized",false)) if version>=20 else false
		if version>=22:
			station.state=str(entry.get("state","idle"))
			station.order_dish=str(entry.get("order_dish",""))
			station.order_tick=maxf(0.0,float(entry.get("order_tick",0.0)))
			station.order_tempo=maxf(0.01,float(entry.get("order_tempo",1.0)))
			station.order_portions_total=maxi(1,int(entry.get("order_portions_total",1)))
			station.order_portions_done=maxi(0,int(entry.get("order_portions_done",0)))
			station.order_paid=maxi(0,int(entry.get("order_paid",0)))
			station.customer_id=int(entry.get("customer_id",-1))
			station.customer_order=entry.get("customer_order",{}).duplicate(true)
			station.pending_teacher=int(entry.get("pending_teacher",0))
			station.pending_dish=str(entry.get("pending_dish",""))
			if entry.get("order_model",{}) is Dictionary and not entry.get("order_model",{}).is_empty(): station.model.restore(entry.order_model)
		for role in range(station.role_count()): station.students[role].caption.text = station.crew[role].name
	suppress_group_autocreate=false
	served=int(data.get("served",0))
	revenue=int(data.get("revenue",0))
	missed=int(data.get("missed",0))
	if version>=18:
		guests_arrived=maxi(0,int(data.get("guests_arrived",served+missed)))
		order_stats=blank_order_stats()
		for key in order_stats: order_stats[key]=maxi(0,int(data.get("order_stats",{}).get(key,0)))
	else:
		guests_arrived=maxi(0,served+missed)
		order_stats={"orders_arrived":guests_arrived,"orders_completed":served,"orders_partial":0,"orders_failed":missed,"portions_ordered":guests_arrived,"portions_served":served,"portions_unserved":missed}
	analytics=Insights.normalize(data.get("analytics",{})) if version>=19 else Insights.blank()
	table_group_names=data.get("table_group_names",{}).duplicate(true) if version>=16 and data.get("table_group_names",{}) is Dictionary else {}
	masterclasses=data.get("masterclasses",[]).duplicate(true) if version>=14 else []
	next_masterclass_id=maxi(1,int(data.get("next_masterclass_id",1))) if version>=14 else 1
	if version<14: _archive_legacy_recipes()
	for record in masterclasses:
		Masterclasses.ensure_highlights(record)
		next_masterclass_id=maxi(next_masterclass_id,int(record.get("id",0))+1)
	if version>=20:
		if not group_registry.restore(data.get("table_group_registry",{}),Definition.TYPES): return false
	else:
		group_registry.migrate_legacy(stations,table_group_names,Definition.TYPES)
	_ensure_groups()
	_sync_all_group_intent()
	open_for_business = data.get("open", true)
	progress = Progression.new()
	if data.get("progression") is Dictionary:
		progress.restore(data.progression)
		if version<8: progress.starter_reward=progress.manual_served>0
		progress.recover_deliveries()
		if data.progression.get("phase", "none") in ["preparing", "showcase", "service", "tasting"]: open_for_business = progress.return_open
	if not data.get("progression",{}).has("journey_auto_served"):
		progress.journey_auto_served=maxi(0,served-progress.manual_served)
	# Unfinished visit guests are re-created by slot; paid slots stay settled.
	if Visits.busy(progress): progress.visit.spawn_clock=0.0
	# A rag now belongs to every counter. Refund outstanding old rag deliveries.
	for parcel in progress.deliveries.duplicate():
		var items: Array = parcel.get("items", [parcel.item]).duplicate()
		if "rag" not in items: continue
		items.erase("rag")
		progress.cash += 12
		if items.is_empty(): progress.deliveries.erase(parcel)
		else: parcel.item = items[0]; parcel.items = items
	normalize_workers()
	if not data.get("progression",{}).has("lab_formula_tempo"):
		var known:=0.70
		for option in clone_options(): known=maxf(known,float(option.tempo))
		progress.lab_formula_tempo=known
		progress.lab_formula_version=1 if not clone_options().is_empty() else 0
	if game != null and is_instance_valid(game.laboratory): game.laboratory.recover()
	assign_clones()
	spawn_clock = progress.arrival_interval()
	chef_order_clock=float(data.get("chef_order_clock",progress.chef_order_delay(rng)))
	if version>=22:
		next_customer_id=maxi(1,int(data.get("next_customer_id",1)))
		next_order_id=maxi(1,int(data.get("next_order_id",1)))
		if not _restore_active_customers(data.get("customers",[])): return false
	if version>=21:
		if not training_queue.restore(data.get("training_queue",{})): return false
		apply_movie_snapshot(data.get("movie",{}))
		remote_movie_record=data.get("remote_movie_record",{}).duplicate(true)
		staff_training.apply_snapshot(data.get("staff_training",{}))
	else:
		training_queue.reset()
		staff_training.reset()
		training_queue.migrate_from_plans()
	request_auto_training_reconcile()
	return true

func valid_tracks(tracks: Variant, type_id: String) -> bool:
	if not tracks is Array or tracks.size() != Definition.TYPES[type_id].roles.size(): return false
	var sample = Station.model_for_type(type_id)
	sample.reset(Definition.TYPES[type_id].dishes[0])
	for role in range(tracks.size()):
		var track = tracks[role]
		if not track is Dictionary: return false
		if track.is_empty(): continue
		if not track.get("group") is int or not track.get("frames") is Array: return false
		var schema: Dictionary = sample.snapshot() if type_id == "counter" else sample.zone_snapshot(role)
		for frame in track.frames:
			if not matches_schema(frame, schema): return false
			if type_id == "counter":
				if not frame.held in ["", "jug", "cup", "rag", "pan", "potato", "sausage", "tomato", "plate_0", "plate_1", "plate_2"]: return false
				for puddle in frame.puddles:
					if not Station.TeamModel.numbers(puddle, 3): return false
			else:
				if not frame.hand in sample.ITEMS + [""]: return false
				for item in frame.owners:
					var owner_role := int(frame.owners[item])
					if owner_role < -1 or owner_role >= tracks.size(): return false
	return true

func matches_schema(value: Variant, schema: Variant) -> bool:
	if schema is Dictionary:
		if not value is Dictionary: return false
		for key in schema:
			if key in ["ramp_velocity","equipment","guest_serving","chef_order","guest_roles","guest_zone"]: continue
			if key in ["presentation", "sausage_launched", "sausage_high", "sausage_showy", "guest_serving", "chef_order", "guest_pour", "equipment", "guest_active", "guest_roles", "guest_zone"] and not value.has(key): continue
			if not value.has(key) or not matches_schema(value[key], schema[key]): return false
	elif schema is Array:
		if not value is Array: return false
		if not schema.is_empty():
			if value.size() != schema.size(): return false
			for i in range(schema.size()):
				if not matches_schema(value[i], schema[i]): return false
	elif schema is float or schema is int: return Station.TeamModel.finite(value)
	elif typeof(value) != typeof(schema): return false
	return true

func manual_order(station: Node3D) -> String:
	if game != null and game.session.is_guest() and station.customer_id >= 0: return station.order_dish
	for customer in customers:
		if customer.id == station.customer_id and customer.state not in ["leaving","eating","queued"]: return customer.dish
	return ""

func request_manual(station: Node3D, dish: String, peer: int) -> bool:
	if station == null or station.state=="serving" or not station.manual_station or station.training.active() or training_for(peer) != null or (progress.busy() and progress.phase!="service"): return false
	var ordered := manual_order(station)
	if progress.phase=="service" and ordered.is_empty(): return false
	if not ordered.is_empty(): dish = ordered
	else: station.customer_order = {}
	if not dish in station.dishes(): return false
	station.training.dish = dish
	_attach_customer(station)
	station.training.open(dish, peer, "manual")
	if dish not in progress.tutorial_served:
		announce("Требования блюда — в книге [B]. Готовое поставь на поднос и позвони в настольный звонок [E].")
	return station.training.start_pass([peer])

func finish_manual(station: Node3D, report: Dictionary) -> void:
	if station.training.purpose == "tasting":
		if not report.present or not report.grade in ["B", "A", "S"]:
			var inspector: Node3D = station.taster
			station.taster = null
			station.training.close()
			station.taster = inspector
			announce("Дегустатор: пока %s. Попробуй это блюдо ещё раз — бесплатно." % report.grade)
			start_tasting_dish()
			return
		progress.tasting_done.append(station.training.dish)
		var inspector: Node3D = station.taster
		station.taster = null
		station.training.close()
		station.taster = inspector
		if progress.tasting_done.size() < 3:
			start_tasting_dish()
		else:
			station.finish_taster(false)
			progress.stars = 1
			progress.cash += 120
			progress.phase = "won"
			progress.result = "Первая звезда! +120. Открыты мастер-классы и видеотека. Покажи блюдо на шеф-станции, сохрани фильм, установи телевизор и назначь запись первому производственному столу. Лаборатория тоже готова для выращивания работников."
			progress.revision += 1
			open_for_business = progress.return_open
			announce(progress.result)
			if game != null: game.save_cafe()
		return
	station.finish_taster(true)
	station.training.close()
	if game != null: game.save_cafe()

func start_tasting_dish() -> void:
	var first: Node3D = by_id(1)
	var dish: String = Progression.DISHES[progress.tasting_done.size()]
	first.training.open(dish, progress.event_peer, "tasting")
	first.training.start_pass([progress.event_peer])
	first.taster.caption.text = "Дегустатор · %s\nB или лучше · %d/3" % [Definition.DISHES[dish], progress.tasting_done.size() + 1]
	progress.revision += 1

func toggle_business() -> void:
	if progress.busy(): return
	if progress.shift == "night":
		announce("Смена закончена. Ляг на свободную кровать в комнате отдыха.")
		return
	if progress.shift == "closing": return
	if open_for_business:
		end_shift()
	else:
		progress.shift = "open"
		open_for_business = true
		spawn_clock = 2.0
	progress.revision += 1

func end_shift() -> void:
	Visits.close_shift(self)
	trace("shift_closed", {"day":progress.day,"elapsed":progress.shift_elapsed})
	open_for_business = false
	progress.shift = "closing"
	for customer in customers.duplicate():
		if customer.state=="queued":
			dismiss_queue(customer,"closing")
			continue
		if customer.state=="auto_queue":
			_finish_multi_departure(customer,null,"closing")
			continue
		var station: Node3D = by_id(int(customer.get("station",-1)))
		if station != null and station.manual_station and not station.training.active() and customer.state != "leaving": finish_customer(customer.id,false,"closing")
	if is_instance_valid(training_queue): training_queue.on_shift_closed()
	progress.revision += 1

func advance_shift(delta: float) -> void:
	if progress.shift=="night": progress.night_elapsed+=delta
	if progress.busy(): return
	if open_for_business and progress.shift == "open":
		progress.shift_elapsed += delta
		if progress.shift_elapsed >= Progression.SHIFT_SECONDS: end_shift()
	if progress.shift == "closing":
		if is_instance_valid(training_queue) and training_queue.active_blocks_night(): return
		for station in stations:
			if station.state != "idle" or station.pending_teacher > 0: return
		progress.shift = "night"
		progress.night_elapsed=0.0
		progress.revision += 1
		announce("Смена закончена. Клоны бегут в комнату отдыха. Новый день начнётся, когда все игроки лягут спать.")
		if game != null: game.save_cafe()

func next_day() -> String:
	if progress.shift != "night" or any_training(): return "Сначала заверши дела текущей смены."
	if game != null and is_instance_valid(game.evening): game.evening.apply_rest()
	if is_instance_valid(training_queue): training_queue.clear_handoffs()
	trace("next_day", {"day":progress.day+1})
	progress.day += 1
	progress.shift = "open"
	open_for_business = true
	spawn_clock = 2.0
	chef_order_clock = progress.chef_order_delay(rng)
	progress.shift_elapsed = 0
	progress.revision += 1
	return ""

func night_action(action: String, _data: Dictionary, _peer: int) -> String:
	if action == "next_day": return "Для нового дня всем нужно лечь в Шеф-кровать."
	return "Закажи детали у компьютера и установи их из коробки."

static func valid_wall_point(point: Vector3) -> bool:
	if point.y < 1.4 or point.y > 3.7: return false
	return (absf(point.z + 7.35) < 0.08 or absf(point.z - 10.35) < 0.08) and point.x >= -11.5 and point.x <= 17.5

func trace(kind: String, data := {}) -> void:
	if game != null and is_instance_valid(game.telemetry): game.telemetry.event(kind,data)

func normalize_workers() -> void:
	# Old prototype saves may carry clone_id=0, duplicate ids or a stale next_clone_id.
	# Stations render by staffed count, while evening actors are keyed by clone id, so make
	# every active worker identity positive and unique before assignment or animation.
	var max_existing_id := 0
	for station in stations:
		if station.manual_station: continue
		var active_roles: int=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
		for role in range(active_roles): max_existing_id=maxi(max_existing_id,int(station.crew[role].get("clone_id",0)))
	for worker in progress.free_workers: max_existing_id=maxi(max_existing_id,int(worker.get("id",0)))
	progress.next_clone_id=maxi(maxi(1,progress.next_clone_id),max_existing_id+1)

	var used_ids := {}
	for station in stations:
		if station.manual_station: continue
		var active_roles: int=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
		for role in range(active_roles):
			var member: Dictionary=station.crew[role]
			var id:=int(member.get("clone_id",0))
			if id<=0 or used_ids.has(id):
				id=progress.next_clone_id
				progress.next_clone_id+=1
				member.clone_id=id
			used_ids[id]=true
			member.tempo=clampf(float(member.get("tempo",1.0)),0.7,10.0)
			member.rest=progress.rest_multiplier

	for worker in progress.free_workers:
		var id:=int(worker.get("id",0))
		if id<=0 or used_ids.has(id):
			id=progress.next_clone_id
			progress.next_clone_id+=1
			worker.id=id
		used_ids[id]=true
		worker.tempo=clampf(float(worker.get("tempo",1.0)),0.7,10.0)
		worker.rest=1.0

	while progress.free_workers.size()<progress.free_clones:
		var id: int=progress.next_clone_id
		progress.next_clone_id+=1
		progress.free_workers.append({"id":id,"tempo":1.0,"rest":1.0})
		used_ids[id]=true
	progress.free_clones=progress.free_workers.size()

func assign_clones() -> void:
	# Existing saves keep their workers at 100%; unassigned workers retain individual tempo.
	normalize_workers()
	var changed:=false
	for station in stations:
		if station.manual_station or station.staffed<0: continue
		while station.staffed<station.role_count():
			var available := -1
			for i in range(progress.free_workers.size()):
				if game==null or not is_instance_valid(game.laboratory) or game.laboratory.reserved_clone_id()!=int(progress.free_workers[i].id): available=i; break
			if available<0: break
			var worker: Dictionary=progress.free_workers.pop_at(available)
			station.crew[station.staffed].clone_id=worker.id
			station.crew[station.staffed].tempo=worker.tempo
			station.crew[station.staffed].rest=worker.get("rest",1.0)
			station.staffed+=1
			changed=true
			progress.revision+=1
	progress.free_clones=progress.free_workers.size()
	if changed: request_auto_training_reconcile()

func clone_options() -> Array:
	var options: Array=[]
	for station in stations:
		if station.manual_station: continue
		for role in range(station.role_count() if station.staffed<0 else station.staffed):
			var member: Dictionary=station.crew[role]
			if not member.has("clone_id"): continue
			options.append({"id":member.clone_id,"tempo":member.get("tempo",1.0),"station":station.station_id,"name":str(member.name)+" · станция %d"%station.station_id})
	for worker in progress.free_workers: options.append({"id":worker.id,"tempo":worker.tempo,"station":0,"name":"Свободный клон №%d"%worker.id})
	return options

func clone_data(id: int) -> Dictionary:
	for station in stations:
		for member in station.crew:
			if int(member.get("clone_id",0))==id and id>0: return member
	for worker in progress.free_workers:
		if int(worker.id)==id: return worker
	return {}

func create_clone(tempo := 1.0, prepaid := false) -> String:
	if progress.stars<1 or progress.lab_stage<3: return "Нужны готовая лаборатория и первая звезда."
	if not prepaid and progress.cash<60: return "Ингредиенты клона стоят 60."
	if not prepaid: progress.cash-=60
	progress.free_workers.append({"id":progress.next_clone_id,"tempo":clampf(tempo,0.7,10.0),"rest":1.0})
	progress.next_clone_id+=1
	progress.free_clones=progress.free_workers.size()
	assign_clones()
	progress.revision+=1
	trace("clone_created",{"free":progress.free_clones,"tempo":tempo})
	announce("Клон создан · темп %d%% · свободно %d"%[roundi(tempo*100),progress.free_clones])
	return ""

func chef_queue() -> Array:
	return customers.filter(func(c): return c.state=="queued")

func queue_point(index: int) -> Vector3:
	var first: Node3D=by_id(1)
	return first.to_global(Vector3(0,0,-3.0-index*0.95))

func assign_customer(station: Node3D, customer: Dictionary) -> void:
	customer.state="walking"
	customer.station=station.station_id
	customer.wait_limit=maxf(float(customer.get("wait_limit",0.0)),order_wait_limit(int(customer.get("portions_total",1)),station,str(customer.dish)))
	customer.path=[station.to_global(Vector3(0,0,-1.85))]
	station.customer_order=customer.get("order",{}).duplicate(true)
	station.order_dish=customer.dish
	station.order_portions_total=int(customer.get("portions_total",1))
	station.order_portions_done=int(customer.get("portions_done",0))
	station.order_paid=int(customer.get("order_paid",0))
	station.customer_id=customer.id
	station.state="waiting"
	_update_multi_caption(customer)

func advance_queue(delta: float) -> void:
	var line:=chef_queue()
	var first: Node3D=by_id(1)
	if first==null: return
	if not line.is_empty() and first.state=="idle" and first.customer_id<0 and not first.training.active() and progress.shift not in ["closing","night"]:
		assign_customer(first,line.pop_front())
	for i in range(line.size()-1,-1,-1):
		var customer: Dictionary=line[i]
		customer.wait=float(customer.get("wait",0.0))+delta
		if not customer.get("banquet",false) and float(customer.wait)>=CHEF_WAIT_LIMIT:
			dismiss_queue(customer,"chef_wait")
			line.remove_at(i)
	for i in range(line.size()):
		var goal:=queue_point(i)
		if line[i].view.position.distance_to(goal)>0.05: line[i].path=[goal]
		var bonus_text: String=" · ×%.1f"%float(line[i].get("order",{}).get("chef_bonus",1.0)) if line[i].get("chef_order",false) else ""
		var left: int=maxi(0,ceili(CHEF_WAIT_LIMIT-float(line[i].get("wait",0.0)))) if not line[i].get("banquet",false) else 0
		line[i].view.caption.text=Definition.DISHES[line[i].dish]+"\nК шефу%s · %d в очереди%s"%[bonus_text,i+1," · %d с"%left if left>0 else ""]

func dismiss_queue(customer: Dictionary,reason := "busy") -> void:
	if customer.state=="leaving": return
	customer.state="leaving"
	customer.path=[Vector3(-8.8,0,4.8),Vector3(17.4,0,1.65)]
	customer.view.caption.text="До завтра · "+Insights.reason_label(str(reason))
	_record_failed_order(customer,str(reason))
	if customer.get("banquet",false): progress.banquet_finished+=1
	Visits.settled(self,customer,false,"D")
