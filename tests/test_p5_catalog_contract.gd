extends SceneTree
## The JSON is a handoff document, not executable runtime policy.
const Catalog = preload("res://scripts/progression/feature_catalog.gd")
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func visit(id: String, edges: Dictionary, visiting: Dictionary, visited: Dictionary) -> void:
	if visited.has(id): return
	check(not visiting.has(id), "dependency cycle at " + id)
	if visiting.has(id): return
	visiting[id] = true
	for dependency in edges.get(id, []):
		check(edges.has(dependency), "unresolved dependency " + id + " -> " + str(dependency))
		if edges.has(dependency): visit(str(dependency), edges, visiting, visited)
	visiting.erase(id)
	visited[id] = true

func _initialize() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/progression/P5_CATALOG_RULES.json"))
	if not data is Dictionary:
		printerr("FAIL: invalid catalogue handoff JSON")
		quit(1)
		return
	var actual: Dictionary = preload("res://scripts/cafe_catalogue.gd").ITEMS.duplicate(true)
	actual.merge(preload("res://scripts/laboratory_progression.gd").catalogue(), true)
	actual.merge(preload("res://scripts/lounge_progression.gd").shop_items(), true)
	var expected: Array = actual.keys().filter(func(id): return str(id).begins_with("lab_") or str(id).begins_with("rest_"))
	check(expected.size() == 52 and data.items.size() == expected.size(), "complete 52-item inventory")
	check(Catalog.validate().is_empty(), "effective current feature graph valid")
	var groups: Dictionary = {}
	var items: Dictionary = {}
	var edges: Dictionary = {}
	for id in Catalog.ordered_ids():
		edges["feature:" + id] = []
		for dependency in Catalog.definition(id).get("requires_features", []): edges["feature:" + id].append("feature:" + str(dependency))
	for group in data.groups:
		check(not groups.has(group.group_id), "unique group " + str(group.group_id))
		groups[group.group_id] = group
		edges["feature:" + str(group.feature_id)] = []
		for dependency in group.features_all: edges["feature:" + str(group.feature_id)].append("feature:" + str(dependency))
		for milestone in group.milestones_all:
			if milestone == "lounge_expansion_1_completed": edges["feature:" + str(group.feature_id)].append("item:lounge_expansion_1")
			if milestone == "lounge_expansion_2_completed": edges["feature:" + str(group.feature_id)].append("item:lounge_expansion_2")
	for expansion in data.implementation_targets.room_expansions:
		var feature_key: String = "feature:" + str(expansion.feature_id)
		edges[feature_key] = []
		for dependency in expansion.features_all: edges[feature_key].append("feature:" + str(dependency))
		edges["item:" + str(expansion.item_id)] = [feature_key]
		if int(expansion.tier_from) == 1: edges["item:" + str(expansion.item_id)].append("item:" + str(expansion.item_id).replace("_2", "_1"))
	for item in data.items:
		var id: String = str(item.item_id)
		check(not items.has(id) and id in expected, "unique existing item " + id)
		items[id] = item
		check(groups.has(item.group_id), "resolved group " + id)
		check(item.price_policy == "preserve_current" and int(item.price) == int(actual.get(id, {}).get("price", -1)), "unchanged real price " + id)
		check(int(item.min_stars) == int(groups[item.group_id].min_stars), "one exact star gate " + id)
		check(item.feature_id == groups[item.group_id].feature_id, "one feature mapping " + id)
		check(data.predicate_specs.has(item.context_rule), "defined context validator " + id)
		check(item.dependencies.milestones_all == groups[item.group_id].milestones_all, "item and group milestones agree " + id)
		check(item.dependencies.counters_all == groups[item.group_id].counters_all, "item and group counters agree " + id)
		check(not bool(item.expected_states.before_introduction.command_allowed), "hidden item cannot be bought " + id)
		check(bool(item.expected_states.insufficient_funds.visible), "known item remains visible " + id)
		edges["item:" + id] = ["feature:" + str(item.feature_id)]
		for dependency in item.dependencies.installed_items_all: edges["item:" + id].append("item:" + str(dependency))
		var room: Dictionary = item.dependencies.room
		if int(room.lab_tier_min) > 0: edges["item:" + id].append("item:lab_expansion_%d" % int(room.lab_tier_min))
		if int(room.lounge_tier_min) > 0: edges["item:" + id].append("item:lounge_expansion_%d" % int(room.lounge_tier_min))
	for id in expected: check(items.has(id), "no item silently omitted " + str(id))
	check(int(items.rest_television.dependencies.room.lounge_tier_min) == 0 and items.rest_television.dependencies.installed_items_all.is_empty(), "television independent of optional room/furniture")
	check(int(groups.manual_growth_help.counters_all[0].gte) == 2, "repeat growing threshold exactly two")
	check(int(groups.lab_scale.counters_all[0].gte) == 6 and int(groups.lab_scale_large.counters_all[0].gte) == 9, "staff thresholds exactly six and nine")
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	for id in edges: visit(str(id), edges, visiting, visited)
	print("PASS: P5.04 catalogue contract: 52 items, exact prices, resolved dependencies and acyclic room graph" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
