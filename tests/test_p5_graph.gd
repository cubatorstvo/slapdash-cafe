extends SceneTree
## Full-scene boundary checks; timers/food replay are accelerated, domain entry points are real.
var failures := 0
var game: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func run() -> void:
	game = load("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	await process_frame
	var service: Node = game.service
	var p = service.progress
	check(not p.cafe_inaugurated and not service.open_for_business, "fresh cafe waits for ribbon")
	var fresh: Dictionary = service.save_data()
	check(service.load_data(fresh), "pristine current save loads")
	p = service.progress
	check(not p.cafe_inaugurated and not service.open_for_business, "loading before ribbon cannot open cafe")
	p.stars = 2; p.lab_stage = 3; p.lab_formula_version = 1; p.lab_formula_tempo = 1.0; p.cash = 5000
	service._refresh_progression()
	check(service.create_clone(1.0, true).is_empty(), "create first actual worker")
	check(p.manual_clone_growth_completed == 0, "creation alone is not a completed manual pot cycle")
	var nursery: Node = game.laboratory.nursery
	nursery.ensure_pots()
	for automatic in [false, false, true]:
		var pot: Dictionary = nursery.pot(0)
		pot.phase = "ready"; pot.tempo = 1.0; pot.formula = 1
		nursery.pulls[0] = {"automatic":automatic,"owner":0 if automatic else 1}
		nursery.harvest(pot)
	check(p.manual_clone_growth_completed == 2, "exactly two manual harvests; automatic extraction excluded")
	check(service.progression_director.has_milestone("repeat_manual_clone_growth_completed"), "repeat means second completed harvest even at 2 stars")
	p.lab_formula_tempo = 1.25
	service._refresh_progression()
	check(service.progression_director.has_milestone("formula_improvement_relevant"), "usefulness includes actual free worker id field")
	p.lab_calibration.revision = 12
	service._refresh_progression()
	check(not service.progression_director.has_milestone("first_recalibration_completed"), "opening/cancelling chair cannot count as success")
	service.progression_director.observe("recalibration_completed", {"clone_id":1,"before":1.0,"after":1.0})
	check(not service.progression_director.has_milestone("first_recalibration_completed"), "no tempo improvement is not success")
	var calibrator: Node = game.laboratory.calibrator
	p.lab_calibration.phase = "manual"; p.lab_calibration.clone_id = 1; p.lab_calibration.start = 1.0
	p.lab_calibration.route = [Vector3.ZERO, Vector3.ONE]
	service.clone_data(1).tempo = 1.25
	calibrator.begin_return("Проверка завершения")
	check(service.progression_director.has_milestone("first_recalibration_completed"), "improved actual worker returning from chair confirms recalibration")
	calibrator.reset()

	var a: Node3D = service.add_station("counter", 1, false)
	var b: Node3D = service.add_station("counter", 2, false)
	service.assign_clones()
	for station in [a, b]:
		station.equipment = ["sauce","plates","rag"]; station.apply_equipment()
	var model = service.by_id(1).model
	model.reset("sausage")
	var record: Dictionary = {"id":55,"name":"Учебный фильм","dish":"sausage","source_type":"counter","quality":{"present":true,"grade":"B"},"tracks":[{"group":1,"frames":[model.snapshot()],"events":[]}],"required_equipment":["sauce","plates"]}
	var clone_a := int(a.crew[0].clone_id)
	var clone_b := int(b.crew[0].clone_id)
	var learned: Array = service.complete_video_lesson(77, record, [{"station":2,"clone_id":clone_a,"role":0},{"station":3,"clone_id":99999,"role":0}])
	check(learned == [clone_a], "only actual attending assigned worker gets skill")
	var video: Dictionary = service.progression_director.milestones.get("first_video_training_completed", {})
	check(video.get("station_ids", []) == [2] and video.get("clone_ids", []) == [clone_a], "first video fact retains complete attendance evidence")
	check(not service.progression_director.has_milestone("first_group_training_completed"), "one real learner plus stale participant is not group completion")
	check(not service._milestone_matches_service("first_video_training_completed", 3, "sausage"), "untrained table cannot confirm post-video service")
	check(service._milestone_matches_service("first_video_training_completed", 2, "sausage"), "actual taught crew can confirm post-video service")
	var original: int = int(a.crew[0].clone_id)
	a.crew[0].clone_id = clone_b
	check(not service._milestone_matches_service("first_video_training_completed", 2, "sausage"), "replaced crew cannot reuse attendance proof")
	a.crew[0].clone_id = original
	service.complete_video_lesson(78, record, [{"station":2,"clone_id":clone_a,"role":0},{"station":3,"clone_id":clone_b,"role":0}])
	check(service.progression_director.has_milestone("first_group_training_completed"), "actual shared two-table lesson confirms group")
	var replacement_record: Dictionary = record.duplicate(true)
	replacement_record.id = 56
	service.complete_video_lesson(79, replacement_record, [{"station":2,"clone_id":clone_a,"role":0},{"station":3,"clone_id":clone_b,"role":0}])
	check(service._milestone_matches_service("first_group_training_completed", 2, "sausage"), "later group film can complete service step after replacing the first film")
	check(int(service.progression_director.milestones.first_group_training_completed.record_id) == 55, "first group fact stays immutable")
	var retrained_save: Dictionary = bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(retrained_save), "retraining evidence survives before first post-group service")
	p = service.progress
	a = service.by_id(2)
	check(service._milestone_matches_service("first_group_training_completed", 2, "sausage"), "post-load latest learned film still proves group service")
	service.progression_director.observe("live_lesson_accepted", {"clone_id":clone_a,"dish":"sausage"})
	service._count_completed_customer({"dish":"sausage","automatic_serving":true}, a)
	service._refresh_progression()
	check(service.feature_access.feature_state("kitchen_pair").unlocked, "group service opens pair without chair purchase")
	check("lab_chair" not in p.lab_upgrades, "chair is optional")
	p.cash = 0
	check(service.feature_access.feature_state("kitchen_pair").unlocked, "no funds cannot unlearn pair")
	var saved: Dictionary = bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(saved), "current-format graph roundtrip")
	p = service.progress
	service._refresh_progression()
	check(p.manual_clone_growth_completed == 2 and service.feature_access.feature_state("kitchen_pair").unlocked, "facts and known systems survive reload")
	game._shutdown_tree(game); game.free()
	print("PASS: P5.04 graph event boundaries" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
