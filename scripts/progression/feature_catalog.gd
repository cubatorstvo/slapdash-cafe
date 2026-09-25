extends RefCounted

const DEFINITIONS := {
	"cafe_core":{"id":"cafe_core","title_key":"Кафе","min_stars":0,"requires_features":[],"requires_milestones":[],"unlock_rule_id":"always","sort_order":10,"announce":false},
	"shop_basic":{"id":"shop_basic","title_key":"Магазин","min_stars":0,"requires_features":[],"requires_milestones":[],"unlock_rule_id":"always","sort_order":20,"announce":false},
	"stars":{"id":"stars","title_key":"Развитие","min_stars":0,"requires_features":[],"requires_milestones":[],"unlock_rule_id":"always","sort_order":30,"announce":false},
	"dish_potato":{"id":"dish_potato","title_key":"Картошка","min_stars":0,"requires_features":[],"requires_milestones":[],"unlock_rule_id":"always","sort_order":40,"announce":false},
	"dish_sausage":{"id":"dish_sausage","title_key":"Сосиска","min_stars":0,"requires_features":[],"requires_milestones":[],"unlock_rule_id":"always","sort_order":50,"announce":false},
	"dish_wine":{"id":"dish_wine","title_key":"Вино","min_stars":0,"requires_features":[],"requires_milestones":[],"unlock_rule_id":"always","sort_order":60,"announce":false},
	"cafe_statistics":{"id":"cafe_statistics","title_key":"Статистика","min_stars":0,"requires_features":["cafe_core"],"requires_milestones":["first_manual_served"],"unlock_rule_id":"always","sort_order":70,"announce":false},
	"clone_lab":{"id":"clone_lab","title_key":"Лаборатория","min_stars":0,"requires_features":["shop_basic"],"requires_milestones":["basic_dishes_served"],"unlock_rule_id":"always","sort_order":80,"announce":true},
	"formula_research":{"id":"formula_research","title_key":"Исследование формулы","min_stars":0,"requires_features":["clone_lab"],"requires_milestones":["lab_assembled"],"unlock_rule_id":"always","sort_order":90,"announce":true},
	"clone_growth":{"id":"clone_growth","title_key":"Выращивание клонов","min_stars":1,"requires_features":["formula_research"],"requires_milestones":["first_formula_obtained"],"unlock_rule_id":"always","sort_order":100,"announce":true},
	"staff_roster":{"id":"staff_roster","title_key":"Сотрудники","min_stars":1,"requires_features":["clone_growth"],"requires_milestones":["first_clone_created"],"unlock_rule_id":"always","sort_order":110,"announce":true},
	"production_tables":{"id":"production_tables","title_key":"Производственные столы","min_stars":1,"requires_features":["clone_growth"],"requires_milestones":["first_clone_created"],"unlock_rule_id":"always","sort_order":120,"announce":true},
	"video_recording":{"id":"video_recording","title_key":"Запись мастер-классов","min_stars":1,"requires_features":["staff_roster"],"requires_milestones":["first_clone_created"],"unlock_rule_id":"always","sort_order":130,"announce":true},
	"video_training":{"id":"video_training","title_key":"Видеообучение","min_stars":1,"requires_features":["video_recording"],"requires_milestones":["first_masterclass_saved"],"unlock_rule_id":"always","sort_order":140,"announce":true},
	"group_training":{"id":"group_training","title_key":"Групповое обучение","min_stars":1,"requires_features":["video_training"],"requires_milestones":["first_video_training_completed","two_compatible_stations_seen"],"unlock_rule_id":"always","sort_order":150,"announce":true},
	"rest_basics":{"id":"rest_basics","title_key":"Отдых","min_stars":1,"requires_features":["staff_roster"],"requires_milestones":["first_auto_served"],"unlock_rule_id":"always","sort_order":160,"announce":true},
	"decor_basic":{"id":"decor_basic","title_key":"Декор","min_stars":1,"requires_features":["stars"],"requires_milestones":["first_auto_served"],"unlock_rule_id":"always","sort_order":170,"announce":false},
	"formula_upgrades":{"id":"formula_upgrades","title_key":"Улучшения формулы","min_stars":1,"requires_features":["formula_research"],"requires_milestones":["first_auto_served"],"unlock_rule_id":"always","sort_order":180,"announce":true},
	"kitchen_pair":{"id":"kitchen_pair","title_key":"Парная кухня","min_stars":2,"requires_features":["production_tables"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":190,"announce":true},
	"lab_growth_upgrades":{"id":"lab_growth_upgrades","title_key":"Развитие выращивания","min_stars":2,"requires_features":["clone_growth"],"requires_milestones":["first_auto_served"],"unlock_rule_id":"always","sort_order":200,"announce":true},
	"recalibration":{"id":"recalibration","title_key":"Рекалибровка","min_stars":2,"requires_features":["formula_upgrades"],"requires_milestones":["first_auto_served","formula_improvement_relevant"],"unlock_rule_id":"always","sort_order":210,"announce":true},
	"lab_automation":{"id":"lab_automation","title_key":"Автоматизация лаборатории","min_stars":2,"requires_features":["lab_growth_upgrades"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":220,"announce":true},
	"rest_extended":{"id":"rest_extended","title_key":"Расширенный отдых","min_stars":2,"requires_features":["rest_basics"],"requires_milestones":["first_staff_rest_completed"],"unlock_rule_id":"always","sort_order":230,"announce":true},
	"kitchen_specialty":{"id":"kitchen_specialty","title_key":"Бургерная кухня","min_stars":3,"requires_features":["kitchen_pair"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":240,"announce":true},
	"rest_large":{"id":"rest_large","title_key":"Большая комната отдыха","min_stars":3,"requires_features":["rest_extended"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":250,"announce":true},
	"kitchen_orchestration":{"id":"kitchen_orchestration","title_key":"Кухня «Солянка»","min_stars":4,"requires_features":["kitchen_specialty"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":260,"announce":true},
	"content.sauce_ramp":{"id":"content.sauce_ramp","title_key":"Соусный трамплин","min_stars":1,"requires_features":["production_tables"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":1000,"announce":false},
	"content.lab_expansion.1":{"id":"content.lab_expansion.1","title_key":"Расширение лаборатории I","min_stars":1,"requires_features":["clone_lab"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":1010,"announce":false},
	"content.lab_expansion.2":{"id":"content.lab_expansion.2","title_key":"Расширение лаборатории II","min_stars":2,"requires_features":["lab_growth_upgrades"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":1020,"announce":false},
	"content.lounge_expansion.1":{"id":"content.lounge_expansion.1","title_key":"Расширение отдыха I","min_stars":2,"requires_features":["rest_extended"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":1030,"announce":false},
	"content.lounge_expansion.2":{"id":"content.lounge_expansion.2","title_key":"Расширение отдыха II","min_stars":3,"requires_features":["rest_large"],"requires_milestones":[],"unlock_rule_id":"always","sort_order":1040,"announce":false}
}

const LEGACY_ALIASES := {"kitchen_grill":"kitchen_specialty","kitchen_solyanka":"kitchen_orchestration"}

const ITEM_FEATURES := {
	"cup":["dish_wine"],"jug":["dish_wine"],"pan":["dish_potato"],"sauce":["dish_sausage"],"plates":["shop_basic"],
	"counter":["production_tables"],"sauce_ramp":["production_tables","content.sauce_ramp"],
	"lab_0":["clone_lab"],"lab_1":["clone_lab"],"lab_2":["clone_lab"],
	"meat_kit":["kitchen_pair"],"pasta_kit":["kitchen_pair"],"kitchen":["kitchen_pair"],"expansion":["kitchen_pair"],
	"grill_kit":["kitchen_specialty"],"assembly_kit":["kitchen_specialty"],"grill_kitchen":["kitchen_specialty"],"specialty_expansion":["kitchen_specialty"],
	"fire_kit":["kitchen_orchestration"],"stir_kit":["kitchen_orchestration"],"salt_kit":["kitchen_orchestration"],"solyanka_kitchen":["kitchen_orchestration"],"orchestration_expansion":["kitchen_orchestration"],
	"sign":["decor_basic"],"plants":["decor_basic"],"lights":["decor_basic"],
	"lab_power":["formula_upgrades"],"lab_power_2":["formula_upgrades"],"lab_power_3":["formula_upgrades"],"lab_valve":["formula_upgrades"],"lab_damper":["formula_upgrades"],
	"lab_chair":["recalibration"],"lab_cal_focus":["recalibration"],"lab_cal_slow":["recalibration"],
	"lab_feeder":["lab_growth_upgrades"],"lab_irrigation":["lab_growth_upgrades"],"lab_lamps":["lab_growth_upgrades"],"lab_nutrients":["lab_growth_upgrades"],"lab_rack":["lab_growth_upgrades"],"lab_rack_2":["lab_growth_upgrades"],
	"lab_planter":["lab_automation"],"lab_extractor":["lab_automation"],"lab_production":["lab_automation"],"lab_climate":["lab_automation"],"lab_cal_auto":["lab_automation","recalibration"],"lab_cal_speed":["lab_automation","recalibration"],
	"rest_sofa":["rest_basics"],"rest_beanbag":["rest_basics"],"rest_rocking_chair":["rest_basics"],"rest_plants":["rest_basics"],"rest_floor_lamp":["rest_basics"],
	"rest_television":["video_training"],
	"rest_bookcase":["rest_extended"],"rest_board_games":["rest_extended"],"rest_tea_station":["rest_extended"],"rest_snack_fridge":["rest_extended"],"rest_foosball":["rest_extended"],"rest_arcade":["rest_extended"],"rest_textiles":["rest_extended"],
	"rest_table_tennis":["rest_large"],"rest_jukebox":["rest_large"],"rest_aquarium":["rest_large"],"rest_ambient":["rest_large"]
}

const RECIPE_FEATURES := {"sausage":"dish_sausage","potato":"dish_potato","wine":"dish_wine","meal":"kitchen_pair","burger":"kitchen_specialty","cheeseburger":"kitchen_specialty","spicy_burger":"kitchen_specialty","solyanka":"kitchen_orchestration"}

static func normalize_feature_id(feature_id: String) -> String:
	return str(LEGACY_ALIASES.get(feature_id, feature_id))

static func definition(feature_id: String) -> Dictionary:
	return DEFINITIONS.get(normalize_feature_id(feature_id), {})

static func ordered_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in DEFINITIONS.keys(): ids.append(str(raw_id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: Dictionary = DEFINITIONS[a]
		var db: Dictionary = DEFINITIONS[b]
		var oa := int(da.get("sort_order", 0)); var ob := int(db.get("sort_order", 0))
		return a < b if oa == ob else oa < ob)
	return ids

static func item_features(item_id: String, spec: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	if ITEM_FEATURES.has(item_id):
		for feature_id in ITEM_FEATURES[item_id]: result.append(normalize_feature_id(str(feature_id)))
	elif spec.has("feature"):
		result.append(normalize_feature_id(str(spec.feature)))
	else:
		result.append("shop_basic")
	if item_id.begins_with("rest_upgrade_"):
		var base_id := "rest_" + item_id.trim_prefix("rest_upgrade_")
		result = item_features(base_id, spec)
	return result

static func recipe_feature(dish_id: String) -> String:
	return str(RECIPE_FEATURES.get(dish_id, ""))

static func validate() -> Array[String]:
	var errors: Array[String] = []
	for id in DEFINITIONS:
		var definition_value: Dictionary = DEFINITIONS[id]
		if str(definition_value.get("id", "")) != str(id): errors.append("Feature id mismatch: %s" % id)
		if str(definition_value.get("unlock_rule_id", "")) not in ["always"]: errors.append("Unknown unlock rule: %s" % id)
		for dependency in definition_value.get("requires_features", []):
			if not DEFINITIONS.has(str(dependency)): errors.append("Unknown dependency %s -> %s" % [id, dependency])
	var visiting := {}; var visited := {}
	for id in DEFINITIONS: _validate_cycle(str(id), visiting, visited, errors)
	return errors

static func _validate_cycle(id: String, visiting: Dictionary, visited: Dictionary, errors: Array[String]) -> void:
	if visited.has(id): return
	if visiting.has(id):
		errors.append("Feature dependency cycle at %s" % id)
		return
	visiting[id] = true
	for dependency in DEFINITIONS[id].get("requires_features", []): _validate_cycle(str(dependency), visiting, visited, errors)
	visiting.erase(id); visited[id] = true
