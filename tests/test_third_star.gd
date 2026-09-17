extends SceneTree
const Progression=preload("res://scripts/cafe_progression.gd")
var failures:=0

class Station:
	extends RefCounted
	var station_id:=1
	var manual_station:=false
	var staffed:=1
	var type_id:="counter"
	var recipes: Dictionary={}
	func role_count() -> int: return 2 if type_id=="kitchen" else 1
	func ready_crew() -> bool: return manual_station or staffed>=role_count()

func check(ok: bool, text: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL: ",text)

func b_record() -> Dictionary:
	return {"quality":{"present":true,"grade":"B"}}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("1/3: third-star requirements describe a scaled cafe")
	var p=Progression.new()
	p.stars=2
	p.shift="morning"
	p.popularity=40
	p.third_star_auto_served=10
	p.journey_meals_served=3
	var manual=Station.new(); manual.manual_station=true
	var a=Station.new(); a.station_id=2; a.recipes={"wine":b_record(),"potato":b_record(),"sausage":b_record()}
	var b=Station.new(); b.station_id=3; b.recipes={"wine":b_record(),"potato":b_record(),"sausage":b_record()}
	var kitchen=Station.new(); kitchen.station_id=4; kitchen.type_id="kitchen"; kitchen.staffed=2; kitchen.recipes={"meal":b_record()}
	var stations: Array=[manual,a,b,kitchen]
	var requirements: Array=p.star_requirements(stations,99)
	check(requirements.size()==5,"Third star has five visible preparation requirements")
	check(requirements.all(func(r):return bool(r.done)),"Prepared cafe satisfies every third-star requirement")
	check(p.can_attempt(stations,99),"Prepared cafe can invite the Big Lunch")
	p.third_star_auto_served=9
	check(not p.can_attempt(stations,99),"Ten post-second-star automatic servings are required")
	p.third_star_auto_served=10
	p.popularity=39
	check(not p.can_attempt(stations,99),"Popularity 40 is required")
	p.popularity=40

	print("2/3: Big Lunch profile is distinct from second-star delegation")
	check(p.inspection_orders().size()==14,"Big Lunch schedules fourteen guests")
	check(p.inspection_guest_count()==14,"Big Lunch waits for fourteen settled guests")
	check(p.inspection_served_target()==11,"Big Lunch needs eleven served guests")
	check(p.inspection_good_target()==8,"Big Lunch needs eight B+ results")
	check(is_equal_approx(p.inspection_seconds(),240.0),"Big Lunch lasts four minutes")
	check(is_equal_approx(p.inspection_spawn_interval(),4.0),"Big Lunch presents new work faster than the second-star delegation")
	check(p.inspection_chef_indices()==[1,6,11],"Exactly three spread-out Big Lunch orders belong to the chef")
	for index in p.inspection_chef_indices():
		check(p.inspection_orders()[index]!="meal","Chef is never assigned the pair-kitchen meal")
	p.stars=1
	check(p.inspection_orders().size()==9 and p.inspection_served_target()==8 and p.inspection_good_target()==6,"Second-star delegation keeps its existing profile")

	print("3/3: winning the Big Lunch awards the third star once")
	var game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var service=game.service
	service.progress.stars=2
	service.progress.phase="service"
	service.progress.cash=100
	service.progress.return_open=false
	service.progress.banquet_served=11
	service.progress.banquet_good=8
	service.finish_banquet(true)
	check(service.progress.stars==3,"Big Lunch win grants star three")
	check(service.progress.cash==100+Progression.BIG_LUNCH_REWARD,"Big Lunch pays the configured third-star reward")
	check(service.progress.result.begins_with("Третья звезда!"),"Big Lunch result clearly names the third star")
	var cash_after: int=service.progress.cash
	service.finish_banquet(true)
	check(service.progress.cash==cash_after,"Resolved inspection cannot pay twice")
	game._shutdown_tree(game)
	game.free()

	print("PASS: third-star scaling and Big Lunch" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
