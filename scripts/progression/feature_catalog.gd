extends "res://scripts/progression/feature_catalog_legacy.gd"
## Stage 5.1 narrows the first-game unlock gates; stage 5.2 continues the 1★ clone route.
## Stage 5.3 makes the 2★+ systems depend on completed domain actions rather than UI intent.

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
		"video_recording":
			result.min_stars = 2
			result.requires_milestones = ["first_live_lesson_accepted", "first_auto_served"]
		"video_training":
			result.min_stars = 2
			result.requires_milestones = ["first_masterclass_saved"]
		"group_training":
			result.min_stars = 2
			result.requires_milestones = ["first_video_training_completed", "first_video_trained_auto_served", "two_compatible_stations_seen"]
		"formula_research":
			result.min_stars = 2
			result.requires_milestones = ["first_group_training_completed"]
		"formula_upgrades":
			result.min_stars = 2
			result.requires_milestones = ["first_group_training_completed"]
		"recalibration":
			result.min_stars = 2
			result.requires_milestones = ["formula_improvement_relevant"]
		"kitchen_pair":
			result.min_stars = 2
			result.requires_milestones = ["first_group_training_completed", "first_group_trained_auto_served"]
		"kitchen_specialty":
			result.min_stars = 3
			result.requires_milestones = ["first_pair_kitchen_auto_served"]
		"kitchen_orchestration":
			result.min_stars = 4
			result.requires_milestones = ["first_specialty_kitchen_auto_served"]
	return result
