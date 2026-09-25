extends SceneTree

const Director = preload("res://scripts/progression/progression_director.gd")
const Access = preload("res://scripts/progression/feature_access.gd")
const Reasons = preload("res://scripts/progression/access_reasons.gd")

class FakeProgress extends RefCounted:
	var day := 1
	var feature_progress: Dictionary = {}
	var world_epoch := "local-epoch"
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

func _initialize() -> void: run.call_deferred()

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

	var lab_before := access.check_action("lab_pot", {})
	check(not lab_before.allowed and lab_before.reason_code == Reasons.FEATURE_LOCKED, "raw lab action is rejected before clone growth")
	var video_before := access.check_action("masterclass_watch", {})
	check(not video_before.allowed and video_before.reason_code == Reasons.FEATURE_LOCKED, "raw video watch is rejected before video training")

	# Client-local state is deliberately much richer than the host snapshot.
	service.progress.stars = 5
	service.progress.tutorial_served = ["sausage", "potato", "wine"]
	service.progress.lab_stage = 3
	service.progress.lab_formula_version = 1
	service.progress.next_clone_id = 9
	service.progress.free_workers = [{"clone_id":8,"tempo":0.5}]
	var host_cafe := "host-cafe"
	var host_base := {"schema_version":1,"cafe_id":host_cafe,"revision":7,"milestones":{},"unlocked_features":["cafe_core","shop_basic","stars","dish_sausage","dish_potato","dish_wine"],"announced_features":[]}
	service.progress.world_epoch = "host-epoch-a"
	service.progress.feature_progress = host_base.duplicate(true)
	check(not access.feature_state(&"clone_lab").unlocked, "authoritative host snapshot overrides richer local evidence")
	check(director.cafe_id == host_cafe and director.revision == 7, "first host generation is applied exactly")

	var older_save := host_base.duplicate(true)
	older_save.revision = 2
	service.progress.world_epoch = "host-epoch-b"
	service.progress.feature_progress = older_save
	check(not access.feature_state(&"clone_lab").unlocked and director.revision == 2, "new epoch accepts lower revision")

	var stale_old_world := host_base.duplicate(true)
	stale_old_world.revision = 99
	stale_old_world.unlocked_features = ["cafe_core","shop_basic","stars","clone_lab","formula_research","clone_growth","video_recording","video_training"]
	service.progress.world_epoch = "host-epoch-a"
	service.progress.feature_progress = stale_old_world
	check(not access.feature_state(&"clone_lab").unlocked and director.revision == 2, "retired epoch is ignored even with higher revision")

	service.progress.world_epoch = "host-epoch-b"
	service.progress.feature_progress = older_save
	service.queue_free()
	print("PASS: feature access authority" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
