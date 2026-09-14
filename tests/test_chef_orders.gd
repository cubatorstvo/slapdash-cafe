extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",text)

func run() -> void:
	var game=preload("res://scenes/cafe.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false)
	var service=game.service
	var p=service.progress
	service.rng.seed=12345
	var expected_premium: Array=[1.0,1.5,2.2,3.0,3.8,4.8]
	for star in range(6):
		p.stars=star
		var window: Vector2=p.CHEF_ORDER_INTERVALS[star]
		for sample in range(8):
			var delay: float=p.chef_order_delay(service.rng)
			check(delay>=window.x and delay<=window.y,"Chef interval stays inside %d-star window"%star)
		check(is_equal_approx(p.chef_order_premium(),expected_premium[star]),"Chef premium matches %d-star stage"%star)

	p.stars=0; p.manual_served=0; p.shift="open"; service.open_for_business=true
	service.chef_order_clock=0.0
	service.advance_chef_orders(0.01)
	var chef=service.by_id(1)
	check(chef.customer_id>=0,"Dedicated chef timer creates the active personal order")
	check(is_equal_approx(float(chef.customer_order.get("chef_bonus",0.0)),1.0),"Zero-star chef order keeps base payout")
	for i in range(3):
		service.chef_order_clock=0.0
		service.advance_chef_orders(0.01)
	check(service.chef_queue().size()==3,"Chef queue holds three waiting guests")
	var count_before: int=service.customers.size()
	service.chef_order_clock=0.0
	service.advance_chef_orders(0.01)
	check(service.customers.size()==count_before,"Full chef queue does not create a fourth waiting guest")
	check(service.chef_order_clock>=p.CHEF_ORDER_INTERVALS[0].x,"Full queue starts a fresh cooldown instead of banking an instant replacement")
	var queued: Dictionary=service.chef_queue()[0]
	service.dismiss_queue(queued)
	var remaining_before: float=service.chef_order_clock
	service.advance_chef_orders(0.1)
	check(service.chef_queue().size()==2 and service.chef_order_clock<remaining_before,"Opening a queue slot does not instantly refill it")

	# Ordinary traffic belongs to clone stations; it must no longer fall back to the chef.
	service.clear_world(); service.progress=p
	service.initial_stations(false)
	var automatic=service.add_station("counter",1,false,false)
	automatic.state="cooking"
	p.stars=2
	check(not service.spawn_customer("sausage"),"Busy automation does not redirect an ordinary guest to the chef")
	check(service.chef_queue().is_empty() and service.by_id(1).customer_id<0,"Ordinary overflow leaves the personal station untouched")

	# Late-game chef orders are rare but visibly more valuable.
	p.stars=5; p.manual_served=0
	service.chef_order_clock=0.0
	service.advance_chef_orders(0.01)
	chef=service.by_id(1)
	check(chef.customer_id>=0,"Five-star chef timer still creates a personal order")
	check(is_equal_approx(float(chef.customer_order.get("chef_bonus",0.0)),4.8),"Five-star chef order carries the 4.8x stage bonus")
	check(service.chef_order_clock>=180.0 and service.chef_order_clock<=220.0,"Five-star cooldown uses the 180-220 second range")

	game._shutdown_tree(game); game.free()
	print("PASS: chef traffic scales down by stars while queue capacity and payout scale correctly" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
