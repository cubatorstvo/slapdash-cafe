extends "res://scripts/progression/feature_catalog_legacy.gd"
## Stage 5.1 narrows the first-game unlock gates; stage 5.2 continues the 1★ clone route.

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
		"rest_basics":
			result.min_stars = 1
			result.requires_milestones = ["first_clone_created"]
	return result
