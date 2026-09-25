extends RefCounted

const ENTRIES := {
	"office.cafe":{"id":"office.cafe","parent_id":"","sort_order":10,"required_features":["cafe_core"],"any_features":[],"legacy_page":"overview"},
	"office.shop":{"id":"office.shop","parent_id":"","sort_order":20,"required_features":["shop_basic"],"any_features":[],"legacy_page":"stations"},
	"office.development":{"id":"office.development","parent_id":"","sort_order":30,"required_features":["stars"],"any_features":[],"legacy_page":"star"},
	"office.staff":{"id":"office.staff","parent_id":"","sort_order":40,"required_features":["staff_roster"],"any_features":[],"legacy_page":"groups"},
	"office.training":{"id":"office.training","parent_id":"","sort_order":50,"required_features":["video_recording"],"any_features":[],"legacy_page":"videos"},
	"office.cafe.statistics":{"id":"office.cafe.statistics","parent_id":"office.cafe","sort_order":10,"required_features":["cafe_statistics"],"any_features":[],"legacy_page":"stats"},
	"office.development.laboratory":{"id":"office.development.laboratory","parent_id":"office.development","sort_order":10,"required_features":["clone_lab"],"any_features":[],"legacy_page":"laboratory"},
	"office.development.rest":{"id":"office.development.rest","parent_id":"office.development","sort_order":20,"required_features":["rest_basics"],"any_features":[],"legacy_page":"lounge"},
	"office.training.library":{"id":"office.training.library","parent_id":"office.training","sort_order":10,"required_features":["video_recording"],"any_features":[],"legacy_page":"videos"},
	"office.training.assignments":{"id":"office.training.assignments","parent_id":"office.training","sort_order":20,"required_features":["video_training"],"any_features":[],"legacy_page":"videos"},
	"office.training.groups":{"id":"office.training.groups","parent_id":"office.training","sort_order":30,"required_features":["group_training"],"any_features":[],"legacy_page":"videos"},
	"office.settings":{"id":"office.settings","parent_id":"","sort_order":1000,"required_features":["cafe_core"],"any_features":[],"legacy_page":"settings","auxiliary":true},
	"shop.category.equipment":{"id":"shop.category.equipment","parent_id":"office.shop","sort_order":10,"required_features":["shop_basic"],"any_features":[]},
	"shop.category.tables":{"id":"shop.category.tables","parent_id":"office.shop","sort_order":20,"required_features":[],"any_features":["production_tables","kitchen_pair","kitchen_specialty","kitchen_orchestration"]},
	"shop.category.rooms":{"id":"shop.category.rooms","parent_id":"office.shop","sort_order":30,"required_features":[],"any_features":["kitchen_pair","kitchen_specialty","kitchen_orchestration","lab_growth_upgrades","rest_extended","rest_large"]},
	"shop.category.lab":{"id":"shop.category.lab","parent_id":"office.shop","sort_order":40,"required_features":[],"any_features":["clone_lab","formula_upgrades","lab_growth_upgrades","recalibration","lab_automation"]},
	"shop.category.lounge":{"id":"shop.category.lounge","parent_id":"office.shop","sort_order":50,"required_features":[],"any_features":["video_training","rest_basics","rest_extended","rest_large"]},
	"shop.category.decor":{"id":"shop.category.decor","parent_id":"office.shop","sort_order":60,"required_features":["decor_basic"],"any_features":[]}
}

const ALIASES := {"overview":"office.cafe","stations":"office.shop","star":"office.development","stats":"office.cafe.statistics","laboratory":"office.development.laboratory","lounge":"office.development.rest","videos":"office.training.library","groups":"office.staff","settings":"office.settings"}

const ACTION_FEATURES := {
	"buy":[],"buy_bundle":[],"buy_station_batch":[],
	"masterclass_start":["video_recording"],"masterclass_rename":["video_recording"],"masterclass_delete":["video_recording"],
	"video_watch":["video_training"],"masterclass_watch":["video_training"],"training_course_confirm":["video_training"],"training_course_edit":["video_training"],
	"group_train":["video_training"],"group_create":["group_training"],"group_dissolve":["group_training"],"group_rename":["group_training"],"group_active":["group_training"],
	"clone_create":["clone_growth"],"lab_clone_growth":["clone_growth"],"lab_tool":["clone_growth"],"lab_pot":["clone_growth"],"lab_pull":["clone_growth"],"lab_research":["formula_research"],"lab_sample":["formula_research"],"lab_scan":["formula_research"],"lab_restart":["formula_research"],"lab_press":["formula_research"],"lab_formula_upgrade":["formula_upgrades"],"lab_recalibrate":["recalibration"],"lab_cal_select":["recalibration"],"lab_cal_start":["recalibration"],"lab_cal_hit":["recalibration"],"lab_cal_cancel":["recalibration"],"lab_cal_auto":["recalibration"],"lab_automation":["lab_automation"],"lab_controls":["lab_automation"],"lab_production_config":["lab_automation"],"banquet":["stars"],
	"take_parcel":[],"drop_parcel":[],"install_parcel":[],"manual":[],"sleep":[],"wake":[],"save":[]
}

static func entry(entry_id: String) -> Dictionary:
	return ENTRIES.get(route_id(entry_id), {})
static func route_id(value: String) -> String:
	return str(ALIASES.get(value, value))
static func legacy_page(entry_id: String) -> String:
	var definition := entry(entry_id)
	return str(definition.get("legacy_page", entry_id))
static func action_features(action_id: String) -> Array[String]:
	var result: Array[String] = []
	for feature_id in ACTION_FEATURES.get(action_id, []): result.append(str(feature_id))
	return result
static func children(parent_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw in ENTRIES.values():
		var definition: Dictionary = raw
		if str(definition.get("parent_id", "")) == parent_id: result.append(definition)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa := int(a.get("sort_order", 0)); var ob := int(b.get("sort_order", 0))
		return str(a.id) < str(b.id) if oa == ob else oa < ob)
	return result
static func validate(feature_catalog) -> Array[String]:
	var errors: Array[String] = []
	for id in ENTRIES:
		var definition: Dictionary = ENTRIES[id]
		var parent_id := str(definition.get("parent_id", ""))
		if not parent_id.is_empty() and not ENTRIES.has(parent_id): errors.append("Unknown UI parent %s -> %s" % [id, parent_id])
		for feature_id in definition.get("required_features", []):
			if feature_catalog.definition(str(feature_id)).is_empty(): errors.append("Unknown UI feature %s -> %s" % [id, feature_id])
		for feature_id in definition.get("any_features", []):
			if feature_catalog.definition(str(feature_id)).is_empty(): errors.append("Unknown UI any-feature %s -> %s" % [id, feature_id])
	for action_id in ACTION_FEATURES:
		for feature_id in ACTION_FEATURES[action_id]:
			if feature_catalog.definition(str(feature_id)).is_empty(): errors.append("Unknown action feature %s -> %s" % [action_id, feature_id])
	return errors
