extends SceneTree

const Progression = preload("res://scripts/cafe_progression.gd")
const Journey = preload("res://scripts/cafe_journey.gd")
const Director = preload("res://scripts/progression/progression_director.gd")
var failures := 0

class Station:
	extends RefCounted
	var station_id := 0
	var manual_station := false
	var masterclass_station := false
	var staffed := 1
	var type_id := "counter"
	var equipment: Array = []
	var recipes: Dictionary = {}
	var method_sources: Dictionary = {}
	var crew: Array = []
	var training = null
	var remote_summary: Dictionary = {}
	func _init(id: int, kind: String, clone_ids: Array) -> void:
		station_id = id
		type_id = kind
		staffed = clone_ids.size()
		for clone_id in clone_ids: crew.append({"clone_id":clone_id,"name":"Клон %d" % clone_id,"tempo":1.0})
	func role_count() -> int: return 3 if type_id == "solyanka_kitchen" else 2 if type_id in ["kitchen","grill_kitchen"] else 1
	func ready_crew() -> bool: return crew.size() >= role_count()
	func missing_recipe_equipment(_dish: String) -> Array: return []
	func dishes() -> Array: return recipes.keys()
	func bind(dish: String, clone_ids: Array, record_id := 1) -> void:
		recipes[dish] = {"quality":{"present":true,"grade":"B"}}
		method_sources[dish] = {"id":record_id,"record_id":record_id,"clone_ids":clone_ids.duplicate()}

class Service:
	extends Node
	var progress = Progression.new()
	var stations: Array = []
	var masterclasses: Array = []
	var group_registry = null
	var progression_director
	func compatible_training_station_ids(_record_id: int) -> Array: return [2,3]
	func by_id(id: int):
		for station in stations:
			if station.station_id == id: return station
		return null

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func mark(director, event_id: String, payload := {}) -> void:
	director.observe(StringName(event_id), payload)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var service := Service.new()
	root.add_child(service)
	var p = service.progress
	p.stars = 2
	p.lab_stage = 3
	p.lab_formula_version = 1
	p.lab_formula_tempo = 1.0
	p.next_clone_id = 103
	p.cash = 10000
	p.shift = "morning"
	var a := Station.new(2,"counter",[101])
	var b := Station.new(3,"counter",[102])
	for dish in ["sausage","potato"]: a.bind(dish,[101],10)
	b.bind("wine",[102],11)
	service.stations = [a,b]
	var director := Director.new()
	service.progression_director = director
	director.setup(service)
	mark(director,"live_lesson_accepted",{"clone_id":101,"dish":"sausage"})
	mark(director,"auto_served",{"station_id":2,"dish":"sausage"})
	director.reconcile()
	check(director.is_unlocked("video_recording"),"2★ plus personal lesson and real auto service unlock filming")
	check(Journey.current(p,service.stations,99,true,service).key == "scale_first_film","2★ route starts with a saved film")

	service.masterclasses = [{"id":41,"dish":"sausage","source_type":"counter","name":"Сосиска · фильм"}]
	mark(director,"masterclass_saved",{"record_id":41,"dish":"sausage"})
	check(director.is_unlocked("video_training"),"saved film unlocks single-table video training")
	check(Journey.current(p,service.stations,99,true,service).key == "scale_television","film points to the existing lounge television")
	p.lounge_items.append("television")
	mark(director,"television_installed",{})
	check(Journey.current(p,service.stations,99,true,service).key == "scale_single_video","single-table viewing comes before group setup")
	check(Journey.current(p,service.stations,99,true).key == "scale_single_video","service-free objective follows persisted milestones instead of getting stuck on film lookup")

	mark(director,"video_training_completed",{"station_count":1,"station_ids":[2],"clone_ids":[101],"record_id":41,"dish":"sausage"})
	check(not director.is_unlocked("group_training"),"completed viewing alone does not unlock group training")
	check(Journey.current(p,service.stations,99,true,service).key == "scale_single_video_work","viewing must be followed by a real automatic serving")
	mark(director,"video_trained_auto_served",{"station_id":2,"dish":"sausage"})
	director.migrate_from_game_state()
	director.reconcile()
	check(director.has_milestone("two_compatible_stations_seen"),"two compatible production tables are recorded from real cafe state")
	check(director.is_unlocked("group_training"),"single viewing, its auto serve and two compatible tables unlock grouping")
	check(Journey.current(p,service.stations,99,true,service).key == "scale_group_video","route now asks for one real multi-table session")

	mark(director,"group_training_completed",{"station_count":2,"station_ids":[2,3],"clone_ids":[101,102],"record_id":41,"dish":"sausage"})
	check(director.is_unlocked("formula_research"),"real group completion unlocks formula research")
	check(not director.is_unlocked("kitchen_pair"),"group completion without post-training service does not unlock paired kitchen")
	check(Journey.current(p,service.stations,99,true,service).key == "scale_group_work","queue creation is not enough; group learning needs a served order")
	mark(director,"group_trained_auto_served",{"station_id":2,"dish":"sausage"})
	check(director.is_unlocked("kitchen_pair"),"post-group automatic service unlocks paired kitchen")
	check(not director.is_unlocked("recalibration"),"recalibration stays closed until a formula is actually useful")
	p.lab_formula_tempo = 1.20
	director.migrate_from_game_state()
	director.reconcile()
	check(director.has_milestone("formula_improvement_relevant") and director.is_unlocked("recalibration"),"faster formula opens recalibration as an independent branch")
	mark(director,"recalibration_completed",{"clone_id":101,"before":1.0,"after":1.2})

	p.expanded = true
	var pair := Station.new(4,"kitchen",[201,202])
	pair.equipment = ["meat_kit","pasta_kit"]
	pair.bind("meal",[201,202],51)
	service.stations.append(pair)
	check(Journey.current(p,service.stations,99,true,service).key == "first_meal","paired kitchen waits for its first real automatic order")
	mark(director,"pair_kitchen_auto_served",{"station_id":4,"dish":"meal"})
	p.journey_meals_served = p.THIRD_STAR_MEALS
	p.third_star_auto_served = p.THIRD_STAR_AUTO_SERVED
	p.popularity = p.THIRD_STAR_POPULARITY
	check(p.can_attempt(service.stations,99),"current crews, current methods and equipment can reach 3★")
	check(Journey.current(p,service.stations,99,true,service).key == "third_star","2★ chapter reaches the third-star inspection")

	p.stars = 3
	director.reconcile()
	check(director.is_unlocked("kitchen_specialty"),"3★ plus proven paired kitchen unlocks specialization")
	p.specialized_expanded = true
	var grill := Station.new(5,"grill_kitchen",[301,302])
	grill.equipment = ["grill_kit","assembly_kit"]
	for dish in p.SPECIALTY_DISHES: grill.bind(str(dish),[301,302],61)
	service.stations.append(grill)
	check(Journey.current(p,service.stations,99,true,service).key == "first_specialty","burger line is introduced before 4★")
	mark(director,"specialty_kitchen_auto_served",{"station_id":5,"dish":"burger"})
	p.fourth_star_specialty_served = p.FOURTH_STAR_SPECIALTY_SERVED
	p.fourth_star_auto_served = p.FOURTH_STAR_AUTO_SERVED
	p.popularity = p.FOURTH_STAR_POPULARITY
	check(p.can_attempt(service.stations,99),"specialized line can reach 4★ with current workers")
	check(Journey.current(p,service.stations,99,true,service).key == "fourth_star","3★ chapter reaches Three Waves")

	p.stars = 4
	director.reconcile()
	check(director.is_unlocked("kitchen_orchestration"),"4★ plus proven burger line unlocks orchestration")
	p.orchestration_expanded = true
	var solyanka := Station.new(6,"solyanka_kitchen",[401,402,403])
	solyanka.equipment = ["fire_kit","stir_kit","salt_kit"]
	solyanka.bind("solyanka",[401,402,403],71)
	service.stations.append(solyanka)
	check(Journey.current(p,service.stations,99,true,service).key == "first_solyanka","three-role kitchen requires its first real automatic order")
	mark(director,"solyanka_auto_served",{"station_id":6,"dish":"solyanka"})
	p.fifth_star_solyanka_served = p.FIFTH_STAR_SOLYANKA_SERVED
	p.fifth_star_auto_served = p.FIFTH_STAR_AUTO_SERVED
	check(p.can_attempt(service.stations,99),"orchestration line can reach the current fifth-star check")
	check(Journey.current(p,service.stations,99,true,service).key == "fifth_star","4★ chapter hands off to the existing final inspection")

	var before := director.snapshot()
	var payload: Dictionary = bytes_to_var(var_to_bytes(before))
	var restored := Director.new()
	service.progression_director = restored
	restored.setup(service)
	restored.restore(payload,true)
	p.day += 1
	restored.reconcile()
	check(restored.has_milestone("first_group_training_completed") and restored.has_milestone("first_solyanka_auto_served"),"current-format save/load and next day preserve action milestones")
	check(restored.is_unlocked("kitchen_pair") and restored.is_unlocked("kitchen_specialty") and restored.is_unlocked("kitchen_orchestration"),"current-format save/load preserves learned major systems")

	service.queue_free()
	print("PASS: P5.03 video scale 2★→5★" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
