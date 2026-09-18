extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("1/4: real station starts one simultaneous three-role pass")
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var station = game.service.add_station("solyanka_kitchen", 5, false, false)
	station.staffed = -1
	station.equipment = ["fire_kit", "stir_kit", "salt_kit"]
	station.apply_equipment()
	station.training.open("solyanka", 1)
	check(station.training.start_pass([1, 2, 3]), "Three distinct peers can own all three solyanka roles in one pass")
	check(station.training.live_roles == [0, 1, 2], "All three roles are live at the same time")

	print("2/4: fire, stirring and salt execute concurrently")
	station.training.inputs = {
		0: {"grab":"lighter"},
		1: {"grab":"paddle"},
		2: {"grab":"salt"}
	}
	station.training.advance(0.05)
	var target := [station.model.POT.x, station.model.POT.y]
	for _tick in range(12):
		station.training.inputs = {
			0: {"target":target, "height":0.35},
			1: {"target":target, "height":0.35},
			2: {"target":target, "height":0.35}
		}
		station.training.advance(0.05)
	for _tick in range(45):
		station.training.inputs = {
			0: {"target":target, "height":0.35, "use":true},
			1: {"target":target, "height":0.35, "use":true},
			2: {"target":target, "height":0.35, "use":true}
		}
		station.training.advance(0.05)
	check(station.model.fire_started, "Fire role lights the cauldron during the shared take")
	check(station.model.stir_progress >= 0.999, "Stir role reaches full mixing during the same take")
	check(station.model.salt_amount >= 1.0, "Salt role seasons the soup during the same take")

	print("3/4: one take records three linked tracks")
	station.training.finish_pass(true)
	check(station.training.phase == "review", "Confirmed three-role pass reaches review")
	check(station.training.pending_tracks.size() == 3, "Review contains three recorded role tracks")
	var groups: Array = station.training.pending_tracks.map(func(track): return int(track.get("group", -1)))
	check(groups[0] > 0 and groups[0] == groups[1] and groups[1] == groups[2], "Simultaneous roles share one recording group")
	check(station.training.pending_tracks.all(func(track): return not track.get("frames", []).is_empty()), "Every role captured frames")

	print("4/4: imperfect shared take can still be accepted")
	station.training.keep_pass()
	check(station.training.can_accept(), "Three linked tracks are a complete record even with recipe mistakes")
	check(station.training.accept(), "Training accepts a non-S solyanka instead of blocking completion")
	check(station.recipes.has("solyanka") and station.recipes.solyanka.tracks.size() == 3, "Accepted recipe stores all three tracks")
	check(str(station.recipes.solyanka.quality.grade) != "S", "Missing thirteen dumped items lowers quality rather than blocking the record")
	game._shutdown_tree(game)
	game.free()
	print("PASS: simultaneous three-role solyanka training" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
