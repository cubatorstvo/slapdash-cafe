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
		slippery.move_item("sausage", slippery.sausage - Vector2(0.015, 0))
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

	print("PASS: potato recovery, sausage methods and full-kit replay" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
