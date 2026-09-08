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

func press_mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func check_item_controls(game) -> void:
	game.live.reset()
	game.player.rotation.y = 0
	game.camera.rotation = Vector3(-0.35, 0, 0)
	game._grab("jug")
	check(game._held_target().is_equal_approx(game.live.jug), "Pickup anchors the actual item without a jump")
	game.camera.rotation.x = 0.30
	var right_edge: Vector2
	for angle in [-0.4, 0.4]:
		game.player.rotation.y = angle
		var target: Vector2 = game._held_target()
		check(target.is_finite() and is_equal_approx(target.y, -Model.BOUNDS.y), "Looking above table keeps a finite far-edge target")
		if angle < 0: right_edge = target
		else: check(target.distance_to(right_edge) > 0.5, "Turning off-table moves the target along the edge")
	for tick in range(60):
		var before: Vector2 = game.live.jug
		game._physics_process(DELTA)
		check(before.distance_to(game.live.jug) <= game.ITEM_MOVE_SPEED * DELTA + 0.0001, "Off-table motion is bounded per frame")
	check(game.live.jug.is_equal_approx(game._held_target()), "Item reaches edge while gaze remains off table")
	game.player.rotation.y = 0
	game.camera.rotation.x = -0.8
	var before_return: Vector2 = game.live.jug
	game._physics_process(DELTA)
	check(before_return.distance_to(game.live.jug) <= game.ITEM_MOVE_SPEED * DELTA + 0.0001, "Re-entering table never teleports the item")
	for tick in range(40): game._physics_process(DELTA)
	check(game.live.jug.is_equal_approx(game._held_target()), "Item follows gaze back into the work area")
	press_key(KEY_SHIFT, true)
	game._physics_process(DELTA)
	game._move_precisely(Vector2(40, 10))
	var precise_position: Vector2 = game.live.jug
	press_key(KEY_SHIFT, false)
	game._physics_process(DELTA)
	check(game.live.jug.is_equal_approx(precise_position), "Releasing precision preserves the new position")
	game._refresh_views()
	var anchor: Vector3 = game.training.grip_marker.position
	check(game.training.grip_marker.visible and is_equal_approx(anchor.x, game.live.jug.x) and is_equal_approx(anchor.z, game.live.jug.y), "Blue marker projects the item centre")
	check(game.training.target_ring.position.distance_to(anchor) > 0.2, "Pour target stays distinct from item centre")
	check(game.training.height_dashes[0].visible and not game.production.grip_marker.visible, "Height guide belongs only to held player item")
	press_mouse(MOUSE_BUTTON_RIGHT, true)
	game._physics_process(DELTA)
	press_mouse(MOUSE_BUTTON_RIGHT, false)
	check(game.live.tilt > 0, "RMB uses the jug")
	var previous_tilt: float = game.live.tilt
	game._physics_process(DELTA)
	check(game.live.tilt < previous_tilt, "Releasing RMB straightens the jug")
	game.live.reset()
	game.live.rag = game.live.cup
	game._grab("rag")
	game.live.lift_held(0.6)
	game.live.soaked = 250
	game.live.wine = 750
	press_key(KEY_SPACE, true)
	game._physics_process(DELTA)
	press_key(KEY_SPACE, false)
	check(not game.live.squeezing and game.live.filled == 0, "Space no longer activates the rag")
	press_mouse(MOUSE_BUTTON_RIGHT, true)
	for tick in range(160): game._physics_process(DELTA)
	press_mouse(MOUSE_BUTTON_RIGHT, false)
	check(game.live.success() and game.live.squeezed_total >= 225 and conserved(game.live), "RMB alone squeezes a valid serving")
	game._physics_process(DELTA)
	check(not game.live.squeezing, "Releasing RMB stops squeezing")
	game.live.put_down()
	game._refresh_views()
	check(not game.training.grip_marker.visible and not game.training.height_dashes[0].visible, "Putting item down hides its guides")

func run() -> void:
	var save_path := "user://cafe_staff.json"
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
	game.service.open_for_business = false
	game.service.clones[0].recipes.clear()
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
	check(game.hud.teaching_panel.visible and not game.recording, "E opens dish and employee selection")
	game._begin_selected_training("wine", game.service.clones[0].id, 1)
	check(game.recording and game.player.constrained, "Selection starts teaching")
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

	print("[4/8] Pickup, height, edge continuity, guides, precision and RMB actions")
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
	check_item_controls(game)

	print("[5/8] Students observe instead of echoing cooking")
	game.cancel_recording()
	game.player.rotation.y = 0
	game.camera.rotation = Vector3(-0.15, 0, 0)
	game.start_recording()
	check(game.lecture.students.size() == 1, "Selected clone attends the presentation")
	var production_before: Dictionary = game.playback.snapshot()
	for tick in range(160): game._physics_process(DELTA)
	check(game.playback.snapshot() == production_before, "Production does not echo the demonstration")
	for tick in range(1000): game.lecture.advance(DELTA)
	check(game.lecture.students[0].actor.notebook.visible, "Student takes notes at the table")

	print("[6/8] Success, walk home, cancellation and on-demand playback")
	game.live.filled = 225
	game.live.wine = 775
	game.finish_recording()
	check(not game.recording and not game.player.constrained and not game.service.get_clone(game.selected_clone_id).recipes.is_empty(), "Success commits and releases zone immediately")
	check(game.service.stations[1].state == "training", "Employee finishes walking home before taking orders")
	for wall in game.barrier_bodies: check(wall.collision_layer == 0, "Barriers released")
	var saved: Array = game.service.get_clone(game.selected_clone_id).recipes.wine.frames.duplicate(true)
	for tick in range(1800): game.lecture.advance(DELTA)
	check(game.lecture.students.is_empty(), "Employee has returned home")
	check(game.service.stations[1].state == "idle", "Employee returns to customer service")
	game.start_recording()
	game.finish_recording()
	check(game.recording and game.service.get_clone(game.selected_clone_id).recipes.wine.frames == saved, "Failed attempt preserves earlier training")
	game.cancel_recording()
	check(game.service.get_clone(game.selected_clone_id).recipes.wine.frames == saved, "Cancellation preserves training")

	print("[7/8] Save roundtrip and validation")
	game.service.get_clone(game.selected_clone_id).recipes.clear()
	game._load_staff()
	check(game.service.get_clone(game.selected_clone_id).recipes.wine.frames.size() == saved.size(), "FPS recording loads")
	check(not game._valid_frame({}), "Incomplete save rejected")
	var invalid: Dictionary = saved[0].duplicate(true)
	invalid.elevations.jug = -1
	check(not game._valid_frame(invalid), "Negative height rejected")
	var loaded := Model.new()
	loaded.restore(JSON.parse_string(JSON.stringify(saved.back())))
	check(loaded.success(), "JSON roundtrip preserves success")

	print("[8/8] Pause freezes player and teaching")
	game.toggle_pause()
	var old_tick: int = game.tick_count
	var old_position: Vector3 = game.player.global_position
	game._physics_process(DELTA)
	check(game.tick_count == old_tick and game.player.global_position == old_position, "Paused state remains still")
	game.queue_free()
	await process_frame
	if had_save:
		var backup := FileAccess.open(save_path, FileAccess.WRITE)
		backup.store_string(original_save)
		backup.close()
	else: DirAccess.remove_absolute(save_path)
	print("PASS: all FPS demo checks" if failures == 0 else "FAILED: %d checks" % failures)
	quit(0 if failures == 0 else 1)
