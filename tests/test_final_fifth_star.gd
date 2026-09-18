extends SceneTree
const Progression = preload("res://scripts/cafe_progression.gd")
const Journey = preload("res://scripts/cafe_journey.gd")
var failures := 0

class Station:
	extends RefCounted
	var station_id := 6
	var manual_station := false
	var staffed := 3
	var type_id := "solyanka_kitchen"
	var recipes := {"solyanka":{"quality":{"present":true,"grade":"B"}}}
	func role_count() -> int: return 3
	func ready_crew() -> bool: return staffed>=role_count()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	run.call_deferred()

func ready_progression():
	var p=Progression.new()
	p.stars=4
	p.shift="morning"
	p.fifth_star_solyanka_served=p.FIFTH_STAR_SOLYANKA_SERVED
	p.fifth_star_auto_served=p.FIFTH_STAR_AUTO_SERVED
	return p

func run() -> void:
	print("1/4: final day unlocks after the existing orchestration preparation")
	var p=ready_progression()
	var station=Station.new()
	check(p.can_attempt([station],100),"Completed 4→5 preparation unlocks the final inspection")
	var goal: Dictionary=Journey.current(p,[station],100,true)
	check(goal.key=="fifth_star","Journey points to the final-day launch instead of the old handoff placeholder")

	print("2/4: final day has three deterministic structural phases")
	var orders: Array=p.inspection_orders()
	check(orders.size()==p.FINAL_INSPECTION_GUESTS and orders.size()==24,"Final day defines 24 structural orders")
	check(["wine","potato","sausage","meal","burger","cheeseburger","spicy_burger","solyanka"].all(func(dish): return dish in orders),"Final day exercises every campaign dish family")
	p.banquet_spawned=0
	check(p.inspection_phase_index()==0 and p.inspection_phase_name()=="Наплыв","First eight orders are the opening rush")
	check(is_equal_approx(p.inspection_spawn_interval(),6.0),"Opening rush uses its own cadence")
	p.banquet_spawned=8
	check(p.inspection_phase_index()==1 and p.inspection_phase_name()=="Критики","Second eight orders are the critics phase")
	check(is_equal_approx(p.inspection_spawn_interval(),4.0),"Critics phase tightens the cadence")
	p.banquet_spawned=16
	check(p.inspection_phase_index()==2 and p.inspection_phase_name()=="Общий финал","Last eight orders are the combined finale")
	check(is_equal_approx(p.inspection_spawn_interval(),3.0),"Combined finale is the densest structural phase")
	for index in p.inspection_chef_indices():
		check(orders[index] in Progression.DISHES,"Chef-only final orders stay compatible with the personal counter")

	print("3/4: the real cafe starts the final event through the existing host-owned event path")
	var game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var service=game.service
	p=service.progress
	p.stars=4
	p.shift="morning"
	p.fifth_star_solyanka_served=p.FIFTH_STAR_SOLYANKA_SERVED
	p.fifth_star_auto_served=p.FIFTH_STAR_AUTO_SERVED
	var live_solyanka=service.add_station("solyanka_kitchen",5,false)
	live_solyanka.staffed=3
	live_solyanka.recipes.solyanka={"quality":{"present":true,"grade":"B"}}
	check(service.start_banquet(1).is_empty(),"Host can launch Day of Five Stars")
	check(p.phase=="preparing" and p.orders.size()==p.FINAL_INSPECTION_GUESTS,"Launch freezes ordinary business and prepares all final orders")
	service.advance_event(0.1)
	check(p.phase=="service","Final day enters timed service after stations are free")
	check(is_equal_approx(p.remaining,p.FINAL_INSPECTION_SECONDS),"Final day owns an independent event timer")

	print("4/4: failure is retryable and stage 1 does not prematurely award the fifth star")
	service.finish_banquet(false,"Тестовый провал.")
	check(p.phase=="lost" and p.stars==4,"Failure keeps the fourth star and ends the event cleanly")
	check(p.can_attempt(service.stations,service.served),"Failed final day can be retried immediately when preparation remains valid")
	check(service.start_banquet(1).is_empty(),"Retry starts through the same event path")
	service.finish_banquet(true)
	check(p.phase=="won" and p.stars==4,"Stage 1 success freezes the event result without awarding 5★ before the scoring/ending stages")
	check(p.result.contains("итоговая шкала"),"Temporary success text makes the unfinished score layer explicit")
	game._shutdown_tree(game)
	game.free()
	print("PASS: final fifth-star day structural framework" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
