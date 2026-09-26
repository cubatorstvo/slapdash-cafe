extends SceneTree

const Progression = preload("res://scripts/cafe_progression.gd")
const Journey = preload("res://scripts/cafe_journey.gd")
const Pacing = preload("res://scripts/progression/learning_pacing_core.gd")
var failures := 0

class Run:
	extends RefCounted
	var phase := "idle"
	var purpose := "lesson"
	var lengths: Array = [10]
	func active() -> bool: return phase != "idle"
	func summary() -> Dictionary: return {"lengths":lengths}

class Station:
	extends RefCounted
	var station_id := 1
	var manual_station := false
	var staffed := 1
	var type_id := "counter"
	var equipment: Array = []
	var recipes: Dictionary = {}
	var remote_summary: Dictionary = {}
	var training = Run.new()
	var state := "idle"
	var pending_teacher := 0
	func role_count() -> int: return 1
	func ready_crew() -> bool: return staffed == role_count()
	func missing_recipe_equipment(_dish: String) -> Array: return []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func snapshot(features: Array = [], milestones: Array = []) -> Dictionary:
	var records := {}
	for milestone_id in milestones: records[str(milestone_id)] = {"day":1}
	return {"cafe_id":"test-cafe","unlocked_features":features,"milestones":records}

func _initialize() -> void:
	print("1/3: one current journey task follows real state")
	var p = Progression.new()
	p.stars = 1; p.lab_stage = 3; p.cash = 500
	var personal = Station.new(); personal.manual_station = true
	personal.equipment = ["sauce","plates","pan","jug","cup"]
	var stations: Array = [personal]
	check(str(Journey.current(p, stations, 15, true).get("key", "")) == "standard_formula", "first unfinished real step selected")
	p.lab_formula_version = 1; p.lab_pots = [{"id":0,"phase":"growing_sprout"}]
	check(str(Journey.current(p, stations, 15, true).get("key", "")) == "buy_counter", "already completed formula skipped without repetition")
	p.deliveries = [{"item":"counter","station":2,"owner":0,"remaining":8}]
	check(str(Journey.current(p, stations, 15, true).get("key", "")) == "delivery_counter", "temporary delivery becomes actionable current task")

	print("2/3: explanations are deterministic, grouped and deduplicated")
	var before_auto := snapshot(["clone_growth","production_tables"], ["first_clone_created","first_live_lesson_accepted"])
	var known := Pacing.snapshot_sets(before_auto)
	var after_auto := snapshot(["clone_growth","production_tables"], ["first_clone_created","first_live_lesson_accepted","first_auto_served"])
	var queue := Pacing.collect_new(after_auto, known, {})
	check(queue.size() == 1 and str(queue[0].id) == "p5.first_automation", "first real auto serve adds exactly one explanation")
	var queued := {"p5.first_automation":true}
	check(Pacing.collect_new(after_auto, known, {}, queued).is_empty(), "same stable explanation id cannot duplicate while queued")
	check(Pacing.collect_new(after_auto, known, {"p5.first_automation":true}).is_empty(), "seen explanation never repeats")
	var before_video := snapshot(["video_recording"], ["first_masterclass_saved"])
	var after_video := snapshot(["video_recording","video_training"], ["first_masterclass_saved","first_video_training_completed"])
	queue = Pacing.collect_new(after_video, Pacing.snapshot_sets(before_video), {})
	check(queue.size() == 1 and str(queue[0].id) == "p5.video_learning", "first completed video lesson introduces video training once")
	var before_late := snapshot([], [])
	var after_late := snapshot(["kitchen_orchestration","lab_automation","recalibration_automation"], [])
	queue = Pacing.collect_new(after_late, Pacing.snapshot_sets(before_late), {})
	check(queue.size() == 1 and str(queue[0].id) == "p5.orchestration", "three features of one late bundle produce one explanation")
	var catchup := Pacing.collapse_catchup(snapshot(["clone_lab","video_training","kitchen_orchestration"],["first_clone_created","first_video_training_completed"]), {})
	check(not catchup.current.is_empty() and str(catchup.current.id) == "p5.orchestration", "developed cafe collapses history to latest applicable context")
	check(catchup.skip_ids.size() >= 2, "older catch-up explanations are not replayed in a dump")

	print("3/3: UI/control state gates presentation without timers")
	var calm := {"ui_mode":"world"}
	check(Pacing.can_present(calm), "calm world state can present")
	for blocker in ["holding_item","cooking","teaching","confirming","inspection","sleep","urgent_notice"]:
		var state := calm.duplicate(); state[blocker] = true
		check(not Pacing.can_present(state), blocker + " blocks explanation")
	check(not Pacing.can_present({"ui_mode":"office"}), "other modal/UI mode blocks explanation")
	print("PASS: P5.06 pacing task, queue and safe presentation" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
