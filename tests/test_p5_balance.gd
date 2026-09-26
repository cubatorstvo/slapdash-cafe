extends SceneTree
## Finite campaign proof through purchases, lessons, paid service and inspections.
## Only cooking snapshots, travel/delivery waits and nursery waiting are accelerated.
var Food = load("res://tests/p5_balance_food.gd")
const Journey = preload("res://scripts/cafe_journey.gd")
const Visits = preload("res://scripts/cafe_visits.gd")
const MAX_EXTRA_ORDERS := 180
var game
var service
var p
var scenario := "focused"
var rows: Array = []
var extra_orders := 0
var failed_orders := 0
var stage := "start"
var last_cash := 20
var last_revenue := 0
var last_extra := 0
var spending := 0
var last_spending := 0
var reward := 0
var last_reward := 0
var stress_loss := 0

func _initialize() -> void: run.call_deferred()

func must(ok: bool, message: String) -> void:
	if ok: return
	printerr("FIRST BLOCKER: ", JSON.stringify({"scenario":scenario,"step":stage,"message":message,"cash":p.cash if p != null else -1,"extra_orders":extra_orders,"day":p.day if p != null else 0,"requirements":p.star_requirements(service.stations,service.served) if p != null else []}))
	OS.kill(OS.get_process_id()) # Stop at the first blocker, including inside bounded helper loops.

func clear_travel() -> void:
	# Payment and all counters must already have happened. Skip only diners exiting.
	for customer in service.customers.duplicate():
		must(str(customer.state) in ["leaving","eating"], "cannot discard an unsettled customer")
		service._release_order_station(service.by_id(int(customer.station)), int(customer.id))
		customer.view.queue_free()
	service.customers.clear()
	for station in service.stations:
		if station.state == "serving": station.state = "idle"; station.customer_id = -1
	service._refresh_progression()

func complete_customer(customer: Dictionary, fail := false, grade := "B") -> void:
	var station = service.by_id(int(customer.station))
	must(station != null, "order has an available station")
	if station.manual_station:
		must(service.request_manual(station, str(customer.dish), 1), "start manual " + str(customer.dish))
		if not fail: Food.prepare(station.model, str(customer.dish), grade, station.customer_order)
		station.training.advance(1.0 / 60.0)
		station.training.finish_pass(true)
	else:
		must(station.can_execute(str(customer.dish)), "automatic method exists for " + str(customer.dish))
		service._start_automatic_order(station, customer)
		# Existing executor replays the accepted physical snapshots and settles its own order.
		for index in range(80):
			advance_without_arrivals(0.05)
			if bool(customer.get("stats_finalized", false)): break
	must(bool(customer.get("stats_finalized", false)), "customer settled " + str(customer.dish))
	var cash: int = p.cash
	service.finish_customer(int(customer.id), true)
	must(p.cash == cash, "duplicate serving cannot pay twice")
	clear_travel()

func manual(dish := "", fail := false) -> void:
	if dish.is_empty(): dish = service.chef_order_recipe()
	must(not dish.is_empty(), "manual recovery has an equipped recipe")
	var cash_before: int = p.cash
	must(service.spawn_customer(dish, false, true), "manual order can arrive: " + dish)
	complete_customer(service.customers.back(), fail)
	if fail:
		must(p.cash == cash_before, "failed serving pays nothing and has no ingredient debit")
		failed_orders += 1

func auto_serve(dish: String) -> void:
	must(service.spawn_customer(dish, false, false, {}, 1), "automatic order has a trained destination: " + dish)
	complete_customer(service.customers.back())

func serve_until_milestone(dish: String, milestone: String) -> void:
	# The dispatcher can choose another already trained table before the new pupil.
	for index in range(8):
		auto_serve(dish)
		if service.progression_director.has_milestone(milestone): return
	must(false, "bounded real work after training: " + milestone)

func auto_to_count(dish: String, counter: String, target: int) -> void:
	for index in range(target + 8):
		if int(p.get(counter)) >= target: return
		auto_serve(dish)
	must(int(p.get(counter)) >= target, "bounded paid counter: " + counter)

func advance_without_arrivals(delta: float) -> void:
	# Arrival order is the deterministic scenario input; the game still runs its executors.
	service.spawn_clock = 10000.0; service.chef_order_clock = 10000.0
	service.advance(delta)

func afford(price: int) -> void:
	var start: int = extra_orders
	while p.cash < price:
		must(extra_orders < MAX_EXTRA_ORDERS and extra_orders - start < 70, "bounded earnings for price %d" % price)
		var before: int = p.cash
		manual()
		extra_orders += 1
		must(p.cash > before, "available manual work has positive net income")

func buy(item: String, station_id := 0) -> void:
	var cost: int = int(game.shop.ITEMS[item].price)
	afford(cost)
	var before: int = p.cash
	var error: String = game.shop.order(item, station_id)
	must(error.is_empty(), "order " + item + ": " + error)
	must(p.cash == before - cost, "purchase charged actual catalogue price")
	spending += cost
	var parcel: Dictionary = p.deliveries.back()
	parcel.remaining = 0.0 # Delivery travel only; price/unlock checked by order().
	if item == "lights":
		game.player.global_position = Vector3(parcel.position[0],0,parcel.position[2])
		error = game.shop.action(1,{"action":"take_parcel","id":int(parcel.id)})
	else: error = game.shop._install_parcel(parcel, game.shop.clone_delivery_claimed(parcel))
	must(error.is_empty(), "install " + item + ": " + error)
	service._refresh_progression()

func equip(station_id: int, dish: String) -> void:
	for item in service.Definition.DISH_EQUIPMENT[dish]:
		if item not in service.by_id(station_id).equipment: buy(str(item), station_id)

func checkpoint(name: String) -> void:
	var row := {"point":name,"cash_in":last_cash,"cost":spending-last_spending,"rewards":reward-last_reward,"order_income":service.revenue-last_revenue,"extra_manual_orders":extra_orders-last_extra,"cash_out":p.cash,"served":service.served,"day":p.day}
	rows.append(row); print("CHECKPOINT ", JSON.stringify(row))
	last_cash = p.cash; last_revenue = service.revenue; last_extra = extra_orders; last_spending = spending; last_reward = reward
	stage = name
	var save: Dictionary = bytes_to_var(var_to_bytes(service.save_data()))
	must(service.load_data(save), "current format reload at " + name)
	p = service.progress
	var file := FileAccess.open("user://p5_%s.save" % name, FileAccess.WRITE)
	file.store_var(save); file.close()

func nursery_action(nursery, pot: Dictionary, tool: String) -> void:
	var position: Vector3 = nursery.Layout.pot_point(int(pot.id))
	game.player.global_position = nursery.Layout.tool_point(tool)
	var error: String = nursery.action(1,{"action":"lab_tool","tool":tool})
	must(error.is_empty(), "pick nursery tool " + tool + ": " + error)
	game.player.global_position = position
	error = nursery.action(1,{"action":"lab_pot","pot":int(pot.id),"revision":int(pot.revision)})
	must(error.is_empty(), "use nursery tool " + tool + ": " + error)
	nursery.discard_infinite_tool(1)

func grow_clone() -> void:
	afford(game.laboratory.nursery.Policy.CLONE_PRICE)
	var nursery = game.laboratory.nursery
	nursery.ensure_pots()
	var pot: Dictionary = nursery.pot(0)
	var before: int = p.cash
	nursery_action(nursery, pot, "soil")
	nursery_action(nursery, pot, "liquid")
	must(p.cash == before - nursery.Policy.CLONE_PRICE, "growth pays once for the seed")
	spending += before - p.cash
	nursery_action(nursery, pot, "water")
	nursery.advance(nursery.STAGE_SECONDS)
	nursery_action(nursery, pot, "fertilizer")
	nursery.advance(nursery.STAGE_SECONDS)
	must(pot.phase == "ready", "ordinary standard formula reaches harvest")
	must(nursery.action(1,{"action":"lab_pull","pot":0,"revision":int(pot.revision),"grip":"armpits"}).is_empty(), "start manual pull")
	nursery.harvest(pot) # Only pulling duration is skipped; the initiated manual pull identifies its owner.
	nursery.departures.clear()
	service._refresh_progression()

func teach_live(station_id: int, dish: String) -> void:
	var station = service.by_id(station_id)
	var clone_id: int = int(station.crew[0].clone_id)
	must(service.request_live_lesson(dish,clone_id,1).is_empty(), "request personal lesson " + dish)
	for index in range(600):
		service.live_training.advance(0.05)
		if service.live_training.phase == "ready": break
	must(service.begin_live_lesson(1).is_empty(), "student arrives for " + dish)
	var chef = service.by_id(1)
	Food.prepare(chef.model, dish)
	chef.training.advance(1.0 / 60.0); chef.training.finish_pass(true)
	must(chef.training.accept(), "accept actual lesson " + dish)
	for index in range(600):
		service.live_training.advance(0.05)
		if not service.live_training.is_active(): break
	must(not service.live_training.is_active(), "student returns")
	must(p._p5_station_has_current_method(station,dish), "accepted B+ skill belongs to current worker")
	service._refresh_progression()

func film(dish: String) -> int:
	must(service.request_masterclass(dish,1).is_empty(), "start film " + dish)
	var station = service.masterclass_station
	must(station != null, "filming station is available")
	for role in range(station.role_count()):
		var assignments: Array = []; assignments.resize(station.role_count()); assignments.fill(0); assignments[role] = 1
		must(station.training.start_pass(assignments), "record film role %d" % role)
		Food.prepare(station.model,dish)
		station.training.advance(1.0 / 60.0)
		Food.prepare(station.model,dish) # Preserve prepared role after inactive-track composition.
		station.training.finish_pass(true); station.training.keep_pass()
	must(station.training.accept(), "accept film after recording all roles")
	service._refresh_progression()
	var record: Dictionary = service.masterclasses.back()
	must(str(record.quality.grade) in ["B","A","S"], "film B+ physical result")
	return int(record.id)

func watch(record_id: int, stations: Array, command: String) -> void:
	var request := [{"record_id":record_id,"station_ids":stations}]
	var result: Dictionary = service.queue_training_course(request,"together",command,1)
	must(str(result.get("error","")).is_empty(), "enqueue video: " + str(result))
	var repeated: Dictionary = service.queue_training_course(request,"together",command,1)
	must(int(result.course_id) == int(repeated.course_id), "duplicate command reuses course")
	for index in range(2400):
		advance_without_arrivals(0.1)
		var ready: bool = not service.staff_training.is_active() and service.training_queue.active_batch_id == 0
		var dish: String = service.masterclass_by_id(record_id).dish
		for id in stations:
			var source: Dictionary = service.by_id(int(id)).method_sources.get(dish,{})
			if int(source.get("record_id",source.get("id",0))) != record_id or service.by_id(int(id)).pending_teacher != 0: ready = false
		if ready: break
	for id in stations:
		must(p._p5_station_has_current_method(service.by_id(int(id)),str(service.masterclass_by_id(record_id).dish)), "video taught current complete crew: " + JSON.stringify(service.training_course_views()) + " executor=" + str(service.staff_training.phase))
	service._refresh_progression()

func inspection() -> void:
	var star: int = p.stars
	must(p.can_attempt(service.stations,service.served), "inspection requirements at %d stars" % star)
	must(service.start_banquet(1).is_empty(), "start inspection")
	service.advance_event(0.0)
	if star == 0:
		var chef = service.by_id(1)
		for dish in p.DISHES:
			Food.prepare(chef.model,str(dish)); chef.training.advance(1.0/60.0); chef.training.finish_pass(true)
		reward += p.FIRST_STAR_REWARD
	else:
		var income_before: int = service.revenue
		var cash_before: int = p.cash
		for index in range(1000):
			service.advance_event(1.0)
			if not service.customers.is_empty(): complete_customer(service.customers.back())
			if p.stars > star or not p.busy(): break
		reward += p.cash - cash_before - (service.revenue - income_before)
	must(p.stars == star + 1, "inspection awards next star from actual paid guests")
	service._refresh_progression()
	var cash: int = p.cash
	service.finish_banquet(true)
	must(p.cash == cash, "repeated inspection finish does not reward twice")
	if game.office.opened(): game.office.close()

func night() -> void:
	service.end_shift(); service.advance_shift(0.0)
	must(service.next_day().is_empty(), "night and next day")
	service._refresh_progression()
	must(p.day <= 16, "finite day bound")

func expand(kind: String, price: int) -> void:
	afford(price)
	var before: int = p.cash
	must(service.purchase(kind,"").is_empty(), "expand " + kind)
	must(p.cash == before-price, "expansion charges actual price"); spending += price
	service._refresh_progression()

func popularity(target: int) -> void:
	for item in ["sign","plants"]:
		if p.popularity >= target: return
		if item not in p.decorations: buy(item)
	if p.popularity < target and not p.garland_complete:
		buy("lights")
		# Let the current scene's wall validator exclude doors and other invalid anchors.
		var wall_z: float = preload("res://scripts/cafe_annex.gd").CAFE_BACK_Z
		for x in range(-39,39,2):
			if p.garland_complete: break
			var point := Vector3(x,2,wall_z)
			if not service.valid_wall_point(point): continue
			game.player.global_position = point + Vector3(0,-point.y,1)
			var error: String = game.shop.action(1,{"action":"garland_anchor","point":[point.x,point.y,point.z]})
			must(error.is_empty(), "mount owned garland: " + error + " at " + str(point))
	# Visits are a real renewable alternative to optional garland installation.
	for attempt in range(8):
		if p.popularity >= target: return
		while p.day < p.visit_next_day: night()
		Visits.advance(service,0.0)
		must(p.visit.get("phase","") == "offered", "reachable popularity source")
		must(Visits.action(service,"visit_accept",int(p.visit.id)).is_empty(), "accept visit")
		while p.day < int(p.visit.start_day): night()
		var cash_before: int = p.cash; var income_before: int = service.revenue
		for index in range(400):
			Visits.advance(service,1.0)
			if not service.customers.is_empty(): complete_customer(service.customers.back(),false,"S")
			if not Visits.busy(p): break
		must(p.visit.phase == "won", "visit wins via served guests")
		reward += p.cash-cash_before-(service.revenue-income_before)
	must(p.popularity >= target, "popularity finite bound")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): scenario = args[0]
	game = load("res://scenes/cafe.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_physics_process(false); game.new_cafe(); await process_frame
	service = game.service; p = service.progress; service.rng.seed = 57007
	# The scene's real ribbon validates proximity and opens the first order.
	var ribbon = game.find_child("Inauguration",true,false)
	if ribbon == null:
		for node in game.find_children("*","Node3D",true,false):
			if node.has_method("_host_inaugurate"): ribbon = node; break
	must(ribbon != null, "ribbon scene exists")
	game.player.global_position = ribbon.global_position
	ribbon._host_inaugurate(1)
	must(p.cafe_inaugurated, "ribbon opens pristine cafe")
	complete_customer(service.customers.back())
	ribbon._advance_host_intro(game,0.0)
	if scenario == "mistakes":
		for index in range(3): manual("sausage",true)
	buy("pan",1); manual("potato")
	buy("jug",1); buy("cup",1); manual("wine")
	checkpoint("starter_dishes")
	while not p.can_attempt(service.stations,service.served):
		must(extra_orders < 50, "bounded first-star practice")
		manual(); extra_orders += 1
	inspection(); checkpoint("star1")
	if scenario == "low_cash":
		# Adversarial input: remove funds, never inject income, unlocks or free purchases.
		stress_loss = p.cash; p.cash = 0; last_cash = 0
	for item in ["lab_0","lab_1","lab_2"]: buy(item)
	must(p.lab_formula_version == 1 and is_equal_approx(p.lab_formula_tempo,1.0), "free standard 100 percent formula")
	grow_clone(); checkpoint("first_clone")
	buy("counter"); equip(2,"sausage"); teach_live(2,"sausage"); auto_serve("sausage")
	var first = service.by_id(2)
	first.delivery_celebration_active = true
	must(p._p5_station_has_current_method(first,"sausage") and Journey._p5_current_b_plus(first,"sausage"), "delivery preserves learned structural function")
	first.delivery_celebration_active = false
	checkpoint("first_auto")
	if scenario == "mistakes": buy("rest_beanbag")
	grow_clone(); buy("counter"); equip(3,"sausage"); teach_live(3,"sausage")
	equip(2,"potato"); teach_live(2,"potato"); equip(3,"wine"); teach_live(3,"wine")
	for index in range(3): auto_serve("sausage")
	popularity(p.STAR_POPULARITY)
	var a = service.by_id(2); var b = service.by_id(3)
	var member: Dictionary = a.crew[0]; a.crew[0] = b.crew[0]; b.crew[0] = member
	must(not p.can_attempt(service.stations,service.served), "replacement cannot inherit the absent worker's recipe binding")
	member = a.crew[0]; a.crew[0] = b.crew[0]; b.crew[0] = member
	must(service.masterclasses.is_empty() and "television" not in p.lounge_items, "2 stars reachable without any film or television")
	inspection(); checkpoint("star2")
	var record := film("sausage")
	must("television" not in p.lounge_items, "first film can be saved before TV")
	buy("rest_television"); watch(record,[3],scenario+":single")
	serve_until_milestone("sausage","first_video_trained_auto_served")
	must(service.progression_director.has_milestone("first_video_trained_auto_served"), "work after actual single video")
	checkpoint("single_video")
	# A new accepted recording has work to teach both existing tables.
	record = film("sausage"); watch(record,[2,3],scenario+":group")
	serve_until_milestone("sausage","first_group_trained_auto_served")
	must(service.progression_director.has_milestone("first_group_trained_auto_served"), "actual common video unlocks pair kitchen")
	must("lab_chair" not in p.lab_upgrades, "pair branch does not depend on chair")
	expand("expansion",p.EXPANSION_PRICE); buy("kitchen"); grow_clone(); grow_clone(); equip(4,"meal")
	record = film("meal"); watch(record,[4],scenario+":meal"); auto_serve("meal")
	checkpoint("pair_kitchen")
	auto_to_count("meal","journey_meals_served",p.THIRD_STAR_MEALS)
	auto_to_count("sausage","third_star_auto_served",p.THIRD_STAR_AUTO_SERVED)
	popularity(p.THIRD_STAR_POPULARITY); inspection(); checkpoint("star3")
	expand("specialty_expansion",p.SPECIALTY_EXPANSION_PRICE); buy("grill_kitchen"); grow_clone(); grow_clone(); equip(5,"burger")
	for dish in p.SPECIALTY_DISHES:
		record = film(str(dish)); watch(record,[5],scenario+":"+str(dish)); auto_serve(str(dish))
	auto_to_count("burger","fourth_star_specialty_served",p.FOURTH_STAR_SPECIALTY_SERVED)
	auto_to_count("sausage","fourth_star_auto_served",p.FOURTH_STAR_AUTO_SERVED)
	popularity(p.FOURTH_STAR_POPULARITY); inspection(); checkpoint("star4")
	expand("orchestration_expansion",p.ORCHESTRATION_EXPANSION_PRICE); buy("solyanka_kitchen")
	for index in range(3): grow_clone()
	equip(6,"solyanka"); record = film("solyanka"); watch(record,[6],scenario+":solyanka")
	auto_to_count("solyanka","fifth_star_solyanka_served",p.FIFTH_STAR_SOLYANKA_SERVED)
	auto_to_count("sausage","fifth_star_auto_served",p.FIFTH_STAR_AUTO_SERVED)
	checkpoint("final_ready"); inspection(); checkpoint("star5")
	must(p.stars == 5 and not p.campaign_result.is_empty(), "campaign completes without milestone injection")
	must(p.cash == 20 + service.revenue + reward - spending - stress_loss, "complete economic ledger reconciles")
	print("BALANCE_RESULT ",JSON.stringify({"scenario":scenario,"rows":rows,"extra_manual_orders":extra_orders,"failed_orders":failed_orders,"cash":p.cash,"spending":spending,"order_revenue":service.revenue,"rewards":reward,"stress_loss":stress_loss,"days":p.day}))
	game._shutdown_tree(game); game.free()
	print("PASS: P5.07 paid domain progression 0 to 5 stars: " + scenario); quit(0)
