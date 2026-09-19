extends Node3D
const Visits = preload("res://scripts/cafe_visits.gd")
const Station = preload("res://scripts/work_station.gd")
const Definition = preload("res://scripts/station_definition.gd")
const Masterclasses = preload("res://scripts/masterclass_library.gd")
const MasterclassLiveScene = preload("res://scripts/masterclass_live_scene.gd")
const StaffTrainingSession = preload("res://scripts/staff_training_session.gd")
const Expansion = preload("res://scripts/cafe_expansion_layout.gd")
const Person = preload("res://scripts/customer_view.gd")
const STARTER_TYPES := ["counter", "counter", "counter", "kitchen"]
const CHEF_QUEUE_LIMIT := 3
const SLOT_COUNT := Expansion.SLOT_COUNT
const SLOT_GAP := 0.6
const SLOT_ROW_CENTER_X := 3.0
const SLOT_Z := -1.4
var stations: Array = []
var customers: Array = []
var next_customer_id := 1
var served := 0
var missed := 0
var revenue := 0
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
var table_group_names: Dictionary={}

func _ready() -> void:
	rng.randomize()
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
	if station.method_sources.has(dish): return station.method_sources[dish].duplicate(true)
	if station.method_plan.has(dish):
		var planned: Dictionary=station.method_plan[dish].duplicate(true)
		planned.planned=true
		return planned
	if station.recipes.has(dish): return {"id":0,"name":"Локальный способ","legacy":true}
	return {}

func _group_signature(station: Node3D,overrides: Dictionary={}) -> String:
	var parts: Array=[station.type_id]
	for dish in station.dishes():
		var source: Dictionary=_method_source(station,str(dish),overrides)
		var token: String="none"
		if not source.is_empty(): token="legacy" if bool(source.get("legacy",false)) else str(int(source.get("id",0)))
		parts.append(str(dish)+"="+token)
	return "|".join(parts)

func _derive_table_groups(overrides: Dictionary={}) -> Array:
	var buckets: Dictionary={}
	for station in stations:
		if station.manual_station or station.masterclass_station: continue
		var signature: String=_group_signature(station,overrides)
		if not buckets.has(signature): buckets[signature]=[]
		buckets[signature].append(station.station_id)
	var result: Array=[]
	for signature in buckets:
		var ids: Array=buckets[signature]
		ids.sort()
		var id_parts: Array=[]
		for id in ids: id_parts.append(str(id))
		var group_id: String="-".join(id_parts)
		var first:=by_id(int(ids[0]))
		var auto_name: String="%s · столы %s"%[Definition.TYPES[first.type_id].title,", ".join(id_parts)]
		result.append({"id":group_id,"name":str(table_group_names.get(group_id,auto_name)),"type":first.type_id,"stations":ids,"dishes":first.dishes().duplicate()})
	result.sort_custom(func(a,b): return int(a.stations[0])<int(b.stations[0]))
	return result

func table_groups() -> Array:
	return _derive_table_groups()

func table_group_by_id(group_id: String) -> Dictionary:
	for group in table_groups():
		if str(group.id)==group_id: return group
	return {}

func rename_table_group(group_id: String,value: String) -> String:
	if table_group_by_id(group_id).is_empty(): return "Группа уже изменилась. Обнови список."
	var name:=value.strip_edges().left(48)
	if name.is_empty(): return "Название группы не может быть пустым."
	table_group_names[group_id]=name
	progress.revision+=1
	return ""

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

func station_group_status(station_id: int,dish: String) -> String:
	var station:=by_id(station_id)
	if station==null: return "нет стола"
	if is_instance_valid(staff_training) and staff_training.targets_station(station_id,dish): return staff_training.phase_label()
	var missing: Array=Definition.missing_equipment(dish,station.equipment)
	if not missing.is_empty(): return "требуется оборудование"
	if station.staffed>=0 and station.staffed<station.role_count(): return "требуются работники"
	if station.recipes.has(dish): return "освоено"
	if station.method_plan.has(dish): return "запланировано обучение"
	return "нет способа"

func compatible_training_station_ids(record_id: int) -> Array:
	var record:=masterclass_by_id(record_id)
	if record.is_empty(): return []
	var result: Array=[]
	for station in stations:
		if station.manual_station or station.masterclass_station: continue
		if station.type_id==str(record.get("source_type","")) and str(record.get("dish","")) in station.dishes(): result.append(station.station_id)
	return result

func training_selection_error(record_id: int,ids: Array) -> String:
	if not is_instance_valid(staff_training): return "Система обучения недоступна."
	if staff_training.is_active(): return "Сначала заверши текущий учебный сеанс."
	if bool(movie_state.get("playing",false)): return "Телевизор сейчас занят просмотром."
	if "television" not in progress.lounge_items: return "Сначала установи телевизор в комнате отдыха."
	var record:=masterclass_by_id(record_id)
	if record.is_empty(): return "Запись не найдена."
	if ids.is_empty(): return "Выбери хотя бы один стол."
	var seen: Array=[]
	for raw_id in ids:
		var id: int=int(raw_id)
		if id in seen: continue
		seen.append(id)
		var station:=by_id(id)
		if station==null or station.manual_station or station.type_id!=str(record.source_type) or str(record.dish) not in station.dishes(): return "В выборе есть несовместимый стол."
		if station.training.active() or station.pending_teacher>0: return "Станция %d занята другим обучением."%id
		var missing: Array=Definition.missing_equipment(str(record.dish),station.equipment)
		if not missing.is_empty(): return "Станция %d: требуется оборудование — %s."%[id,", ".join(missing)]
		if station.staffed>=0 and station.staffed<station.role_count(): return "Станция %d: сначала заполни вакансии."%id
		if not station.ready_crew(): return "Станция %d: сотрудник временно занят."%id
	return ""

func preview_table_groups(record_id: int,ids: Array) -> Array:
	var record:=masterclass_by_id(record_id)
	if record.is_empty(): return table_groups()
	var overrides: Dictionary={}
	for raw_id in ids:
		overrides[int(raw_id)]={"id":record_id,"name":str(record.name),"dish":str(record.dish),"pending":true}
	return _derive_table_groups(overrides)

func start_group_training(record_id: int,ids: Array) -> String:
	var error:=training_selection_error(record_id,ids)
	if not error.is_empty(): return error
	var unique: Array=[]
	for raw_id in ids:
		var id: int=int(raw_id)
		if id not in unique: unique.append(id)
	unique.sort()
	var record:=masterclass_by_id(record_id)
	staff_training.start(record,unique)
	progress.revision+=1
	trace("group_training_assigned",{"record":record_id,"dish":record.dish,"stations":unique})
	return ""

func _archive_legacy_recipes() -> void:
	for station in stations:
		if station.manual_station: continue
		for dish in station.recipes:
			var recipe: Dictionary=station.recipes[dish]
			masterclasses.append(Masterclasses.make_record(next_masterclass_id,str(dish),station.type_id,recipe.tracks,float(recipe.duration),recipe.get("quality",{}),Masterclasses.default_name(str(dish),1,true,station.station_id),true,station.station_id))
			next_masterclass_id+=1

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

func advance(delta: float) -> void:
	if game != null and is_instance_valid(game.shop): game.shop.advance(delta)
	_try_begin_masterclass()
	if bool(movie_state.get("playing",false)):
		movie_state.elapsed=minf(float(movie_state.elapsed)+delta,float(movie_state.duration))
		if float(movie_state.elapsed)>=float(movie_state.duration): movie_state.playing=false
	if is_instance_valid(staff_training): staff_training.advance(delta)
	if game != null and is_instance_valid(game.laboratory): game.laboratory.advance(delta)
	advance_shift(delta)
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
	advance_queue()
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
			finish_customer(station.customer_id, true)
			if station.pending_teacher > 0 and station.state!="serving":
				var teacher: int = station.pending_teacher
				station.pending_teacher = 0
				station.training.open(station.pending_dish, teacher)
	for index in range(customers.size() - 1, -1, -1):
		var customer: Dictionary = customers[index]
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
			customer.state = "waiting"
			var station: Node3D = by_id(customer.station)
			customer.view.rotation.y = station.global_rotation.y + PI
			if station.recipes.has(customer.dish) and not station.manual_station:
				station.state = "cooking"
				station.order_dish = customer.dish
				station.order_tick = 0
				station.order_tempo = station.crew_tempo()
				station.reset_model()
				customer.state = "cooking"
				customer.automatic_serving=true
			elif station.manual_station:
				var request_text: String=preload("res://scripts/chef_orders.gd").special_request(station.customer_order)
				if request_text.is_empty(): request_text=Definition.DISHES[customer.dish]
				if customer.get("chef_order",false): request_text+="\nЗаказ шефу · ×%.1f"%float(station.customer_order.get("chef_bonus",1.0))
				customer.view.caption.text=request_text+" · [E] у стойки"
			else:
				customer.wait += delta
				customer.view.caption.text = Definition.DISHES[customer.dish] + "\nПовара ждут твоего показа · [E]"
				if customer.wait >= 14:
					finish_customer(customer.id, false)

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

func spawn_customer(recipe := "", banquet := false, chef_guest := false, visit_data: Dictionary = {}) -> bool:
	if customers.size() >= 18: return false
	if recipe.is_empty():
		var pool: Array = progress.available_dishes()
		if progress.stars == 0 and by_id(1) != null and "jug" not in by_id(1).equipment: pool.erase("wine")
		recipe = pool[rng.randi_range(0, pool.size() - 1)]
		if progress.stars == 0 and progress.tutorial_served.size() < 3:
			for starter in ["sausage","potato","wine"]:
				if starter in pool and starter not in progress.tutorial_served: recipe = starter; break
	if not recipe in Definition.DISHES: return false
	var candidates: Array = []
	var untrained: Array = []
	var offered := false
	for station in stations:
		if not recipe in station.dishes(): continue
		if station.manual_station or not station.ready_crew(): continue
		if station.recipes.has(recipe): offered = true
		if station.state == "idle" and station.pending_teacher == 0:
			if station.recipes.has(recipe): candidates.append(station)
			else: untrained.append(station)
	if candidates.is_empty() and not banquet and not chef_guest and visit_data.is_empty(): candidates=untrained
	if chef_guest:
		var personal:=by_id(1)
		candidates=[personal] if personal!=null and personal.manual_station and recipe in personal.dishes() and chef_queue().size()<CHEF_QUEUE_LIMIT else []
	var station: Node3D = null if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]
	if station==null and not visit_data.is_empty(): return false
	var person := Person.new()
	person.color = Color("d6b56b") if banquet else [Color("ae7381"), Color("839fbb"), Color("c6a66b"), Color("91aa78")][next_customer_id % 4]
	add_child(person)
	person.position = Vector3(-11.4, 0, 1.65)
	person.caption.text = Definition.DISHES[recipe]
	var data := {"id": next_customer_id, "view": person, "station": station.station_id if station != null else -1, "dish": recipe, "state": "walking", "wait": 0.0, "path": [], "banquet": banquet, "chef_order": chef_guest and not banquet}
	if not visit_data.is_empty():
		data.visit_id=int(visit_data.id); data.visit_slot=int(visit_data.slot); data.visit_kind=str(visit_data.kind)
		data.chef_order=false
		Visits.badge(person,str(visit_data.kind))
	if station == null:
		data.state = "leaving"
		data.path = [Vector3(-9.6, 0, 2.6), Vector3(17.4, 0, 1.65)]
		person.caption.text += "\nВсе заняты · зайду позже" if offered else "\nЕщё не готовят · загляну позже"
		missed += 1
		progress.record_demand(recipe, "busy" if offered else "untrained")
		if banquet: progress.banquet_finished += 1
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
	trace("customer_arrived",{"dish":recipe,"station":data.station,"order":station.customer_order if station != null else {}})
	customers.append(data)
	next_customer_id += 1
	return station != null

func finish_customer(id: int, accepted: bool) -> void:
	for customer in customers:
		if customer.id != id or customer.state in ["leaving","eating"]: continue
		if customer.state=="queued": dismiss_queue(customer); return
		var station: Node3D = by_id(customer.station)
		var report: Dictionary = station.model.quality()
		var paid := accepted and bool(report.get("present", false))
		var premium: float = float(station.customer_order.get("premium",1.0)) if station.manual_station else 1.0
		var base_price := 65 if customer.dish == "meal" else 95 if customer.dish in Progression.ORCHESTRATION_DISHES else 80 if customer.dish in Progression.SPECIALTY_DISHES else 25
		var payment := roundi(base_price * report.price_factor * report.style_multiplier * premium) if paid else 0
		trace("customer_finished",{"dish":customer.dish,"station":station.station_id,"grade":report.grade,"payment":payment,"accepted":paid})
		customer.state = "leaving"
		customer.view.playback_speed = 1.0
		customer.view.caption.text = "%s · +%d\nСпасибо!" % [report.grade, payment] if paid else "Загляну позже"
		if paid and report.get("style_count", 0) > 0: customer.view.caption.text += "\nЛовкая подача · +20%"
		customer.path = [Vector3(17.4, 0, 1.65)]
		station.customer_id = -1
		if not station.training.active(): station.state = "idle"
		if accepted:
			var payload: Array=station.model.take_serving()
			if not payload.is_empty():
				for item in payload: item.from=station.to_global(item.from)
				customer.state="eating"; customer.eat_age=0.0; customer.path=[]
				customer.view.begin_meal(payload)
				station.state="serving"; station.customer_id=customer.id
		if paid:
			served += 1
			if station.manual_station:
				progress.manual_served += 1
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
			revenue += payment
			progress.cash += payment
			progress.record_demand(customer.dish, "served")
		else:
			missed += 1
			progress.record_demand(customer.dish, "untrained")
		if customer.get("banquet", false):
			progress.banquet_finished += 1
			if paid: progress.banquet_served += 1
			if paid and report.grade in ["B", "A", "S"]: progress.banquet_good += 1
		Visits.settled(self,customer,paid,str(report.grade))
		return

func purchase(kind: String, id: String, station_id := 0) -> String:
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
	return game.shop.order(item, station_id)

func start_banquet(peer: int) -> String:
	if Visits.busy(progress): return "Сначала заверши или отмени добровольный визит в компьютере."
	if not progress.can_attempt(stations, served): return "Подготовь кафе по списку во вкладке «Звёзды»."
	if any_training(): return "Сначала закончи текущие показы."
	progress.return_open = open_for_business
	open_for_business = false
	# Do not wait forever for an unattended personal/untrained counter.
	for customer in customers:
		if customer.state in ["walking", "waiting"]: finish_customer(customer.id, false)
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
		entries.append(entry)
	return {"format": "station-cafe", "version": 17, "progression": progress.snapshot(), "stations": entries, "served": served, "revenue": revenue, "missed": missed, "open": open_for_business, "chef_order_clock": chef_order_clock, "masterclasses":masterclasses.duplicate(true), "next_masterclass_id":next_masterclass_id, "table_group_names":table_group_names.duplicate(true)}

func clear_world() -> void:
	if is_instance_valid(staff_training): staff_training.reset()
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
	for station in stations:
		remove_child(station)
		station.queue_free()
	for customer in customers:
		remove_child(customer.view)
		customer.view.queue_free()
	stations.clear()
	customers.clear()
	chef_order_clock=3.0

func _saved_slot(entry: Dictionary, version: int) -> int:
	if version >= 4: return int(entry.get("slot", -1))
	return int(entry.get("id", 0)) - 1

func load_data(data: Dictionary) -> bool:
	var version: int = int(data.get("version", 0))
	if data.get("format") != "station-cafe" or not version in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17] or not data.get("stations") is Array: return false
	if version >= 5 and not data.get("progression") is Dictionary: return false
	if version>=16 and not data.get("table_group_names",{}) is Dictionary: return false
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
		for role in range(station.role_count()): station.students[role].caption.text = station.crew[role].name
	served = int(data.get("served", 0))
	revenue = int(data.get("revenue", 0))
	missed = int(data.get("missed", 0))
	table_group_names=data.get("table_group_names",{}).duplicate(true) if version>=16 and data.get("table_group_names",{}) is Dictionary else {}
	masterclasses=data.get("masterclasses",[]).duplicate(true) if version>=14 else []
	next_masterclass_id=maxi(1,int(data.get("next_masterclass_id",1))) if version>=14 else 1
	if version<14: _archive_legacy_recipes()
	for record in masterclasses:
		Masterclasses.ensure_highlights(record)
		next_masterclass_id=maxi(next_masterclass_id,int(record.get("id",0))+1)
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
			progress.result = "Первая звезда! +120. Лаборатория готова: теперь исследуй формулу и вырасти первого работника. Стол, оборудование и клон приобретаются отдельно."
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
	for customer in customers:
		if customer.state=="queued": dismiss_queue(customer); continue
		var station: Node3D = by_id(customer.station)
		if station != null and station.manual_station and not station.training.active() and customer.state != "leaving": finish_customer(customer.id, false)
	progress.revision += 1

func advance_shift(delta: float) -> void:
	if progress.shift=="night": progress.night_elapsed+=delta
	if progress.busy(): return
	if open_for_business and progress.shift == "open":
		progress.shift_elapsed += delta
		if progress.shift_elapsed >= Progression.SHIFT_SECONDS: end_shift()
	if progress.shift == "closing":
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
			progress.revision+=1
	progress.free_clones=progress.free_workers.size()

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
	customer.path=[station.to_global(Vector3(0,0,-1.85))]
	station.customer_order=customer.get("order",{}).duplicate(true)
	station.order_dish=customer.dish
	station.customer_id=customer.id
	station.state="waiting"

func advance_queue() -> void:
	var line:=chef_queue()
	var first: Node3D=by_id(1)
	if first==null: return
	if not line.is_empty() and first.state=="idle" and first.customer_id<0 and not first.training.active() and progress.shift not in ["closing","night"]:
		assign_customer(first,line.pop_front())
	for i in range(line.size()):
		var goal:=queue_point(i)
		if line[i].view.position.distance_to(goal)>0.05: line[i].path=[goal]
		var bonus_text: String=" · ×%.1f"%float(line[i].get("order",{}).get("chef_bonus",1.0)) if line[i].get("chef_order",false) else ""
		line[i].view.caption.text=Definition.DISHES[line[i].dish]+"\nК шефу%s · %d в очереди"%[bonus_text,i+1]

func dismiss_queue(customer: Dictionary) -> void:
	if customer.state=="leaving": return
	customer.state="leaving"
	customer.path=[Vector3(-8.8,0,4.8),Vector3(17.4,0,1.65)]
	customer.view.caption.text="До завтра!"
	if customer.get("banquet",false): progress.banquet_finished+=1
	Visits.settled(self,customer,false,"D")
