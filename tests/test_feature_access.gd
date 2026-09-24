extends SceneTree

const FeatureAccess = preload("res://scripts/feature_access.gd")
const FeatureDefinition = preload("res://scripts/feature_definition.gd")
const Progression = preload("res://scripts/cafe_progression.gd")
const Catalogue = preload("res://scripts/cafe_catalogue.gd")
const Laboratory = preload("res://scripts/laboratory_progression.gd")
const Lounge = preload("res://scripts/lounge_progression.gd")

class FakeService extends Node:
	var progress = Progression.new()
	var guests_arrived := 0
	var served := 0
	var masterclasses: Array = []

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", text)

func visible(access: FeatureAccess, id: String) -> bool:
	return bool(access.access(id).visible)

func enabled(access: FeatureAccess, id: String) -> bool:
	return bool(access.access(id).enabled)

func run() -> void:
	var service := FakeService.new()
	root.add_child(service)
	var access := FeatureAccess.new()
	access.setup(service)
	var p = service.progress

	# New cafe: only the permanent shell and basic shop are known.
	check(visible(access, "shop_basic"), "Basic shop is introduced on a new game")
	check(not visible(access, "stars"), "Star system is not introduced before the first guest")
	check(not visible(access, "staff_roster"), "Staff is hidden before the first clone")
	check(not visible(access, "video_training"), "Training is hidden before recordings are introduced")
	check(access.nearest_visible_page("videos") == "star", "A hidden deep link falls back to the nearest visible parent")

	# A hidden future item cannot be enabled by a direct request context.
	var future_kitchen := access.item_access("kitchen", Catalogue.ITEMS.kitchen, {"is_host":true})
	check(not bool(future_kitchen.visible) and not bool(future_kitchen.enabled), "Future kitchen is hidden and disabled")

	# First guest introduces development and the lab without dumping later systems into navigation.
	service.guests_arrived = 1
	check(visible(access, "stars"), "First guest introduces development")
	check(visible(access, "clone_lab"), "First guest introduces the clone lab")
	check(not visible(access, "staff_roster"), "Staff remains hidden before clone creation")
	var early_counter := access.item_access("counter", Catalogue.ITEMS.counter, {"is_host":true})
	check(bool(early_counter.visible) and not bool(early_counter.enabled), "Known star-gated item stays visible before its required star")
	check(str(early_counter.reason_code) == "star_required", "Item star requirement comes from FeatureAccess")

	# 1★ introduces recording, while training/staff remain hidden until their own facts exist.
	p.stars = 1
	check(enabled(access, "video_recording"), "First star enables recording")
	check(not visible(access, "staff_roster"), "1 star alone does not reveal staff")
	check(not visible(access, "video_training"), "1 star alone does not reveal training")

	# Money is a temporary command condition, not a visibility rule.
	p.cash = 0
	var poor_item := access.item_access("plants", Catalogue.ITEMS.plants, {"is_host":true})
	check(bool(poor_item.visible), "Unaffordable introduced item remains visible")
	check(not bool(poor_item.enabled), "Unaffordable item is disabled")
	check(str(poor_item.reason_code) == "insufficient_funds", "Unaffordable item exposes a concrete reason code")

	# Guests can browse introduced goods, but host ownership is an explicit disabled state.
	p.cash = 500
	var guest_item := access.item_access("plants", Catalogue.ITEMS.plants, {"host_required":true,"is_host":false})
	check(bool(guest_item.visible) and not bool(guest_item.enabled), "Guest can see introduced item but cannot buy it")
	check(str(guest_item.reason_code) == "host_only", "Guest purchase exposes host-only reason")

	# First clone monotonically reveals staff/rest/growth systems.
	p.next_clone_id = 2
	p.free_workers = [{"id":1,"tempo":1.0,"rest":1.0}]
	check(visible(access, "staff_roster"), "First clone reveals Staff")
	check(visible(access, "rest_basics"), "First clone reveals Rest")
	check(enabled(access, "live_training"), "First clone enables personal training")
	p.free_workers.clear()
	p.next_clone_id = 1
	check(visible(access, "staff_roster"), "Losing the temporary clone state does not hide a learned section")

	# Personal lesson is its own monotonic introduction fact.
	p.training_intro_mass_seen = true
	check(visible(access, "group_training"), "Accepted personal lesson introduces group training")

	# 2★ plus a saved recording reveals the fifth top-level section.
	p.stars = 2
	service.masterclasses = [{"id":1,"dish":"wine"}]
	check(visible(access, "video_training"), "2 stars plus recording reveal Training")
	check(visible(access, "kitchen_pair"), "Second star introduces pair kitchen")

	# Mature cafe reveals later kitchens only in order.
	p.stars = 3
	check(visible(access, "kitchen_grill"), "Third star introduces grill kitchen")
	check(not visible(access, "kitchen_solyanka"), "Solyanka remains hidden at three stars")
	p.stars = 4
	check(visible(access, "kitchen_solyanka"), "Fourth star introduces solyanka kitchen")

	# Facts and per-player hints survive a feature-access snapshot.
	access.mark_player_fact(42, "hint:staff_opened")
	var stored := access.export_state()
	var restored := FeatureAccess.new()
	restored.setup(service)
	restored.import_state(stored)
	check(restored.has_fact("first_clone_created"), "Cafe facts survive save/load snapshot")
	check(restored.has_player_fact(42, "hint:staff_opened"), "Per-player hint facts survive save/load snapshot")

	# Every product source consumed by the shop owns a declared feature ID.
	var all_items: Dictionary = Catalogue.ITEMS.duplicate(true)
	all_items.merge(Laboratory.catalogue(), true)
	all_items.merge(Lounge.shop_items(), true)
	for id in all_items:
		var feature_id := str(all_items[id].get("feature", ""))
		check(not feature_id.is_empty(), "Catalogue item %s declares a feature" % id)
		check(not FeatureDefinition.definition(feature_id).is_empty(), "Catalogue item %s references a known feature" % id)
	for action_id in FeatureDefinition.ACTION_FEATURES:
		var action_feature := FeatureDefinition.feature_for_action(str(action_id))
		check(not action_feature.is_empty(), "Action %s declares a feature" % action_id)
		check(not FeatureDefinition.definition(action_feature).is_empty(), "Action %s references a known feature" % action_id)

	service.queue_free()
	print("PASS: unified feature access progression" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
