extends SceneTree
## Run with Godot 4.7: --headless --path . --script tests/test_demo.gd
const Model = preload("res://scripts/station_model.gd")
const Scene = preload("res://scenes/cafe.tscn")
const Player = preload("res://scripts/fps_player.gd")
const DELTA := 1.0 / 60.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func conserved(model) -> bool:
	return absf(model.wine + model.filled + model.soaked + model.spilled() + model.lost - Model.JUG_CAPACITY) < 0.03

func press_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var save_path := "user://fps_station_recording.json"
	var had_save := FileAccess.file_exists(save_path)
	var original_save := FileAccess.get_file_as_string(save_path) if had_save else ""
	print("[1/8] Pouring, elevation limits and liquid conservation")
	var model := Model.new()
	model.pick_up("jug")
	model.tilt = 70.0
	model.cup = model.spout_target()
	for tick in range(200):
		model.step(DELTA, false, false, false)
		check(conserved(model), "Direct pour conserves volume")
	check(model.success(), "Direct pouring reaches the goal")
	check(model.filled <= 250.001 and model.spilled() > 0, "Overflow is recoverable")
	model.lift_held(100)
	check(model.elevations.jug == Model.MAX_LIFT, "Upper lift bound")
	model.lift_held(-100)
	check(model.elevations.jug >= model.minimum_jug_lift(), "Tilted jug stays above table")
	model.reset()
	model.pick_up("rag")
	model.soaked = 250
	model.wine -= 250
	model.rag = model.cup
	for tick in range(20): model.step(DELTA, false, true, true)
	check(model.filled == 0, "Rag below rim cannot fill through side of cup")
	check(conserved(model), "Low squeezing deposits on table")

	print("[2/8] Wiping requires table contact; raised rag serves successfully")
	model.reset()
	model.pick_up("jug")
	model.tilt = 70
	model.cup = Vector2(1.5, -0.6)
	for tick in range(220): model.step(DELTA, false, false, false)
	model.pick_up("rag")
	model.rag = Vector2(model.puddles[0][0], model.puddles[0][1])
	model.lift_held(0.6)
	model.step(1.0, false, true, false)
	check(model.soaked == 0, "Floating rag does not absorb")
	model.lift_held(-100)
	for tick in range(150):
		if not model.puddles.is_empty(): model.rag = Vector2(model.puddles[0][0], model.puddles[0][1])
		model.step(DELTA, false, true, false)
	check(model.soaked >= 225, "Rag picks up enough wine")
	model.rag = model.cup
	model.lift_held(0.60)
	for tick in range(160): model.step(DELTA, false, true, true)
	check(model.success() and conserved(model), "Rag-only serving is valid and conserved")
	check(Model.pace(14.99) == "Fast" and Model.pace(15.0) == "Medium", "Fast boundary")
	check(Model.pace(60.0) == "Medium" and Model.pace(60.01) == "Slow", "Medium boundary")

	print("[3/8] FPS approach, E interaction and physical boundary")
	var game := Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.session_paused = false
	game.deployed.clear()
	game.start_recording()
	check(not game.recording, "Cannot teach remotely")
	game.player.global_position = game.training.to_global(Vector3(0, 0.02, 2.0))
	game.player.rotation.y = 0
	game.camera.rotation.x = -0.15
	await physics_frame
	check(game.can_start_recording(), "Correct side of station allows E")
	var start_position: Vector3 = game.player.global_position
	press_key(KEY_E, true)
	press_key(KEY_E, false)
	check(game.recording and game.player.constrained, "E starts teaching")
	check(game.player.global_position.is_equal_approx(start_position), "Starting does not teleport player")
	for wall in game.barrier_bodies: check(wall.collision_layer == 1, "Training barriers enabled")
	for tick in range(140):
		game.player.advance(DELTA, Vector2(0, 1))
		await physics_frame
	var local: Vector3 = game.training.to_local(game.player.global_position)
	check(local.z <= Player.ZONE_MAX.y - Player.BODY_RADIUS + 0.02, "Cannot leave backwards")
	game.player.global_position = game.training.to_global(Vector3(0, 0.02, 1.8))
	for tick in range(40):
		game.player.advance(DELTA, Vector2(0, -1))
		await physics_frame
	local = game.training.to_local(game.player.global_position)
	check(local.z >= 1.35, "Player cannot pass through the table")

	print("[4/8] Crosshair pickup, scroll, R/F and precision look separation")
	game.player.global_position = game.training.to_global(Vector3(0, 0.02, 1.9))
	game.camera.look_at(game.training.jug.global_position + Vector3(0, 0.4, 0))
	check(game.training.pick_item(game.camera) == "jug", "Ray selects the jug")
	game._grab("jug")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var previous_lift: float = game.live.elevations.jug
	game._unhandled_input(wheel)
	check(game.live.elevations.jug > previous_lift, "Wheel raises held item")
	var yaw: float = game.player.rotation.y
	var pitch: float = game.camera.rotation.x
	var previous_item: Vector2 = game.live.jug
	press_key(KEY_SHIFT, true)
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(30, 5)
	game._unhandled_input(motion)
	press_key(KEY_SHIFT, false)
	check(game.player.rotation.y == yaw and game.camera.rotation.x == pitch, "Precision freezes view")
	check(game.live.jug != previous_item, "Precision moves item")
	previous_lift = game.live.elevations.jug
	press_key(KEY_R, true)
	game._physics_process(DELTA)
	press_key(KEY_R, false)
	check(game.live.elevations.jug > previous_lift, "R raises the item")

	print("[5/8] Exact 2-second delay includes actor pose and object height")
	game.cancel_recording()
	game.player.rotation.y = 0
	game.camera.rotation = Vector3(-0.15, 0, 0)
	game.start_recording()
	for tick in range(160):
		game.live.actor_position = Vector3(tick * 0.002, 0, 1.8)
		game.live.actor_yaw = tick * 0.001
		game.live.actor_pitch = -tick * 0.0005
		game.live.elevations.rag = tick * 0.001
		game.frames.append(game.live.snapshot())
		game._advance_echo()
		if tick < 120:
			check(game.echo_index == -1, "Clone waits first 120 ticks")
		else:
			check(game.echo_index == tick - 120, "Clone delay is precisely 120 ticks")
			check(game.playback.snapshot() == game.frames[tick - 120], "Pose and contents replay exactly")
	game.production.update_view(game.playback)
	var expected: Vector3 = game.production.to_global(game.playback.actor_position)
	check(game.production.worker.global_position.is_equal_approx(expected), "Actor is transformed into facing station")
	var forward: Vector3 = game.production.global_basis * (Basis(Vector3.UP, game.playback.actor_yaw) * Vector3.FORWARD)
	check(game.production.worker.global_basis.z.is_equal_approx(forward), "Clone faces same local direction as player")

	print("[6/8] Immediate result, tail drain, cancellation and on-demand playback")
	game.live.filled = 225
	game.live.wine = 775
	game.finish_recording()
	check(not game.recording and not game.player.constrained and not game.deployed.is_empty(), "Success commits and releases zone immediately")
	check(not game.production_running, "No mandatory full replay")
	for wall in game.barrier_bodies: check(wall.collision_layer == 0, "Barriers released")
	var saved: Array = game.deployed.duplicate(true)
	for tick in range(121): game._advance_echo()
	check(not game.echo_active and game.playback.success(), "Remaining delayed frames finish")
	game.toggle_production()
	for index in range(saved.size()):
		game._advance_production(DELTA)
		check(game.playback.snapshot() == saved[index], "On-demand replay is exact")
	check(game.completed_orders == 1, "Serving counted")
	game.start_recording()
	game.finish_recording()
	check(game.recording and game.deployed == saved, "Failed attempt preserves earlier training")
	game.cancel_recording()
	check(game.deployed == saved, "Cancellation preserves training")

	print("[7/8] Save roundtrip and validation")
	game.deployed.clear()
	game._load_recording()
	check(game.deployed.size() == saved.size(), "FPS recording loads")
	check(not game._valid_frame({}), "Incomplete save rejected")
	var invalid: Dictionary = saved[0].duplicate(true)
	invalid.elevations.jug = -1
	check(not game._valid_frame(invalid), "Negative height rejected")
	var loaded := Model.new()
	loaded.restore(JSON.parse_string(JSON.stringify(saved.back())))
	check(loaded.success(), "JSON roundtrip preserves success")

	print("[8/8] Pause freezes player and delayed playback")
	game.toggle_pause()
	var old_tick: int = game.echo_clock
	var old_position: Vector3 = game.player.global_position
	game._physics_process(DELTA)
	check(game.echo_clock == old_tick and game.player.global_position == old_position, "Paused state remains still")
	game.queue_free()
	await process_frame
	if had_save:
		var backup := FileAccess.open(save_path, FileAccess.WRITE)
		backup.store_string(original_save)
		backup.close()
	else: DirAccess.remove_absolute(save_path)
	print("PASS: all FPS demo checks" if failures == 0 else "FAILED: %d checks" % failures)
	quit(0 if failures == 0 else 1)
