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
	step({"grab": "pasta_spatula"})
	move(M.STOVE, 0.3)
	step({"use": true}, 130)
	move(Vector2(0, 0.02), 0.3)
	step({"drop": true})
	step({}, 720)
	step({"grab": "pot"})
	move(M.PASTA_PLATE, 0.5)
	step({"use": true}, 60)
	move(M.STOVE, 0.4)
	step({"drop": true})
	step({"grab": "pasta_salt_tool"})
	move(M.PASTA_PLATE, 0.6)
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
	print("PASS: two-zone meal simulation" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
