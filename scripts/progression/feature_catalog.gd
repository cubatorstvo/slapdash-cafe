extends "res://scripts/progression/feature_catalog_legacy.gd"
## Stage 5.1 keeps the shared catalog and narrows only the first-game unlock gates.

static func definition(feature_id: String) -> Dictionary:
	var normalized := normalize_feature_id(feature_id)
	var result: Dictionary = super.definition(normalized).duplicate(true)
	if result.is_empty(): return result
	match normalized:
		"dish_sausage":
			result.requires_milestones = []
		"dish_potato":
			result.requires_milestones = ["first_sausage_served"]
		"dish_wine":
			result.requires_milestones = ["first_potato_served"]
		"clone_lab":
			result.min_stars = 1
			result.requires_milestones = ["first_star_earned"]
	return result
