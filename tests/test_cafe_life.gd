extends SceneTree
const DT := 1.0/60.0
var game
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",text)
func run() -> void:
	game=preload("res://scenes/cafe.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_physics_process(false)
	var service=game.service
	var p=service.progress
	var chef=service.by_id(1)
	p.shift="open"; p.manual_served=4
	check(service.spawn_customer("sausage",false,true),"First customer takes chef station")
	var first_id: int=chef.customer_id
	var first_order: Dictionary=chef.customer_order.duplicate(true)
	for dish in ["potato","wine","sausage"]: check(service.spawn_customer(dish,false,true),"Guest joins chef queue")
	check(service.chef_queue().size()==3,"Three waiting customers visible")
	check(not service.spawn_customer("potato",false,true),"Full queue declines additional arrivals")
	check(chef.customer_id==first_id and chef.customer_order==first_order,"Queue does not overwrite active order")
	check(service.manual_order(chef)=="sausage","Active dish stays assigned")
	chef.equipment=["rag","plates","cup","jug","pan","sauce"]; chef.apply_equipment()
	check(service.request_manual(chef,"sausage",1),"Cook for first customer")
	var m=chef.model
	m.plates[0].point=m.Layout.TRAY; m.elevations.plate_0=m.Layout.TRAY_Y-m.BASE_Y
	m.sausage=m.Layout.TRAY; m.sausage_state="plate_0"; m.sausage_coating=1
	m.elevations.sausage=m.Layout.TRAY_Y-m.BASE_Y+0.035
	m._store_food("sausage")
	# A second different food on the tray must also be taken, even if it is not ordered.
	m.potato=m.Layout.TRAY; m.potato_state="plate_0"; m.elevations.potato=m.Layout.TRAY_Y-m.BASE_Y+0.035
	m._store_food("potato")
	chef.training.advance(DT); chef.training.finish_pass(true)
	var first: Dictionary=service.customers.filter(func(c):return c.id==first_id)[0]
	check(first.state=="eating" and chef.state=="serving","Guest takes serving before next order")
	check(first.view.meal_items.size()>=3,"Plate and all served food animated together")
	check(not chef.model.item_available("sausage_0") and not chef.model.item_available("plate_0"),"Consumed objects leave station")
	var cash: int=p.cash
	service.finish_customer(first_id,true)
	check(p.cash==cash,"Repeated completion cannot pay twice")
	for i in range(80): service.advance(DT)
	check(chef.customer_id!=first_id and service.manual_order(chef)=="potato","Queue advances in FIFO order")
	check(service.chef_queue().size()==2,"Waiting line shortens by one")
	service.end_shift()
	for i in range(100): service.advance(DT)
	check(service.chef_queue().is_empty() and p.shift=="night","Closing dismisses waiting line and reaches night")
	check(service.next_day().is_empty() and service.open_for_business and p.shift=="open","Sleep automatically opens next shift")
	service.open_for_business=false
	p.stars=1; p.lab_stage=3; p.cash=500
	var lab=game.laboratory
	game.player.global_position=lab.operator_position()
	lab.reset(); lab.state.selected=0; lab.press(1,lab.state.revision)
	check(p.cash==480,"Attempt charged once at start")
	lab.advance_balance(0.1,true)
	check(lab.state.phase=="fill" and not lab.state.armed,"Initial empty flask is safe")
	lab.advance_balance(0.2,true)
	check(lab.state.armed,"Crossing lower green boundary arms failure")
	lab.advance_balance(0.3,false)
	check(lab.state.phase=="failed" and p.cash==480,"Dropping below green spoils prepaid attempt")
	lab.press(1,lab.state.revision)
	check(p.cash==480 and p.free_clones==0,"Failure cannot emit or recharge a clone")
	lab.advance(3); lab.press(1,lab.state.revision)
	lab.state.level=0.65; lab.state.armed=true
	lab.advance_balance(0.01,true)
	check(lab.state.balanced>0 and lab.state.balanced<0.01,"Yellow still fills progress more slowly")
	var before: float=lab.state.balanced
	lab.state.level=0.95; lab.advance_balance(0.01,true)
	check(lab.state.balanced>before and lab.state.balanced-before<0.005,"Red also fills progress slowly")
	lab.reset()
	var st=service.add_station("counter",1,false,true); service.create_clone()
	p.shift="night"; p.night_elapsed=1.0
	game.evening._process(DT)
	check(game.evening.performers.size()==1,"Staff celebrate once in night scene")
	var entry: Dictionary=game.evening.performers.values()[0]
	check(entry.hat.visible and not entry.actor.hat.visible,"Chef throws physical hat")
	p.night_elapsed=25; game.evening._process(DT)
	check(entry.actor.visible and entry.get("settled",false),"Staff settle visibly into lounge activities")
	var resting_id: int=st.crew[0].clone_id
	service.next_day(); game.evening._process(DT)
	var rested: Dictionary=service.clone_data(resting_id)
	check(is_equal_approx(float(rested.get("rest",1.0)),float(p.rest_multiplier)),"Visual lounge preview applies shared next-day rest multiplier")
	check(is_equal_approx(st.crew_tempo(),float(rested.tempo)*float(rested.rest)),"Rest multiplies effective tempo without changing permanent tempo")
	check(game.evening.performers.is_empty(),"Morning clears night props and opens cafe")
	game._shutdown_tree(game); game.free()
	print("PASS: paid flask risk, graded filling, queue, meal handoff, visible leisure and auto-opening" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
