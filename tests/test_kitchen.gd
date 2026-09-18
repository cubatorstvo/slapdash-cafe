extends SceneTree
const Model = preload("res://scripts/cooking_model.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func prepared(dish: String):
	var model := Model.new()
	model.reset(dish)
	if dish == "potato":
		model.held = ""
		model.plates[0].point = model.Layout.TRAY
		model.elevations.plate_0 = model.Layout.TRAY_Y - model.BASE_Y
		model.potato = model.Layout.TRAY
		model.potato_heat = [1.0,1.0,1.0,1.0,1.0,1.0]
		model.potato_state = "plate_0"
		model.elevations.potato = model.Layout.TRAY_Y - model.BASE_Y + 0.035
	else:
		model.held = ""
		model.plates[0].point = model.Layout.TRAY
		model.elevations.plate_0 = model.Layout.TRAY_Y - model.BASE_Y
		model.sausage = model.Layout.TRAY
		model.sausage_coating = 0.95
		model.sausage_state = "plate_0"
		model.elevations.sausage = model.Layout.TRAY_Y - model.BASE_Y + 0.035
	return model

func roundtrip(model) -> void:
	var encoded = JSON.stringify(model.snapshot())
	var parsed = JSON.parse_string(encoded)
	var replay := Model.new()
	replay.restore(parsed)
	check(replay.quality() == model.quality(), "Serialized replay preserves dish quality")
	check(replay.snapshot().keys().size() == model.snapshot().keys().size(), "Serialized replay restores the full snapshot shape")

func run() -> void:
	print("[1/3] Potato completion and quality")
	var potato = prepared("potato")
	check(potato.cooked_faces() == 6, "Prepared potato has all six cooked faces")
	check(potato.quality().present and potato.quality().grade in ["B","A","S"], "Cooked plated potato is a valid serving")
	roundtrip(potato)

	print("[2/3] Sausage completion and quality")
	var sausage = prepared("sausage")
	check(sausage.quality().present and sausage.quality().grade in ["B","A","S"], "Coated plated sausage is a valid serving")
	roundtrip(sausage)

	print("[3/3] Incomplete food remains distinguishable")
	var raw := Model.new()
	raw.reset("potato")
	check(not raw.quality().present or raw.quality().grade == "D", "Raw unplated food is not mistaken for a completed serving")

	print("PASS: deterministic kitchen completion and serialized replay" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
