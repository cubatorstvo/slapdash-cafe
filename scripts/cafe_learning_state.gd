extends RefCounted
const CookingMethod=preload("res://scripts/cooking_method.gd")
const Definition=preload("res://scripts/station_definition.gd")
var next_method_id:=1
var next_live_session_id:=1
var revision:=0
var methods: Dictionary={}
var clone_skills: Dictionary={}
var committed_acquisitions: Dictionary={}

func reset()->void:
	next_method_id=1; next_live_session_id=1; revision=0; methods.clear(); clone_skills.clear(); committed_acquisitions.clear()

func register_method(dish: String,type_id: String,tracks: Array,quality: Dictionary,required_equipment: Array=[],scene_config: Dictionary={}) -> int:
	var id:=next_method_id
	var method:=CookingMethod.make(id,dish,type_id,tracks,quality,required_equipment,scene_config)
	if not CookingMethod.valid(method): return 0
	methods[str(id)]=method.duplicate(true)
	next_method_id+=1; revision+=1
	return id

func method(method_id: int) -> Dictionary:
	var value: Variant=methods.get(str(method_id),{})
	return value.duplicate(true) if value is Dictionary else {}

func method_ref(method_id: int) -> Dictionary:
	var value: Variant=methods.get(str(method_id),{})
	return value if value is Dictionary else {}

func method_summary(method_id: int)->Dictionary:
	return CookingMethod.summary(method_ref(method_id))

func skill_key(type_id: String,dish: String,role_id: String)->String:
	return "%s/%s/%s"%[type_id,dish,role_id]

func clone_skill(clone_id: int,type_id: String,dish: String,role_id: String)->Dictionary:
	if clone_id<=0: return {}
	var owner: Variant=clone_skills.get(str(clone_id),{})
	if not owner is Dictionary: return {}
	var skills: Variant=owner.get("skills",{})
	if not skills is Dictionary: return {}
	var value: Variant=skills.get(skill_key(type_id,dish,role_id),{})
	return value.duplicate(true) if value is Dictionary else {}

func grant_skill(clone_id: int,type_id: String,dish: String,role_id: String,method_id: int,source: Dictionary,acquisition_id: String,learned_day: int)->Dictionary:
	if clone_id<=0 or acquisition_id.is_empty(): return {"ok":false,"reason":"clone_missing"}
	var method_value:=method_ref(method_id)
	if not CookingMethod.valid(method_value) or str(method_value.source_type)!=type_id or str(method_value.dish)!=dish or role_id not in method_value.role_ids: return {"ok":false,"reason":"method_invalid"}
	if committed_acquisitions.has(acquisition_id): return committed_acquisitions[acquisition_id].duplicate(true)
	var owner: Dictionary=clone_skills.get(str(clone_id),{"clone_id":clone_id,"revision":0,"skills":{}})
	if not owner.get("skills",{}) is Dictionary: owner.skills={}
	owner.skills[skill_key(type_id,dish,role_id)]={"method_id":method_id,"role_id":role_id,"source":source.duplicate(true),"acquisition_id":acquisition_id,"learned_day":learned_day}
	owner.revision=int(owner.get("revision",0))+1
	clone_skills[str(clone_id)]=owner
	var result: Dictionary={"ok":true,"method_id":method_id,"learned_clone_ids":[clone_id],"acquisition_id":acquisition_id}
	committed_acquisitions[acquisition_id]=result.duplicate(true)
	revision+=1
	return result

func grant_method_to_role(clone_id: int,role_index: int,method_id: int,source: Dictionary,acquisition_id: String,learned_day: int)->Dictionary:
	var method_value:=method_ref(method_id)
	if not CookingMethod.valid(method_value) or role_index<0 or role_index>=method_value.role_ids.size(): return {"ok":false,"reason":"method_invalid"}
	return grant_skill(clone_id,str(method_value.source_type),str(method_value.dish),str(method_value.role_ids[role_index]),method_id,source,acquisition_id,learned_day)

func snapshot()->Dictionary:
	return {"schema_version":1,"revision":revision,"next_method_id":next_method_id,"next_live_session_id":next_live_session_id,"methods":methods.duplicate(true),"clone_skills":clone_skills.duplicate(true),"committed_acquisitions":committed_acquisitions.duplicate(true)}

func restore(data: Variant)->bool:
	if not data is Dictionary or int(data.get("schema_version",0))!=1: return false
	var source: Dictionary=data
	if not source.get("methods",{}) is Dictionary or not source.get("clone_skills",{}) is Dictionary or not source.get("committed_acquisitions",{}) is Dictionary: return false
	for raw in source.methods.values():
		if not CookingMethod.valid(raw): return false
	methods=source.methods.duplicate(true)
	clone_skills=source.clone_skills.duplicate(true)
	committed_acquisitions=source.committed_acquisitions.duplicate(true)
	next_method_id=maxi(1,int(source.get("next_method_id",1)))
	next_live_session_id=maxi(1,int(source.get("next_live_session_id",1)))
	revision=maxi(0,int(source.get("revision",0)))
	for key in methods: next_method_id=maxi(next_method_id,int(key)+1)
	return true
