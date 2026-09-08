extends SceneTree
const M = preload("res://scripts/team_cooking_model.gd")
const Scene = preload("res://scenes/cafe.tscn")
const DT := 1.0 / 60.0
var failures := 0
var model := M.new()
var first: Array = []
var second: Array = []
var frames: Array = []
var role := 0
var cursor := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func step(command := {}, count := 1) -> void:
	for i in range(count):
		var commands: Array = [{}, {}]
		commands[role] = command.duplicate(true)
		if role == 1 and cursor < first.size(): commands[0] = first[cursor]
		model.step(commands, DT)
		if role == 0: first.append(command.duplicate(true))
		else:
			second.append(command.duplicate(true))
			frames.append(model.snapshot())
		cursor += 1

func move(point: Vector2, elevation: float, count := 60) -> void:
	step({"target": [point.x, point.y], "height": elevation}, count)

func meat_role() -> void:
	step({"grab": "steak"})
	move(M.GRILL, 0.3)
	step({"drop": true})
	step({}, 370)
	step({"grab": "spatula"})
	move(M.GRILL, 0.3)
	step({"use": true})
	move(Vector2(0, 0.02), 0.3)
	step({"drop": true})
	step({"grab": "salt"})
	move(M.GRILL, 0.6)
	step({"use": true}, 40)
	move(Vector2(0, -0.48), 0.5)
	step({"drop": true})
	step({}, 220)
	step({"grab": "steak"})
	move(M.PLATE, 0.3)
	step({"drop": true})

func pasta_role() -> void:
	step({"grab": "water"})
	move(M.STOVE, 0.6)
	step({"use": true}, 160)
	move(Vector2(2.3, 0.45), 0.5)
	step({"drop": true})
	step({"grab": "pasta_bag"})
	move(M.STOVE, 0.6)
	step({"use": true}, 130)
	move(Vector2(2.25, -0.55), 0.5)
	step({"drop": true})
	step({}, 180)
	step({"grab": "spatula"})
	move(M.STOVE, 0.3)
	step({"use": true}, 130)
	move(Vector2(0, 0.02), 0.3)
	step({"drop": true})
	step({}, 720)
	step({"grab": "pot"})
	move(M.PLATE, 0.5)
	step({"use": true}, 60)
	move(M.STOVE, 0.4)
	step({"drop": true})
	step({"grab": "salt"})
	move(M.PLATE, 0.6)
	step({"use": true}, 40)
	move(Vector2(0, -0.48), 0.4)
	step({"drop": true})

func run() -> void:
	print("[1/5] Shared utensils are exclusive, failed grabs never steal")
	model.step([{"grab": "salt"}, {"grab": "salt"}], DT)
	check(model.hands == ["salt", ""] and model.owners.salt == 0 and model.conflicts.size() == 1, "One physical shaker, one owner")
	model.step([{"drop": true}, {"grab": "salt"}], DT)
	check(model.hands == ["", "salt"], "Second role can pick up a released utensil")
	model.reset()
	print("[2/5] Full meal from two command tapes, shared kitchen and exact production replay")
	meat_role()
	check(model.meat_state == "plate" and model.meat_sides[0] >= 0.999 and model.meat_sides[1] >= 0.999 and model.meat_salt >= 1, "First role cooks and salts both-sided steak")
	check(not model.success(), "Steak alone is not a meal")
	model.reset()
	role = 1
	cursor = 0
	pasta_role()
	check(model.success(), "Second role completes pasta while first tape cooks meat")
	print("  Joint recording: %.1f seconds" % model.elapsed)
	var replay := M.new()
	var encoded: Array = JSON.parse_string(JSON.stringify(frames))
	for frame in encoded:
		check(M.valid(frame), "Joint snapshot validates")
		replay.restore(frame)
	check(replay.success(), "Joint recording survives JSON")
	var commands_replay := M.new()
	for i in range(second.size()): commands_replay.step([first[i] if i < first.size() else {}, second[i]], DT)
	check(commands_replay.snapshot() == model.snapshot(), "Command replay reproduces the shared meal deterministically")
	print("[3/5] Teaching phases, retakes, observers and old recording safety")
	var game := Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.service.open_for_business = false
	game.session_paused = false
	while game.service.clones.size() < 2: game.service.create_clone()
	var ids := [game.service.clones[0].id, game.service.clones[1].id]
	game.team.start("roles", ids, -1)
	check(game.team.phase == "role1" and game.lecture.students.size() == 2, "Two employees observe first role")
	check(game.lecture.students[0].home == game.service.stations[3].view.to_global(Vector3(-1.35, 0, 1.85)), "Employee returns to the newly assigned team counter")
	check(not game.service.stations[3].view.actors[0].visible or game.service.stations[3].state == "training", "No employee cooks during training")
	game.team.tapes[0] = first.duplicate(true)
	game.team.finish()
	check(game.team.phase == "between", "First role can finish before complete meal")
	game.team.finish()
	check(game.team.phase == "role2" and game.team.model.water == 0 and game.team.model.meat_state == "raw", "Role two starts from a clean shared kitchen")
	game.team.retake()
	check(game.team.tapes[0].size() >= first.size() and game.team.tick == 0, "Retry second role preserves first tape")
	game.team.model.restore(frames.back())
	game.team.frames = frames.duplicate(true)
	game.team.tick = frames.size()
	game.team.finish()
	check(game.team.phase == "idle" and game.service.team_recipe.clone_ids == ids, "Successful full recording commits to selected team")
	var old_frames: Array = game.service.team_recipe.frames
	game.team.start("roles", ids, -1)
	game.team.cancel()
	check(game.service.team_recipe.frames == old_frames, "Cancel keeps existing successful record")
	for i in range(2500): game.lecture.advance(DT)
	check(game.lecture.students.is_empty() and game.service.stations[3].state == "idle", "Students walk home before taking orders")
	print("[4/5] Fourth counter serves complete meals; original counters stay separate")
	check(game.service.stations.size() == 4, "Original three plus team station")
	check(game.service.spawn_customer("meal"), "A meal order can arrive")
	check(game.service.stations[3].state == "waiting", "Meal routes to fourth counter")
	for i in range(6000): game.service.advance(DT)
	check(game.service.served == 1 and game.service.revenue > 0 and game.service.customers.is_empty(), "Team repeats joint recording, pays, customer leaves")
	print("[5/5] New saves preserve both tiers and reject corrupt team recordings")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.service.save_data()))
	check(game.service.load_data(saved, game._valid_frame), "Two-tier save loads")
	check(game.service.record_for(3, "meal").frames.size() == old_frames.size(), "Team recording survives save")
	var damaged: Dictionary = saved.duplicate(true)
	damaged.team_recipe.frames[0].poses = []
	check(not game.service.load_data(damaged, game._valid_frame), "Invalid team data cannot replace valid roster")
	game.queue_free()
	await process_frame
	print("PASS: team cooking and teaching" if failures == 0 else "FAILED: %d checks" % failures)
	quit(0 if failures == 0 else 1)
