extends SceneTree
const Progression=preload("res://scripts/cafe_progression.gd")
const Journey=preload("res://scripts/cafe_journey.gd")
const Visits=preload("res://scripts/cafe_visits.gd")
var failed := false

class Run:
	extends RefCounted
	var phase := "idle"
	var purpose := "lesson"
	var lengths: Array=[10]
	func active() -> bool: return phase!="idle"
	func summary() -> Dictionary: return {"lengths":lengths}

class Station:
	extends RefCounted
	var station_id := 1
	var manual_station := false
	var staffed := 1
	var type_id := "counter"
	var equipment: Array=[]
	var recipes: Dictionary={}
	var remote_summary: Dictionary={}
	var training=Run.new()
	var state := "idle"
	var pending_teacher := 0
	func role_count() -> int: return 3 if type_id=="solyanka_kitchen" else 2 if type_id in ["kitchen","grill_kitchen"] else 1
	func ready_crew() -> bool: return staffed==role_count()

class Game:
	extends RefCounted
	var saves := 0
	func save_cafe() -> bool: saves+=1; return true

class Service:
	extends RefCounted
	const CHEF_QUEUE_LIMIT := 3
	var progress=Progression.new()
	var stations: Array=[]
	var customers: Array=[]
	var open_for_business := true
	var game=Game.new()
	func by_id(id: int):
		for station in stations:
			if station.station_id==id: return station
		return null
	func chef_queue() -> Array: return []
	func announce(_message: String) -> void: pass
	func trace(_event: String,_data: Dictionary) -> void: pass
	func spawn_customer(_dish: String,_banquet: bool,_chef: bool,data: Dictionary) -> bool:
		customers.append({"id":customers.size()+1,"visit_id":data.id,"visit_slot":data.slot,"state":"walking"})
		return true
	func finish_customer(id: int,_paid: bool) -> void:
		for customer in customers:
			if int(customer.id)==id: customer.state="leaving"

func check(ok: bool, message: String) -> void:
	if not ok: failed=true; printerr("FAIL: ",message)

func _initialize() -> void:
	print("1/3: journey follows actual equipment, pots and accepted records")
	var service=Service.new()
	var p=service.progress
	p.stars=1; p.lab_stage=3; p.cash=500
	var personal=Station.new(); personal.manual_station=true
	personal.equipment=["sauce","plates","pan","jug","cup"]
	service.stations=[personal]
	check(Journey.current(p,service.stations,15,true).key=="formula","Formula comes before an empty station")
	p.lab_sample={"serial":1,"carrier":0}
	check(Journey.current(p,service.stations,15,true).key=="microscope","Pending sample goes to microscope")
	p.lab_sample={}; p.lab_formula_version=1
	p.lab_pots=[{"id":0,"phase":"soil"}]
	check(Journey.current(p,service.stations,15,true).key=="seed","Formula drop follows soil")
	p.lab_pots[0].phase="growing_sprout"
	check(Journey.current(p,service.stations,15,true).key=="buy_counter","Prepare station while clone grows")
	p.deliveries=[{"item":"counter","station":2,"owner":0,"remaining":8}]
	check(Journey.current(p,service.stations,15,true).key=="delivery_counter","Paid order becomes a delivery step")
	p.lab_pots[0].phase="ready"
	check(Journey.current(p,service.stations,15,true).key=="harvest","Ready worker takes precedence")
	p.deliveries.clear()
	var first=Station.new(); first.station_id=2; first.equipment=["sauce","plates"]
	service.stations.append(first)
	first.training.phase="review"
	check(Journey.current(p,service.stations,15,true).title=="Сохрани удачный показ","Guide distinguishes review")
	first.training.phase="ready"
	check(Journey.current(p,service.stations,15,true).title=="Прими запись для бригады","Draft still needs acceptance")
	first.training.phase="idle"
	first.recipes={"sausage":{"quality":{"present":false,"grade":"D"}}}
	check(Journey.current(p,service.stations,15,true).key.begins_with("teach_"),"Empty serving record is not a working automation")
	first.recipes.sausage.quality.present=true
	check(Journey.current(p,service.stations,15,true).key=="first_income","First real payout is an explicit milestone")
	p.journey_auto_served=1
	check(Journey.current(p,service.stations,15,true).station==3,"Second brigade excludes personal station")
	var second=Station.new(); second.station_id=3; service.stations.append(second)
	for dish in ["sausage","potato","wine"]: first.recipes[dish]={"quality":{"present":true,"grade":"B"}}
	p.popularity=30
	check(Journey.current(p,service.stations,15,true).key=="second_star","Existing preparations are credited")
	p.stars=2
	check(Journey.current(p,service.stations,15,true).key=="third_expand","Third-star chapter starts with the pair-kitchen expansion")
	p.expanded=true
	var kitchen=Station.new(); kitchen.station_id=4; kitchen.type_id="kitchen"; kitchen.staffed=2; kitchen.equipment=["meat_kit","pasta_kit"]
	kitchen.recipes={"meal":{"quality":{"present":true,"grade":"B"}}}
	service.stations.append(kitchen)
	p.journey_meals_served=3
	p.third_star_auto_served=10
	p.popularity=40
	check(Journey.current(p,service.stations,15,true).key=="third_star","Existing scaling preparations unlock the Big Lunch")
	p.stars=3
	check(Journey.current(p,service.stations,15,true).key=="specialty_expand","Third star opens the specialization chapter")
	p.specialized_expanded=true
	var specialty=Station.new(); specialty.station_id=5; specialty.type_id="grill_kitchen"; specialty.staffed=2; specialty.equipment=["grill_kit","assembly_kit"]
	for dish in p.SPECIALTY_DISHES: specialty.recipes[dish]={"quality":{"present":true,"grade":"B"}}
	service.stations.append(specialty)
	p.fourth_star_specialty_served=6
	p.fourth_star_auto_served=14
	p.popularity=55
	check(Journey.current(p,service.stations,15,true).key=="fourth_star","Existing specialization preparations unlock the three-wave test")
	p.stars=4
	check(Journey.current(p,service.stations,15,true).key=="orchestration_expand","Fourth star opens the orchestration sector")
	p.orchestration_expanded=true
	var solyanka=Station.new(); solyanka.station_id=6; solyanka.type_id="solyanka_kitchen"; solyanka.staffed=3; solyanka.equipment=["fire_kit","stir_kit","salt_kit"]
	solyanka.recipes={"solyanka":{"quality":{"present":true,"grade":"B"}}}
	service.stations.append(solyanka)
	p.fifth_star_solyanka_served=p.FIFTH_STAR_SOLYANKA_SERVED
	p.fifth_star_auto_served=p.FIFTH_STAR_AUTO_SERVED
	check(Journey.current(p,service.stations,15,true).key=="fifth_prep_done","Three-role kitchen completes the current fifth-star preparation chapter")

	print("2/3: optional visits, cooldown and persisted single rewards")
	p.journey_auto_served=3; p.shift="open"; p.shift_elapsed=0
	Visits.advance(service,0)
	check(p.visit.phase=="offered","Offer follows proven automation")
	var money: int=p.cash
	Visits.action(service,"visit_decline",p.visit.id)
	Visits.advance(service,100)
	check(p.visit.phase=="declined" and p.cash==money,"Declining has no fee and no immediate replacement")
	p.day+=2
	Visits.advance(service,0)
	Visits.action(service,"visit_accept",p.visit.id)
	check(p.visit.phase=="scheduled","Accept before countdown starts")
	Visits.advance(service,60)
	check(p.visit.phase=="active" and p.visit.remaining==240.0,"Visit begins with its full service time after preparation")
	var first_guest: Dictionary={"visit_id":p.visit.id,"visit_slot":0}
	Visits.settled(service,first_guest,true,"A")
	Visits.settled(service,first_guest,true,"A")
	check(p.visit.paid==1,"Guest settles once")
	var restored=Progression.new()
	restored.restore(bytes_to_var(var_to_bytes(p.snapshot())))
	service.progress=restored; p=restored; service.customers.clear()
	Visits.settled(service,first_guest,true,"A")
	check(p.visit.paid==1,"Settled slot survives serialized restore")
	for slot in [1,2,3]: Visits.settled(service,{"visit_id":p.visit.id,"visit_slot":slot},true,"A")
	check(p.visit.phase=="won" and p.cash==money+60,"Critics pay one completion reward")
	Visits.finish(service,true,"")
	check(p.cash==money+60,"Completion reward cannot repeat")

	print("3/3: clone-only credit, cancellation and next-day scheduling")
	p.visit={}; p.visit_next_day=0; p.visit_next_kind="crew"
	Visits.advance(service,0)
	check(p.visit.kind=="crew","Prepared brigades unlock workshop lunch")
	p.shift_elapsed=400
	Visits.action(service,"visit_accept",p.visit.id)
	check(p.visit.start_day==p.day+1,"Late acceptance schedules next morning")
	p.day+=1; p.shift_elapsed=0
	Visits.advance(service,60)
	Visits.settled(service,{"visit_id":p.visit.id,"visit_slot":0,"automatic_serving":false},true,"S")
	check(p.visit.paid==0,"Personal demonstration cannot count as autonomous service")
	Visits.settled(service,{"visit_id":p.visit.id,"visit_slot":1,"automatic_serving":true},true,"B")
	check(p.visit.paid==1 and p.visit.good==1,"Recorded clone service counts")
	var before: int=p.cash
	Visits.close_shift(service)
	check(p.visit.phase=="lost" and p.cash==before,"Closing active visit does not grant its reward")
	print("PASS: journey and voluntary visits" if not failed else "FAILED")
	quit(1 if failed else 0)
