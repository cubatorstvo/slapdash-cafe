extends RefCounted
const Definition=preload("res://scripts/station_definition.gd")
const Library=preload("res://scripts/masterclass_library.gd")

static func make(method_id: int,dish: String,type_id: String,tracks: Array,quality: Dictionary,required_equipment: Array=[],scene_config: Dictionary={}) -> Dictionary:
	var stored_tracks: Array=tracks.duplicate(true)
	var roles: Array=Definition.role_ids(type_id)
	var required: Array=[]
	var source_required: Array=required_equipment if not required_equipment.is_empty() else Definition.DISH_EQUIPMENT.get(dish,[])
	for raw in source_required:
		var item:=str(raw)
		if Definition.equipment_allowed(type_id,item) and item not in required: required.append(item)
	var duration_ticks:=0
	for track in stored_tracks:
		if track is Dictionary: duration_ticks=maxi(duration_ticks,track.get("frames",[]).size())
	return {"method_id":method_id,"schema_version":1,"source_type":type_id,"dish":dish,"role_ids":roles,"tick_rate":60,"duration_ticks":duration_ticks,"tracks":stored_tracks,"quality":quality.duplicate(true),"effectiveness":Library.effectiveness(quality),"required_equipment":required,"scene_config":scene_config.duplicate(true)}

static func valid(method: Variant) -> bool:
	if not method is Dictionary: return false
	var type_id:=str(method.get("source_type",""))
	var dish:=str(method.get("dish",""))
	if int(method.get("method_id",0))<=0 or int(method.get("schema_version",0))!=1: return false
	if type_id not in Definition.TYPES or dish not in Definition.TYPES[type_id].dishes: return false
	var roles: Variant=method.get("role_ids",[])
	var tracks: Variant=method.get("tracks",[])
	if not roles is Array or roles!=Definition.role_ids(type_id): return false
	if not tracks is Array or tracks.size()!=roles.size(): return false
	for track in tracks:
		if not track is Dictionary or track.is_empty() or not track.get("frames",[]) is Array or track.frames.is_empty(): return false
	if not method.get("quality",{}) is Dictionary: return false
	if int(method.get("duration_ticks",0))<=0: return false
	for item in method.get("required_equipment",[]):
		if not item is String or not Definition.equipment_allowed(type_id,str(item)): return false
	return true

static func runtime_record(method: Dictionary) -> Dictionary:
	if not valid(method): return {}
	return {"method_id":int(method.method_id),"tracks":method.tracks,"duration":float(method.duration_ticks)/float(method.get("tick_rate",60)),"quality":method.quality,"required_equipment":method.get("required_equipment",[])}

static func summary(method: Dictionary) -> Dictionary:
	if not valid(method): return {}
	return {"method_id":int(method.method_id),"source_type":str(method.source_type),"dish":str(method.dish),"role_ids":method.role_ids.duplicate(),"duration":float(method.duration_ticks)/float(method.get("tick_rate",60)),"quality":method.quality.duplicate(true),"effectiveness":method.get("effectiveness",{}).duplicate(true),"required_equipment":method.get("required_equipment",[]).duplicate()}
