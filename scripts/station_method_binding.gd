extends RefCounted
const Definition=preload("res://scripts/station_definition.gd")
const CookingMethod=preload("res://scripts/cooking_method.gd")

static func binding(service,station,dish: String)->Dictionary:
	if station==null or station.manual_station or station.masterclass_station: return {"learned":false,"reason":"not_production"}
	if dish not in station.dishes(): return {"learned":false,"reason":"incompatible_dish"}
	var roles:=Definition.role_ids(station.type_id)
	var active_roles: int=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
	if active_roles<station.role_count(): return {"learned":false,"reason":"missing_workers"}
	var method_id:=0
	var bindings: Array=[]
	var sources: Array=[]
	for role in range(station.role_count()):
		var clone_id:=int(station.crew[role].get("clone_id",0))
		if clone_id<=0: return {"learned":false,"reason":"skill_missing","role":roles[role]}
		var skill: Dictionary=service.learning_state.clone_skill(clone_id,station.type_id,dish,str(roles[role]))
		if skill.is_empty(): return {"learned":false,"reason":"skill_missing","role":roles[role],"clone_id":clone_id}
		var learned_method:=int(skill.get("method_id",0))
		if method_id==0: method_id=learned_method
		elif method_id!=learned_method: return {"learned":false,"reason":"crew_method_mismatch"}
		bindings.append({"role_index":role,"role_id":str(roles[role]),"clone_id":clone_id})
		sources.append(skill.get("source",{}).duplicate(true))
	var method_value: Dictionary=service.learning_state.method_ref(method_id)
	if not CookingMethod.valid(method_value) or str(method_value.source_type)!=station.type_id or str(method_value.dish)!=dish: return {"learned":false,"reason":"method_invalid"}
	return {"learned":true,"reason":"","method_id":method_id,"roles":bindings,"sources":sources,"quality":method_value.quality,"duration":float(method_value.duration_ticks)/60.0,"required_equipment":method_value.get("required_equipment",[])}

static func source_summary(binding_value: Dictionary)->Dictionary:
	if not bool(binding_value.get("learned",false)): return {}
	var sources: Array=binding_value.get("sources",[])
	var kinds: Array=[]
	var record_ids: Array=[]
	var names: Array=[]
	for source in sources:
		var kind:=str(source.get("kind","legacy"))
		if kind not in kinds: kinds.append(kind)
		var record_id:=int(source.get("record_id",0))
		if record_id>0 and record_id not in record_ids: record_ids.append(record_id)
		var name:=str(source.get("record_name",""))
		if not name.is_empty() and name not in names: names.append(name)
	var summary_kind: String=kinds[0] if kinds.size()==1 else "mixed"
	var record_id: int=record_ids[0] if summary_kind=="video" and record_ids.size()==1 else 0
	var name: String="Личный урок" if summary_kind=="live" else "Ранее освоенный способ" if summary_kind=="legacy" else names[0] if summary_kind=="video" and not names.is_empty() else "Освоенный способ"
	return {"id":record_id,"method_id":int(binding_value.method_id),"kind":summary_kind,"name":name,"clone_ids":binding_value.get("roles",[]).map(func(row):return int(row.clone_id)),"roles":binding_value.get("roles",[]).duplicate(true)}

static func apply(service,station,dish: String)->Dictionary:
	var result:=binding(service,station,dish)
	if not bool(result.get("learned",false)):
		if station.state!="cooking" or station.order_dish!=dish: station.recipes.erase(dish)
		station.method_sources.erase(dish)
		return result
	var method_value: Dictionary=service.learning_state.method_ref(int(result.method_id))
	station.recipes[dish]=CookingMethod.runtime_record(method_value)
	station.method_sources[dish]=source_summary(result)
	return result
