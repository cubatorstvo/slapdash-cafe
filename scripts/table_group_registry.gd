extends RefCounted
## Persistent organizational groups for production stations.
## Recipes are actual learned knowledge; curriculum is only desired intent.
var groups: Dictionary={}
var next_group_id:=1

func reset()->void:
	groups.clear()
	next_group_id=1

func _new_id()->String:
	while groups.has("g%d"%next_group_id): next_group_id+=1
	var value:="g%d"%next_group_id
	next_group_id+=1
	return value

func _normalize_ids(value: Variant)->Array:
	var result: Array=[]
	if value is Array:
		for raw in value:
			var id:=int(raw)
			if id>0 and id not in result: result.append(id)
	result.sort()
	return result

func _normalize_dishes(value: Variant,allowed: Array)->Array:
	var result: Array=[]
	if value is Array:
		for raw in value:
			var dish:=str(raw)
			if dish in allowed and dish not in result: result.append(dish)
	return result

func _normalize_curriculum(value: Variant,allowed: Array)->Array:
	var result: Array=[]
	var seen: Array=[]
	if value is Array:
		for raw in value:
			if not raw is Dictionary: continue
			var dish:=str(raw.get("dish_id",raw.get("dish","")))
			var record_id:=int(raw.get("record_id",raw.get("id",0)))
			if dish not in allowed or dish in seen or record_id<=0: continue
			seen.append(dish)
			result.append({"dish_id":dish,"record_id":record_id,"revision":maxi(1,int(raw.get("revision",1)))})
	elif value is Dictionary:
		for dish_raw in allowed:
			var dish:=str(dish_raw)
			if not value.has(dish): continue
			var raw=value[dish]
			var record_id:=int(raw.get("id",raw.get("record_id",0))) if raw is Dictionary else int(raw)
			if record_id<=0: continue
			result.append({"dish_id":dish,"record_id":record_id,"revision":maxi(1,int(raw.get("revision",1))) if raw is Dictionary else 1})
	return result

func _group(id: String,name: String,type_id: String,station_ids: Array,active_dishes: Array,curriculum: Array,plan_revision := 1)->Dictionary:
	return {"id":id,"name":name.left(48),"type_id":type_id,"station_ids":_normalize_ids(station_ids),"active_dishes":active_dishes.duplicate(),"curriculum":curriculum.duplicate(true),"plan_revision":maxi(1,int(plan_revision))}

func snapshot()->Dictionary:
	return {"next_group_id":next_group_id,"groups":groups.duplicate(true)}

func restore(data: Dictionary,types: Dictionary)->bool:
	if not data.get("groups",{}) is Dictionary: return false
	var restored: Dictionary={}
	var occupied: Array=[]
	for key in data.groups:
		var raw=data.groups[key]
		if not raw is Dictionary: return false
		var id:=str(raw.get("id",key))
		var type_id:=str(raw.get("type_id",raw.get("type","")))
		if id.is_empty() or type_id not in types: return false
		var allowed: Array=types[type_id].dishes
		var ids:=_normalize_ids(raw.get("station_ids",raw.get("stations",[])))
		if ids.is_empty(): continue
		for station_id in ids:
			if station_id in occupied: return false
			occupied.append(station_id)
		var name:=str(raw.get("name","Группа "+id))
		var active:=_normalize_dishes(raw.get("active_dishes",allowed),allowed)
		var curriculum:=_normalize_curriculum(raw.get("curriculum",raw.get("plan",{})),allowed)
		restored[id]=_group(id,name,type_id,ids,active,curriculum,int(raw.get("plan_revision",1)))
	groups=restored
	next_group_id=maxi(1,int(data.get("next_group_id",1)))
	while groups.has("g%d"%next_group_id): next_group_id+=1
	return true

func all()->Array:
	var result: Array=groups.values()
	result.sort_custom(func(a,b):
		var a_first: int=int(a.station_ids[0]) if not a.station_ids.is_empty() else 9999
		var b_first: int=int(b.station_ids[0]) if not b.station_ids.is_empty() else 9999
		return a_first<b_first if a_first!=b_first else str(a.id)<str(b.id))
	return result

func by_id(id: String)->Dictionary:
	return groups.get(id,{})

func group_id_for_station(station_id: int)->String:
	for id in groups:
		if station_id in groups[id].station_ids: return str(id)
	return ""

func for_station(station_id: int)->Dictionary:
	var id:=group_id_for_station(station_id)
	return groups.get(id,{}) if not id.is_empty() else {}

func plan_map(group: Dictionary)->Dictionary:
	var result: Dictionary={}
	for item in group.get("curriculum",[]):
		result[str(item.dish_id)]={"record_id":int(item.record_id),"revision":int(item.revision)}
	return result

func plan_record(group: Dictionary,dish: String)->Dictionary:
	for item in group.get("curriculum",[]):
		if str(item.dish_id)==dish: return item
	return {}

func signature_for_station(station)->String:
	var parts: Array=[station.type_id]
	for dish in station.dishes():
		var source: Dictionary=station.method_sources.get(dish,{})
		if source.is_empty(): source=station.method_plan.get(dish,{})
		var token: String="none"
		if not source.is_empty(): token=str(int(source.get("id",source.get("record_id",0)))) if int(source.get("id",source.get("record_id",0)))>0 else "legacy"
		elif station.recipes.has(dish): token="legacy"
		parts.append("%s=%s"%[dish,token])
	return "|".join(parts)

func _legacy_plan(station)->Array:
	var result: Array=[]
	for dish in station.dishes():
		var source: Dictionary=station.method_plan.get(dish,{})
		if source.is_empty(): source=station.method_sources.get(dish,{})
		var id:=int(source.get("id",source.get("record_id",0)))
		if id>0: result.append({"dish_id":str(dish),"record_id":id,"revision":maxi(1,int(source.get("revision",1)))})
	return result

func _legacy_active(station)->Array:
	var result: Array=[]
	for dish in station.dishes():
		if station.recipes.has(dish) or station.method_plan.has(dish):
			result.append(str(dish))
	return result

func migrate_legacy(stations: Array,legacy_names: Dictionary,types: Dictionary)->void:
	reset()
	var buckets: Dictionary={}
	for station in stations:
		if station.manual_station or station.masterclass_station: continue
		var signature:=signature_for_station(station)
		if not buckets.has(signature): buckets[signature]=[]
		buckets[signature].append(station)
	for signature in buckets:
		var members: Array=buckets[signature]
		members.sort_custom(func(a,b):return a.station_id<b.station_id)
		var ids: Array=members.map(func(station):return station.station_id)
		var old_id: String="-".join(ids.map(func(id):return str(id)))
		var id:=old_id
		if groups.has(id): id=_new_id()
		var first=members[0]
		var auto_name: String="%s · столы %s"%[types[first.type_id].title,", ".join(ids.map(func(raw):return str(raw)))]
		groups[id]=_group(id,str(legacy_names.get(old_id,auto_name)),first.type_id,ids,_legacy_active(first),_legacy_plan(first),1)

func ensure_station(station,types: Dictionary)->String:
	if station.manual_station or station.masterclass_station: return ""
	var existing:=group_id_for_station(station.station_id)
	if not existing.is_empty(): return existing
	var id:=_new_id()
	var name: String="%s · стол %d"%[types[station.type_id].title,station.station_id]
	groups[id]=_group(id,name,station.type_id,[station.station_id],_legacy_active(station),_legacy_plan(station),1)
	return id

func rename(id: String,value: String)->String:
	if not groups.has(id): return "Группа уже изменилась. Обнови список."
	var name:=value.strip_edges().left(48)
	if name.is_empty(): return "Название группы не может быть пустым."
	groups[id].name=name
	return ""

func _remove_station_from_other_groups(station_id: int,except_id := "")->void:
	var remove_ids: Array=[]
	for id in groups:
		if str(id)==except_id: continue
		var group: Dictionary=groups[id]
		group.station_ids.erase(station_id)
		if group.station_ids.is_empty(): remove_ids.append(id)
	for id in remove_ids: groups.erase(id)

func create_group(station_ids: Array,type_id: String,name: String,template: Dictionary={})->Dictionary:
	var ids:=_normalize_ids(station_ids)
	if ids.is_empty(): return {}
	for id in ids: _remove_station_from_other_groups(int(id))
	var group_id:=_new_id()
	var active: Array=template.get("active_dishes",[]).duplicate() if not template.is_empty() else []
	var curriculum: Array=template.get("curriculum",[]).duplicate(true) if not template.is_empty() else []
	var revision: int=int(template.get("plan_revision",1)) if not template.is_empty() else 1
	groups[group_id]=_group(group_id,name,type_id,ids,active,curriculum,revision)
	return groups[group_id]

func split(id: String,selected_ids: Array)->Dictionary:
	if not groups.has(id): return {}
	var source: Dictionary=groups[id]
	var selected:=_normalize_ids(selected_ids)
	if selected.is_empty() or selected.size()>=source.station_ids.size(): return {}
	for station_id in selected:
		if station_id not in source.station_ids: return {}
	for station_id in selected: source.station_ids.erase(station_id)
	var suffix:=2
	var candidate: String=str(source.name)+" · 2"
	var names: Array=groups.values().map(func(group):return str(group.name))
	while candidate in names:
		suffix+=1
		candidate=str(source.name)+" · %d"%suffix
	return create_group(selected,str(source.type_id),candidate,source)

func set_members(id: String,station_ids: Array,type_id: String)->String:
	if not groups.has(id): return "Группа не найдена."
	if str(groups[id].type_id)!=type_id: return "Можно объединять только столы одной кухни."
	var ids:=_normalize_ids(station_ids)
	if ids.is_empty(): return "В группе должен остаться хотя бы один стол."
	for station_id in ids: _remove_station_from_other_groups(int(station_id),id)
	groups[id].station_ids=ids
	return ""

func set_active_dish(id: String,dish: String,enabled: bool)->String:
	if not groups.has(id): return "Группа не найдена."
	var group: Dictionary=groups[id]
	if dish not in group.get("active_dishes",[]):
		if enabled: group.active_dishes.append(dish)
	elif not enabled: group.active_dishes.erase(dish)
	return ""

func set_plan(id: String,dish: String,record_id: int)->String:
	if not groups.has(id): return "Группа не найдена."
	var group: Dictionary=groups[id]
	if record_id<=0:
		for i in range(group.curriculum.size()-1,-1,-1):
			if str(group.curriculum[i].dish_id)==dish: group.curriculum.remove_at(i)
		group.plan_revision=int(group.plan_revision)+1
		return ""
	var found:=false
	for item in group.curriculum:
		if str(item.dish_id)==dish:
			if int(item.record_id)!=record_id:
				item.record_id=record_id
				item.revision=int(item.revision)+1
				group.plan_revision=int(group.plan_revision)+1
			found=true
			break
	if not found:
		group.plan_revision=int(group.plan_revision)+1
		group.curriculum.append({"dish_id":dish,"record_id":record_id,"revision":int(group.plan_revision)})
	return ""

func apply_plan_to_selection(station_ids: Array,dish: String,record_id: int)->Array:
	var ids:=_normalize_ids(station_ids)
	var affected: Array=[]
	var source_groups: Array=[]
	for station_id in ids:
		var group_id:=group_id_for_station(int(station_id))
		if not group_id.is_empty() and group_id not in source_groups: source_groups.append(group_id)
	for group_id in source_groups:
		if not groups.has(group_id): continue
		var group: Dictionary=groups[group_id]
		var chosen: Array=[]
		for station_id in group.station_ids:
			if station_id in ids: chosen.append(station_id)
		if chosen.is_empty(): continue
		var target_id: String=str(group_id)
		if chosen.size()<group.station_ids.size():
			var created:=split(group_id,chosen)
			if created.is_empty(): continue
			target_id=str(created.id)
		set_plan(target_id,dish,record_id)
		affected.append(target_id)
	return affected

func merge(group_ids: Array,record_choices: Dictionary={},active_dishes: Variant=null)->Dictionary:
	var ids: Array=[]
	for raw in group_ids:
		var id:=str(raw)
		if groups.has(id) and id not in ids: ids.append(id)
	if ids.size()<2: return {}
	var target: Dictionary=groups[ids[0]]
	var type_id:=str(target.type_id)
	for id in ids:
		if str(groups[id].type_id)!=type_id: return {}
	var members: Array=[]
	for id in ids:
		for station_id in groups[id].station_ids:
			if station_id not in members: members.append(station_id)
	members.sort()
	var allowed: Array=[]
	if active_dishes is Array:
		allowed=active_dishes.duplicate()
	else:
		for dish in target.get("active_dishes",[]): if dish not in allowed: allowed.append(dish)
		for id in ids:
			for dish in groups[id].get("active_dishes",[]): if dish not in allowed: allowed.append(dish)
	var all_dishes: Array=[]
	for id in ids:
		for item in groups[id].curriculum:
			if str(item.dish_id) not in all_dishes: all_dishes.append(str(item.dish_id))
	target.station_ids=members
	target.active_dishes=allowed
	target.plan_revision=int(target.plan_revision)+1
	var new_curriculum: Array=[]
	for dish in all_dishes:
		var chosen:=int(record_choices.get(dish,0))
		if chosen<=0:
			var first:=plan_record(target,dish)
			if not first.is_empty(): chosen=int(first.record_id)
		if chosen<=0:
			for id in ids:
				var item:=plan_record(groups[id],dish)
				if not item.is_empty(): chosen=int(item.record_id); break
		if chosen>0: new_curriculum.append({"dish_id":dish,"record_id":chosen,"revision":int(target.plan_revision)})
	target.curriculum=new_curriculum
	for index in range(1,ids.size()): groups.erase(ids[index])
	return target

func preview_merge(group_ids: Array)->Dictionary:
	var ids: Array=[]
	for raw in group_ids:
		var id:=str(raw)
		if groups.has(id) and id not in ids: ids.append(id)
	if ids.size()<2: return {}
	var type_id:=str(groups[ids[0]].type_id)
	for id in ids:
		if str(groups[id].type_id)!=type_id: return {}
	var differences: Dictionary={}
	var dishes: Array=[]
	for id in ids:
		for item in groups[id].curriculum:
			if str(item.dish_id) not in dishes: dishes.append(str(item.dish_id))
	for dish in dishes:
		var values: Array=[]
		for id in ids:
			var item:=plan_record(groups[id],dish)
			var value:=int(item.get("record_id",0))
			if value not in values: values.append(value)
		if values.size()>1: differences[dish]=values
	return {"groups":ids,"type_id":type_id,"differences":differences}
