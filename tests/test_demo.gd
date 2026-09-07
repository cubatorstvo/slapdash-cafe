extends SceneTree
## Run: godot --headless --path . --script tests/test_demo.gd

const Model = preload("res://scripts/station_model.gd")
const Scene = preload("res://scenes/cafe.tscn")
const DELTA := 1.0 / 30.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func conserved(model) -> bool:
	return absf(model.wine + model.filled + model.soaked + model.spilled() + model.lost - Model.JUG_CAPACITY) < 0.02

func run() -> void:
	var save_path := "user://station_recording.json"
	var had_save := FileAccess.file_exists(save_path)
	var original_save := FileAccess.get_file_as_string(save_path) if had_save else ""
	print("[1/5] Direct pour and overflow conserve liquid")
	var model := Model.new()
	model.held = "jug"
	for tick in range(100):
		# Aim at the next tick's spout, testing the actual gradual tilt model.
		model.cup = model.jug + Vector2(0.23 + minf(95, model.tilt + 45 * DELTA) * 0.005, 0)
		model.step(DELTA, true, false, false)
		check(conserved(model), "Direct pour conserves volume")
	check(model.success(), "Direct pouring reaches the goal")
	check(model.filled <= 250.001, "Cup never overfills")
	check(model.spilled() > 0.0, "Overflow becomes a recoverable puddle")

	print("[2/5] Entire serving can be recovered with the rag")
	model.reset()
	model.cup = Vector2(1.5, -0.6)
	model.held = "jug"
	for tick in range(105): model.step(DELTA, true, false, false)
	model.tilt = 0
	model.held = "rag"
	for tick in range(150):
		if not model.puddles.is_empty():
			model.rag = Vector2(model.puddles[0][0], model.puddles[0][1])
		model.step(DELTA, false, true, false)
	check(model.soaked >= 225.0, "Rag picks up enough wine")
	model.rag = model.cup
	for tick in range(85): model.step(DELTA, false, true, true)
	check(model.success(), "Rag-only serving is valid")
	check(conserved(model), "Wiping and squeezing conserve liquid")
	var restored := Model.new()
	restored.restore(JSON.parse_string(JSON.stringify(model.snapshot())))
	check(restored.success() and conserved(restored), "Recording survives JSON roundtrip")

	print("[3/5] Tier boundaries and recoverable spills")
	check(Model.pace(14.99) == "Fast", "Fast threshold")
	check(Model.pace(15.0) == "Medium", "15 seconds is Medium")
	check(Model.pace(60.0) == "Medium", "60 seconds is Medium")
	check(Model.pace(60.01) == "Slow", "Soft deadline")
	model.reset()
	model.jug = Vector2(1.75, 0)
	model.held = "jug"
	for tick in range(70): model.step(DELTA, true, false, false)
	check(model.lost > 0.0 and conserved(model), "Wine off the table is accounted for")

	print("[4/5] Scene, failed attempt, recording, deployment and exact replay")
	var game := Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.session_paused = false
	game.deployed.clear()
	game.start_recording()
	game.finish_recording()
	check(game.recording, "Unfinished order remains editable")
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT
	button.pressed = true
	Input.parse_input_event(button)
	Input.flush_buffered_events()
	game.live.held = "jug"
	for tick in range(100):
		game.live.cup = game.live.jug + Vector2(0.23 + minf(95, game.live.tilt + 45 * DELTA) * 0.005, 0)
		game._physics_process(DELTA)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(game.live.success(), "Actual game tick responds to pouring input")
	game.finish_recording()
	check(not game.recording and not game.pending.is_empty(), "Successful show becomes deployable")
	game.deploy_recording()
	check(not game.deployed.is_empty(), "Clone receives full recording")
	var saved: Array = game.deployed.duplicate(true)
	for index in range(saved.size()):
		game._advance_production(DELTA)
		check(game.playback.snapshot() == saved[index], "Clone exactly reproduces snapshot %d" % index)
	check(game.playback.success(), "Clone finishes with a successful serving")
	game.start_recording()
	game.finish_recording()
	check(game.deployed == saved, "Failed re-training preserves working clone")
	game.reset_practice()
	check(game.deployed == saved, "Practice reset preserves working clone")
	for tick in range(1900): game._advance_production(DELTA)
	check(game.completed_orders >= 1, "Production serves and restarts")

	print("[5/5] Save loading and pause")
	game.deployed.clear()
	game._load_recording()
	check(game.deployed.size() == saved.size(), "Last deployed show loads")
	game.toggle_pause()
	var old_tick: int = game.replay_tick
	game._physics_process(DELTA)
	check(game.replay_tick == old_tick, "Pause stops replay")
	check(not game._valid_frame({}), "Broken save frames are rejected")
	game.queue_free()
	await process_frame
	if had_save:
		var backup := FileAccess.open(save_path, FileAccess.WRITE)
		backup.store_string(original_save)
		backup.close()
	else:
		DirAccess.remove_absolute(save_path)
	if failures == 0: print("PASS: all demo checks")
	else: printerr("FAILED: ", failures, " checks")
	quit(0 if failures == 0 else 1)
