extends SceneTree
## Parameterized acceptance for the P5.05 catalogue bindings.
const Director = preload("res://scripts/progression/progression_director.gd")
const Access = preload("res://scripts/progression/feature_access.gd")
const Reasons = preload("res://scripts/progression/access_reasons.gd")
const Catalog = preload("res://scripts/progression/feature_catalog.gd")
const Bindings = preload("res://scripts/progression/catalog_bindings.gd")
const Laboratory = preload("res://scripts/laboratory_progression.gd")
const Lounge = preload("res://scripts/lounge_progression.gd")
const BaseCatalogue = preload("res://scripts/cafe_catalogue.gd")

class FakeProgress extends RefCounted:
	var day := 1
	var feature_progress: Dictionary = {}
	var world_epoch := "epoch-catalog"
	var stars := 0
	var cash := 0
	var lab_stage := 0
	var lab_tier := 0
	var lab_formula_version := 0
	var lab_formula_tempo := 1.0
	var lab_upgrades: Array = []
	var lounge_tier := 0
	var lounge_items: Array = ["sofa"]
	var lounge_upgrades: Array = []
	var deliveries: Array = []
	var free_workers: Array = []
	var next_clone_id := 1
	var manual_clone_growth_completed := 0
	var manual_served := 0
	var cafe_inaugurated := false
	var tutorial_served: Array = []
	var delivery_history: Array = []
	var rest_report: Dictionary = {}
	var journey_auto_served := 0
	var third_star_auto_served := 0
	var fourth_star_auto_served := 0
	var fifth_star_auto_served := 0
	func busy() -> bool: return false

class FakeService extends Node:
	var progress := FakeProgress.new()
	var stations: Array = []
	var clone_roster: Array = []
	var progression_director
	func clone_options() -> Array: return clone_roster

var failures := 0
var service: FakeService
var director
var access

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", text)

func fresh() -> void:
	if service != null and is_instance_valid(service): service.queue_free()
	service = FakeService.new()
	root.add_child(service)
	director = Director.new()
	service.progression_director = director
	director.setup(service)
	access = Access.new()
	access.setup(service, director)

func satisfy(feature_id: String, seen: Dictionary = {}) -> void:
	if seen.has(feature_id): return
	seen[feature_id] = true
	var definition: Dictionary = Catalog.definition(feature_id)
	service.progress.stars = maxi(int(service.progress.stars), int(definition.get("min_stars", 0)))
	for dependency in definition.get("requires_features", []):
		satisfy(str(dependency), seen)
	for milestone_id in definition.get("requires_milestones", []):
		director._record_milestone(str(milestone_id), {}, false)
	director.revision += 1
	director.reconcile()

func prepare_item(item_id: String) -> void:
	var row: Dictionary = Bindings.item(item_id)
	satisfy(str(row.feature))
	var p = service.progress
	p.lab_stage = maxi(int(p.lab_stage), int(row.stage))
	p.lab_tier = maxi(int(p.lab_tier), int(row.lab_tier))
	p.lounge_tier = maxi(int(p.lounge_tier), int(row.lounge_tier))
	for raw in row.requires:
		var prerequisite := str(raw)
		if prerequisite.begins_with("rest_"):
			var lounge_id := prerequisite.trim_prefix("rest_upgrade_").trim_prefix("rest_")
			if lounge_id not in p.lounge_items: p.lounge_items.append(lounge_id)
		elif prerequisite not in p.lab_upgrades and not prerequisite.begins_with("lab_0") and prerequisite not in ["lab_0", "lab_1", "lab_2"]:
			p.lab_upgrades.append(prerequisite)
		elif prerequisite in ["lab_0", "lab_1", "lab_2"]:
			p.lab_stage = maxi(int(p.lab_stage), int(prerequisite.get_slice("_", 1)) + 1)
	p.cash = 100000
	p.deliveries.clear()

func run() -> void:
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/progression/P5_CATALOG_RULES.json"))
	check(rules is Dictionary, "catalogue rules JSON parses")
	if not rules is Dictionary:
		quit(1)
		return
	var data: Dictionary = rules
	fresh()
	check(Catalog.validate().is_empty(), "effective feature graph validates")
	for group in data.groups:
		var feature_id := str(group.feature_id)
		var definition: Dictionary = Catalog.definition(feature_id)
		check(int(definition.min_stars) == int(group.min_stars), "stars " + feature_id)
		check(definition.requires_features == group.features_all, "features " + feature_id)
		check(definition.requires_milestones == group.milestones_all, "milestones " + feature_id)
		check(str(definition.title_key) == str(group.title), "title " + feature_id)
		check(str(definition.locked_reason) == str(group.locked_reason), "reason " + feature_id)
		check(str(definition.unlock_rule_id) == "always", "rule " + feature_id)
	for expansion in data.implementation_targets.room_expansions:
		var feature_id := str(expansion.feature_id)
		var definition: Dictionary = Catalog.definition(feature_id)
		check(int(definition.min_stars) == int(expansion.min_stars), "expansion stars " + feature_id)
		check(definition.requires_features == expansion.features_all, "expansion features " + feature_id)
		check(definition.requires_milestones == expansion.milestones_all, "expansion milestones " + feature_id)
		check(not ("rest_large" in definition.requires_features), "room 2 does not require its reward")
	var actual: Dictionary = BaseCatalogue.ITEMS.duplicate(true)
	actual.merge(Laboratory.catalogue(), true)
	actual.merge(Lounge.shop_items(), true)
	var seen_items := {}
	for item in data.items:
		var item_id := str(item.item_id)
		seen_items[item_id] = true
		check(actual.has(item_id), "runtime item " + item_id)
		check(int(actual[item_id].price) == int(item.price), "price " + item_id)
		check(Catalog.item_features(item_id, actual[item_id]) == [str(item.feature_id)], "feature map " + item_id)
		var row: Dictionary = Bindings.item(item_id)
		check(int(row.lab_tier) == int(item.dependencies.room.lab_tier_min), "lab tier " + item_id)
		check(int(row.lounge_tier) == int(item.dependencies.room.lounge_tier_min), "lounge tier " + item_id)
		check(row.requires == item.dependencies.installed_items_all, "prerequisites " + item_id)
		fresh()
		var hidden: Dictionary = access.item_access(item_id, actual[item_id], {"available_funds":999999,"host_required":true,"is_host":true})
		var hidden_buy: Dictionary = access.check_action("buy", {"item_id":item_id,"spec":actual[item_id],"available_funds":999999,"host_required":true,"is_host":true})
		check(not hidden.visible and not hidden_buy.allowed and hidden.reason_code == hidden_buy.reason_code, "hidden parity " + item_id)
		prepare_item(item_id)
		if bool(row.upgrade):
			service.progress.lounge_items.erase(str(row.internal))
			var concealed: Dictionary = access.item_access(item_id, actual[item_id], {"available_funds":999999,"host_required":true,"is_host":true})
			check(not concealed.visible, "upgrade hidden before base " + item_id)
			service.progress.lounge_items.append(str(row.internal))
		var ready: Dictionary = access.item_access(item_id, actual[item_id], {"available_funds":999999,"host_required":true,"is_host":true})
		var ready_buy: Dictionary = access.check_action("buy", {"item_id":item_id,"spec":actual[item_id],"available_funds":999999,"host_required":true,"is_host":true})
		var owned := str(ready.state) == "owned"
		check(ready.visible and ready.reason_code == ready_buy.reason_code, "ready parity " + item_id)
		check(owned or (ready.enabled and ready_buy.allowed), "ready command " + item_id)
		if not owned:
			service.progress.cash = 0
			var poor: Dictionary = access.item_access(item_id, actual[item_id], {"available_funds":0,"host_required":true,"is_host":true})
			var poor_buy: Dictionary = access.check_action("buy", {"item_id":item_id,"spec":actual[item_id],"available_funds":0,"host_required":true,"is_host":true})
			check(poor.visible and not poor.enabled and poor.reason_code == Reasons.INSUFFICIENT_FUNDS and poor.reason_code == poor_buy.reason_code, "funds " + item_id)
			var pending: Dictionary = access.item_access(item_id, actual[item_id], {"available_funds":999999,"pending_delivery":true,"host_required":true,"is_host":true})
			check(pending.visible and pending.state == "pending" and pending.reason_code == Reasons.DELIVERY_PENDING, "pending " + item_id)
	check(seen_items.size() == 52, "52 catalogue rows")
	fresh()
	service.progress.stars = 1
	director.migrate_from_game_state(); director.reconcile()
	check(director.is_unlocked("clone_lab") and not director.is_unlocked("formula_upgrades") and not director.is_unlocked("lab_growth_upgrades") and not director.is_unlocked("video_training"), "1 star opens only the base laboratory")
	var early_power: Dictionary = access.item_access("lab_power", actual.lab_power, {"available_funds":999999})
	var early_tv: Dictionary = access.item_access("rest_television", actual.rest_television, {"available_funds":999999})
	check(not early_power.visible and not early_tv.visible, "1 star does not reveal later groups")
	fresh()
	service.clone_roster = [{"id":1},{"id":2},{"id":2},{"id":3},{"id":4},{"id":5}]
	director.migrate_from_game_state(); director.reconcile()
	check(not director.has_milestone("staff_6_seen"), "duplicate ids do not reach six")
	service.clone_roster.append({"id":6})
	director.migrate_from_game_state(); director.reconcile()
	check(director.has_milestone("staff_6_seen") and not director.has_milestone("staff_9_seen"), "six distinct workers latch the first scale")
	service.clone_roster = [{"id":9},{"id":8},{"id":7},{"id":6},{"id":5},{"id":4},{"id":3},{"id":2},{"id":1}]
	director.migrate_from_game_state(); director.reconcile()
	check(director.has_milestone("staff_9_seen"), "nine workers latch the large scale")
	service.clone_roster.clear()
	director.migrate_from_game_state(); director.reconcile()
	check(director.has_milestone("staff_6_seen") and director.has_milestone("staff_9_seen"), "losing workers keeps the latch")
	fresh()
	director.migrate_from_game_state(); director.reconcile()
	check(not director.has_milestone("lounge_expansion_1_completed"), "room 0 does not complete an expansion")
	service.progress.lounge_tier = 1
	director.migrate_from_game_state(); director.reconcile()
	check(director.has_milestone("lounge_expansion_1_completed") and not director.has_milestone("lounge_expansion_2_completed"), "room 1 latches only the first expansion")
	var snapshot: Dictionary = director.snapshot()
	fresh()
	director.restore(snapshot, true)
	check(director.has_milestone("lounge_expansion_1_completed"), "expansion fact survives the current save")
	service.queue_free()
	print("PASS: P5.05 catalogue rules" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
