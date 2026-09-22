extends SceneTree

const Model = preload("res://scripts/cooking_model.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	run.call_deferred()

func place_on_slope(model, item: String, point: Vector2) -> String:
	model.pick_up(item)
	var held_name: String = model.held
	model.move_item(held_name, point)
	model.put_down()
	return held_name

func run() -> void:
	var start := Vector2(-1.70, 0.65)
	var downhill := Model.Layout.broken_corner_downhill()
	check(Model.Layout.broken_corner_contains(start), "regression start point lies on broken corner")

	for requested in ["jug", "cup", "rag", "plate_0", "tomato", "potato_0", "sausage_0"]:
		var model := Model.new()
		model.reset("sausage")
		var item := place_on_slope(model, requested, start)
		var before: Vector2 = model.get(item)
		for step_index in range(6):
			model.step(0.05, false, true, false)
		var after: Vector2 = model.get(item)
		var progress := (after - before).dot(downhill)
		check(progress > 0.015, "%s moves downhill on the broken corner: %.3f" % [requested, progress])

	var snapshot_model := Model.new()
	snapshot_model.reset("wine")
	place_on_slope(snapshot_model, "cup", start)
	for step_index in range(4): snapshot_model.step(0.05, false, true, false)
	var copy := Model.new()
	copy.restore(snapshot_model.snapshot())
	check(copy.cup.distance_to(snapshot_model.cup) < 0.0001, "loose-item position survives snapshot restore")
	check(Vector2(copy.loose_motion.cup.velocity).distance_to(Vector2(snapshot_model.loose_motion.cup.velocity)) < 0.0001, "loose-item velocity survives snapshot restore")

	print("PASS: all loose counter items slide down the broken corner" if failures == 0 else "FAILED: %d broken-counter loose-item checks" % failures)
	quit(1 if failures > 0 else 0)
