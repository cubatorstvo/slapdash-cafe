extends SceneTree
const Model = preload("res://scripts/cooking_model.gd")
const Scene = preload("res://scenes/cafe.tscn")
const DELTA := 1.0 / 60.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func tick(model, frames: Array, use_item := false) -> void:
	model.step(DELTA, use_item, not use_item, use_item)
	frames.append(model.snapshot())

func sausage_recipe(upright: bool) -> Array:
	var model := Model.new()
	model.reset("sausage")
	model.pick_up("sausage")
	model.lift_held(-10)
	var frames: Array = []
	while model.sausage.distance_to(Model.SAUCE_CENTER) > 0.005:
		model.move_item("sausage", model.sausage.move_toward(Model.SAUCE_CENTER, DELTA * 0.65))
		tick(model, frames)
	for i in range(60): tick(model, frames, upright)
	if upright: model.lift_held(0.4)
	while model.sausage.distance_to(Model.PLATE_CENTER) > 0.005:
		model.move_item("sausage", model.sausage.move_toward(Model.PLATE_CENTER, DELTA * 0.7))
		tick(model, frames, upright)
	model.put_down()
	frames.append(model.snapshot())
	check(model.success() and model.falls == 0, "Sausage has a successful %s route" % ("upright" if upright else "table-rolling"))
	return frames

func potato_recipe() -> Array:
	var model := Model.new()
	model.reset("potato")
	model.pick_up("pan")
	var frames: Array = []
	for index in range(5400):
		var time := index * DELTA
		if model.potato_state == "table":
			model.pick_up("potato")
			model.move_item("potato", Model.PAN_CENTER + Vector2(0, 0.32))
			model.put_down()
			model.pick_up("pan")
		var target := Vector2(sin(time * 1.6) * 0.24, cos(time * 1.1) * 0.20)
		model.tilt_pan((target - model.pan_tilt) / 0.003)
		tick(model, frames, true)
		if model.cooked_faces() == 6: break
	check(model.cooked_faces() == 6, "Rolling can cook all six actual faces")
	check(model.falls > 0, "Hole falls are recoverable within the same demonstration")
	check(not model.success(), "A cooked potato still needs plating")
	model.pick_up("potato")
	while model.potato.distance_to(Model.PLATE_CENTER) > 0.005:
		model.move_item("potato", model.potato.move_toward(Model.PLATE_CENTER, DELTA))
		tick(model, frames)
	model.put_down()
	frames.append(model.snapshot())
	check(model.success(), "Six cooked faces plus plating completes potato")
	print("  Potato route: %.1f s, %d recovered falls" % [frames.size() * DELTA, model.falls])
	return frames

func run() -> void:
	print("[1/6] Potato balance, six faces and recovery")
	var potato := potato_recipe()
	print("[2/6] Sausage: two valid methods and a real slip risk")
	var rolling := sausage_recipe(false)
	var upright := sausage_recipe(true)
	var slippery := Model.new()
	slippery.reset("sausage")
	slippery.pick_up("sausage")
	for i in range(160):
		slippery.move_item("sausage", slippery.sausage + Vector2(0.015, 0))
		slippery.step(DELTA, false, true, false)
		if slippery.falls > 0: break
	check(slippery.falls > 0 and slippery.held.is_empty(), "Horizontal carrying can actually slip")
	slippery.pick_up("sausage")
	check(slippery.held == "sausage", "Slipped sausage is retrievable")

	print("[3/6] Every food frame replays exactly through JSON")
	var replay := Model.new()
	for record in [potato, rolling, upright]:
		for frame in record:
			replay.restore(JSON.parse_string(JSON.stringify(frame)))
			var restored := replay.snapshot()
			check(JSON.stringify(restored) == JSON.stringify(frame), "Food snapshot survives JSON and restores all state")
		check(replay.success(), "Successful recorded food stays successful")

	print("[4/6] Staff selection, clone machine and independent recordings")
	var game := Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.service.open_for_business = false
	game.session_paused = false
	var service = game.service
	game.player.global_position = game.training.to_global(Vector3(0, 0.02, 1.7))
	game.camera.rotation = Vector3(-0.2, 0, 0)
	game.interact()
	check(game.hud.teaching_panel.visible and game.hud.dish_choice.item_count == 3, "E exposes three dishes and staff selection")
	game.hud.training_requested.emit("potato", service.clones[0].id, 1)
	check(game.recording and game.live.dish == "potato", "Teaching selection loads the chosen dish")
	game._grab("pan")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var look: Vector3 = game.camera.rotation
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(30, 20)
	game._unhandled_input(motion)
	check(game.live.pan_tilt.length() > 0 and game.camera.rotation == look, "RMB and mouse tilt the pan without rotating the camera")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	game.cancel_recording()
	game.lecture.clear_now()
	var first: Dictionary = service.clones[0]
	first.recipes = {"potato": {"frames": potato, "duration": potato.size() * DELTA}}
	var second: Dictionary = service.create_clone()
	second.recipes = {"sausage": {"frames": rolling, "duration": rolling.size() * DELTA}}
	var third: Dictionary = service.create_clone()
	third.recipes = {"sausage": {"frames": upright, "duration": upright.size() * DELTA}}
	var fourth: Dictionary = service.create_clone()
	check(service.slot_of(fourth.id) == -1 and service.clones.size() == 4, "More than three employees can exist in reserve")
	check(not first.recipes.has("sausage") and not second.recipes.has("potato"), "Teaching is per employee and per dish")
	for record in [potato, rolling, upright]:
		for frame in record: check(game._valid_frame(frame), "Recorded food passes save validation")
	var corrupt: Dictionary = potato.back().duplicate(true)
	corrupt.food.potato_orientation = [1, 0]
	check(not game._valid_frame(corrupt), "Malformed food recording rejected")

	print("[5/6] Customers arrive, order, receive exact cooking and leave")
	check(service.spawn_customer("potato"), "Potato customer appears")
	check(service.spawn_customer("sausage"), "Sausage customer appears")
	var arrivals: int = service.customers.size()
	var saw_cooking := false
	for frame in range(4200):
		service.advance(DELTA)
		for station in service.stations:
			if station.state == "cooking":
				saw_cooking = true
				if station.tick > 0: check(station.model.snapshot() == station.frames[station.tick - 1], "Employee repeats the recorded frame for the order")
	check(saw_cooking and service.served == arrivals and service.customers.is_empty(), "Guests are served and disappear only after walking out")
	check(service.revenue > 0, "Completed orders pay")
	check(service.spawn_customer("wine"), "Unknown dish can be ordered")
	for frame in range(2400): service.advance(DELTA)
	check(service.missed == 1 and service.customers.is_empty(), "Unknown recipe does not block a counter forever")
	service.reserve_station(1, fourth.id)
	check(service.stations[1].state == "training" and service.slot_of(first.id) == -1, "Reserve employee can replace a counter's cook for teaching")
	service.release_station(1)

	print("[6/6] Staff persistence, assignments and old wine compatibility")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(service.save_data()))
	check(service.load_data(saved, game._valid_frame), "Multiple employees and recipes reload")
	check(service.get_clone(second.id).recipes.sausage.frames.size() == rolling.size(), "Individual recipe survives reload")
	check(service.slot_of(fourth.id) == 1, "Counter assignment survives reload")
	check(game._valid_frame(preload("res://scripts/station_model.gd").new().snapshot()), "Existing wine frame can be imported")
	game.queue_free()
	await process_frame
	print("PASS: kitchen and cafe checks" if failures == 0 else "FAILED: %d checks" % failures)
	quit(0 if failures == 0 else 1)
