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
	var equipment: Array = ["fire_kit","stir_kit","salt_kit"]
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
	p.orchestration_expanded=true
	p.journey_auto_served=1
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
	live_solyanka.equipment=["fire_kit","stir_kit","salt_kit"]
	live_solyanka.apply_equipment()
	for role in range(3): live_solyanka.crew[role].clone_id = 101 + role
	live_solyanka.method_sources.solyanka = {"clone_ids":[101,102,103]}
	live_solyanka.recipes.solyanka={"quality":{"present":true,"grade":"B"}}
	var start_error: String = service.start_banquet(1)
	check(start_error.is_empty(),"Host can launch Day of Five Stars: " + start_error)
	check(p.phase=="preparing" and p.orders.size()==p.FINAL_INSPECTION_GUESTS,"Launch freezes ordinary business and prepares all final orders")
	service.advance_event(0.1)
	check(p.phase=="service","Final day enters timed service after stations are free")
	check(is_equal_approx(p.remaining,p.FINAL_INSPECTION_SECONDS),"Final day owns an independent event timer")

	print("4/4: failure, real threshold award, immutable result and save/load")
	service.finish_banquet(false,"Тестовый провал.")
	check(p.phase=="lost" and p.stars==4,"Failure keeps 4★")
	check(service.start_banquet(1).is_empty(),"Retry is free")
	service.advance_event(0.0)
	service.finish_banquet(true)
	check(p.stars==4 and p.campaign_result.is_empty(),"Success flag without real totals cannot award 5★")
	check(service.start_banquet(1).is_empty(),"Second retry starts normally")
	service.advance_event(0.0)
	p.banquet_finished=p.FINAL_INSPECTION_GUESTS
	p.banquet_served=p.FINAL_INSPECTION_SERVED
	p.banquet_good=p.FINAL_INSPECTION_GOOD
	service.served=123; service.revenue=4567; p.cash=890
	service.advance_event(0.0)
	await process_frame
	check(p.phase=="won" and p.stars==5,"Existing event evaluator awards 5★ at the exact thresholds")
	check(p.campaign_result.guests_served==123 and p.campaign_result.order_revenue==4567,"Campaign result uses cumulative guest/revenue totals")
	check(game.office.opened() and game.office.tab=="star","Completion opens its result once")
	var result_panel = game.office.content.get_node("CampaignResult")
	check(result_panel != null,"Result is mounted from its UI scene")
	result_panel.get_node("Margin/Column/Continue").pressed.emit()
	check(not game.office.opened() and p.stars==5 and p.cash==890,"Continue returns to cafe and retains star/cash")
	var earned: Dictionary=p.campaign_result.duplicate(true)
	service.served+=1; service.revenue+=25; p.cash+=25
	service.finish_banquet(true)
	check(p.campaign_result==earned,"Completed event cannot re-award or rewrite final totals")
	var save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(save),"Completed cafe saves and loads")
	await process_frame
	p=service.progress
	check(p.stars==5 and p.cash==915 and service.revenue==4592 and p.campaign_result==earned,"Save preserves 5★, continuing income and frozen campaign result")
	check(not game.office.opened(),"Loading completed cafe does not force result popup")
	game.office.open("star")
	check(game.office.content.get_node_or_null("CampaignResult")!=null,"Result can be reopened from Development")
	check(not p.can_attempt(service.stations,service.served),"There is no sixth required chapter")

	game._shutdown_tree(game)
	game.free()
	print("PASS: final fifth-star campaign completion" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
