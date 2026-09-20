extends RefCounted
## Shared metadata and persistence helpers for chef master-classes.
const Definition=preload("res://scripts/station_definition.gd")
const Highlights=preload("res://scripts/masterclass_highlights.gd")

static func effectiveness(report: Dictionary) -> Dictionary:
	var tricks: Array=report.get("style_tricks",[]).duplicate()
	var count: int=maxi(int(report.get("style_count",0)),tricks.size())
	var label: String="Обычная" if count<=0 else "Эффектная" if count==1 else "Зрелищная" if count==2 else "Шоу"
	var explanation: String="Аккуратное приготовление без отдельного трюка." if tricks.is_empty() else ", ".join(tricks)
	return {"score":count,"label":label,"tricks":tricks,"explanation":explanation}

static func default_name(dish: String, number: int, archived := false, station_id := 0) -> String:
	if archived: return "Архив · %s · стол %d"%[Definition.DISHES.get(dish,dish),station_id]
	return "%s · мастер-класс %d"%[Definition.DISHES.get(dish,dish),number]

static func make_record(id: int,dish: String,type_id: String,tracks: Array,duration: float,quality: Dictionary,name: String,archived := false,source_station := 0,scene_config: Dictionary={}) -> Dictionary:
	var stored_tracks: Array=tracks.duplicate(true)
	var events: Array=Highlights.extract_events(stored_tracks)
	var stored_scene: Dictionary=scene_config.duplicate(true)
	var required: Array=stored_scene.get("required_equipment",stored_scene.get("equipment",Definition.DISH_EQUIPMENT.get(dish,[]))).duplicate()
	stored_scene.required_equipment=required.duplicate()
	return {"id":id,"name":name,"dish":dish,"source_type":type_id,"tracks":stored_tracks,"duration":duration,"quality":quality.duplicate(true),"effectiveness":effectiveness(quality),"archived":archived,"source_station":source_station,"scene_config":stored_scene,"required_equipment":required,"highlight_plan_version":Highlights.PLAN_VERSION,"highlight_events":events,"highlight_segments":Highlights.build(stored_tracks,events),"highlight_duration":Highlights.duration(stored_tracks)}

static func ensure_highlights(record: Dictionary) -> void:
	if record.get("tracks",[]) is Array:
		var needs_rebuild: bool=int(record.get("highlight_plan_version",0))!=Highlights.PLAN_VERSION or not record.get("highlight_events",[]) is Array or not record.get("highlight_segments",[]) is Array
		if needs_rebuild:
			var events: Array=Highlights.extract_events(record.tracks)
			record.highlight_plan_version=Highlights.PLAN_VERSION
			record.highlight_events=events
			record.highlight_segments=Highlights.build(record.tracks,events)
		record.highlight_duration=Highlights.duration(record.tracks)
	if not record.has("scene_config") or not record.scene_config is Dictionary: record.scene_config={}
	if not record.has("effectiveness"): record.effectiveness=effectiveness(record.get("quality",{}))

static func required_equipment(record: Dictionary) -> Array:
	if record.get("required_equipment",null) is Array: return record.required_equipment.duplicate()
	var scene: Variant=record.get("scene_config",{})
	if scene is Dictionary:
		if scene.get("required_equipment",null) is Array: return scene.required_equipment.duplicate()
		if scene.get("equipment",null) is Array: return scene.equipment.duplicate()
	return Definition.DISH_EQUIPMENT.get(str(record.get("dish","")),[]).duplicate()

static func summary(record: Dictionary) -> Dictionary:
	var result:=record.duplicate(true)
	result.required_equipment=required_equipment(record)
	result.erase("tracks")
	result.erase("highlight_events")
	return result

static func movie_payload(record: Dictionary) -> Dictionary:
	var payload:=record.duplicate(true)
	var segments: Array=record.get("highlight_segments",[])
	var compact_tracks: Array=[]
	for source_track in record.get("tracks",[]):
		var compact: Dictionary={"group":source_track.get("group",-1),"frames":[]}
		var frames: Array=source_track.get("frames",[])
		for segment in segments:
			for tick in range(int(segment.source_start),int(segment.source_end)):
				if not frames.is_empty(): compact.frames.append(frames[mini(tick,frames.size()-1)])
		compact_tracks.append(compact)
	payload.tracks=compact_tracks
	var compact_segments: Array=[]
	for segment in segments:
		var copy: Dictionary=segment.duplicate(true)
		copy.source_start=int(copy.film_start)
		copy.source_end=int(copy.film_end)
		compact_segments.append(copy)
	payload.highlight_segments=compact_segments
	return payload

static func valid(record: Dictionary) -> bool:
	if not record is Dictionary: return false
	if int(record.get("id",0))<=0 or not record.get("name","") is String: return false
	var dish: String=str(record.get("dish",""))
	var type_id: String=str(record.get("source_type",""))
	if type_id not in Definition.TYPES or dish not in Definition.TYPES[type_id].dishes: return false
	if not record.get("tracks",[]) is Array or not record.get("quality",{}) is Dictionary: return false
	if record.has("highlight_segments") and not record.highlight_segments is Array: return false
	if record.has("highlight_events") and not record.highlight_events is Array: return false
	if record.has("scene_config") and not record.scene_config is Dictionary: return false
	var required: Array=required_equipment(record)
	for item in required:
		if not item is String or not Definition.equipment_allowed(type_id,str(item)): return false
	var duration=record.get("duration")
	if not (duration is float or duration is int) or float(duration)<0.0: return false
	return true
