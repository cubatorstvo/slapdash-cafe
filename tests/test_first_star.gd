extends SceneTree
## Full service/state-machine test. Prepared food snapshots are fixtures, not a dexterity playtest.
const Scene = preload("res://scenes/cafe.tscn")
const Model = preload("res://scripts/cooking_model.gd")
const Progress = preload("res://scripts/cafe_progression.gd")
var game
var failures := 0
const DT := 1.0 / 60.0
func _initialize() -> void: run.call_deferred()
func check(value: bool, title: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", title)

func ready_food(model, dish: String) -> void:
	model.reset(dish)
	if dish == "wine":
		model.cup = model.Layout.TRAY
		model.elevations.cup = model.Layout.TRAY_Y - model.BASE_Y
		model.filled = 225.0
		model.wine = 775.0
	else:
		model.plates[0].point = model.Layout.TRAY
		model.elevations.plate_0 = model.Layout.TRAY_Y - model.BASE_Y
		if dish == "potato":
			model.potato = model.Layout.TRAY
			model.potato_heat = [1.0,1.0,1.0,1.0,1.0,1.0]
			model.potato_state = "plate_0"
		else:
			model.sausage = model.Layout.TRAY
			model.sausage_coating = 1.0
			model.sausage_state = "plate_0"
		model.elevations[dish] = model.Layout.TRAY_Y - model.BASE_Y + 0.035
	check(model.quality().grade == "S", "Prepared fixture " + dish)

func teach(station: Node3D, dish: String) -> void:
	check(game.service.request_training(station, dish, 1), "Open training")
	check(station.training.start_pass([1]), "Start whole role")
	ready_food(station.model, dish)
	station.training.advance(DT)
	station.training.finish_pass(true)
	station.training.keep_pass()
	check(station.training.accept(), "Accept whole dish")

func ticks(count: int) -> void:
	for i in range(count):
		game.service.advance(DT)
		if i % 120 == 0: await process_frame

func serve_manual(dish: String) -> void:
	var station = game.service.by_id(1)
	check(game.service.spawn_customer(dish), "Personal customer accepted")
	check(game.service.request_manual(station, dish, 1), "Begin live order")
	ready_food(station.model, dish)
	station.training.advance(DT)
	station.training.finish_pass(true)
	check(not station.training.active() and station.recipes.is_empty(), "Serving does not record a clone")

func run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var service = game.service
	var p = service.progress
	var first = service.by_id(1)
	print("[1/7] Manual opening, guided orders and actual income")
	check(first.manual_station and service.stations.size() == 1 and not service.open_for_business, "Personal counter, no starting brigade")
	check(not service.purchase("counter", "").is_empty(), "Cloning needs the first star")
	check(not service.night_action("lab_begin", {}, 1).is_empty(), "Laboratory waits for night")
	service.toggle_business()
	service.spawn_clock = 999
	for i in range(15):
		serve_manual(Progress.DISHES[i % 3])
		await ticks(60 * 15)
	check(p.manual_served == 15 and service.served == 15 and p.cash == 435, "Fifteen real payments; no practice income")
	check(not p.can_attempt(service.stations, service.served), "Laboratory remains necessary")
	service.open_for_business = false
	check(service.request_manual(first, "wine", 1), "Free practice")
	ready_food(first.model, "wine")
	first.training.advance(DT)
	first.training.finish_pass(true)
	check(p.manual_served == 15 and p.cash == 435, "Practice cannot farm money")
	print("[2/7] Closing drains cooking, night has no forced timer")
	service.open_for_business = true
	service.spawn_clock = 999
	check(service.spawn_customer("wine"), "Last customer")
	check(service.request_manual(first, "wine", 1), "Last live order")
	p.shift_elapsed = Progress.SHIFT_SECONDS - DT
	service.advance(DT * 2)
	check(p.shift == "closing" and not service.open_for_business, "Finite shift stops arrivals")
	ready_food(first.model, "wine")
	first.training.advance(DT)
	first.training.finish_pass(true)
	service.advance(DT)
	check(p.shift == "night", "Night begins after last cooking")
	var cash: int = p.cash
	service.advance(5000)
	check(p.shift == "night" and p.cash == cash, "Night neither spawns customers nor auto-skips")
	print("[3/7] Three laboratory assemblies, free mistakes, one taster")
	for sequence in [[0,1,2],[2,0,1],[1,2,0]]:
		check(service.night_action("lab_begin", {}, 1).is_empty(), "Buy one lab kit")
		var paid: int = p.cash
		check(not service.night_action("lab_switch", {"index": -1}, 1).is_empty() and p.cash == paid, "Incorrect connection is retryable without cost")
		for index in sequence: check(service.night_action("lab_switch", {"index": index}, 1).is_empty(), "Connect laboratory")
	check(p.lab_stage == 3 and p.cash == cash - 180, "Laboratory completed for 180")
	check(service.next_day().is_empty() and p.day == 2, "Rest until next morning")
	check(p.can_attempt(service.stations, service.served), "First star requirements complete")
	check(service.start_banquet(1).is_empty(), "Invite the taster")
	service.advance(DT)
	check(p.phase == "tasting" and first.training.purpose == "tasting", "Live tasting starts")
	var inspector = first.taster
	first.training.advance(DT)
	first.training.finish_pass(true)
	check(p.phase == "tasting" and p.tasting_done.is_empty() and first.taster == inspector, "D fails only this dish; same taster stays")
	for dish in Progress.DISHES:
		check(first.training.dish == dish, "Taster requests each starter dish")
		ready_food(first.model, dish)
		first.training.advance(DT)
		first.training.finish_pass(true)
	check(p.stars == 1 and p.phase == "won" and first.recipes.is_empty(), "First star unlocks clones, personal counter stays manual")
	check(service.purchase("counter", "").is_empty(), "Buy first brigade")
	var brigade = service.by_id(2)
	for dish in Progress.DISHES: teach(brigade, dish)
	check(brigade.recipes.size() == 3 and first.manual_station, "Independent automatic and personal counters")
	print("[4/7] Night decoration places actual chosen anchors")
	service.end_shift()
	service.advance(DT)
	check(p.shift == "night", "Can close early")
	check(service.night_action("garland_begin", {}, 1).is_empty(), "Buy garland once")
	var paid: int = p.cash
	check(service.night_action("garland_begin", {}, 1).is_empty() and p.cash == paid, "Resuming garland cannot charge twice")
	check(not service.night_action("garland_anchor", {"point": [0,2,0]}, 1).is_empty(), "Reject unsupported anchor")
	for point in [[-4,2,-7.35],[-2,2.8,-7.35],[0,2.2,-7.35],[2,3,-7.35]]:
		check(service.night_action("garland_anchor", {"point": point}, 1).is_empty(), "Place wall anchor")
	check(p.garland_complete and p.popularity == 15, "Physical garland rewards popularity once")
	game.development.refresh()
	check(game.development.cable_root.get_child_count() > 4, "Anchors produce visible sagging cable")
	print("[5/7] Launch, catch, unique style and exact replay")
	var model = Model.new()
	model.sauce_ramp = true
	model.reset("sausage")
	model.pick_up("sausage_0")
	model.move_item("sausage", Vector2(Model.RAMP_X, Model.RAMP_START))
	model.lift_held(1.0)
	model.put_down()
	check(model.sausage_state == "ramp", "Release on ramp")
	var peak := 0.0
	var caught := false
	for i in range(240):
		model.plates[0].point = model.sausage
		model.elevations.plate_0 = 1.0 - model.BASE_Y
		model.step(DT, false, true, false)
		peak = maxf(peak, model.BASE_Y + float(model.elevations.sausage))
		if model.sausage_state == "plate_0": caught = true; break
	check(caught and peak >= 2.8 and model.sausage_coating >= 0.9 and model.sausage_showy, "High launch coats and is caught on plate")
	model.plates[0].point = model.Layout.TRAY
	model.elevations.plate_0 = model.Layout.TRAY_Y - model.BASE_Y
	model._sync_carried_food()
	var report: Dictionary = model.quality()
	check(report.grade == "S" and report.style_count == 1 and is_equal_approx(report.style_multiplier, 1.2), "Style adds 20 percent separately from quality")
	var replica = Model.new()
	replica.restore(model.snapshot())
	check(replica.quality() == report, "Clone restores trick and quality exactly")
	print("[6/7] Save thread coalesces writes, preserves detached records")
	var snapshot: Dictionary = service.save_data()
	var writer = game.save_writer
	var started := Time.get_ticks_usec()
	writer.request(snapshot, "user://shift-test.save")
	var enqueue_us := Time.get_ticks_usec() - started
	p.cash += 1
	writer.request(service.save_data(), "user://shift-test.save")
	p.cash += 1
	writer.request(service.save_data(), "user://shift-test.save")
	writer.flush()
	var file := FileAccess.open("user://shift-test.save", FileAccess.READ)
	var saved = bytes_to_var(file.get_buffer(file.get_length()).decompress_dynamic(268435456, FileAccess.COMPRESSION_DEFLATE))
	file.close()
	check(writer.last_error == OK and writer.writes == 2, "Active save plus latest pending snapshot")
	check(saved.progression.cash == p.cash and snapshot.progression.cash == p.cash - 2, "Detached snapshot and newest disk state")
	check(service.load_data(saved) and service.by_id(1).manual_station and service.progress.garland_complete, "Manual counter, night lab and garland persist")
	print("SAVE: enqueue_us=", enqueue_us, " worker_ms=", writer.last_write_ms)
	# A minute-long record exercises the expensive serializer while frame processing continues.
	var frames: Array = []
	frames.resize(3600)
	frames.fill(model.snapshot())
	started = Time.get_ticks_usec()
	writer.request({"long_record": frames}, "user://shift-thread-test.save")
	enqueue_us = Time.get_ticks_usec() - started
	var heartbeat := 0
	while writer.worker != null:
		heartbeat += 1
		await process_frame
	check(heartbeat > 0 and writer.last_error == OK, "Frame processing continues during large save")
	print("SAVE_LARGE: enqueue_us=", enqueue_us, " frames_during_write=", heartbeat, " worker_ms=", writer.last_write_ms)
	print("[7/7] UI and second-star gates remain reachable")
	p = service.progress
	p.cash = 1000
	check(service.purchase("counter", "").is_empty(), "Second independent brigade")
	check(service.purchase("decor", "plants").is_empty(), "Reach popularity threshold")
	check(service.next_day().is_empty() and p.can_attempt(service.stations, service.served), "Second-star milestone follows clone training")
	check(service.start_banquet(1).is_empty(), "Start second-star inspection")
	service.advance(DT)
	first = service.by_id(1)
	check(p.phase == "showcase" and first.training.start_pass([1]), "Personal cooking remains part of later banquet")
	ready_food(first.model, "potato")
	first.training.advance(DT)
	first.training.finish_pass(true)
	await ticks(60 * 180)
	check(p.stars == 2 and p.phase == "won", "Later brigade banquet still awards second star")
	for tab in ["overview", "stations", "decor", "star", "night"]:
		game.office.open(tab)
		await process_frame
	game.office.close()
	game._shutdown_tree(game)
	game.free()
	print("PASS: manual opening, nights, lab, tasting, style, saves and later banquet" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
