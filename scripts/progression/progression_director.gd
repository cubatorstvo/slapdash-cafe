extends "res://scripts/progression/progression_director_core.gd"

const STARTER_DISHES := ["sausage", "potato", "wine"]
const STARTER_EQUIPMENT := ["sauce", "plates", "pan", "jug", "cup"]

func observe(event_id: StringName, payload: Dictionary = {}) -> void:
	super(event_id, payload)
	if event_id not in ["video_training_completed", "group_training_completed"]: return
	if not _event_is_confirmed(str(event_id), payload): return
	var milestone_id := _milestone_for_event(str(event_id), payload)
	var served_id := "first_group_trained_auto_served" if event_id == "group_training_completed" else "first_video_trained_auto_served"
	if has_milestone(served_id) or not milestones.has(milestone_id): return
	var record: Dictionary = milestones[milestone_id]
	if int(record.get("lesson_id", 0)) == int(payload.get("lesson_id", 0)): return
	# Preserve the first fact, but allow a later real lesson to finish its service step.
	var evidence: Array = record.get("confirmed_lessons", [])
	if evidence.any(func(entry): return int(entry.get("lesson_id", 0)) == int(payload.get("lesson_id", 0))): return
	evidence.append(payload.duplicate(true))
	record.confirmed_lessons = evidence
	revision += 1
	_publish_to_progress()

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
	if int(p.get("lab_stage")) >= 3 and int(p.get("lab_formula_version")) > 0 and float(p.get("lab_formula_tempo")) >= 1.0: changed = _record_milestone("standard_formula_available", {"tempo":float(p.get("lab_formula_tempo")),"version":int(p.get("lab_formula_version"))}, false) or changed
	var created_count := maxi(0, int(_object_value(p, "manual_clone_growth_completed", 0)))
	if created_count >= 1: changed = _record_milestone("first_manual_clone_growth_completed", {"count":created_count}, false) or changed
	if created_count >= 2: changed = _record_milestone("repeat_manual_clone_growth_completed", {"count":created_count}, false) or changed
	var history: Variant = p.get("delivery_history")
	if history is Array and _starter_equipment_was_installed(history): changed = _record_milestone("first_equipment_installed", {}, false) or changed
	if _formula_improvement_relevant(): changed = _record_milestone("formula_improvement_relevant", {"tempo":float(p.get("lab_formula_tempo"))}, false) or changed
	if changed:
		revision += 1
		_publish_to_progress()
		progression_changed.emit([])


func _restore_compatibility_unlocks() -> void:
	# Current campaigns open from confirmed facts. Installed items and UI state
	# cannot grant systems; persisted unlocks are already monotonic in reconcile().
	pass

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
	match event_id:
		"cafe_opened": return "cafe_opened"
		"starter_equipment_installed": return "first_equipment_installed"
		"standard_formula_available": return "standard_formula_available"
		"manual_clone_growth_completed": return "first_manual_clone_growth_completed" if int(payload.get("ordinal", 0)) <= 1 else "repeat_manual_clone_growth_completed"
		"video_trained_auto_served": return "first_video_trained_auto_served"
		"group_trained_auto_served": return "first_group_trained_auto_served"
		"pair_kitchen_auto_served": return "first_pair_kitchen_auto_served"
		"specialty_kitchen_auto_served": return "first_specialty_kitchen_auto_served"
		"solyanka_auto_served": return "first_solyanka_auto_served"
		"starter_dish_served":
			var dish := str(payload.get("dish", ""))
			return "first_%s_served" % dish if dish in STARTER_DISHES else ""
	return super(event_id, payload)

func _event_is_confirmed(event_id: String, payload: Dictionary) -> bool:
	if event_id == "recalibration_completed": return int(payload.get("clone_id", 0)) > 0 and float(payload.get("after", 0.0)) > float(payload.get("before", 0.0)) + 0.00001
	if event_id == "cafe_opened": return service != null and service.get("progress") != null and bool(service.progress.get("cafe_inaugurated"))
	if event_id == "starter_equipment_installed": return int(payload.get("station_id", 0)) == 1 and str(payload.get("item", "")) in STARTER_EQUIPMENT
	if event_id == "standard_formula_available": return service != null and service.get("progress") != null and int(service.progress.get("lab_stage")) >= 3 and int(service.progress.get("lab_formula_version")) > 0 and float(service.progress.get("lab_formula_tempo")) >= 1.0
	if event_id == "manual_clone_growth_completed": return int(payload.get("clone_id", 0)) > 0 and int(payload.get("ordinal", 0)) > 0
	if event_id in ["video_trained_auto_served", "group_trained_auto_served", "pair_kitchen_auto_served", "specialty_kitchen_auto_served", "solyanka_auto_served"]: return int(payload.get("station_id", 0)) > 0 and not str(payload.get("dish", "")).is_empty()
	if event_id == "starter_dish_served": return int(payload.get("station_id", 0)) == 1 and str(payload.get("dish", "")) in STARTER_DISHES
	return super(event_id, payload)

func _formula_improvement_relevant() -> bool:
	if service == null or service.get("progress") == null: return false
	var formula := float(service.progress.get("lab_formula_tempo"))
	if formula <= 0.0: return false
	var seen_ids: Dictionary = {}
	var workers: Array = []
	var free: Variant = service.progress.get("free_workers")
	if free is Array: workers.append_array(free)
	var station_list: Variant = service.get("stations")
	if station_list is Array:
		for station in station_list:
			if station == null: continue
			var crew: Variant = station.get("crew")
			if crew is Array: workers.append_array(crew)
	for worker in workers:
		if not worker is Dictionary: continue
		var clone_id := int(worker.get("clone_id", worker.get("id", 0)))
		if clone_id <= 0 or seen_ids.has(clone_id): continue
		seen_ids[clone_id] = true
		if float(worker.get("tempo", 1.0)) < formula: return true
	return false
