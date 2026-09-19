extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Library=preload("res://scripts/masterclass_library.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func repeated(value: Dictionary,count: int)->Array:
	var result: Array=[]
	for i in range(count): result.append(value.duplicate(true))
	return result

func sausage_recipe(station: Node3D)->Dictionary:
	station.model.reset("sausage")
	var m=station.model
	m.plates[0].point=m.Layout.TRAY
	m.elevations.plate_0=m.Layout.TRAY_Y-m.BASE_Y
	m.sausage=m.Layout.TRAY
	m.sausage_state="plate_0"
	m.sausage_coating=1.0
	m.elevations.sausage=m.Layout.TRAY_Y-m.BASE_Y+0.035
	m._store_food("sausage")
	var frame: Dictionary=m.snapshot()
	return {"tracks":[{"group":1,"frames":repeated(frame,60)}],"duration":1.0,"quality":m.quality()}

func masterclass_for(station: Node3D,id: int,dish: String,name: String)->Dictionary:
	station.model.reset(dish)
	if dish=="sausage":
		var m=station.model
		m.plates[0].point=m.Layout.TRAY
		m.elevations.plate_0=m.Layout.TRAY_Y-m.BASE_Y
		m.sausage=m.Layout.TRAY
		m.sausage_state="plate_0"
		m.sausage_coating=1.0
		m.elevations.sausage=m.Layout.TRAY_Y-m.BASE_Y+0.035
		m._store_food("sausage")
	var frame: Dictionary=station.model.snapshot()
	return Library.make_record(id,dish,station.type_id,[{"group":1,"frames":repeated(frame,120)}],2.0,station.model.quality(),name)

func make_game():
	var game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var service=game.service
	service.progress.stars=4
	service.progress.shift="open"
	service.open_for_business=false
	service.progress.cash=1000
	if "television" not in service.progress.lounge_items: service.progress.lounge_items.append("television")
	return game

func add_sausage_station(service: Node3D,slot := 1)->Node3D:
	var station=service.add_station("counter",slot,false)
	station.staffed=1
	station.equipment=["rag","plates","sauce"]
	station.apply_equipment()
	station.recipes.sausage=sausage_recipe(station)
	service.set_group_dish_active(service.group_id_for_station(station.station_id),"sausage",true)
	return station

func customer_by_order(service: Node3D,order_id: int)->Dictionary:
	for customer in service.customers:
		if int(customer.get("order_id",0))==order_id: return customer
	return {}

func active_large(service: Node3D,total := 10)->Dictionary:
	for customer in service.customers:
		if int(customer.get("portions_total",1))==total and customer.state!="leaving": return customer
	return {}

func settle(service: Node3D,customer: Dictionary)->void:
	var station=service.by_id(int(customer.station))
	customer.path.clear()
	customer.view.global_position=station.to_global(Vector3(0,0,-1.85))
	service.advance(0.02)

func advance_to(service: Node3D,order_id: int,state: String,done: int,limit := 4000)->Dictionary:
	for i in range(limit):
		var customer:=customer_by_order(service,order_id)
		if not customer.is_empty() and str(customer.state)==state and int(customer.get("portions_done",0))==done: return customer
		service.advance(0.05)
	return {}

func advance_done(service: Node3D,order_id: int,done: int,limit := 4000)->Dictionary:
	for i in range(limit):
		var customer:=customer_by_order(service,order_id)
		if not customer.is_empty() and int(customer.get("portions_done",0))>=done: return customer
		service.advance(0.05)
	return {}

func wait_course(service: Node3D,course_id: int,limit := 4000)->bool:
	for i in range(limit):
		if str(service.training_queue._course(course_id).get("state",""))=="completed": return true
		service.advance(0.05)
	return false

func dispose(game)->void:
	game._shutdown_tree(game)
	game.free()

func _initialize()->void:
	run.call_deferred()

func run()->void:
	print("T16: save after 7/10, save again during eighth, resume the same order")
	var game=await make_game()
	var service=game.service
	var station=add_sausage_station(service)
	var unit: int=roundi(25.0*float(station.recipes.sausage.quality.price_factor)*float(station.recipes.sausage.quality.style_multiplier))
	check(service.spawn_customer("sausage",false,false,{},10),"T16 ten-portion order starts")
	var large:=active_large(service)
	var customer_id:=int(large.id)
	var order_id:=int(large.order_id)
	var station_id:=int(large.station)
	settle(service,large)
	large=await advance_to(service,order_id,"cooking",7)
	check(not large.is_empty() and int(large.order_paid)==unit*7,"T16 seven portions are paid before first save")
	var revenue_after_seven: int=service.revenue
	var cash_after_seven: int=service.progress.cash
	var completed_before:=int(service.order_stats.orders_completed)
	var portions_before:=int(service.order_stats.portions_served)
	var save7: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(save7.version==22 and save7.customers.size()>0,"T16 v22 contains active customers")
	check(service.load_data(save7),"T16 first active-order save reloads")
	large=customer_by_order(service,order_id)
	check(not large.is_empty() and int(large.id)==customer_id and int(large.station)==station_id,"T16 same customer and same station survive first reload")
	check(int(large.portions_done)==7 and int(large.order_paid)==unit*7,"T16 7/10 progress and paid total survive first reload")
	station=service.by_id(station_id)
	check(station.state=="cooking" and station.customer_id==customer_id,"T16 original station remains occupied by the restored order")
	for i in range(8): service.advance(0.05)
	large=customer_by_order(service,order_id)
	station=service.by_id(station_id)
	check(str(large.state)=="cooking" and int(large.portions_done)==7 and station.order_tick>0.0,"T16 eighth portion is genuinely in progress")
	var eighth_tick: float=station.order_tick
	var save8: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(save8),"T16 mid-eighth save reloads")
	large=customer_by_order(service,order_id)
	station=service.by_id(station_id)
	check(not large.is_empty() and int(large.id)==customer_id and int(large.station)==station_id,"T16 same order identity survives the second reload")
	check(str(large.state)=="cooking" and int(large.portions_done)==7 and is_equal_approx(station.order_tick,eighth_tick),"T16 current eighth-portion execution resumes from the saved tick")
	var ten:=await advance_done(service,order_id,10)
	check(not ten.is_empty() and int(ten.order_paid)==unit*10,"T16 remaining three portions finish on the restored order")
	for i in range(40): service.advance(0.05)
	check(service.revenue==revenue_after_seven+unit*3 and service.progress.cash==cash_after_seven+unit*3,"T16 reload charges exactly the remaining three portions")
	check(int(service.order_stats.orders_completed)==completed_before+1,"T16 final result registers exactly one completed order")
	check(int(service.order_stats.portions_served)==portions_before+3,"T16 only three new portion-stat events occur after the 7/10 save")
	check(service.served==1,"T16 campaign semantics still count one served guest")
	dispose(game)

	print("T17: replay the same paid-portion completion across save/load")
	game=await make_game()
	service=game.service
	station=add_sausage_station(service)
	unit=roundi(25.0*float(station.recipes.sausage.quality.price_factor)*float(station.recipes.sausage.quality.style_multiplier))
	check(service.spawn_customer("sausage",false,false,{},3),"T17 three-portion order starts")
	var replay:=active_large(service,3)
	order_id=int(replay.order_id)
	customer_id=int(replay.id)
	station_id=int(replay.station)
	settle(service,replay)
	# Let the learned track put a valid serving on the tray, but complete it through one explicit event token.
	for i in range(15):
		if service.by_id(station_id).order_tick>=50.0: break
		service.advance(0.05)
	replay=customer_by_order(service,order_id)
	station=service.by_id(station_id)
	station.show_tracks(station.recipes.sausage.tracks,59)
	var before_event_revenue: int=service.revenue
	var before_event_portions:=int(service.order_stats.portions_served)
	service.finish_customer(customer_id,true,"",1,order_id)
	replay=customer_by_order(service,order_id)
	check(int(replay.portions_done)==1 and service.revenue==before_event_revenue+unit,"T17 first completion token pays portion one")
	var once_revenue: int=service.revenue
	var once_cash: int=service.progress.cash
	var once_portions:=int(service.order_stats.portions_served)
	var boundary: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(boundary),"T17 save immediately after payment reloads")
	replay=customer_by_order(service,order_id)
	check(int(replay.portions_done)==1 and int(replay.order_paid)==unit,"T17 paid portion survives boundary reload")
	# Finish eating so the next cooking cycle exists, then replay the stale network-equivalent token.
	replay=await advance_to(service,order_id,"cooking",1)
	check(not replay.is_empty(),"T17 second portion begins normally")
	service.finish_customer(customer_id,true,"",1,order_id)
	check(service.revenue==once_revenue and service.progress.cash==once_cash and int(service.order_stats.portions_served)==once_portions,"T17 stale completion token cannot pay portion one twice")
	check(int(customer_by_order(service,order_id).portions_done)==1,"T17 stale event cannot advance order progress")
	var finished:=await advance_done(service,order_id,3)
	check(not finished.is_empty(),"T17 order continues after ignored duplicate event")
	for i in range(40): service.advance(0.05)
	check(service.revenue==before_event_revenue+unit*3,"T17 total payment is exactly three portion prices")
	check(int(service.order_stats.portions_served)==before_event_portions+3 and int(service.order_stats.orders_completed)==1,"T17 final statistics contain three portions and one completed order")
	dispose(game)

	print("Ordinary automatic order and visible large-order queue survive save/load")
	game=await make_game()
	service=game.service
	station=add_sausage_station(service)
	check(service.spawn_customer("sausage",false,false,{},1),"Ordinary one-portion automatic order starts")
	var ordinary: Dictionary={}
	for customer in service.customers:
		if int(customer.get("portions_total",1))==1 and int(customer.get("station",-1))==station.station_id:
			ordinary=customer
			break
	var ordinary_order_id: int=int(ordinary.get("order_id",0))
	var ordinary_customer_id: int=int(ordinary.get("id",0))
	settle(service,ordinary)
	for i in range(6): service.advance(0.05)
	station=service.by_id(int(ordinary.station))
	check(str(ordinary.state)=="cooking" and station.order_tick>0.0,"Ordinary order is saved during real automatic cooking")
	var ordinary_tick: float=station.order_tick
	var ordinary_saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(ordinary_saved),"Ordinary active order reloads")
	ordinary=customer_by_order(service,ordinary_order_id)
	station=service.by_id(int(ordinary.station))
	check(not ordinary.is_empty() and int(ordinary.id)==ordinary_customer_id and str(ordinary.state)=="cooking" and is_equal_approx(station.order_tick,ordinary_tick),"Same ordinary customer resumes the same cooking tick")
	var ordinary_completed_before: int=int(service.order_stats.orders_completed)
	var ordinary_revenue_before: int=service.revenue
	for i in range(300):
		ordinary=customer_by_order(service,ordinary_order_id)
		if not ordinary.is_empty() and bool(ordinary.get("stats_finalized",false)): break
		service.advance(0.05)
	ordinary=customer_by_order(service,ordinary_order_id)
	check(not ordinary.is_empty() and bool(ordinary.stats_finalized),"Restored ordinary order completes")
	var ordinary_paid: int=service.revenue-ordinary_revenue_before
	for i in range(40): service.advance(0.05)
	check(ordinary_paid>0 and int(service.order_stats.orders_completed)==ordinary_completed_before+1,"Ordinary restored order pays and finalizes exactly once")
	# Occupy the only trained station with a real order and create a visible large-order queue with no station yet.
	check(service.spawn_customer("sausage",false,false,{},1),"Real blocker order occupies the only trained table")
	var blocker: Dictionary={}
	for customer in service.customers:
		if int(customer.get("portions_total",1))==1 and int(customer.get("order_id",0))!=ordinary_order_id and customer.state!="leaving":
			blocker=customer
			break
	check(not blocker.is_empty(),"Real blocker customer exists")
	var blocker_order_id: int=int(blocker.get("order_id",0))
	settle(service,blocker)
	check(str(blocker.state)=="cooking","Real blocker is actively cooking before queue snapshot")
	check(service.spawn_customer("sausage",false,false,{},3),"Busy trained station sends a large order to auto_queue")
	var queued_order: Dictionary={}
	for customer in service.customers:
		if str(customer.state)=="auto_queue":
			queued_order=customer
			break
	check(not queued_order.is_empty() and int(queued_order.station)==-1,"Large queued order has no assigned station yet")
	var queued_order_id: int=int(queued_order.order_id)
	var queued_customer_id: int=int(queued_order.id)
	queued_order.order_age=3.25
	var queued_position: Vector3=queued_order.view.position
	var queued_saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(queued_saved),"Visible automatic queue reloads")
	queued_order=customer_by_order(service,queued_order_id)
	blocker=customer_by_order(service,blocker_order_id)
	check(not blocker.is_empty() and str(blocker.state)=="cooking","The real order blocking the queue also survives reload")
	check(not queued_order.is_empty() and int(queued_order.id)==queued_customer_id and str(queued_order.state)=="auto_queue" and int(queued_order.station)==-1,"Same queued guest remains in auto_queue after reload")
	check(is_equal_approx(float(queued_order.order_age),3.25) and queued_order.view.position.distance_to(queued_position)<0.001,"Queued wait age and physical position survive reload")
	service.finish_customer(int(blocker.id),false,"busy")
	service.advance(0.05)
	queued_order=customer_by_order(service,queued_order_id)
	check(not queued_order.is_empty() and int(queued_order.station)==2 and str(queued_order.state)=="walking","Restored queued order takes the newly freed original table instead of respawning")
	dispose(game)

	print("T09-save: queued training keeps draining through a mid-order reload")
	game=await make_game()
	service=game.service
	station=add_sausage_station(service)
	var new_method:=masterclass_for(station,3601,"sausage","После большого заказа")
	service.masterclasses=[new_method]
	check(service.spawn_customer("sausage",false,false,{},10),"T09-save ten-portion order starts")
	var training_order:=active_large(service)
	order_id=int(training_order.order_id)
	customer_id=int(training_order.id)
	station_id=int(training_order.station)
	settle(service,training_order)
	training_order=await advance_to(service,order_id,"cooking",3)
	check(not training_order.is_empty(),"T09-save three portions finish before training assignment")
	var queued: Dictionary=service.queue_training_course([{"record_id":3601,"station_ids":[station_id]}],"together","t09-save",1)
	check(str(queued.error).is_empty(),"T09-save training course is accepted")
	service.training_queue.advance(0.0)
	var course_id:=int(queued.course_id)
	var batch: Dictionary=service.training_queue._batch(int(service.training_queue._course(course_id).batch_ids[0]))
	check(str(batch.state)=="draining","T09-save training waits for the accepted large order")
	training_order=await advance_to(service,order_id,"cooking",5)
	check(not training_order.is_empty(),"T09-save order continues to fifth portion while training drains")
	var mid_order: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(mid_order),"T09-save cafe reloads during the accepted order")
	training_order=customer_by_order(service,order_id)
	station=service.by_id(station_id)
	batch=service.training_queue._batch(int(service.training_queue._course(course_id).batch_ids[0]))
	check(not training_order.is_empty() and int(training_order.id)==customer_id and int(training_order.station)==station_id and int(training_order.portions_done)==5,"T09-save same 5/10 customer remains on the same table")
	check(str(batch.state)=="draining" and station.state=="cooking","T09-save training still waits behind the restored active order")
	check(not (await advance_done(service,order_id,10)).is_empty(),"T09-save restored large order reaches 10/10")
	check(await wait_course(service,course_id),"T09-save training begins only after the restored order releases its table")
	check(int(station.method_sources.get("sausage",{}).get("id",0))==3601,"T09-save station learns the queued method after the order")
	dispose(game)

	print("Chef orders: queue and interrupted manual cooking survive, served food stays served")
	game=await make_game()
	service=game.service
	service.progress.stars=2
	var chef=service.by_id(1)
	check(chef!=null and chef.manual_station,"Chef station exists")
	check(service.spawn_customer("sausage",false,true),"First personal chef order starts")
	var first_chef: Dictionary={}
	for customer in service.customers:
		if bool(customer.get("chef_order",false)) and customer.state!="leaving": first_chef=customer; break
	check(not first_chef.is_empty(),"First chef customer exists")
	first_chef.path.clear()
	first_chef.view.global_position=chef.to_global(Vector3(0,0,-1.85))
	service.advance(0.02)
	check(service.request_manual(chef,"potato",1),"Chef begins the personal order")
	check(str(first_chef.state)=="training","Chef customer is attached to manual cooking")
	check(service.spawn_customer("potato",false,true),"Second personal chef order joins queue")
	var queued_chef: Dictionary={}
	for customer in service.customers:
		if bool(customer.get("chef_order",false)) and int(customer.id)!=int(first_chef.id): queued_chef=customer; break
	check(not queued_chef.is_empty() and str(queued_chef.state)=="queued","Second chef customer waits in visible queue")
	var first_order_id:=int(first_chef.order_id)
	var second_order_id:=int(queued_chef.order_id)
	var chef_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(chef_save),"Chef queue save reloads")
	first_chef=customer_by_order(service,first_order_id)
	queued_chef=customer_by_order(service,second_order_id)
	chef=service.by_id(1)
	check(not first_chef.is_empty() and str(first_chef.state)=="waiting" and int(first_chef.station)==1,"Interrupted manual cooking returns the same unpaid order to waiting")
	check(not queued_chef.is_empty() and str(queued_chef.state)=="queued","Queued personal customer keeps queue state and order")
	check(int(service.chef_queue()[0].order_id)==second_order_id,"Chef queue order is preserved")
	check(service.request_manual(chef,str(first_chef.dish),1),"Restored personal order can be cooked again")
	# Complete that same restored order and save while its already-paid serving is being eaten.
	chef.model.reset("sausage")
	var m=chef.model
	m.plates[0].point=m.Layout.TRAY
	m.elevations.plate_0=m.Layout.TRAY_Y-m.BASE_Y
	m.sausage=m.Layout.TRAY
	m.sausage_state="plate_0"
	m.sausage_coating=1.0
	m.elevations.sausage=m.Layout.TRAY_Y-m.BASE_Y+0.035
	m._store_food("sausage")
	var completed_before_eating:=int(service.order_stats.orders_completed)
	service.finish_customer(int(first_chef.id),true)
	check(str(first_chef.state)=="eating" and bool(first_chef.stats_finalized),"Chef served order enters eating with finalized payment")
	var paid_revenue: int=service.revenue
	var eating_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(eating_save),"Served chef eating phase reloads")
	first_chef=customer_by_order(service,first_order_id)
	check(not first_chef.is_empty() and str(first_chef.state)=="eating" and bool(first_chef.stats_finalized),"Already served chef order restores its eating phase")
	queued_chef=customer_by_order(service,second_order_id)
	check(not queued_chef.is_empty() and str(queued_chef.state)=="queued","Other personal order still waits while served guest eats")
	for i in range(40): service.advance(0.05)
	check(service.revenue==paid_revenue and int(service.order_stats.orders_completed)==completed_before_eating+1,"Restored served chef order never pays or completes twice")
	dispose(game)

	print("v21 migration keeps historical counters but has no invented active customers")
	game=await make_game()
	service=game.service
	station=add_sausage_station(service)
	check(service.spawn_customer("sausage",false,false,{},3),"Legacy fixture has one active order before synthetic old save")
	var legacy_active:=active_large(service,3)
	settle(service,legacy_active)
	var old: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	var historical_stats: Dictionary=old.order_stats.duplicate(true)
	var historical_revenue:=int(old.revenue)
	old.version=21
	old.erase("customers")
	old.erase("next_customer_id")
	old.erase("next_order_id")
	check(service.load_data(old),"v21 save remains loadable")
	check(service.customers.is_empty(),"v21 migration does not invent active customers absent from the old format")
	check(service.order_stats==historical_stats and service.revenue==historical_revenue,"v21 migration preserves historical counters and money")
	check(service.save_data().version==22,"Migrated old cafe subsequently writes v22")
	dispose(game)

	print("PASS: T16-T17 active-order persistence, T09 mid-order training wait and chef-order recovery" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
