extends "res://scripts/progression/feature_catalog_legacy.gd"
## Stage 5.1 narrows the first-game unlock gates; stage 5.2 continues the 1★ clone route.
## Stage 5.3 makes the 2★+ systems depend on completed domain actions rather than UI intent.
## Stage 5.5 binds laboratory and lounge goods to the accepted catalogue groups.
const CatalogBindings = preload("res://scripts/progression/catalog_bindings.gd")

static func definition(feature_id: String) -> Dictionary:
	var normalized := normalize_feature_id(feature_id)
	var result: Dictionary = super.definition(normalized).duplicate(true)
	if result.is_empty() and CatalogBindings.feature_patch(normalized).is_empty(): return result
	match normalized:
		"dish_sausage":
			result.requires_milestones = []
		"dish_potato":
			result.requires_milestones = ["first_sausage_served"]
		"dish_wine":
			result.requires_milestones = ["first_potato_served"]
		"video_recording":
			result.min_stars = 2
			result.requires_milestones = ["first_live_lesson_accepted", "first_auto_served"]
		"group_training":
			result.min_stars = 2
			result.requires_milestones = ["first_video_training_completed", "first_video_trained_auto_served", "two_compatible_stations_seen"]
		"formula_research":
			result.min_stars = 2
			result.requires_milestones = ["first_group_training_completed"]
		"kitchen_pair":
			result.min_stars = 2
			result.requires_milestones = ["first_group_training_completed", "first_group_trained_auto_served"]
		"kitchen_specialty":
			result.min_stars = 3
			result.requires_milestones = ["first_pair_kitchen_auto_served"]
		"kitchen_orchestration":
			result.min_stars = 4
			result.requires_milestones = ["first_specialty_kitchen_auto_served"]
	var patch := CatalogBindings.feature_patch(normalized)
	if not patch.is_empty():
		if result.is_empty(): result = patch
		else:
			for key in patch: result[key] = patch[key]
	return result

static func ordered_ids() -> Array[String]:
	var ids: Array[String] = super.ordered_ids()
	var seen := {}
	for feature_id in ids: seen[feature_id] = true
	for feature_id in CatalogBindings.extra_feature_ids():
		if not seen.has(feature_id):
			ids.append(feature_id)
			seen[feature_id] = true
	ids.sort_custom(func(a: String, b: String) -> bool:
		var oa := int(definition(a).get("sort_order", 0))
		var ob := int(definition(b).get("sort_order", 0))
		return a < b if oa == ob else oa < ob)
	return ids

static func item_features(item_id: String, spec: Dictionary = {}) -> Array[String]:
	var row := CatalogBindings.item(item_id)
	if not row.is_empty():
		var features: Array[String] = [str(row.feature)]
		return features
	return super.item_features(item_id, spec)

static func validate() -> Array[String]:
	var errors: Array[String] = []
	var visiting := {}
	var visited := {}
	for feature_id in ordered_ids():
		var value := definition(feature_id)
		if str(value.get("id", "")) != feature_id: errors.append("Feature id mismatch: " + feature_id)
		if str(value.get("unlock_rule_id", "")) != "always": errors.append("Unknown unlock rule: " + feature_id)
		_validate_effective_cycle(feature_id, visiting, visited, errors)
	return errors

static func _validate_effective_cycle(id: String, visiting: Dictionary, visited: Dictionary, errors: Array[String]) -> void:
	if visited.has(id): return
	if visiting.has(id):
		errors.append("Feature dependency cycle: " + id)
		return
	visiting[id] = true
	for dependency in definition(id).get("requires_features", []):
		if definition(str(dependency)).is_empty(): errors.append("Unknown dependency: %s -> %s" % [id, dependency])
		else: _validate_effective_cycle(str(dependency), visiting, visited, errors)
	visiting.erase(id)
	visited[id] = true
