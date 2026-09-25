extends SceneTree

const Director = preload("res://scripts/progression/progression_director.gd")
const Access = preload("res://scripts/progression/feature_access.gd")
const Reasons = preload("res://scripts/progression/access_reasons.gd")
const Catalog = preload("res://scripts/progression/feature_catalog.gd")
const UiCatalog = preload("res://scripts/progression/ui_entry_catalog.gd")
const BaseCatalogue = preload("res://scripts/cafe_catalogue.gd")
const Laboratory = preload("res://scripts/laboratory_progression.gd")
const Lounge = preload("res://scripts/lounge_progression.gd")

class FakeProgress extends RefCounted:
	var day := 1
	var feature_progress: Dictionary = {}
	var world_epoch := "epoch-a"
	var cafe_inaugurated := false
	var stars := 0
	var cash := 20
	var manual_served := 0
	var tutorial_served: Array = []
	var lab_stage := 0
	var lab_formula_version := 0
	var lab_formula_tempo := 0.7
	var next_clone_id := 1
	var free_workers: Array = []
	var journey_auto_served := 0
	var third_star_auto_served := 0
	var fourth_star_auto_served := 0
	var fifth_star_auto_served := 0
	var rest_report: Dictionary = {}
	var lab_calibration: Dictionary = {}
	var deliveries: Array = []
	var delivery_history: Array = []
	var lab_upgrades: Array = []
	var lounge_tier := 0
	var lounge_items: Array = ["sofa"]
	var lounge_upgrades: Array = []
	var expanded := false
	var specialized_expanded := false
	var orchestration_expanded := false

class FakeService extends Node:
	var progress := FakeProgress.new()
	var masterclasses: Array = []
	var stations: Array = []
	var group_registry = null
	var progression_director

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, text: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", text)

func run() -> void:
	var service := FakeService.new()
	root.add_child(service)
	var director := Director.new()
	service.progression_director = director
	director.setup(service)
	var access := Access.new()
	access.setup(service, director)

	check(Catalog.validate().is_empty(), "feature catalogue validates")
	check(UiCatalog.validate(Catalog).is_empty(), "UI/action catalogue validates")
	check(director.is_unlocked("cafe_core") and director.is_unlocked("shop_basic") and director.is_unlocked("stars"), "new cafe has three base systems")
	check(director.is_unlocked("dish_sausage") and not director.is_unlocked("dish_potato") and not director.is_unlocked("dish_wine"), "new cafe introduces only the first starter dish")
	check(not director.is_unlocked("clone_lab") and not director.is_unlocked("staff_roster") and not director.is_unlocked("video_recording"), "future systems stay locked on new cafe")
	var roots := access.visible_entries("")
	check(roots.size() == 3, "new cafe exposes only Cafe, Shop and Development roots")
	check(access.nearest_visible_route("office.training.groups") == "office.cafe", "closed deep link falls back to Cafe")
	var future := access.check_action("clone_create", {})
	check(not future.allowed and future.reason_code == Reasons.FEATURE_LOCKED, "hidden future command is rejected directly")
	var unknown := access.check_action("client_says_allowed", {"allowed":true,"stars":99})
	check(not unknown.allowed and unknown.reason_code == Reasons.UNKNOWN_ACTION, "client-provided decisions cannot invent commands")

	var hidden_jug := access.item_access("jug", BaseCatalogue.ITEMS.jug, {"available_funds":999,"host_required":true,"is_host":true})
	check(not hidden_jug.visible, "future wine equipment stays hidden before wine is introduced")
	var poor_sauce := access.item_access("sauce", BaseCatalogue.ITEMS.sauce, {"available_funds":20,"host_required":true,"is_host":true})
	check(poor_sauce.visible and not poor_sauce.enabled and poor_sauce.reason_code == Reasons.INSUFFICIENT_FUNDS and int(poor_sauce.reason_args.missing) == 4, "known starter item stays visible when funds are low")
	var guest_sauce := access.item_access("sauce", BaseCatalogue.ITEMS.sauce, {"available_funds":100,"host_required":true,"is_host":false})
	check(guest_sauce.visible and not guest_sauce.enabled and guest_sauce.reason_code == Reasons.HOST_ONLY, "guest can browse introduced goods but host owns purchase")

	service.progress.cafe_inaugurated = true
	director.observe(&"cafe_opened")
	check(director.has_milestone("cafe_opened"), "ribbon completion is a persisted domain milestone")
	service.progress.tutorial_served = ["sausage"]
	director.migrate_from_game_state(); director.reconcile()
	check(director.is_unlocked("dish_potato") and not director.is_unlocked("dish_wine"), "successful sausage introduces potato only")
	check(not director.is_unlocked("clone_lab"), "laboratory remains hidden after first dish")
	service.progress.tutorial_served.append("potato")
	director.migrate_from_game_state(); director.reconcile()
	check(director.is_unlocked("dish_wine"), "successful potato introduces wine")
	service.progress.tutorial_served.append("wine")
	director.migrate_from_game_state(); director.reconcile()
	check(director.has_milestone("first_sausage_served") and director.has_milestone("first_potato_served") and director.has_milestone("first_wine_served"), "starter dish facts are persisted independently")
	check(not director.is_unlocked("clone_lab"), "three base dishes do not introduce laboratory before 1★")
	var wine_after_intro := access.item_access("jug", BaseCatalogue.ITEMS.jug, {"available_funds":40,"host_required":true,"is_host":true})
	check(wine_after_intro.visible and not wine_after_intro.enabled and wine_after_intro.reason_code == Reasons.INSUFFICIENT_FUNDS and int(wine_after_intro.reason_args.missing) == 14, "introduced wine equipment remains visible with a concrete funds reason")

	service.progress.stars = 1
	director.migrate_from_game_state(); director.reconcile()
	check(director.has_milestone("first_star_earned") and director.is_unlocked("clone_lab"), "real 1★ introduces the laboratory")
	service.progress.lab_stage = 3
	service.progress.lab_formula_version = 1
	director.migrate_from_game_state(); director.reconcile()
	check(director.is_unlocked("clone_growth") and not director.is_unlocked("formula_research"), "assembled lab and 1 star unlock standard clone growth while formula improvement stays later")
	service.progress.next_clone_id = 2
	service.progress.free_workers = [{"clone_id":1,"tempo":0.7}]
	director.migrate_from_game_state(); director.reconcile()
	check(director.is_unlocked("staff_roster") and director.is_unlocked("production_tables") and director.is_unlocked("live_training") and not director.is_unlocked("video_recording"), "first clone unlocks staff, production table and personal training without early recording")
	service.progress.next_clone_id = 1
	service.progress.free_workers.clear()
	director.migrate_from_game_state(); director.reconcile()
	check(director.is_unlocked("staff_roster") and access.ui_state("office.staff").visible, "learned Staff section stays after workers disappear")

	var tv_before := access.item_access("rest_television", Lounge.shop_items().rest_television, {"available_funds":999})
	check(not tv_before.visible, "television stays hidden during the 1★ personal-training chapter")
	director.observe(&"live_lesson_accepted", {"clone_id":1,"dish":"sausage"})
	director.reconcile()
	check(not director.is_unlocked("video_recording"), "accepted personal lesson does not unlock filming before 2★")
	service.progress.stars = 2
	director.reconcile()
	check(director.is_unlocked("video_recording"), "2★ introduces filming after a real personal lesson")
	director.observe(&"masterclass_saved", {"record_id":1})
	check(director.is_unlocked("video_training"), "saved post-2★ masterclass unlocks single-viewer video training")
	var tv_after := access.item_access("rest_television", Lounge.shop_items().rest_television, {"available_funds":999})
	check(tv_after.visible and tv_after.enabled, "television becomes buyable without requiring Rest unlock")
	check(not director.is_unlocked("rest_basics"), "television availability does not create Rest cycle")

	var one_table := access.check_action("buy_station_batch", {"items":[{"item_id":"counter","spec":BaseCatalogue.ITEMS.counter}],"station_ids":[2],"available_funds":999})
	check(one_table.allowed, "single production table batch does not require group training")
	var two_tables := access.check_action("buy_station_batch", {"items":[{"item_id":"counter","spec":BaseCatalogue.ITEMS.counter}],"station_ids":[2,3],"available_funds":999})
	check(not two_tables.allowed and two_tables.reason_code == Reasons.FEATURE_LOCKED, "multi-table batch cannot bypass group training")
	service.stations = [{"manual_station":false,"masterclass_station":false,"type_id":"counter"},{"manual_station":false,"masterclass_station":false,"type_id":"counter"}]
	director.observe(&"video_training_completed", {"station_count":1})
	director.migrate_from_game_state(); director.reconcile()
	check(not director.is_unlocked("group_training"), "completed video training alone does not unlock group training")
	director.observe(&"video_trained_auto_served", {"station_id":2,"dish":"sausage"})
	director.reconcile()
	check(director.is_unlocked("group_training"), "completed video training, its automatic serving and compatible tables unlock group training")
	var two_tables_after := access.check_action("buy_station_batch", {"items":[{"item_id":"counter","spec":BaseCatalogue.ITEMS.counter}],"station_ids":[2,3],"available_funds":999})
	check(two_tables_after.allowed, "multi-table batch becomes valid after group training unlock")

	var repeatable := access.item_access("counter", BaseCatalogue.ITEMS.counter, {"available_funds":999})
	check(repeatable.visible and repeatable.enabled and repeatable.state == "ready", "installed production table does not make all future tables owned")
	var pending := access.item_access("counter", BaseCatalogue.ITEMS.counter, {"available_funds":999,"pending_delivery":true})
	check(pending.visible and not pending.enabled and pending.state == "pending" and pending.reason_code == Reasons.DELIVERY_PENDING, "pending delivery keeps card visible with pending state")
	var empty_page := access.ui_state("office.staff", {"empty":true})
	check(empty_page.visible, "open empty section stays visible")

	var snapshot := director.snapshot()
	var original_cafe := director.cafe_id
	check(not snapshot.has("world_epoch"), "world epoch is not persisted inside feature_progress")
	var restored := Director.new()
	service.progression_director = restored
	restored.setup(service)
	restored.restore(snapshot, true)
	check(restored.cafe_id == original_cafe, "cafe id survives save/load")
	check(restored.has_milestone("cafe_opened") and restored.has_milestone("first_star_earned"), "early progression milestones survive current-format save/load")
	check(restored.is_unlocked("staff_roster") and restored.is_unlocked("live_training") and restored.is_unlocked("video_recording") and restored.is_unlocked("video_training") and restored.is_unlocked("group_training"), "monotonic learning unlocks survive save/load")
	service.progress.free_workers.clear(); service.progress.next_clone_id = 1
	restored.reconcile()
	check(restored.is_unlocked("staff_roster"), "temporary state loss never removes a saved unlock")

	access.setup(service, restored)
	access.mark_seen("staff_roster")
	check(access.has_seen("staff_roster"), "seen is stored per cafe/player UI state")

	var all_items: Dictionary = BaseCatalogue.ITEMS.duplicate(true)
	all_items.merge(Laboratory.catalogue(), true)
	all_items.merge(Lounge.shop_items(), true)
	for raw_id in all_items:
		var item_id := str(raw_id)
		var features := Catalog.item_features(item_id, all_items[item_id])
		check(not features.is_empty(), "item %s has access rule" % item_id)
		for feature_id in features: check(not Catalog.definition(str(feature_id)).is_empty(), "item %s references known feature %s" % [item_id, feature_id])
	for dish_id in Catalog.RECIPE_FEATURES:
		check(not Catalog.definition(Catalog.recipe_feature(str(dish_id))).is_empty(), "recipe %s references known feature" % dish_id)
	for action_id in UiCatalog.ACTION_FEATURES:
		for feature_id in UiCatalog.action_features(str(action_id)): check(not Catalog.definition(feature_id).is_empty(), "action %s references known feature %s" % [action_id, feature_id])

	service.queue_free()
	print("PASS: unified feature access contract" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
