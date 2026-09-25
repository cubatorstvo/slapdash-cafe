extends SceneTree
## Stage 5.1 regression: ribbon gate -> sausage -> delivered gear -> potato -> wine -> 15 manual orders -> 1★.
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

func clear_serving(service, station) -> void:
	station.state = "idle"
	station.customer_id = -1
	for customer in service.customers:
		if is_instance_valid(customer.get("view")): customer.view.queue_free()
	service.customers.clear()

func serve_manual(service, station, dish: String) -> void:
	check(service.spawn_customer(dish, false, true), "Chef accepts manual order " + dish)
	check(service.request_manual(station, dish, 1), "Chef starts manual order " + dish)
	ready_food(station.model, dish)
	station.training.advance(DT)
	station.training.finish_pass(true)
	clear_serving(service, station)

func install_ordered(game, item: String) -> void:
	var p = game.service.progress
	var before_history := p.delivery_history.size()
	check(game.shop.order(item, 1).is_empty(), "Order starter equipment " + item)
	check(not p.deliveries.is_empty(), "Delivery exists for " + item)
	if p.deliveries.is_empty(): return
	var parcel: Dictionary = p.deliveries.back()
	parcel.remaining = 0.0
	check(game.shop._install_parcel(parcel).is_empty(), "Player installs starter equipment " + item)
	check(p.delivery_history.size() == before_history + 1, "Installation is recorded for " + item)

func run() -> void:
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	var service = game.service
	var p = service.progress
	var first = service.by_id(1)
	var access = service.feature_access

	print("[1/5] New cafe and first real serving")
	check(first.manual_station and p.stars == 0 and p.lab_stage == 0, "New campaign starts manual with no laboratory")
	check("sauce" in first.equipment and "plates" in first.equipment and "rag" in first.equipment, "Starter counter can really prepare sausage")
	check("pan" not in first.equipment and "jug" not in first.equipment and "cup" not in first.equipment, "Future dish equipment is not preinstalled")
	check(p.available_dishes() == ["sausage"], "Only sausage is in the initial menu")
	check(bool(access.feature_state("dish_sausage").unlocked), "Sausage is introduced at start")
	check(not bool(access.feature_state("dish_potato").unlocked) and not bool(access.feature_state("dish_wine").unlocked), "Potato and wine stay hidden before their steps")
	check(not bool(access.feature_state("clone_lab").unlocked), "Laboratory stays hidden before 1★")
	check(str(preload("res://scripts/cafe_journey.gd").current(p,service.stations,service.served,service.open_for_business,service).key) == "inaugurate", "HUD route starts at the ribbon")

	# Use the same authoritative state transition as the ribbon after proving the initial gate.
	p.cafe_inaugurated = true
	p.inauguration_first_service_pending = true
	p.shift = "open"
	service.open_for_business = true
	service.progression_director.observe(&"cafe_opened")
	service._refresh_progression()
	serve_manual(service, first, "sausage")
	p.inauguration_first_service_pending = false
	service._refresh_progression()
	check(p.manual_served == 1 and "sausage" in p.tutorial_served, "First accepted sausage is one manual learning order")
	check(service.progression_director.has_milestone("first_sausage_served"), "First sausage milestone comes from completed service")
	check(bool(access.feature_state("dish_potato").unlocked) and not bool(access.feature_state("dish_wine").unlocked), "Successful sausage introduces potato only")
	check(p.available_dishes() == ["sausage","potato"], "Ordinary menu grows only through potato")
	check(service.chef_order_recipe() == "sausage", "Without a pan the chef can keep earning on mastered sausage")

	print("[2/5] Delivered equipment introduces potato and wine")
	p.cash = 300
	install_ordered(game, "pan")
	service._refresh_progression()
	check(service.progression_director.has_milestone("first_equipment_installed"), "First starter-equipment install is a persisted milestone")
	serve_manual(service, first, "potato")
	service._refresh_progression()
	check("potato" in p.tutorial_served and service.progression_director.has_milestone("first_potato_served"), "Real potato service confirms its learning step")
	check(bool(access.feature_state("dish_wine").unlocked), "Successful potato introduces wine")
	install_ordered(game, "jug")
	install_ordered(game, "cup")
	service._refresh_progression()
	serve_manual(service, first, "wine")
	service._refresh_progression()
	check(["sausage","potato","wine"].all(func(dish): return dish in p.tutorial_served), "All three starter dishes require real successful service")
	check(p.available_dishes() == ["sausage","potato","wine"], "All starter dishes enter normal flow after introduction")
	check(not bool(access.feature_state("clone_lab").unlocked) and p.lab_stage == 0, "Three dishes do not reveal or assemble the laboratory before 1★")

	print("[3/5] First-star preparation has no laboratory gate")
	p.manual_served = 15
	p.shift = "morning"
	check(p.can_attempt(service.stations, service.served), "Fifteen manual services and three learned dishes unlock tasting without lab")
	var requirements := p.star_requirements(service.stations, service.served)
	check(requirements.size() == 2 and requirements.all(func(row): return bool(row.done)), "Zero-star checklist contains only manual work and starter dishes")

	print("[4/5] Three B+ tasting dishes award 1★")
	check(service.start_banquet(1).is_empty(), "Invite the first-star taster")
	service.advance_event(0.0)
	check(p.phase == "tasting" and first.training.purpose == "tasting", "Tasting starts on the personal counter")
	var first_dish: String = str(first.training.dish)
	first.training.advance(DT)
	first.training.finish_pass(true)
	check(p.phase == "tasting" and first.training.dish == first_dish and p.tasting_done.is_empty(), "Bad tasting attempt retries without failing the whole inspection")
	for dish in Progress.DISHES:
		check(first.training.dish == dish, "Taster requests starter dish " + dish)
		ready_food(first.model, dish)
		first.training.advance(DT)
		first.training.finish_pass(true)
	service._refresh_progression()
	check(p.stars == 1 and p.phase == "won" and p.lab_stage == 0, "Three B+ dishes award first star with laboratory still unassembled")
	check(service.progression_director.has_milestone("first_star_earned"), "First-star milestone follows the real awarded star")
	check(bool(access.feature_state("clone_lab").unlocked), "Laboratory is introduced only after 1★")
	check(not bool(access.feature_state("clone_growth").unlocked), "Clone growth still waits for the laboratory to be assembled")

	print("[5/5] Handoff to the laboratory chapter")
	var next_goal: Dictionary = preload("res://scripts/cafe_journey.gd").current(p,service.stations,service.served,service.open_for_business,service)
	check(str(next_goal.get("item","")) == "lab_0", "After 1★ the next route starts basic laboratory assembly")
	var snapshot := service.progression_director.snapshot()
	var restored = preload("res://scripts/progression/progression_director.gd").new()
	restored.setup(service)
	restored.restore(snapshot, true)
	check(restored.has_milestone("first_sausage_served") and restored.has_milestone("first_star_earned"), "Current-format progression facts survive authoritative save/load")
	check(restored.is_unlocked("clone_lab") and not restored.is_unlocked("clone_growth"), "Current-format unlock boundary survives authoritative save/load")

	game._shutdown_tree(game)
	game.free()
	print("PASS: P5.01 start-to-first-star progression" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
