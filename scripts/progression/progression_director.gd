extends "res://scripts/progression/progression_director_core.gd"

const STARTER_DISHES := ["sausage", "potato", "wine"]
const STARTER_EQUIPMENT := ["sauce", "plates", "pan", "jug", "cup"]

func restore(data: Variant, authoritative_snapshot := false) -> void:
	if not authoritative_snapshot:
		super(data)
		return
	if not data is Dictionary: return
	var source: Dictionary = data
	cafe_id = str(source.get("cafe_id", ""))
	if cafe_id.is_empty(): cafe_id = _new_cafe_id()
	revision = maxi(0, int(source.get("revision", 0)))
	milestones.clear()
	unlocked_features.clear()
	announced_features.clear()
	var saved_milestones: Variant = source.get("milestones", {})
	if saved_milestones is Dictionary:
		for key in saved_milestones:
			var value: Variant = saved_milestones[key]
			if value is Dictionary: milestones[str(key)] = value.duplicate(true)
			elif bool(value): milestones[str(key)] = {}
	var saved_unlocks: Variant = source.get("unlocked_features", [])
	if saved_unlocks is Array:
		for raw_id in saved_unlocks: unlocked_features[str(raw_id)] = true
	var saved_announced: Variant = source.get("announced_features", [])
	if saved_announced is Array:
		for raw_id in saved_announced: announced_features[str(raw_id)] = true
	_publish_to_progress()

func migrate_from_game_state() -> void:
	super()
	if service == null or service.get("progress") == null: return
	var p = service.progress
	var changed := false
	if bool(p.get("cafe_inaugurated")): changed = _record_milestone("cafe_opened", {}, false) or changed
	var tutorial: Variant = p.get("tutorial_served")
	if tutorial is Array:
		for dish in STARTER_DISHES:
			if dish in tutorial: changed = _record_milestone("first_%s_served" % dish, {"dish":dish}, false) or changed
	if int(p.get("stars")) >= 1: changed = _record_milestone("first_star_earned", {"stars":int(p.get("stars"))}, false) or changed
	var history: Variant = p.get("delivery_history")
	if history is Array and _starter_equipment_was_installed(history): changed = _record_milestone("first_equipment_installed", {}, false) or changed
	if changed:
		revision += 1
		_publish_to_progress()
		progression_changed.emit([])

func _starter_equipment_was_installed(history: Array) -> bool:
	for raw_entry in history:
		if not raw_entry is Dictionary: continue
		var entry: Dictionary = raw_entry
		if int(entry.get("station", 0)) != 1: continue
		var items: Variant = entry.get("items", [entry.get("item", "")])
		if not items is Array: continue
		for raw_item in items:
			if str(raw_item) in STARTER_EQUIPMENT: return true
	return false

func _milestone_for_event(event_id: String, payload: Dictionary) -> String:
	if event_id == "cafe_opened": return "cafe_opened"
	if event_id == "starter_equipment_installed": return "first_equipment_installed"
	if event_id == "starter_dish_served":
		var dish := str(payload.get("dish", ""))
		return "first_%s_served" % dish if dish in STARTER_DISHES else ""
	return super(event_id, payload)

func _event_is_confirmed(event_id: String, payload: Dictionary) -> bool:
	if event_id == "cafe_opened": return service != null and service.get("progress") != null and bool(service.progress.get("cafe_inaugurated"))
	if event_id == "starter_equipment_installed": return int(payload.get("station_id", 0)) == 1 and str(payload.get("item", "")) in STARTER_EQUIPMENT
	if event_id == "starter_dish_served": return int(payload.get("station_id", 0)) == 1 and str(payload.get("dish", "")) in STARTER_DISHES
	return super(event_id, payload)
