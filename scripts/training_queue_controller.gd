extends Node
## Host-authoritative owner of staff courses, batches and lessons.
## Physical walking/watching remains in staff_training_session.gd.
const Definition=preload("res://scripts/station_definition.gd")
const Masterclasses=preload("res://scripts/masterclass_library.gd")
var service: Node3D
var courses: Array=[]
var batches: Array=[]
var lessons: Array=[]
var next_course_id:=1
var next_batch_id:=1
var next_lesson_id:=1
var command_courses: Dictionary={}
var suspended_assignments: Dictionary={}
var active_batch_id:=0
var revision:=0
var handoff_positions: Dictionary={}
var auto_reconcile_due:=true
var auto_reconcile_clock:=0.0

func setup(owner_service: Node3D)->void:
	service=owner_service
	name="TrainingQueueController"

func reset()->void:
	courses.clear()
	batches.clear()
	lessons.clear()
	command_courses.clear()
	suspended_assignments.clear()
	active_batch_id=0
	next_course_id=1
	next_batch_id=1
	next_lesson_id=1
	handoff_positions.clear()
	auto_reconcile_due=true
	auto_reconcile_clock=0.0
	revision+=1

func _course(id: int)->Dictionary:
	for value in courses:
		if int(value.get("id",0))==id: return value
	return {}

func _batch(id: int)->Dictionary:
	for value in batches:
		if int(value.get("id",0))==id: return value
	return {}

func _lesson(id: int)->Dictionary:
	for value in lessons:
		if int(value.get("id",0))==id: return value
	return {}

func _unique_ids(raw_ids: Array)->Array:
	var result: Array=[]
	for raw in raw_ids:
		var id:=int(raw)
		if id>0 and id not in result: result.append(id)
	result.sort()
	return result

func _current_assignment(station_id: int,dish: String)->Dictionary:
	var group: Dictionary=service.group_for_station(station_id)
	if group.is_empty(): return {}
	for item in group.get("curriculum",[]):
		if str(item.get("dish_id",""))==dish:
			return {"record_id":int(item.get("record_id",0)),"revision":int(item.get("revision",1)),"group":str(group.id)}
	return {}

func _assignment_key(station_id: int,dish: String,record_id: int,version: int)->String:
	return "%d|%s|%d|%d"%[station_id,dish,record_id,version]

func _legacy_assignment_key(station_id: int,dish: String,version: int)->String:
	return "%d|%s|%d"%[station_id,dish,version]

func _actual_matches(station,record_id: int,dish: String)->bool:
	return station!=null and station.recipes.has(dish) and int(station.method_sources.get(dish,{}).get("id",0))==record_id

func _record_valid_for_station(record: Dictionary,station)->bool:
	return station!=null and not station.manual_station and not station.masterclass_station and station.type_id==str(record.get("source_type","")) and str(record.get("dish","")) in station.dishes()

func _normalize_assignments(assignments: Array)->Dictionary:
	var result: Array=[]
	for raw in assignments:
		if not raw is Dictionary: return {"error":"Некорректный урок.","assignments":[]}
		var record_id:=int(raw.get("record_id",raw.get("record",0)))
		var record: Dictionary=service.masterclass_by_id(record_id)
		if record.is_empty(): return {"error":"Запись #%d не найдена."%record_id,"assignments":[]}
		var ids:=_unique_ids(raw.get("station_ids",raw.get("stations",[])) if raw.get("station_ids",raw.get("stations",[])) is Array else [])
		if ids.is_empty(): return {"error":"Выбери хотя бы один стол для урока.","assignments":[]}
		for station_id in ids:
			var station=service.by_id(int(station_id))
			if not _record_valid_for_station(record,station): return {"error":"Стол %d несовместим с записью «%s»."%[station_id,str(record.get("name","Запись"))],"assignments":[]}
		result.append({"record_id":record_id,"station_ids":ids,"dish":str(record.dish)})
	return {"error":"","assignments":result}

func _apply_plans(assignments: Array)->void:
	for spec in assignments:
		service._apply_group_plan(int(spec.record_id),spec.station_ids)

func _capture_assignments(assignments: Array)->Array:
	var result: Array=[]
	for spec in assignments:
		var record: Dictionary=service.masterclass_by_id(int(spec.record_id))
		var versions: Dictionary={}
		for station_id in spec.station_ids:
			var current:=_current_assignment(int(station_id),str(record.dish))
			versions[str(int(station_id))]=int(current.get("revision",1))
			suspended_assignments.erase(_assignment_key(int(station_id),str(record.dish),int(current.get("record_id",record.id)),int(current.get("revision",1))))
			suspended_assignments.erase(_legacy_assignment_key(int(station_id),str(record.dish),int(current.get("revision",1))))
		result.append({"record_id":int(record.id),"record":record.duplicate(true),"dish":str(record.dish),"station_ids":spec.station_ids.duplicate(),"versions":versions})
	return result

func _signature(assignments: Array,mode: String,group_order: Array=[])->String:
	var parts: Array=[mode]
	for spec in assignments:
		var ids: Array=spec.station_ids.duplicate()
		ids.sort()
		var versions: Array=[]
		for station_id in ids: versions.append("%d:%d"%[int(station_id),int(spec.versions.get(str(int(station_id)),0))])
		parts.append("%d@%s#%s"%[int(spec.record_id),",".join(ids.map(func(v):return str(v))),",".join(versions)])
	if mode=="by_groups":
		var order_parts: Array=[]
		for raw in group_order:
			if raw is Array:
				var ids: Array=raw.duplicate()
				ids.sort()
				order_parts.append(",".join(ids.map(func(v):return str(int(v)))))
			else: order_parts.append(str(raw))
		parts.append("order="+">".join(order_parts))
	return "|".join(parts)

func _preferred_group_station_sets(group_order: Array,assignments: Array)->Array:
	if group_order.is_empty(): return []
	var selected: Array=[]
	for spec in assignments:
		for station_id in spec.station_ids:
			if int(station_id) not in selected: selected.append(int(station_id))
	var result: Array=[]
	for raw_group_id in group_order:
		var group: Dictionary=service.table_group_by_id(str(raw_group_id))
		if group.is_empty(): continue
		var subset: Array=[]
		for station_id in group.stations:
			if int(station_id) in selected: subset.append(int(station_id))
		if not subset.is_empty(): result.append(subset)
	return result

func _existing_signature(signature: String)->Dictionary:
	for course in courses:
		if str(course.get("signature",""))==signature and str(course.get("state","")) not in ["completed","cancelled"]: return course
	return {}

func _supersede_waiting(assignments: Array)->void:
	for spec in assignments:
		for lesson in lessons:
			if str(lesson.get("dish",""))!=str(spec.dish) or str(lesson.get("state","")) not in ["queued","blocked","deferred"]: continue
			var changed:=false
			for station_id in spec.station_ids:
				var index: int=lesson.station_ids.find(int(station_id))
				if index<0: continue
				var current:=_current_assignment(int(station_id),str(spec.dish))
				var old_version:=int(lesson.versions.get(str(int(station_id)),0))
				if int(lesson.record_id)==int(spec.record_id) and old_version==int(current.get("revision",0)): continue
				lesson.station_ids.remove_at(index)
				lesson.versions.erase(str(int(station_id)))
				changed=true
			if changed and lesson.station_ids.is_empty(): lesson.state="superseded"
	_reconcile_empty_batches()

func _new_lesson(course_id: int,batch_id: int,spec: Dictionary,target_ids: Array)->Dictionary:
	var ids: Array=[]
	var versions: Dictionary={}
	for station_id in target_ids:
		var station=service.by_id(int(station_id))
		if station==null or _actual_matches(station,int(spec.record_id),str(spec.dish)): continue
		ids.append(int(station_id))
		versions[str(int(station_id))]=int(spec.versions.get(str(int(station_id)),1))
	var lesson: Dictionary={
		"id":next_lesson_id,"course_id":course_id,"batch_id":batch_id,"state":"completed" if ids.is_empty() else "queued",
		"record_id":int(spec.record_id),"record":spec.record.duplicate(true),"dish":str(spec.dish),
		"station_ids":ids,"versions":versions,"applied":false
	}
	next_lesson_id+=1
	lessons.append(lesson)
	return lesson

func _new_batch(course_id: int,station_ids: Array,specs: Array,depends_on: int)->Dictionary:
	var batch_id:=next_batch_id
	next_batch_id+=1
	var lesson_ids: Array=[]
	var needed_station_ids: Array=[]
	for spec in specs:
		var targets: Array=[]
		for station_id in spec.station_ids:
			if int(station_id) in station_ids: targets.append(int(station_id))
		if targets.is_empty(): continue
		var lesson:=_new_lesson(course_id,batch_id,spec,targets)
		lesson_ids.append(int(lesson.id))
		for needed_id in lesson.station_ids:
			if int(needed_id) not in needed_station_ids: needed_station_ids.append(int(needed_id))
	needed_station_ids.sort()
	var batch: Dictionary={
		"id":batch_id,"course_id":course_id,"state":"queued","station_ids":needed_station_ids,
		"lesson_ids":lesson_ids,"current_lesson_id":0,"depends_on":depends_on,"blocked_reason":"","last_feed_reason":"",
		"defer_day":service.progress.day,"close_after_lesson":false,"gathers":0,"movies":0,"returns":0
	}
	if needed_station_ids.is_empty() or lesson_ids.is_empty() or lesson_ids.all(func(id):return str(_lesson(int(id)).state)=="completed"): batch.state="completed"
	batches.append(batch)
	return batch

func _intent_from_captured(captured: Array)->Array:
	var result: Array=[]
	for spec in captured:
		result.append({"record_id":int(spec.record_id),"dish":str(spec.dish),"station_ids":spec.station_ids.duplicate(),"versions":spec.versions.duplicate(true)})
	return result

func _build_course_batches(course: Dictionary,captured: Array,mode: String,preferred_group_order: Array=[])->void:
	course.batch_ids=[]
	if mode=="together":
		var all_ids: Array=[]
		for spec in captured:
			for station_id in spec.station_ids:
				if station_id not in all_ids: all_ids.append(station_id)
		all_ids.sort()
		var batch:=_new_batch(int(course.id),all_ids,captured,0)
		course.batch_ids.append(int(batch.id))
		return
	var group_order: Array=[]
	var group_specs: Dictionary={}
	for spec in captured:
		for station_id in spec.station_ids:
			var group_id: String=service.group_id_for_station(int(station_id))
			if group_id.is_empty(): continue
			if group_id not in group_order:
				group_order.append(group_id)
				group_specs[group_id]=[]
	if not preferred_group_order.is_empty():
		var ordered: Array=[]
		for raw_preference in preferred_group_order:
			if raw_preference is Array:
				for station_id in raw_preference:
					var actual_group: String=service.group_id_for_station(int(station_id))
					if actual_group in group_order and actual_group not in ordered:
						ordered.append(actual_group)
						break
			else:
				var wanted: String=str(raw_preference)
				if wanted in group_order and wanted not in ordered: ordered.append(wanted)
		for group_id in group_order:
			if group_id not in ordered: ordered.append(group_id)
		group_order=ordered
	course.group_order=group_order.duplicate()
	for group_id in group_order:
		var group: Dictionary=service.table_group_by_id(str(group_id))
		for spec in captured:
			var targets: Array=[]
			for station_id in spec.station_ids:
				if int(station_id) in group.stations: targets.append(int(station_id))
			if not targets.is_empty():
				var copy: Dictionary=spec.duplicate(true)
				copy.station_ids=targets
				group_specs[group_id].append(copy)
	var dependency:=0
	for group_id in group_order:
		var group: Dictionary=service.table_group_by_id(str(group_id))
		var batch:=_new_batch(int(course.id),group.stations,group_specs[group_id],dependency)
		course.batch_ids.append(int(batch.id))
		dependency=int(batch.id)

func _retire_pending_course(course: Dictionary)->void:
	for batch_id in course.get("batch_ids",[]):
		var batch:=_batch(int(batch_id))
		if batch.is_empty(): continue
		for lesson_id in batch.get("lesson_ids",[]):
			var lesson:=_lesson(int(lesson_id))
			if str(lesson.get("state","")) not in ["completed","cancelled","superseded"]: lesson.state="superseded"
		if str(batch.get("state","")) not in ["completed","cancelled"]: batch.state="cancelled"
		_clear_batch_stations(batch)

func _course_intent(course: Dictionary)->Array:
	if course.get("assignments",[]) is Array and not course.get("assignments",[]).is_empty(): return course.assignments
	var order: Array=[]
	var merged: Dictionary={}
	for batch_id in course.get("batch_ids",[]):
		var batch:=_batch(int(batch_id))
		for lesson_id in batch.get("lesson_ids",[]):
			var lesson:=_lesson(int(lesson_id))
			var key: String=str(lesson.get("record_id",0))
			if key not in merged:
				order.append(key)
				merged[key]={"record_id":int(lesson.record_id),"dish":str(lesson.dish),"station_ids":[],"versions":{}}
			for station_id in lesson.get("station_ids",[]):
				if int(station_id) not in merged[key].station_ids: merged[key].station_ids.append(int(station_id))
				merged[key].versions[str(int(station_id))]=int(lesson.get("versions",{}).get(str(int(station_id)),1))
	var result: Array=[]
	for key in order:
		merged[key].station_ids.sort()
		result.append(merged[key])
	return result

func _course_feed_name(course_id: int)->String:
	var course:=_course(course_id)
	if course.is_empty(): return "Курс #%d"%course_id
	var parts: Array=[]
	for assignment in _course_intent(course):
		var dish: String=str(assignment.get("dish",""))
		var title: String=str(Definition.DISHES.get(dish,dish))
		if title not in parts: parts.append(title)
	return " + ".join(parts) if not parts.is_empty() else "Курс #%d"%course_id

func _remaining_course_lessons(course_id: int)->int:
	var count:=0
	for lesson in lessons:
		if int(lesson.get("course_id",0))!=course_id: continue
		if str(lesson.get("state","")) not in ["completed","cancelled","superseded"]: count+=1
	return count

func _course_feed_payload(course_id: int,extra: Dictionary={}) -> Dictionary:
	var course:=_course(course_id)
	var payload: Dictionary={"course":course_id,"name":_course_feed_name(course_id),"stations":_course_station_ids(course_id),"batches":course.get("batch_ids",[]).size(),"mode":str(course.get("mode","together")),"automatic":bool(course.get("automatic",false))}
	for key in extra: payload[key]=extra[key]
	return payload

func linked_course_id(station_ids: Array,dish: String)->int:
	for lesson in lessons:
		if str(lesson.get("dish",""))!=dish or str(lesson.get("state","")) not in ["queued","blocked","deferred","active","watching"]: continue
		for raw_id in station_ids:
			if int(raw_id) in lesson.get("station_ids",[]): return int(lesson.get("course_id",0))
	return 0

func _feed_deferred(batch: Dictionary)->void:
	var course_id: int=int(batch.get("course_id",0))
	var remaining: int=_remaining_course_lessons(course_id)
	service.feed_system("training_deferred",_course_feed_payload(course_id,{"batch":int(batch.get("id",0)),"remaining":remaining,"day":service.progress.day+1}),1)

func course_view(course_id: int)->Dictionary:
	var course:=_course(course_id)
	if course.is_empty(): return {}
	var rows: Array=[]
	for raw in _course_intent(course):
		var row: Dictionary=raw.duplicate(true)
		var record: Dictionary=service.masterclass_by_id(int(row.get("record_id",0)))
		row.name=str(record.get("name","Запись #%d"%int(row.get("record_id",0))))
		row.duration=float(record.get("duration",0.0))
		row.highlight_duration=float(record.get("highlight_duration",0.0))
		rows.append(row)
	var batch_rows: Array=[]
	for batch_id in course.get("batch_ids",[]):
		var batch:=_batch(int(batch_id))
		if batch.is_empty(): continue
		var lesson_rows: Array=[]
		for lesson_id in batch.get("lesson_ids",[]):
			var lesson:=_lesson(int(lesson_id))
			lesson_rows.append({"id":int(lesson.id),"dish":str(lesson.dish),"record_id":int(lesson.record_id),"name":str(lesson.record.get("name","Запись")),"state":str(lesson.state),"stations":lesson.station_ids.duplicate()})
		batch_rows.append({"id":int(batch.id),"state":str(batch.state),"stations":batch.station_ids.duplicate(),"blocked_reason":str(batch.get("blocked_reason","")),"lessons":lesson_rows})
	return {"id":int(course.id),"mode":str(course.get("mode","together")),"state":str(course.get("state","queued")),"assignments":rows,"batches":batch_rows,"group_order":course.get("group_order",[]).duplicate(),"automatic":bool(course.get("automatic",false)),"editable":str(course.get("state","")) in ["queued","blocked","deferred"] and active_batch_id not in course.get("batch_ids",[])}

func course_views()->Array:
	var result: Array=[]
	for course in courses:
		if str(course.get("state","")) in ["completed","cancelled"]: continue
		result.append(course_view(int(course.id)))
	return result

func edit_course(course_id: int,assignments: Array,mode := "together",peer := 1,group_order: Array=[])->String:
	var course:=_course(course_id)
	if course.is_empty(): return "Курс не найден."
	if str(course.get("state","")) not in ["queued","blocked","deferred"]: return "Можно редактировать только ожидающий курс."
	if active_batch_id in course.get("batch_ids",[]): return "Активную учебную партию сначала нужно завершить или отменить."
	if mode not in ["together","by_groups"]: return "Неизвестный режим курса."
	var normalized:=_normalize_assignments(assignments)
	if not str(normalized.error).is_empty(): return str(normalized.error)
	var preferred_order: Array=_preferred_group_station_sets(group_order,normalized.assignments)
	_retire_pending_course(course)
	_apply_plans(normalized.assignments)
	var captured:=_capture_assignments(normalized.assignments)
	_supersede_waiting(captured)
	course.mode=mode
	course.state="queued"
	course.peer=int(peer)
	course.automatic=false
	course.erase("auto_key")
	course.signature=_signature(captured,mode,preferred_order)
	course.assignments=_intent_from_captured(captured)
	_build_course_batches(course,captured,mode,preferred_order)
	_update_course_state(course_id)
	revision+=1
	service.progress.revision+=1
	return ""

func resume_assignment(station_id: int,dish: String,peer := 1)->String:
	var current:=_current_assignment(station_id,dish)
	var record_id:=int(current.get("record_id",0))
	if record_id<=0: return "Для блюда нет назначенной записи."
	var station=service.by_id(station_id)
	if station==null: return "Стол не найден."
	if _actual_matches(station,record_id,dish): return "Этот способ уже освоен."
	var result:=enqueue_course([{"record_id":record_id,"station_ids":[station_id]}],"together","resume:%d:%s:%d"%[station_id,dish,int(current.get("revision",0))],peer)
	return str(result.get("error",""))

func request_auto_reconcile()->void:
	auto_reconcile_due=true

func _pending_current_course_id(station_id: int,dish: String,record_id: int,version: int)->int:
	for lesson in lessons:
		if str(lesson.get("state","")) not in ["queued","blocked","deferred","active","watching"]: continue
		if str(lesson.get("dish",""))!=dish or int(lesson.get("record_id",0))!=record_id: continue
		if station_id not in lesson.get("station_ids",[]): continue
		if int(lesson.get("versions",{}).get(str(station_id),0))==version: return int(lesson.get("course_id",0))
	return 0

func _waiting_auto_course(auto_key: String)->Dictionary:
	for course in courses:
		if not bool(course.get("automatic",false)) or str(course.get("auto_key",""))!=auto_key: continue
		if str(course.get("state","")) not in ["queued","blocked","deferred"]: continue
		if active_batch_id in course.get("batch_ids",[]): continue
		return course
	return {}

func _auto_captured_specs(specs: Array)->Array:
	var result: Array=[]
	for spec in specs:
		var record: Dictionary=service.masterclass_by_id(int(spec.record_id))
		if record.is_empty(): return []
		result.append({"record_id":int(spec.record_id),"record":record.duplicate(true),"dish":str(spec.dish),"station_ids":spec.station_ids.duplicate(),"versions":spec.versions.duplicate(true)})
	return result

func _replace_waiting_auto_course(course: Dictionary,captured: Array,auto_key: String)->void:
	var signature:=_signature(captured,"together")
	if str(course.get("signature",""))==signature: return
	_retire_pending_course(course)
	_supersede_waiting(captured)
	course.mode="together"
	course.state="queued"
	course.peer=1
	course.signature=signature
	course.assignments=_intent_from_captured(captured)
	course.group_order=[]
	course.automatic=true
	course.auto_key=auto_key
	_build_course_batches(course,captured,"together")
	_update_course_state(int(course.id))
	revision+=1
	service.progress.revision+=1

func _create_auto_course(captured: Array,auto_key: String)->Dictionary:
	if captured.is_empty(): return {}
	_supersede_waiting(captured)
	var course_id:=next_course_id
	next_course_id+=1
	var signature:=_signature(captured,"together")
	var course: Dictionary={"id":course_id,"command_id":"auto:"+auto_key+":"+signature,"mode":"together","state":"queued","batch_ids":[],"signature":signature,"peer":1,"created_day":service.progress.day,"assignments":_intent_from_captured(captured),"group_order":[],"automatic":true,"auto_key":auto_key}
	courses.append(course)
	_build_course_batches(course,captured,"together")
	_update_course_state(course_id)
	revision+=1
	service.progress.revision+=1
	service.trace("automatic_training_queued",{"course":course_id,"auto_key":auto_key,"stations":_course_station_ids(course_id)})
	var group_id: String=str(auto_key.get_slice("|",0))
	var group: Dictionary=service.table_group_by_id(group_id)
	service.feed_system("group_training",_course_feed_payload(course_id,{"automatic":true,"group":group_id,"group_name":str(group.get("name",group_id))}),_course_station_ids(course_id).size())
	return course

func reconcile_automatic_needs()->void:
	if service==null: return
	if service.game!=null and is_instance_valid(service.game.session) and service.game.session.is_guest(): return
	var buckets: Dictionary={}
	for group in service.table_groups():
		var curriculum: Array=group.get("curriculum",[])
		if curriculum.is_empty(): continue
		for raw_station_id in group.get("stations",[]):
			var station_id:=int(raw_station_id)
			var station=service.by_id(station_id)
			if station==null or station.manual_station or station.masterclass_station: continue
			if station.staffed>=0 and station.staffed<station.role_count(): continue
			var residue: Array=[]
			var ready:=true
			for item in curriculum:
				var dish:=str(item.get("dish_id",""))
				var record_id:=int(item.get("record_id",0))
				var version:=int(item.get("revision",1))
				if dish.is_empty() or record_id<=0: continue
				if _actual_matches(station,record_id,dish): continue
				if assignment_suspended(station_id,dish): continue
				var record: Dictionary=service.masterclass_by_id(record_id)
				if record.is_empty():
					ready=false
					break
				if not Definition.missing_equipment(dish,station.equipment).is_empty():
					ready=false
					break
				residue.append({"dish":dish,"record_id":record_id,"revision":version})
			if not ready or residue.is_empty(): continue
			var residue_parts: Array=[]
			for item in residue: residue_parts.append("%s:%d:%d"%[str(item.dish),int(item.record_id),int(item.revision)])
			var auto_key: String="%s|%s"%[str(group.id),">".join(residue_parts)]
			var waiting: Dictionary=_waiting_auto_course(auto_key)
			var blocked_by_other:=false
			for item in residue:
				var owner:=_pending_current_course_id(station_id,str(item.dish),int(item.record_id),int(item.revision))
				if owner>0 and (waiting.is_empty() or owner!=int(waiting.id)):
					blocked_by_other=true
					break
			if blocked_by_other: continue
			if not buckets.has(auto_key):
				var lesson_specs: Array=[]
				for item in residue:
					lesson_specs.append({"record_id":int(item.record_id),"dish":str(item.dish),"station_ids":[],"versions":{}})
				buckets[auto_key]={"group":str(group.id),"specs":lesson_specs}
			var bucket: Dictionary=buckets[auto_key]
			for index in range(residue.size()):
				bucket.specs[index].station_ids.append(station_id)
				bucket.specs[index].versions[str(station_id)]=int(residue[index].revision)
	for auto_key in buckets:
		var bucket: Dictionary=buckets[auto_key]
		var captured:=_auto_captured_specs(bucket.specs)
		if captured.is_empty(): continue
		var waiting:=_waiting_auto_course(str(auto_key))
		if waiting.is_empty(): _create_auto_course(captured,str(auto_key))
		else: _replace_waiting_auto_course(waiting,captured,str(auto_key))

func migrate_from_plans()->void:
	for group in service.table_groups():
		var assignments: Array=[]
		for item in group.get("curriculum",[]):
			var record_id:=int(item.get("record_id",0))
			var record: Dictionary=service.masterclass_by_id(record_id)
			if record.is_empty(): continue
			var targets: Array=[]
			for station_id in group.stations:
				var station=service.by_id(int(station_id))
				if not _actual_matches(station,record_id,str(item.get("dish_id",""))): targets.append(int(station_id))
			if not targets.is_empty(): assignments.append({"record_id":record_id,"station_ids":targets})
		if assignments.is_empty(): continue
		var command: String="migration:%s:%d"%[str(group.id),int(group.get("plan_revision",1))]
		enqueue_course(assignments,"together",command,1)

func enqueue_course(assignments: Array,mode := "together",command_id := "",peer := 1,group_order: Array=[])->Dictionary:
	var command:=str(command_id)
	if not command.is_empty() and command_courses.has(command):
		return {"error":"","course_id":int(command_courses[command]),"duplicate":true}
	if mode not in ["together","by_groups"]: return {"error":"Неизвестный режим курса.","course_id":0}
	var normalized:=_normalize_assignments(assignments)
	if not str(normalized.error).is_empty(): return {"error":str(normalized.error),"course_id":0}
	var preferred_order: Array=_preferred_group_station_sets(group_order,normalized.assignments)
	_apply_plans(normalized.assignments)
	var captured:=_capture_assignments(normalized.assignments)
	var signature:=_signature(captured,mode,preferred_order)
	var existing:=_existing_signature(signature)
	if not existing.is_empty():
		if not command.is_empty(): command_courses[command]=int(existing.id)
		return {"error":"","course_id":int(existing.id),"duplicate":true}
	_supersede_waiting(captured)
	var course_id:=next_course_id
	next_course_id+=1
	var course: Dictionary={"id":course_id,"command_id":command,"mode":mode,"state":"queued","batch_ids":[],"signature":signature,"peer":int(peer),"created_day":service.progress.day,"assignments":_intent_from_captured(captured),"group_order":[]}
	courses.append(course)
	if not command.is_empty(): command_courses[command]=course_id
	_build_course_batches(course,captured,mode,preferred_order)
	_update_course_state(course_id)
	revision+=1
	service.progress.revision+=1
	service.trace("training_course_queued",{"course":course_id,"mode":mode,"batches":course.batch_ids.duplicate(),"command":command})
	service.feed_player(int(peer),"group_training",_course_feed_payload(course_id),_course_station_ids(course_id).size())
	return {"error":"","course_id":course_id,"duplicate":false}

func _course_station_ids(course_id: int)->Array:
	var result: Array=[]
	var course:=_course(course_id)
	for batch_id in course.get("batch_ids",[]):
		for station_id in _batch(int(batch_id)).get("station_ids",[]):
			if station_id not in result: result.append(station_id)
	result.sort()
	return result

func _pending_lessons(batch: Dictionary)->Array:
	var result: Array=[]
	for lesson_id in batch.get("lesson_ids",[]):
		var lesson:=_lesson(int(lesson_id))
		if str(lesson.get("state","")) in ["queued","blocked","deferred","active","watching"]: result.append(lesson)
	return result

func _reconcile_lesson(lesson: Dictionary)->void:
	if str(lesson.get("state","")) not in ["queued","blocked","deferred"]: return
	for index in range(lesson.station_ids.size()-1,-1,-1):
		var station_id:=int(lesson.station_ids[index])
		var station=service.by_id(station_id)
		var current:=_current_assignment(station_id,str(lesson.dish))
		var version:=int(lesson.versions.get(str(station_id),0))
		if station==null or _actual_matches(station,int(lesson.record_id),str(lesson.dish)) or int(current.get("record_id",0))!=int(lesson.record_id) or int(current.get("revision",0))!=version:
			lesson.station_ids.remove_at(index)
			lesson.versions.erase(str(station_id))
	if lesson.station_ids.is_empty(): lesson.state="completed" if bool(lesson.get("applied",false)) else "superseded"

func _reconcile_empty_batches()->void:
	for lesson in lessons: _reconcile_lesson(lesson)
	for batch in batches:
		if str(batch.get("state","")) in ["completed","cancelled","returning","watching","gathering","draining"]: continue
		if _pending_lessons(batch).is_empty():
			batch.state="completed"
			batch.blocked_reason=""
	for course in courses: _update_course_state(int(course.id))

func _dependency_done(batch: Dictionary)->bool:
	var dependency:=int(batch.get("depends_on",0))
	if dependency<=0: return true
	var previous:=_batch(dependency)
	return previous.is_empty() or str(previous.get("state","")) in ["completed","cancelled"]

func _batch_block_reason(batch: Dictionary)->String:
	if service.progress.shift!="open": return "До следующего рабочего дня"
	if service.progress.busy(): return "Сначала завершится проверка кафе"
	if "television" not in service.progress.lounge_items: return "Нет телевизора"
	if bool(service.movie_state.get("playing",false)): return "Телевизор занят"
	for lesson in _pending_lessons(batch):
		if str(lesson.state) not in ["queued","blocked","deferred"]: continue
		var record: Dictionary=lesson.record
		for station_id in lesson.station_ids:
			var station=service.by_id(int(station_id))
			if station==null: return "Стол %d больше не существует"%int(station_id)
			if station.staffed>=0 and station.staffed<station.role_count(): return "Стол %d: нужны сотрудники"%int(station_id)
			if station.training.active(): return "Стол %d занят другим обучением"%int(station_id)
			if not station.group_training_state.is_empty(): return "Стол %d занят другой учебной партией"%int(station_id)
			if not station.ready_crew(): return "Стол %d: сотрудник занят другой активностью"%int(station_id)
			if not _record_valid_for_station(record,station): return "Стол %d несовместим с уроком"%int(station_id)
	return ""

func _mark_batch_stations(batch: Dictionary,state: String)->void:
	for station_id in batch.get("station_ids",[]):
		var station=service.by_id(int(station_id))
		if station!=null: station.group_training_state=state

func _clear_batch_stations(batch: Dictionary)->void:
	_mark_batch_stations(batch,"")

func _select_next_batch()->void:
	if active_batch_id>0 or service.progress.shift!="open": return
	_reconcile_empty_batches()
	for batch in batches:
		if str(batch.get("state","")) in ["completed","cancelled","gathering","watching","returning","draining"]: continue
		if int(batch.get("defer_day",service.progress.day))>service.progress.day:
			batch.state="deferred"
			continue
		if not _dependency_done(batch): continue
		var reason:=_batch_block_reason(batch)
		if not reason.is_empty():
			batch.state="blocked"
			batch.blocked_reason=reason
			if str(batch.get("last_feed_reason",""))!=reason:
				batch.last_feed_reason=reason
				service.feed_system("training_wait",_course_feed_payload(int(batch.course_id),{"batch":int(batch.id),"reason":reason,"stations":batch.station_ids.duplicate()}),1)
			for lesson in _pending_lessons(batch):
				if str(lesson.state) in ["queued","blocked"]: lesson.state="blocked"
			_update_course_state(int(batch.course_id))
			continue
		batch.last_feed_reason=""
		for lesson in _pending_lessons(batch):
			if str(lesson.state)=="blocked": lesson.state="queued"
		batch.state="draining"
		batch.blocked_reason=""
		active_batch_id=int(batch.id)
		_mark_batch_stations(batch,"draining")
		_update_course_state(int(batch.course_id))
		revision+=1
		service.progress.revision+=1
		return

func _batch_idle(batch: Dictionary)->bool:
	for station_id in batch.get("station_ids",[]):
		var station=service.by_id(int(station_id))
		if station==null: return false
		if station.state!="idle" or station.customer_id>=0 or station.training.active(): return false
	return true

func _next_lesson(batch: Dictionary)->Dictionary:
	for lesson_id in batch.get("lesson_ids",[]):
		var lesson:=_lesson(int(lesson_id))
		if str(lesson.get("state","")) in ["queued","blocked","deferred"]: return lesson
	return {}

func _start_active_batch(batch: Dictionary)->void:
	var lesson:=_next_lesson(batch)
	if lesson.is_empty():
		batch.state="completed"
		_clear_batch_stations(batch)
		active_batch_id=0
		_update_course_state(int(batch.course_id))
		return
	batch.current_lesson_id=int(lesson.id)
	batch.state="gathering"
	batch.gathers=int(batch.get("gathers",0))+1
	lesson.state="active"
	service.staff_training.start_queue(lesson.record,batch.station_ids,lesson.station_ids,int(lesson.id))
	revision+=1
	service.progress.revision+=1

func _advance_active()->void:
	if active_batch_id<=0: return
	var batch:=_batch(active_batch_id)
	if batch.is_empty():
		active_batch_id=0
		return
	if str(batch.state)=="draining":
		if service.progress.shift!="open":
			_defer_batch(batch)
			return
		if _batch_idle(batch): _start_active_batch(batch)
	elif service.staff_training.is_active():
		var phase:=str(service.staff_training.phase)
		if phase in ["assigned","gathering","walking"]: batch.state="gathering"
		elif phase=="watching": batch.state="watching"
		elif phase=="returning": batch.state="returning"

func advance(delta: float)->void:
	if service==null: return
	auto_reconcile_clock+=maxf(0.0,delta)
	if auto_reconcile_due or auto_reconcile_clock>=3.0:
		auto_reconcile_due=false
		auto_reconcile_clock=0.0
		reconcile_automatic_needs()
	if service.progress.shift=="open":
		for batch in batches:
			if str(batch.get("state",""))=="deferred" and int(batch.get("defer_day",0))<=service.progress.day: batch.state="queued"
		advance_handoff_cleanup()
	_reconcile_empty_batches()
	if active_batch_id>0: _advance_active()
	else: _select_next_batch()

func executor_watching(lesson_id: int)->void:
	var lesson:=_lesson(lesson_id)
	if lesson.is_empty(): return
	lesson.state="watching"
	var batch:=_batch(int(lesson.batch_id))
	if not batch.is_empty(): batch.state="watching"
	revision+=1
	service.progress.revision+=1

func _apply_lesson(lesson: Dictionary)->void:
	if bool(lesson.get("applied",false)): return
	var record: Dictionary=lesson.record
	for station_id in lesson.station_ids:
		var station=service.by_id(int(station_id))
		if station==null: continue
		station.recipes[str(lesson.dish)]={"tracks":record.get("tracks",[]).duplicate(true),"duration":float(record.get("duration",0.0)),"quality":record.get("quality",{}).duplicate(true),"required_equipment":Masterclasses.required_equipment(record)}
		station.method_sources[str(lesson.dish)]={"id":int(lesson.record_id),"name":str(record.get("name","Запись"))}
		station.drafts.erase(str(lesson.dish))
	lesson.applied=true
	lesson.state="completed"
	var lesson_batch:=_batch(int(lesson.batch_id))
	if not lesson_batch.is_empty(): lesson_batch.movies=int(lesson_batch.get("movies",0))+1
	service.trace("training_lesson_complete",{"lesson":int(lesson.id),"dish":str(lesson.dish),"record":int(lesson.record_id),"stations":lesson.station_ids.duplicate()})
	service.feed_system("training",{"dish":str(lesson.dish),"record":int(lesson.record_id),"name":str(record.get("name","Запись")),"stations":lesson.station_ids.duplicate()},lesson.station_ids.size())
	service.progress.revision+=1
	request_auto_reconcile()

func executor_movie_finished(lesson_id: int)->Dictionary:
	var lesson:=_lesson(lesson_id)
	if lesson.is_empty(): return {"action":"return"}
	_apply_lesson(lesson)
	var batch:=_batch(int(lesson.batch_id))
	if batch.is_empty(): return {"action":"return"}
	batch.current_lesson_id=0
	_reconcile_empty_batches()
	var next:=_next_lesson(batch)
	var must_close: bool=bool(batch.get("close_after_lesson",false)) or service.progress.shift!="open"
	if must_close:
		if next.is_empty():
			batch.state="completed"
		else:
			batch.state="deferred"
			batch.defer_day=service.progress.day+1
			for pending in _pending_lessons(batch):
				if str(pending.state) in ["queued","blocked","active"]: pending.state="deferred"
			_feed_deferred(batch)
		_clear_batch_stations(batch)
		active_batch_id=0
		_update_course_state(int(batch.course_id))
		revision+=1
		return {"action":"evening"}
	if next.is_empty():
		batch.state="returning"
		revision+=1
		return {"action":"return"}
	next.state="active"
	batch.current_lesson_id=int(next.id)
	batch.state="watching"
	revision+=1
	return {"action":"next","record":next.record.duplicate(true),"dish":str(next.dish),"lesson_id":int(next.id),"target_ids":next.station_ids.duplicate()}

func executor_return_finished()->void:
	if active_batch_id<=0: return
	var batch:=_batch(active_batch_id)
	if not batch.is_empty():
		batch.returns=int(batch.get("returns",0))+1
		batch.state="completed" if _pending_lessons(batch).is_empty() else "queued"
		batch.current_lesson_id=0
		_clear_batch_stations(batch)
		_update_course_state(int(batch.course_id))
	active_batch_id=0
	revision+=1
	service.progress.revision+=1

func _update_course_state(course_id: int)->void:
	var course:=_course(course_id)
	if course.is_empty(): return
	var old_state: String=str(course.get("state",""))
	var states: Array=[]
	for batch_id in course.get("batch_ids",[]): states.append(str(_batch(int(batch_id)).get("state","completed")))
	if not states.is_empty() and states.all(func(state):return state in ["completed","cancelled"]):
		course.state="cancelled" if states.all(func(state):return state=="cancelled") else "completed"
	elif states.any(func(state):return state in ["watching","gathering","draining","returning"]): course.state="active"
	elif states.any(func(state):return state=="deferred"): course.state="deferred"
	elif states.any(func(state):return state=="blocked"): course.state="blocked"
	else: course.state="queued"
	if str(course.state)=="completed" and old_state!="completed":
		service.feed_system("training_course_complete",_course_feed_payload(course_id),maxi(1,_course_station_ids(course_id).size()))

func _suspend_lesson_targets(lesson: Dictionary)->void:
	for station_id in lesson.get("station_ids",[]):
		var current:=_current_assignment(int(station_id),str(lesson.dish))
		if int(current.get("record_id",0))==int(lesson.record_id):
			suspended_assignments[_assignment_key(int(station_id),str(lesson.dish),int(lesson.record_id),int(current.get("revision",0)))]=true

func record_renamed(record_id: int,value: String)->void:
	for lesson in lessons:
		if int(lesson.get("record_id",0))==record_id and lesson.get("record",{}) is Dictionary:
			lesson.record.name=value
	if service.staff_training.is_active() and int(service.staff_training.record_id)==record_id:
		service.staff_training.record.name=value
	revision+=1

func cancel_batch(batch_id: int)->String:
	var batch:=_batch(batch_id)
	if batch.is_empty(): return "Партия не найдена."
	if str(batch.get("state","")) in ["completed","cancelled"]: return ""
	for lesson_id in batch.get("lesson_ids",[]):
		var lesson:=_lesson(int(lesson_id))
		if str(lesson.get("state",""))=="completed": continue
		_suspend_lesson_targets(lesson)
		lesson.state="cancelled"
	if batch_id==active_batch_id:
		if service.staff_training.is_active():
			batch.state="returning"
			service.staff_training.cancel_queue(service.progress.shift in ["closing","night"])
		else:
			_clear_batch_stations(batch)
			batch.state="cancelled"
			active_batch_id=0
	else:
		batch.state="cancelled"
		_clear_batch_stations(batch)
	_update_course_state(int(batch.course_id))
	service.feed_system("training_cancel",_course_feed_payload(int(batch.course_id),{"batch":batch_id,"scope":"batch"}),1)
	revision+=1
	service.progress.revision+=1
	request_auto_reconcile()
	return ""

func cancel_course(course_id: int)->String:
	var course:=_course(course_id)
	if course.is_empty(): return "Курс не найден."
	if str(course.get("state","")) in ["completed","cancelled"]: return ""
	for batch_id in course.get("batch_ids",[]):
		var batch:=_batch(int(batch_id))
		for lesson_id in batch.get("lesson_ids",[]):
			var lesson:=_lesson(int(lesson_id))
			if str(lesson.get("state",""))=="completed": continue
			_suspend_lesson_targets(lesson)
			lesson.state="cancelled"
		if int(batch.id)==active_batch_id:
			if service.staff_training.is_active():
				batch.state="returning"
				service.staff_training.cancel_queue(service.progress.shift in ["closing","night"])
			else:
				_clear_batch_stations(batch)
				batch.state="cancelled"
				active_batch_id=0
		else:
			batch.state="cancelled"
			_clear_batch_stations(batch)
	course.state="cancelled"
	service.feed_system("training_cancel",_course_feed_payload(course_id,{"scope":"course"}),1)
	revision+=1
	service.progress.revision+=1
	request_auto_reconcile()
	return ""

func cancel_lesson(lesson_id: int)->String:
	var lesson:=_lesson(lesson_id)
	if lesson.is_empty(): return "Урок не найден."
	if str(lesson.state) in ["completed","cancelled","superseded"]: return ""
	_suspend_lesson_targets(lesson)
	lesson.state="cancelled"
	var batch:=_batch(int(lesson.batch_id))
	if int(batch.get("current_lesson_id",0))==lesson_id and service.staff_training.is_active():
		batch.current_lesson_id=0
		var next:=_next_lesson(batch)
		var to_evening: bool=service.progress.shift in ["closing","night"]
		if not next.is_empty() and not to_evening:
			next.state="active"
			batch.current_lesson_id=int(next.id)
			batch.state="watching"
			service.staff_training.cancel_current_lesson_and_continue({"action":"next","record":next.record.duplicate(true),"dish":str(next.dish),"lesson_id":int(next.id),"target_ids":next.station_ids.duplicate()},false)
		else:
			batch.state="returning" if not to_evening else "deferred"
			if to_evening: batch.defer_day=service.progress.day+1
			service.staff_training.cancel_current_lesson_and_continue({},to_evening)
			if to_evening:
				_clear_batch_stations(batch)
				active_batch_id=0
	elif _pending_lessons(batch).is_empty():
		batch.state="cancelled"
		_clear_batch_stations(batch)
		if int(batch.id)==active_batch_id: active_batch_id=0
	_update_course_state(int(lesson.course_id))
	service.feed_system("training_cancel",_course_feed_payload(int(lesson.course_id),{"lesson":lesson_id,"dish":str(lesson.dish),"scope":"lesson"}),1)
	revision+=1
	service.progress.revision+=1
	request_auto_reconcile()
	return ""

func assignment_suspended(station_id: int,dish: String)->bool:
	var current:=_current_assignment(station_id,dish)
	return bool(suspended_assignments.get(_assignment_key(station_id,dish,int(current.get("record_id",0)),int(current.get("revision",0))),false))

func _defer_batch(batch: Dictionary)->void:
	var already_deferred: bool=str(batch.get("state",""))=="deferred" and int(batch.get("defer_day",0))==service.progress.day+1
	for lesson in _pending_lessons(batch):
		if str(lesson.state) in ["queued","blocked","active"]: lesson.state="deferred"
	batch.state="deferred"
	batch.defer_day=service.progress.day+1
	batch.current_lesson_id=0
	_clear_batch_stations(batch)
	if int(batch.id)==active_batch_id: active_batch_id=0
	_update_course_state(int(batch.course_id))
	if not already_deferred: _feed_deferred(batch)
	revision+=1

func on_shift_closed()->void:
	for batch in batches:
		if str(batch.get("state","")) in ["queued","blocked"]:
			_defer_batch(batch)
	if active_batch_id<=0: return
	var batch:=_batch(active_batch_id)
	if batch.is_empty(): active_batch_id=0; return
	if str(batch.state)=="draining":
		_defer_batch(batch)
		return
	if not service.staff_training.is_active():
		_defer_batch(batch)
		return
	var phase:=str(service.staff_training.phase)
	if phase in ["assigned","gathering","walking"]:
		_defer_batch(batch)
		service.staff_training.handoff_to_evening()
	elif phase=="watching":
		batch.close_after_lesson=true
		revision+=1
	elif phase=="returning":
		batch.state="completed" if _pending_lessons(batch).is_empty() else "deferred"
		if str(batch.state)=="deferred":
			batch.defer_day=service.progress.day+1
			_feed_deferred(batch)
		_clear_batch_stations(batch)
		active_batch_id=0
		service.staff_training.handoff_to_evening()
		_update_course_state(int(batch.course_id))
		revision+=1

func ready_for_tv()->bool:
	if active_batch_id>0: return true
	if service==null or service.progress.shift!="open": return false
	for batch in batches:
		if str(batch.get("state","")) not in ["queued","blocked","deferred"]: continue
		if int(batch.get("defer_day",service.progress.day))>service.progress.day or not _dependency_done(batch): continue
		if _batch_block_reason(batch).is_empty(): return true
	return false

func has_pending()->bool:
	for course in courses:
		if str(course.get("state","")) not in ["completed","cancelled"]: return true
	return false

func active_blocks_night()->bool:
	return service!=null and service.staff_training.is_active()

func capture_handoff(clone_id: int,position: Vector3)->void:
	if clone_id>0: handoff_positions[str(clone_id)]={"position":position}

func handoff_for_clone(clone_id: int)->Dictionary:
	return handoff_positions.get(str(clone_id),{})

func clear_handoffs()->void:
	handoff_positions.clear()

func advance_handoff_cleanup()->void:
	if service.progress.shift=="open" and not service.staff_training.is_active() and service.progress.shift_elapsed>0.2: handoff_positions.clear()

func pending_source(station_id: int,dish: String)->Dictionary:
	for lesson in lessons:
		if str(lesson.get("dish",""))!=dish or station_id not in lesson.get("station_ids",[]): continue
		if str(lesson.get("state","")) not in ["queued","blocked","deferred","active","watching"]: continue
		return {"id":int(lesson.record_id),"name":str(lesson.record.get("name","Запись")),"pending":true,"state":str(lesson.state)}
	return {}

func station_status(station_id: int,dish: String)->String:
	for lesson in lessons:
		if str(lesson.get("dish",""))!=dish or station_id not in lesson.get("station_ids",[]): continue
		var batch: Dictionary=_batch(int(lesson.batch_id))
		var batch_state: String=str(batch.get("state",""))
		if int(batch.get("id",0))==active_batch_id and station_id in batch.get("station_ids",[]):
			if batch_state=="draining": return "заканчивает принятый заказ"
			if batch_state=="gathering": return service.staff_training.phase_label() if service.staff_training.is_active() else "собирается"
			if batch_state=="watching": return service.staff_training.phase_label() if service.staff_training.is_active() else "смотрит"
			if batch_state=="returning": return "возвращается"
		var state:=str(lesson.get("state",""))
		if state in ["active","watching"]:
			return service.staff_training.phase_label() if service.staff_training.is_active() else "обучается"
		if state=="blocked":
			return "ждёт · "+str(batch.get("blocked_reason",""))
		if state=="deferred": return "отложено до следующего дня"
		if state=="queued": return "в очереди на обучение"
	if assignment_suspended(station_id,dish): return "обучение отменено"
	return ""

func queue_summary()->Array:
	var result: Array=[]
	for batch in batches:
		if str(batch.get("state","")) in ["completed","cancelled"]: continue
		result.append({"id":int(batch.id),"course_id":int(batch.course_id),"state":str(batch.state),"stations":batch.station_ids.duplicate(),"lessons":batch.lesson_ids.size(),"blocked_reason":str(batch.get("blocked_reason",""))})
	return result

func snapshot()->Dictionary:
	return {
		"revision":revision,"next_course_id":next_course_id,"next_batch_id":next_batch_id,"next_lesson_id":next_lesson_id,
		"courses":courses.duplicate(true),"batches":batches.duplicate(true),"lessons":lessons.duplicate(true),
		"command_courses":command_courses.duplicate(true),"suspended_assignments":suspended_assignments.duplicate(true),
		"active_batch_id":active_batch_id,"handoff_positions":handoff_positions.duplicate(true)
	}

func public_snapshot()->Dictionary:
	var lesson_rows: Array=[]
	for lesson in lessons:
		var row: Dictionary=lesson.duplicate(true)
		if row.has("record"):
			row.record={"id":int(row.record_id),"name":str(row.record.get("name","Запись")),"dish":str(row.dish)}
		lesson_rows.append(row)
	return {"revision":revision,"courses":courses.duplicate(true),"batches":batches.duplicate(true),"lessons":lesson_rows,"active_batch_id":active_batch_id}

func restore(data: Dictionary)->bool:
	if not data is Dictionary or not data.get("courses",[]) is Array or not data.get("batches",[]) is Array or not data.get("lessons",[]) is Array: return false
	courses=data.get("courses",[]).duplicate(true)
	batches=data.get("batches",[]).duplicate(true)
	lessons=data.get("lessons",[]).duplicate(true)
	command_courses=data.get("command_courses",{}).duplicate(true)
	suspended_assignments=data.get("suspended_assignments",{}).duplicate(true)
	var migrated_suspended: Dictionary={}
	for raw_key in suspended_assignments.keys():
		var key:=str(raw_key)
		var parts:=key.split("|")
		if parts.size()==4:
			migrated_suspended[key]=true
			continue
		if parts.size()!=3: continue
		var station_id:=int(parts[0])
		var dish:=str(parts[1])
		var version:=int(parts[2])
		var record_id:=0
		for lesson in data.get("lessons",[]):
			if not lesson is Dictionary or str(lesson.get("dish",""))!=dish or station_id not in lesson.get("station_ids",[]): continue
			if int(lesson.get("versions",{}).get(str(station_id),0))==version:
				record_id=int(lesson.get("record_id",0))
				break
		if record_id<=0:
			var current:=_current_assignment(station_id,dish)
			record_id=int(current.get("record_id",0))
		if record_id>0: migrated_suspended[_assignment_key(station_id,dish,record_id,version)]=true
	suspended_assignments=migrated_suspended
	active_batch_id=int(data.get("active_batch_id",0))
	next_course_id=maxi(1,int(data.get("next_course_id",1)))
	next_batch_id=maxi(1,int(data.get("next_batch_id",1)))
	next_lesson_id=maxi(1,int(data.get("next_lesson_id",1)))
	revision=int(data.get("revision",0))
	handoff_positions=data.get("handoff_positions",{}).duplicate(true)
	for course in courses: next_course_id=maxi(next_course_id,int(course.get("id",0))+1)
	for batch in batches: next_batch_id=maxi(next_batch_id,int(batch.get("id",0))+1)
	for lesson in lessons:
		next_lesson_id=maxi(next_lesson_id,int(lesson.get("id",0))+1)
		if not lesson.get("record",{}) is Dictionary: return false
	_rebuild_station_states()
	request_auto_reconcile()
	return true

func apply_public_snapshot(data: Dictionary)->void:
	if not data is Dictionary: return
	courses=data.get("courses",[]).duplicate(true)
	batches=data.get("batches",[]).duplicate(true)
	lessons=data.get("lessons",[]).duplicate(true)
	active_batch_id=int(data.get("active_batch_id",0))
	revision=int(data.get("revision",revision))

func _rebuild_station_states()->void:
	for station in service.stations:
		if not station.manual_station: station.group_training_state=""
	if active_batch_id<=0: return
	var batch:=_batch(active_batch_id)
	if batch.is_empty(): return
	var state:=str(batch.get("state",""))
	var visual: String="draining" if state=="draining" else "gathering" if state=="gathering" else "watching" if state=="watching" else "returning" if state=="returning" else ""
	if not visual.is_empty(): _mark_batch_stations(batch,visual)
