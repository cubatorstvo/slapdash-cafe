extends RefCounted
## Stable progression contract. Definitions describe when a mechanic becomes known;
## temporary command conditions belong to FeatureAccess contexts, not here.

const IDS: Array[String] = [
	"shop_basic",
	"stars",
	"clone_lab",
	"clone_growth",
	"live_training",
	"staff_roster",
	"rest_basics",
	"video_recording",
	"video_training",
	"group_training",
	"recalibration",
	"lab_automation",
	"kitchen_pair",
	"kitchen_grill",
	"kitchen_solyanka",
]

const DEFINITIONS: Dictionary = {
	"shop_basic": {"id":"shop_basic","dependencies":[],"introduction_events":["new_game"],"min_chapter":0,"contexts":["navigation","shop","purchase"]},
	"stars": {"id":"stars","dependencies":[],"introduction_events":["first_guest_seen"],"min_chapter":0,"contexts":["development","inspection","shop"]},
	"clone_lab": {"id":"clone_lab","dependencies":["shop_basic"],"introduction_events":["first_guest_seen"],"min_chapter":0,"contexts":["development","shop","world","purchase"]},
	"clone_growth": {"id":"clone_growth","dependencies":["clone_lab"],"introduction_events":["first_clone_created"],"min_chapter":1,"contexts":["staff","shop","purchase"]},
	"live_training": {"id":"live_training","dependencies":["clone_growth"],"introduction_events":["first_clone_created"],"min_chapter":1,"contexts":["staff","training","world"]},
	"staff_roster": {"id":"staff_roster","dependencies":["clone_growth"],"introduction_events":["first_clone_created"],"min_chapter":1,"contexts":["navigation","staff"]},
	"rest_basics": {"id":"rest_basics","dependencies":["staff_roster"],"introduction_events":["first_clone_created"],"min_chapter":1,"contexts":["development","shop","world"]},
	"video_recording": {"id":"video_recording","dependencies":["stars"],"introduction_events":["first_star"],"min_chapter":1,"contexts":["training","world"]},
	"video_training": {"id":"video_training","dependencies":["video_recording","staff_roster"],"introduction_events":["first_recording_saved"],"min_chapter":2,"contexts":["navigation","training"]},
	"group_training": {"id":"group_training","dependencies":["live_training"],"introduction_events":["personal_lesson_accepted"],"min_chapter":1,"contexts":["training","staff"]},
	"recalibration": {"id":"recalibration","dependencies":["clone_growth"],"introduction_events":["first_clone_created"],"min_chapter":1,"contexts":["development","lab","world"]},
	"lab_automation": {"id":"lab_automation","dependencies":["recalibration"],"introduction_events":["auto_feed_completed"],"min_chapter":3,"contexts":["development","lab","world"]},
	"kitchen_pair": {"id":"kitchen_pair","dependencies":["clone_growth"],"introduction_events":["second_star"],"min_chapter":2,"contexts":["shop","training","purchase"]},
	"kitchen_grill": {"id":"kitchen_grill","dependencies":["kitchen_pair"],"introduction_events":["third_star"],"min_chapter":3,"contexts":["shop","training","purchase"]},
	"kitchen_solyanka": {"id":"kitchen_solyanka","dependencies":["kitchen_grill"],"introduction_events":["fourth_star"],"min_chapter":4,"contexts":["shop","training","purchase"]},
}

const PAGE_FEATURES: Dictionary = {
	"overview":"",
	"stations":"shop_basic",
	"star":"",
	"groups":"staff_roster",
	"videos":"video_training",
	"laboratory":"clone_lab",
	"lounge":"rest_basics",
	"stats":"",
	"settings":"",
}

const PAGE_PARENTS: Dictionary = {
	"stations":"overview",
	"star":"overview",
	"groups":"star",
	"videos":"groups",
	"laboratory":"star",
	"lounge":"star",
	"stats":"overview",
	"settings":"overview",
}

const SHOP_CATEGORY_FEATURES: Dictionary = {
	"equipment":"shop_basic",
	"tables":"stars",
	"rooms":"stars",
	"lab":"clone_lab",
	"lounge":"rest_basics",
	"decor":"stars",
}

const ACTION_FEATURES: Dictionary = {
	"buy":"shop_basic",
	"buy_bundle":"shop_basic",
	"buy_station_batch":"stars",
	"masterclass":"video_recording",
	"staff_training":"live_training",
	"group_training":"group_training",
	"clone_create":"clone_lab",
	"recalibration":"recalibration",
	"lab_automation":"lab_automation",
	"banquet":"stars",
}

static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id, {})

static func feature_for_page(page: String) -> String:
	return str(PAGE_FEATURES.get(page, ""))

static func feature_for_category(category: String) -> String:
	return str(SHOP_CATEGORY_FEATURES.get(category, "shop_basic"))

static func feature_for_action(action: String) -> String:
	return str(ACTION_FEATURES.get(action, ""))
