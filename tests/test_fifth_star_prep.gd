extends SceneTree
const Progression = preload("res://scripts/cafe_progression.gd")
const Journey = preload("res://scripts/cafe_journey.gd")
const SolyankaModel = preload("res://scripts/solyanka_cooking_model.gd")
var failures := 0

class Station:
	extends RefCounted
	var station_id := 1
	var manual_station := false
	var staffed := 1
	var type_id := "counter"
	var equipment: Array = []
	var recipes: Dictionary = {}
	var training = Run.new()
	var remote_summary: Dictionary = {}
	func role_count() -> int: return 3 if type_id=="solyanka_kitchen" else 2 if type_id in ["kitchen","grill_kitchen"] else 1
	func ready_crew() -> bool: return manual_station or staffed>=role_count()
class Run:
	extends RefCounted
	var phase := "idle"
	var purpose := "lesson"
	func active() -> bool: return phase!="idle"
	func summary() -> Dictionary: return {"lengths":[1,1,1]}

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("1/5: four stars unlock solyanka preparation")
	var p = Progression.new()
	p.stars = 4
	p.shift = "morning"
	p.journey_auto_served = 1
	check("solyanka" in p.available_dishes(),"Solyanka joins demand after the fourth star")
	check(p.star_requirements([],0).size()==4,"Fifth-star preparation exposes four orchestration requirements")

	print("2/5: a staffed trained kitchen satisfies the preparation gate")
	var kitchen = Station.new()
	kitchen.station_id = 6
	kitchen.type_id = "solyanka_kitchen"
	kitchen.staffed = 3
	kitchen.equipment = ["fire_kit","stir_kit","salt_kit"]
	kitchen.recipes.solyanka = {"quality":{"present":true,"grade":"B"}}
	p.orchestration_expanded = true
	p.fifth_star_solyanka_served = p.FIFTH_STAR_SOLYANKA_SERVED
	p.fifth_star_auto_served = p.FIFTH_STAR_AUTO_SERVED
	var requirements: Array = p.star_requirements([kitchen],100)
	check(requirements.all(func(r): return bool(r.done)),"Completed solyanka line satisfies all current fifth-star prep requirements")
	check(p.can_attempt([kitchen],100),"Completed fifth-star preparation unlocks the final inspection")

	print("3/5: journey finishes on final-inspection handoff")
	var goal: Dictionary = Journey.current(p,[kitchen],100,true)
	check(goal.key=="fifth_star","Journey recognizes completed orchestration chapter and exposes the final day")
	check(goal.title.contains("пяти звёзд"),"Journey hands off explicitly to the final fifth-star day")

	print("4/5: real cafe buys and installs the sixth three-role station")
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var live = game.service.progress
	live.stars = 4
	live.cash = 3000
	check(game.service.purchase("orchestration_expansion","").is_empty(),"Fourth star can buy the orchestration sector")
	check(game.service.purchase("solyanka_kitchen","",6).is_empty(),"Solyanka station can be ordered for slot six")
	var parcel: Dictionary = live.deliveries.back()
	parcel.remaining = 0.0
	parcel.owner = 1
	game.player.global_position = game.shop.installation_position(parcel)
	check(game.shop.action(1,{"action":"install_parcel","id":parcel.id}).is_empty(),"Delivered solyanka station installs")
	var real_station = game.service.by_id(6)
	check(real_station != null and real_station.type_id=="solyanka_kitchen" and real_station.role_count()==3,"Slot six builds a real three-role station")
	check(real_station.view.actors.size()==3 and real_station.view.status.text.is_empty(),"Installed view has three cooks and no world recipe-progress label")
	for item in ["fire_kit","stir_kit","salt_kit"]:
		check(game.service.purchase("equipment",item,6).is_empty(),"Can order "+item)
		parcel = live.deliveries.back()
		parcel.remaining = 0.0
		parcel.owner = 1
		game.player.global_position = game.shop.installation_position(parcel)
		check(game.shop.action(1,{"action":"install_parcel","id":parcel.id}).is_empty(),"Can install "+item)
	check(["fire_kit","stir_kit","salt_kit"].all(func(item): return item in real_station.equipment),"All three role kits install on the solyanka station")
	var tracks: Array = []
	for role in range(3):
		real_station.model.reset("solyanka")
		var item: String = real_station.model.ZONE_ITEMS[role][0]
		check(real_station.model.grab(role,item),"Role %d can own an item in its saved track"%role)
		tracks.append({"group":role+1,"frames":[real_station.model.zone_snapshot(role)]})
	real_station.recipes.solyanka={"tracks":tracks,"duration":1.0/60.0,"quality":real_station.model.quality()}
	var saved: Dictionary = game.service.save_data()
	check(saved.version==13,"Three-role kitchen advances the station save format to v13")
	check(game.service.load_data(saved),"Save with role-three item ownership loads successfully")
	live = game.service.progress
	check(game.service.by_id(6)!=null and game.service.by_id(6).recipes.has("solyanka"),"Solyanka recording survives save/load")

	print("5/5: recorded solyanka serves a real automatic customer")
	real_station = game.service.by_id(6)
	var finished := SolyankaModel.new()
	finished.equipment = ["fire_kit","stir_kit","salt_kit"]
	finished.fire_started = true
	finished.stir_progress = 1.0
	finished.salt_amount = 1.0
	for item in finished.ITEMS.slice(0,finished.MIN_CONTENTS): finished.dumped[item] = true
	var production_tracks: Array = []
	for role in range(3): production_tracks.append({"group":role+1,"frames":[finished.zone_snapshot(role)]})
	real_station.recipes.solyanka = {"tracks":production_tracks,"duration":1.0/60.0,"quality":finished.quality()}
	real_station.staffed = -1
	live.fifth_star_auto_served = 0
	live.fifth_star_solyanka_served = 0
	var cash_before: int = live.cash
	var served_before: int = game.service.served
	check(game.service.spawn_customer("solyanka"),"A real automatic customer can choose the trained solyanka station")
	var customer: Dictionary = game.service.customers.back()
	customer.path.clear()
	game.service.advance(1.0/60.0)
	game.service.advance(0.10)
	check(game.service.served==served_before+1,"Recorded solyanka completes a real customer order")
	check(live.cash>cash_before,"Solyanka customer pays for the serving")
	check(live.fifth_star_auto_served==1 and live.fifth_star_solyanka_served==1,"Production serving advances both fifth-star preparation counters")
	game._shutdown_tree(game)
	game.free()
	print("PASS: fifth-star orchestration preparation" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
