extends SceneTree
const Progression=preload("res://scripts/cafe_progression.gd")
var failures:=0

class Station:
	extends RefCounted
	var station_id:=1
	var manual_station:=false
	var staffed:=1
	var type_id:="counter"
	var recipes:Dictionary={}
	func role_count() -> int: return 3 if type_id=="solyanka_kitchen" else 2 if type_id in ["kitchen","grill_kitchen"] else 1
	func ready_crew() -> bool: return manual_station or staffed>=role_count()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func b_record() -> Dictionary:
	return {"quality":{"present":true,"grade":"B"}}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("1/3: fourth-star preparation requires proven specialization")
	var p=Progression.new()
	p.stars=3
	p.shift="morning"
	p.popularity=55
	p.fourth_star_auto_served=14
	p.fourth_star_specialty_served=6
	var manual=Station.new(); manual.manual_station=true
	var grill=Station.new(); grill.station_id=5; grill.type_id="grill_kitchen"; grill.staffed=2
	for dish in p.SPECIALTY_DISHES: grill.recipes[dish]=b_record()
	var stations:Array=[manual,grill]
	var requirements:Array=p.star_requirements(stations,100)
	check(requirements.size()==5,"Fourth star exposes five preparation requirements")
	check(requirements.all(func(r):return bool(r.done)),"Prepared specialty cafe satisfies fourth-star requirements")
	check(p.can_attempt(stations,100),"Prepared cafe can start Three Waves")
	p.fourth_star_specialty_served=5
	check(not p.can_attempt(stations,100),"Six real specialty servings are required")
	p.fourth_star_specialty_served=6

	print("2/3: Three Waves changes demand profile")
	check(p.inspection_orders().size()==18,"Three Waves schedules eighteen guests")
	check(p.inspection_guest_count()==18 and p.inspection_served_target()==15 and p.inspection_good_target()==11,"Three Waves uses 18/15/11 targets")
	check(is_equal_approx(p.inspection_seconds(),300.0),"Three Waves lasts five minutes")
	check(is_equal_approx(p.inspection_spawn_interval(0),6.0),"Opening mixed wave is measured")
	check(is_equal_approx(p.inspection_spawn_interval(7),3.0),"Burger peak is the fastest wave")
	check(is_equal_approx(p.inspection_spawn_interval(14),4.0),"Final mixed wave settles between them")
	check(p.inspection_chef_indices()==[1,13,16],"Exactly three spread-out orders stay with the chef")
	for index in p.inspection_chef_indices():
		check(p.inspection_orders()[index] not in p.SPECIALTY_DISHES,"Chef never steals a specialty-kitchen order")

	print("3/3: winning awards star four once")
	var game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var service=game.service
	service.progress.stars=3
	service.progress.phase="service"
	service.progress.cash=100
	service.progress.return_open=false
	service.progress.banquet_served=15
	service.progress.banquet_good=11
	service.finish_banquet(true)
	check(service.progress.stars==4,"Three Waves grants the fourth star")
	check(service.progress.cash==100+Progression.FOURTH_STAR_REWARD,"Fourth-star reward is paid")
	var cash_after:int=service.progress.cash
	service.finish_banquet(true)
	check(service.progress.cash==cash_after,"Resolved fourth-star inspection cannot pay twice")
	game._shutdown_tree(game)
	game.free()
	print("PASS: fourth-star specialization and Three Waves" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
