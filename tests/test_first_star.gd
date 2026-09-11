extends SceneTree
## Full service/state-machine test. Prepared food snapshots are fixtures, not a dexterity playtest.
const Scene = preload("res://scenes/cafe.tscn")
const Model = preload("res://scripts/cooking_model.gd")
const Progress = preload("res://scripts/cafe_progression.gd")
var game
var failures := 0
const DT := 1.0 / 60.0
func _initialize() -> void: run.call_deferred()
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
	else:
		model.plates[0].point = model.Layout.TRAY
		model.elevations.plate_0 = model.Layout.TRAY_Y - model.BASE_Y
		if dish == "potato":
			model.potato = model.Layout.TRAY
			model.potato_heat = [1.0,1.0,1.0,1.0,1.0,1.0]
			model.potato_state = "plate_0"
		else:
			model.sausage = model.Layout.TRAY
			model.sausage_coating = 1.0
			model.sausage_state = "plate_0"
		model.elevations[dish] = model.Layout.TRAY_Y - model.BASE_Y + 0.035
	check(model.quality().grade == "S", "Prepared fixture " + dish)

func teach(station: Node3D, dish: String) -> void:
	check(game.service.request_training(station, dish, 1), "Open training")
	check(station.training.start_pass([1]), "Start whole role")
	ready_food(station.model, dish)
	station.training.advance(DT)
	station.training.finish_pass(true)
	station.training.keep_pass()
	check(station.training.accept(), "Accept whole dish")

func ticks(count: int) -> void:
	for i in range(count):
		game.service.advance(DT)
		if i % 120 == 0: await process_frame

func run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var service = game.service
	var p = service.progress
	print("[1/8] Fresh cafe, price gates, demand outside trained menu")
	check(service.stations.size() == 1 and p.cash == 60 and not service.open_for_business, "One crew and closed doors")
	check(not service.purchase("counter", "").is_empty() and p.cash == 60, "Cannot spend missing money")
	check(not service.purchase("kitchen", "").is_empty(), "Star gate")
	service.spawn_customer("sausage")
	await ticks(60 * 40)
	check(service.missed == 1 and p.demand.sausage.untrained == 1 and p.popularity == 0, "Untrained request leaves and reports demand without popularity penalty")
	var first = service.by_id(1)
	for dish in Progress.DISHES: teach(first, dish)
	check(first.recipes.size() == 3, "Station owns three recordings")

	print("[2/8] Actual orders finance decor and second independent crew")
	for i in range(14):
		check(service.spawn_customer(Progress.DISHES[i % 3]), "Spawn trained order")
		await ticks(60 * 16)
	check(service.served == 14 and p.cash == 410 and service.revenue == 350, "Revenue and wallet from delivered orders only")
	check(service.purchase("counter", "").is_empty(), "Buy second crew from income")
	var second = service.by_id(2)
	check(second.recipes.is_empty(), "Second brigade requires its own training")
	check(service.purchase("decor", "sign").is_empty(), "Buy visible sign")
	check(service.purchase("decor", "plants").is_empty(), "Buy plants, reach popularity milestone")
	check(p.popularity == 30 and is_equal_approx(p.arrival_interval(), 12.0), "Popularity changes arrival frequency")
	var money: int = p.cash
	check(not service.purchase("decor", "sign").is_empty() and p.cash == money, "Duplicate purchase cannot charge")
	check(p.can_attempt(service.stations, service.served), "Milestone unlocked without owning every decoration")

	print("[3/8] Upgrade adds a physical cooking alternative, preserves recordings")
	var record: Dictionary = first.recipes.sausage.duplicate(true)
	check(service.purchase("upgrade", "", 1).is_empty(), "Buy sauce ramp")
	check(first.recipes.sausage == record, "Old record untouched")
	check(is_instance_valid(first.upgrade_view), "Upgrade visible")
	var model = first.model
	model.reset("sausage")
	model.pick_up("sausage_0")
	model.move_item("sausage", Vector2(Model.RAMP_X, Model.RAMP_START))
	model.lift_held(1.0)
	model.put_down()
	check(model.sausage_state == "ramp", "Food can be released onto chute")
	model.plates[0].point = Vector2(Model.RAMP_X, Model.RAMP_END + 0.05)
	model.elevations.plate_0 = 0.40 - Model.BASE_Y
	for i in range(300): model.step(DT, false, true, false)
	check(model.sausage_coating >= 0.9 and model.sausage_state == "plate_0", "Ramp coats sausage and a plate catches it")
	model.reset("wine")
	check(model.sauce_ramp, "Reset preserves purchased equipment")

	print("[4/8] Failed personal demonstration is retryable, recipes stay intact")
	var records: Dictionary = first.recipes.duplicate(true)
	check(service.start_banquet(1).is_empty(), "Start examination")
	await ticks(1)
	check(p.phase == "showcase" and first.training.start_pass([1]), "Inspector enters first station")
	first.training.advance(DT)
	first.training.finish_pass(true)
	check(p.phase == "lost" and p.stars == 0 and first.recipes == records, "Poor showcase fails without replacing work recipes")
	var before_retry: int = p.cash
	check(service.start_banquet(1).is_empty() and p.cash == before_retry, "Free retry")
	await ticks(1)
	check(first.training.start_pass([1]), "Restart personal role")
	ready_food(first.model, "potato")
	first.training.advance(DT)
	first.training.finish_pass(true)
	check(p.phase == "service" and first.recipes == records, "Live showcase proceeds to production without overwriting")

	print("[5/8] Delegation, payout, one-time star and unlocked expansion")
	await ticks(60 * 200)
	check(p.phase == "won" and p.stars == 1, "Brigades earn first star")
	check(p.banquet_served == 9 and p.banquet_good == 9, "Nine real guests fulfilled")
	check(p.cash == before_retry + 9 * 25 + 200, "Orders plus single star reward")
	var after_win: int = p.cash
	check(not service.start_banquet(1).is_empty() and p.cash == after_win, "Cannot farm star reward")
	check(service.purchase("expansion", "").is_empty(), "Expansion now purchasable")
	check("meal" in p.available_dishes(), "New demand exists before kitchen purchase")
	service.spawn_customer("meal")
	check(p.demand.meal.untrained == 1, "Absent kitchen creates visible unmet demand")
	check(service.purchase("kitchen", "").is_empty(), "Buy unlocked kitchen with earned money")
	check(service.by_id(4).role_count() == 2 and service.by_id(4).recipes.is_empty(), "New kitchen owns two untrained cooks")

	print("[6/8] Persistence includes money, progression, plates, upgrade and recordings")
	var saved: Dictionary = service.save_data().duplicate(true)
	check(service.load_data(saved), "Load full progression save")
	check(service.progress.snapshot() == saved.progression, "Progress round trip")
	check(service.by_id(1).upgrades == ["sauce_ramp"] and service.by_id(1).recipes == records, "Recipes and upgrade restored")
	var interrupted: Dictionary = saved.duplicate(true)
	interrupted.progression.phase = "showcase"
	interrupted.progression.return_open = true
	interrupted.open = false
	check(service.load_data(interrupted) and not service.progress.busy() and service.open_for_business, "Interrupted check does not resume broken scene")

	print("[7/8] Menu pages, world presentation and host authority")
	for tab in ["overview", "stations", "decor", "star"]:
		game.office.open(tab)
		await process_frame
		check(game.office.content.get_child_count() > 0, "Ledger page " + tab)
	game.office.close()
	game.development.refresh()
	check(game.development.decor.sign.visible and game.development.decor.plants.visible, "Paid decorations rendered")
	check(not game.development.ribbon.visible and game.development.star_label.text.begins_with("★"), "Expansion and star visible")
	var count: int = service.stations.size()
	# Unknown peers never reach execute_action over the network; authority guard also applies here.
	game.session.execute_action(2, {"action": "buy", "kind": "counter"})
	check(service.stations.size() == count, "Guest cannot spend shared balance")

	print("[8/8] Deadlines freeze results and clearing absent food yields no free cash")
	game.new_cafe()
	service.progress.popularity = 30
	service.served = 12
	service.add_station("counter", 1)
	first = service.by_id(1)
	for dish in Progress.DISHES: teach(first, dish)
	service.start_banquet(1)
	await ticks(1)
	service.progress.remaining = DT
	await ticks(2)
	check(service.progress.phase == "lost" and not first.training.active(), "Showcase timeout exits training")
	var money_after_timeout: int = service.progress.cash
	await ticks(120)
	check(service.progress.cash == money_after_timeout, "No payouts after timed-out event")
	print("[balance] Real playback durations, two independently taught brigades")
	for seconds in [20, 35, 50]:
		game.new_cafe()
		service.progress.popularity = 30
		service.served = 12
		service.add_station("counter", 1)
		for station in service.stations:
			for dish in Progress.DISHES:
				ready_food(station.model, dish)
				var frames: Array = []
				frames.resize(seconds * 60)
				frames.fill(station.model.snapshot())
				station.recipes[dish] = {"duration": float(seconds), "quality": station.model.quality(), "tracks": [{"group": 1, "frames": frames}]}
		service.start_banquet(1)
		await ticks(1)
		ready_food(service.by_id(1).model, "potato")
		service.finish_showcase(service.by_id(1).model.quality())
		var elapsed := 0.0
		while service.progress.busy() and elapsed < 245:
			await ticks(60)
			elapsed += 1
		print("BALANCE: %ds recordings, outcome=%s, served=%d, seconds=%d" % [seconds, service.progress.phase, service.progress.banquet_served, elapsed])
		check(service.progress.stars == 1, "First star viable with %ds recordings" % seconds)
	game._shutdown_tree(game)
	game.free()
	print("PASS: first-star progression" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
