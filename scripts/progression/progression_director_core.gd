extends RefCounted

signal progression_changed(changed_feature_ids: Array)

const FeatureCatalog = preload("res://scripts/progression/feature_catalog.gd")
const SCHEMA_VERSION := 1

var service: Node
var cafe_id := ""
var revision := 0
var milestones: Dictionary = {}
var unlocked_features: Dictionary = {}
var announced_features: Dictionary = {}

func setup(owner_service: Node) -> void:
	service = owner_service
	if cafe_id.is_empty(): cafe_id = _new_cafe_id()
	if not FeatureCatalog.validate().is_empty(): push_error("Feature catalog invalid: %s" % "; ".join(FeatureCatalog.validate()))
	migrate_from_game_state()
	reconcile()

func reset_new_cafe() -> void:
	cafe_id = _new_cafe_id(); revision = 0; milestones.clear(); unlocked_features.clear(); announced_features.clear(); reconcile()

func observe(event_id: StringName, payload: Dictionary = {}) -> void:
	var milestone_id := _milestone_for_event(str(event_id), payload)
	if milestone_id.is_empty() or not _event_is_confirmed(str(event_id), payload): return
	var before_revision := revision
	var recorded := _record_milestone(milestone_id, payload, false)
	reconcile()
	if recorded and revision == before_revision:
		revision += 1
		_publish_to_progress()
		progression_changed.emit([])

func has_milestone(milestone_id: String) -> bool: return milestones.has(milestone_id)
func is_unlocked(feature_id: String) -> bool: return bool(unlocked_features.get(FeatureCatalog.normalize_feature_id(feature_id), false))

func reconcile() -> void:
	var changed: Array = []
	var any_changed := true
	while any_changed:
		any_changed = false
		for feature_id in FeatureCatalog.ordered_ids():
			if is_unlocked(feature_id): continue
			var definition := FeatureCatalog.definition(feature_id)
			if _definition_ready(definition):
				unlocked_features[feature_id] = true
				changed.append(feature_id)
				any_changed = true
	if not changed.is_empty():
		revision += 1
		_publish_to_progress()
		progression_changed.emit(changed)
	else: _publish_to_progress()

func restore_from_progress() -> void:
	if service == null or service.get("progress") == null: return
	var stored: Variant = service.progress.get("feature_progress")
	if stored is Dictionary: restore(stored)
	else:
		migrate_from_game_state()
		reconcile()

func migrate_from_game_state() -> void:
	if service == null or service.get("progress") == null: return
	var previous_milestones := milestones.size()
	var previous_unlocks := unlocked_features.duplicate(true)
	var p = service.progress
	if int(p.get("manual_served")) > 0: _record_milestone("first_manual_served", {}, false)
	var tutorial: Variant = p.get("tutorial_served")
	if tutorial is Array and ["sausage", "potato", "wine"].all(func(dish): return dish in tutorial): _record_milestone("basic_dishes_served", {}, false)
	if int(p.get("lab_stage")) >= 3: _record_milestone("lab_assembled", {}, false)
	if int(p.get("lab_formula_version")) > 0: _record_milestone("first_formula_obtained", {}, false)
	if int(p.get("next_clone_id")) > 1 or not _workers().is_empty(): _record_milestone("first_clone_created", {}, false)
	if _has_production_station(): _record_milestone("first_production_station_installed", {}, false)
	if service.get("masterclasses") is Array and not service.masterclasses.is_empty(): _record_milestone("first_masterclass_saved", {}, false)
	if _has_video_training_source(): _record_milestone("first_video_training_completed", {}, false)
	if _two_compatible_stations(): _record_milestone("two_compatible_stations_seen", {}, false)
	if _has_active_group(): _grant_compatibility_unlock("group_training")
	if _television_installed(): _record_milestone("television_installed", {}, false)
	if int(p.get("journey_auto_served")) > 0 or int(p.get("third_star_auto_served")) > 0 or int(p.get("fourth_star_auto_served")) > 0 or int(p.get("fifth_star_auto_served")) > 0: _record_milestone("first_auto_served", {}, false)
	if not _object_value(p, "rest_report", {}).is_empty() and int(_object_value(p, "rest_report", {}).get("workers", 0)) > 0: _record_milestone("first_staff_rest_completed", {}, false)
	if _formula_improvement_relevant(): _record_milestone("formula_improvement_relevant", {}, false)
	if int(_object_value(p, "lab_calibration", {}).get("revision", 0)) > 0: _record_milestone("first_recalibration_completed", {}, false)
	var deliveries: Variant = p.get("deliveries")
	var history: Variant = p.get("delivery_history")
	if (deliveries is Array and not deliveries.is_empty()) or (history is Array and not history.is_empty()): _record_milestone("first_delivery_ordered", {}, false)
	if history is Array and not history.is_empty(): _record_milestone("first_delivery_installed", {}, false)
	_restore_compatibility_unlocks()
	var changed_features: Array = []
	for feature_id in unlocked_features:
		if bool(unlocked_features[feature_id]) and not bool(previous_unlocks.get(feature_id, false)): changed_features.append(str(feature_id))
	if milestones.size() != previous_milestones or not changed_features.is_empty():
		revision += 1
		_publish_to_progress()
		progression_changed.emit(changed_features)

func snapshot() -> Dictionary:
	return {"schema_version":SCHEMA_VERSION,"cafe_id":cafe_id,"revision":revision,"milestones":milestones.duplicate(true),"unlocked_features":_true_keys(unlocked_features),"announced_features":_true_keys(announced_features)}

func restore(data: Variant) -> void:
	if not data is Dictionary:
		migrate_from_game_state(); reconcile(); return
	var source: Dictionary = data
	cafe_id = str(source.get("cafe_id", ""))
	if cafe_id.is_empty(): cafe_id = _new_cafe_id()
	revision = maxi(0, int(source.get("revision", 0)))
	milestones.clear(); unlocked_features.clear(); announced_features.clear()
	var saved_milestones: Variant = source.get("milestones", {})
	if saved_milestones is Dictionary:
		for key in saved_milestones:
			var value: Variant = saved_milestones[key]
			if value is Dictionary: milestones[str(key)] = value.duplicate(true)
			elif bool(value): milestones[str(key)] = {}
	for raw_id in source.get("unlocked_features", []): unlocked_features[str(raw_id)] = true
	for raw_id in source.get("announced_features", []): announced_features[str(raw_id)] = true
	migrate_from_game_state()
	reconcile()

func mark_announced(feature_id: String) -> void:
	var normalized := FeatureCatalog.normalize_feature_id(feature_id)
	if not is_unlocked(normalized) or bool(announced_features.get(normalized, false)): return
	announced_features[normalized] = true
	_publish_to_progress()

func _definition_ready(definition: Dictionary) -> bool:
	if definition.is_empty() or _stars() < int(definition.get("min_stars", 0)): return false
	for dependency in definition.get("requires_features", []):
		if not is_unlocked(str(dependency)): return false
	for milestone_id in definition.get("requires_milestones", []):
		if not has_milestone(str(milestone_id)): return false
	return str(definition.get("unlock_rule_id", "always")) == "always"

func _record_milestone(milestone_id: String, payload: Dictionary = {}, bump_revision := true) -> bool:
	if milestone_id.is_empty() or milestones.has(milestone_id): return false
	var record := {}
	if service != null and service.get("progress") != null: record.day = int(service.progress.get("day"))
	for key in payload:
		if key not in ["allowed", "unlocked", "host", "surface"]: record[key] = payload[key]
	milestones[milestone_id] = record
	if bump_revision:
		revision += 1
		_publish_to_progress()
	return true

func _milestone_for_event(event_id: String, _payload: Dictionary) -> String:
	return {"manual_served":"first_manual_served","delivery_ordered":"first_delivery_ordered","delivery_installed":"first_delivery_installed","basic_dishes_served":"basic_dishes_served","lab_assembled":"lab_assembled","formula_obtained":"first_formula_obtained","clone_created":"first_clone_created","production_station_installed":"first_production_station_installed","live_lesson_accepted":"first_live_lesson_accepted","auto_served":"first_auto_served","masterclass_saved":"first_masterclass_saved","television_installed":"television_installed","video_training_completed":"first_video_training_completed","group_training_completed":"first_group_training_completed","two_compatible_stations_seen":"two_compatible_stations_seen","staff_rest_completed":"first_staff_rest_completed","formula_improvement_relevant":"formula_improvement_relevant","recalibration_completed":"first_recalibration_completed"}.get(event_id, "")

func _event_is_confirmed(event_id: String, payload: Dictionary) -> bool:
	match event_id:
		"clone_created": return int(payload.get("clone_id", 0)) > 0 or int(service.progress.get("next_clone_id")) > 1
		"group_training_completed": return int(payload.get("station_count", 0)) >= 2
		"video_training_completed": return int(payload.get("station_count", 1)) >= 1
		_: return true

func _stars() -> int: return int(service.progress.get("stars")) if service != null and service.get("progress") != null else 0

func _workers() -> Array:
	if service == null or service.get("progress") == null: return []
	var workers: Variant = service.progress.get("free_workers")
	return workers if workers is Array else []

func _stations() -> Array:
	if service == null: return []
	var value: Variant = service.get("stations")
	return value if value is Array else []

func _has_production_station() -> bool:
	for station in _stations():
		if station != null and not bool(station.get("manual_station")) and not bool(station.get("masterclass_station")): return true
	return false

func _two_compatible_stations() -> bool:
	var counts := {}
	for station in _stations():
		if station == null or bool(station.get("manual_station")) or bool(station.get("masterclass_station")): continue
		var type_id := str(station.get("type_id")); counts[type_id] = int(counts.get(type_id, 0)) + 1
		if int(counts[type_id]) >= 2: return true
	return false

func _has_video_training_source() -> bool:
	for station in _stations():
		if station == null: continue
		var sources: Variant = station.get("method_sources")
		if sources is Dictionary:
			for source in sources.values():
				if source is Dictionary and int(source.get("id", source.get("record_id", 0))) > 0: return true
	return false

func _has_active_group() -> bool:
	if service == null or service.get("group_registry") == null: return false
	var registry = service.group_registry
	return registry.has_method("all") and not registry.all().is_empty()

func _television_installed() -> bool:
	if service == null or service.get("progress") == null: return false
	return "television" in _object_value(service.progress, "lounge_items", [])

func _formula_improvement_relevant() -> bool:
	if service == null or service.get("progress") == null: return false
	var formula := float(service.progress.get("lab_formula_tempo"))
	for worker in _workers():
		if worker is Dictionary and float(worker.get("tempo", 1.0)) < formula: return true
	return false

func _restore_compatibility_unlocks() -> void:
	if service == null or service.get("progress") == null: return
	var p = service.progress
	if int(p.get("lab_stage")) >= 1: _grant_compatibility_unlock("clone_lab")
	if int(p.get("lab_formula_version")) > 0 and int(p.get("stars")) >= 2: _grant_compatibility_unlock("formula_research")
	if int(p.get("next_clone_id")) > 1 or not _workers().is_empty():
		_grant_compatibility_unlock("clone_growth"); _grant_compatibility_unlock("staff_roster"); _grant_compatibility_unlock("production_tables")
	if service.get("masterclasses") is Array and not service.masterclasses.is_empty(): _grant_compatibility_unlock("video_recording")
	if _has_video_training_source() or _television_installed(): _grant_compatibility_unlock("video_training")
	for upgrade_id in _object_value(p, "lab_upgrades", []):
		var id := str(upgrade_id)
		if id in ["lab_power","lab_power_2","lab_power_3","lab_valve","lab_damper"]: _grant_compatibility_unlock("formula_upgrades")
		if id in ["lab_chair","lab_cal_focus","lab_cal_slow","lab_cal_auto","lab_cal_speed"]: _grant_compatibility_unlock("recalibration")
		if id in ["lab_feeder","lab_irrigation","lab_lamps","lab_nutrients","lab_rack","lab_rack_2","lab_planter","lab_extractor","lab_production","lab_climate"]: _grant_compatibility_unlock("lab_growth_upgrades")
		if id in ["lab_planter","lab_extractor","lab_production","lab_climate","lab_cal_auto","lab_cal_speed"]: _grant_compatibility_unlock("lab_automation")
	if int(p.get("lounge_tier")) > 0 or _object_value(p, "lounge_items", []).size() > 1 or not _object_value(p, "lounge_upgrades", []).is_empty(): _grant_compatibility_unlock("rest_basics")
	if int(p.get("lounge_tier")) >= 1: _grant_compatibility_unlock("rest_extended")
	if int(p.get("lounge_tier")) >= 2: _grant_compatibility_unlock("rest_large")
	if bool(p.get("expanded")): _grant_compatibility_unlock("kitchen_pair")
	if bool(p.get("specialized_expanded")): _grant_compatibility_unlock("kitchen_specialty")
	if bool(p.get("orchestration_expanded")): _grant_compatibility_unlock("kitchen_orchestration")

func _grant_compatibility_unlock(feature_id: String) -> void:
	var normalized := FeatureCatalog.normalize_feature_id(feature_id)
	if FeatureCatalog.definition(normalized).is_empty(): return
	unlocked_features[normalized] = true

func _true_keys(source: Dictionary) -> Array:
	var result: Array = []
	for key in source:
		if bool(source[key]): result.append(str(key))
	result.sort()
	return result

func _new_cafe_id() -> String: return Crypto.new().generate_random_bytes(16).hex_encode()

func _object_value(object: Object, property: StringName, fallback: Variant) -> Variant:
	var value: Variant = object.get(property)
	return fallback if value == null else value

func _publish_to_progress() -> void:
	if service == null or service.get("progress") == null: return
	for property in service.progress.get_property_list():
		if str(property.get("name", "")) == "feature_progress":
			service.progress.set("feature_progress", snapshot())
			return
