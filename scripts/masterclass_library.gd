extends RefCounted
## Shared metadata and persistence helpers for chef master-classes.
const Definition=preload("res://scripts/station_definition.gd")

static func effectiveness(report: Dictionary) -> Dictionary:
	var tricks: Array=report.get("style_tricks",[]).duplicate()
	var count: int=maxi(int(report.get("style_count",0)),tricks.size())
	var label: String="Обычная" if count<=0 else "Эффектная" if count==1 else "Зрелищная" if count==2 else "Шоу"
	var explanation: String="Аккуратное приготовление без отдельного трюка." if tricks.is_empty() else ", ".join(tricks)
	return {"score":count,"label":label,"tricks":tricks,"explanation":explanation}

static func default_name(dish: String, number: int, archived := false, station_id := 0) -> String:
	if archived: return "Архив · %s · стол %d"%[Definition.DISHES.get(dish,dish),station_id]
	return "%s · мастер-класс %d"%[Definition.DISHES.get(dish,dish),number]

static func make_record(id: int, dish: String, type_id: String, tracks: Array, duration: float, quality: Dictionary, name: String, archived := false, source_station := 0) -> Dictionary:
	return {"id":id,"name":name,"dish":dish,"source_type":type_id,"tracks":tracks.duplicate(true),"duration":duration,"quality":quality.duplicate(true),"effectiveness":effectiveness(quality),"archived":archived,"source_station":source_station}

static func summary(record: Dictionary) -> Dictionary:
	var result:=record.duplicate(true)
	result.erase("tracks")
	return result

static func valid(record: Dictionary) -> bool:
	if not record is Dictionary: return false
	if int(record.get("id",0))<=0 or not record.get("name","") is String: return false
	var dish: String=str(record.get("dish",""))
	var type_id: String=str(record.get("source_type",""))
	if type_id not in Definition.TYPES or dish not in Definition.TYPES[type_id].dishes: return false
	if not record.get("tracks",[]) is Array or not record.get("quality",{}) is Dictionary: return false
	var duration=record.get("duration")
	if not (duration is float or duration is int) or float(duration)<0.0: return false
	return true
