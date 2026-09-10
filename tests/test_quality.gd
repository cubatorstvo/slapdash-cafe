extends SceneTree
const M = preload("res://scripts/cooking_model.gd")
const Team = preload("res://scripts/team_cooking_model.gd")
const Scene = preload("res://scenes/cafe.tscn")
const DT := 1.0 / 60
var errors := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: errors += 1; printerr("FAIL: ", message)
func total(m) -> float: return m.wine + m.filled + m.soaked + m.spilled() + m.lost
func run() -> void:
	check(M.Quality.style_multiplier(1) == 1.2 and M.Quality.style_multiplier(2) == 1.5 and M.Quality.style_multiplier(10) == 2, "Independent style multiplier is capped at x2")
	var m := M.new()
	m.reset("potato")
	check(m.potatoes.size() == 3 and m.sausages.size() == 3, "Three distinct items of each kind")
	m.pick_up("potato_1")
	m.potato_heat = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0]
	check(m.quality().grade == "D", "Food in hand never contributes to plated quality")
	m.move_item("potato", M.PLATE_CENTER)
	m.put_down()
	check(m.quality().grade == "B", "Three of six plated faces gives B dynamically")
	m.pick_up("potato_2")
	check(m.cooked_faces() == 0 and m.quality().grade == "B", "Other potato keeps own heat; plated item still scored")
	m.move_item("potato", Vector2(0, 2))
	m.put_down()
	check(m.elevations.potato < -0.99, "Food can be dropped to station floor")
	var replay := M.new()
	var snap := m.snapshot()
	replay.restore(JSON.parse_string(JSON.stringify(snap)))
	check(JSON.stringify(replay.snapshot()) == JSON.stringify(snap), "All six independent foods replay exactly")
	m.reset("wine")
	m.filled = 225
	m.wine = 775
	check(m.quality().grade == "S", "Correct serving without waste gives S")
	m.filled = 300
	m.wine = 700
	check(m.quality().grade == "B", "Overfilling loses volume criterion")
	m.pick_up("cup")
	m.elevations.cup = 1.0
	for i in range(120):
		m.move_item("cup", m.jug - Vector2(0.26, 0))
		m.step(DT, true, false, false)
	check(m.filled < 300 and m.wine > 700, "Cup uses shared pouring and returns wine to jug")
	check(absf(total(m) - 1000) < 0.01, "Cup pouring conserves volume including overflow")
	m.put_down()
	m.pick_up("jug")
	m.move_item("jug", Vector2(0, 2))
	m.elevations.jug = 0.4
	for i in range(130): m.step(DT, true, false, false)
	check(m.spilled() > 100, "Strong tilt produces substantial floor spill")
	check(absf(total(m) - 1000) < 0.01, "Heavy spill retains all liquid")
	m.put_down()
	var puddle: Array = m.puddles.back()
	m.pick_up("rag")
	m.move_item("rag", Vector2(puddle[0], puddle[1]))
	m.lift_held(-10)
	for i in range(120): m.step(DT, false, true, false)
	check(m.soaked > 0, "Floor spill can be wiped at floor height")
	m.move_item("rag", m.jug)
	m.elevations.rag = 1.0
	var before := m.wine
	for i in range(180): m.step(DT, true, false, true)
	check(m.wine > before and absf(total(m) - 1000) < 0.01, "Rag recovers wine back into jug without creating liquid")
	var t := Team.new()
	t.water = 600
	t.pasta = 120
	t.cooked = 0.3
	t.stirred = 0.5
	t.pasta_salt = 2
	t.grab(1, "pot")
	t.positions.pot = Team.PASTA_PLATE - Vector2(0.2, 0)
	t.heights.pot = 0.6
	for i in range(250): t.step([{}, {"use": true}], DT)
	check(t.served_pasta > 100 and absf(t.served_cooked - 0.3) < 0.001, "Pot can plate undercooked pasta with actual portion quality")
	t.cooked = 1
	check(absf(t.served_cooked - 0.3) < 0.001, "Later cooking cannot improve an already served portion")
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var st = game.service.stations[0]
	st.training.open("potato", 1)
	st.training.start_pass([1])
	st.model.pick_up("potato_0")
	st.model.move_item("potato", M.PLATE_CENTER)
	st.model.put_down()
	st.training.advance(DT)
	st.training.finish_pass()
	st.training.keep_pass()
	check(st.training.can_accept() and st.model.quality().grade == "D", "Raw plated potato can be taught at D")
	check(st.training.accept() and st.recipes.potato.quality.grade == "D", "Low quality recipe saved with independent style multiplier")
	st.training.open("potato", 1)
	st.training.start_pass([1])
	st.model.pick_up("potato_1")
	st.training.advance(DT)
	game.bind_training()
	var before_pause: Dictionary = st.model.snapshot()
	var pause_tick: int = st.training.tick
	st.training.finish_pass()
	check(st.training.phase == "confirm_finish", "Unplated component asks for confirmation")
	game.bind_training()
	check(game.menu.opened(), "Confirmation menu opens")
	st.training.advance(DT)
	check(st.training.tick == pause_tick and st.model.snapshot() == before_pause, "Confirmation freezes physics, hands and tape")
	game.menu.close()
	st.training.resume_pass()
	game.bind_training()
	check(st.training.phase == "recording" and st.model.held == "potato", "Continue keeps held item and same take")
	st.training.finish_pass()
	game.bind_training()
	check(game.menu.opened(), "Repeated confirmation opens again in the same take")
	st.training.finish_pass(true)
	st.training.keep_pass()
	check(st.training.accept() and st.recipes.potato.quality.grade == "D", "Explicitly confirmed empty serving can be saved")
	check(st.recipes.potato.quality.price_factor == 0, "Empty serving earns no money")
	var combined := M.Quality.text(m.quality())
	check(not combined.contains("РЕЦЕПТ И ПРОГРЕСС") and not combined.contains("НА ПОДАЧЕ"), "One recipe block replaces duplicate progress and tray sections")
	game.free()
	print("PASS: live grading, partial recipes, independent stock and conserved pouring" if errors == 0 else "FAILED")
	quit(0 if errors == 0 else 1)
