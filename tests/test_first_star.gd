extends SceneTree
## Current first-star regression: personal chef orders, preparation gate, tasting retry and clone unlock.
const Scene = preload("res://scenes/cafe.tscn")
const Progress = preload("res://scripts/cafe_progression.gd")
var failures := 0
const DT := 1.0 / 60.0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, title: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", title)

func ready_food(model, dish: String) -> void:
	model.reset(dish)
	if dish == "wine":
		model.cup = model.Layout.TRAY
		model.elevations.cup = model.Layout.TRAY_Y - model.BASE_Y
		model.filled = 225.0
		model.wine = 775.0
	elif dish == "potato":
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
		model.sausage_coating = 1.0
		model.sausage_state = "plate_0"
		model.elevations.sausage = model.Layout.TRAY_Y - model.BASE_Y + 0.035
	check(model.quality().present and model.quality().grade in ["B","A","S"], "Prepared fixture " + dish)

func run() -> void:
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var service = game.service
	var p = service.progress
	var first = service.by_id(1)

	print("[1/4] Opening personal chef order")
	check(first.manual_station and first.equipment == ["rag"] and p.stars == 0, "New campaign starts at the manual counter")
	first.equipment = ["jug","cup","plates","pan","sauce","rag"]
	first.apply_equipment()
	check(service.spawn_customer("sausage", false, true), "Personal chef order is accepted")
	check(service.request_manual(first, "sausage", 1), "Chef can start the queued personal order")
	ready_food(first.model, "sausage")
	first.training.advance(DT)
	first.training.finish_pass(true)
	check(p.manual_served == 1 and service.served == 1, "A completed chef order counts as manual service")
	# Eating animation is unrelated to the preparation gate; clear it for this focused progression test.
	first.state = "idle"
	first.customer_id = -1
	service.customers.clear()

	print("[2/4] First-star preparation gate")
	p.manual_served = 15
	p.lab_stage = 3
	p.shift = "morning"
	check(p.can_attempt(service.stations, service.served), "Fifteen personal services and the completed laboratory unlock tasting")

	print("[3/4] Tasting retry and three dishes")
	check(service.start_banquet(1).is_empty(), "Invite the first-star taster")
	service.advance_event(0.0)
	check(p.phase == "tasting" and first.training.purpose == "tasting", "Tasting starts on the personal counter")
	var first_dish: String = str(first.training.dish)
	first.training.advance(DT)
	first.training.finish_pass(true)
	check(p.phase == "tasting" and first.training.dish == first_dish and p.tasting_done.is_empty(), "A bad dish retries without failing the whole tasting")
	for dish in Progress.DISHES:
		check(first.training.dish == dish, "Taster requests starter dish " + dish)
		ready_food(first.model, dish)
		first.training.advance(DT)
		first.training.finish_pass(true)
	check(p.stars == 1 and p.phase == "won" and first.manual_station and first.recipes.is_empty(), "Three B+ dishes award the first star and keep the personal counter manual")

	print("[4/4] Clone production unlock")
	var brigade = service.add_station("counter", 1, false, true)
	check(service.create_clone(1.0, true).is_empty(), "First star permits creating a clone")
	check(brigade.staffed == 1 and not brigade.manual_station, "Created clone staffs the automatic counter")

	game._shutdown_tree(game)
	game.free()
	print("PASS: current first-star personal order, tasting and clone unlock" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
