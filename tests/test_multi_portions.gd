extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
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
	var quality: Dictionary=m.quality()
	return {"tracks":[{"group":1,"frames":repeated(frame,60)}],"duration":1.0,"quality":quality}

func customer_by_portions(service: Node3D,total: int,exclude_id := -1)->Dictionary:
	for customer in service.customers:
		if int(customer.get("portions_total",1))==total and int(customer.id)!=exclude_id and customer.state!="leaving": return customer
	return {}

func settle_at_station(service: Node3D,customer: Dictionary)->void:
	var station=service.by_id(int(customer.station))
	customer.path.clear()
	customer.view.global_position=station.to_global(Vector3(0,0,-1.85))
	service.advance(0.02)

func advance_until_done(service: Node3D,customer_id: int,target: int,limit := 1200)->Dictionary:
	for i in range(limit):
		for customer in service.customers:
			if int(customer.id)==customer_id:
				if int(customer.get("portions_done",0))>=target: return customer
				break
		service.advance(0.05)
	return {}

func advance_until_state(service: Node3D,customer_id: int,state: String,done: int,limit := 1200)->Dictionary:
	for i in range(limit):
		for customer in service.customers:
			if int(customer.id)==customer_id and customer.state==state and int(customer.get("portions_done",0))==done: return customer
		service.advance(0.05)
	return {}

func _initialize()->void:
	run.call_deferred()

func run()->void:
	var game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var service=game.service
	var p=service.progress
	p.stars=4
	p.shift="open"
	service.open_for_business=false
	p.cash=1000

	var first=service.add_station("counter",1,false)
	var second=service.add_station("counter",2,false)
	for station in [first,second]:
		station.staffed=1
		station.equipment=["rag","plates","sauce"]
		station.apply_equipment()
		station.recipes.sausage=sausage_recipe(station)
	var unit: int=roundi(25.0*float(first.recipes.sausage.quality.price_factor)*float(first.recipes.sausage.quality.style_multiplier))

	print("1/8: one guest can place an explicit ten-portion automatic order")
	check(service.spawn_customer("sausage",false,false,{},10),"Ten-portion order is accepted")
	var large: Dictionary=customer_by_portions(service,10)
	check(not large.is_empty() and "×10" in large.view.caption.text,"Large order card shows dish quantity")
	var large_id: int=int(large.id)
	var large_station_id: int=int(large.station)
	settle_at_station(service,large)
	check(large.state=="cooking" and service.by_id(large_station_id).customer_id==large_id,"One table owns the whole large order")
	check("Готово 0/10" in large.view.caption.text,"Customer starts with visible 0/10 progress")

	print("2/8: the neighboring table remains available for another guest")
	check(service.spawn_customer("sausage",false,false,{},1),"Neighbor accepts an ordinary order")
	var neighbor: Dictionary={}
	for customer in service.customers:
		if int(customer.id)!=large_id and int(customer.get("portions_total",1))==1 and customer.state!="leaving":
			neighbor=customer
			break
	check(not neighbor.is_empty() and int(neighbor.station)!=large_station_id,"Second guest is assigned to a different free table")
	if not neighbor.is_empty(): service.finish_customer(int(neighbor.id),false)
	check(service.by_id(large_station_id).customer_id==large_id,"Rejecting the neighbor does not release the large-order table")

	print("3/8: the same table repeats its learned method from 0/10 through 10/10")
	var one: Dictionary=advance_until_done(service,large_id,1)
	check(not one.is_empty() and int(one.station)==large_station_id and int(one.order_paid)==unit,"First portion is paid once on the original table")
	var paid_after_one: int=int(one.order_paid)
	service.finish_customer(large_id,true)
	check(int(one.order_paid)==paid_after_one,"Repeated completion during eating cannot pay the same portion twice")
	var ten: Dictionary=advance_until_done(service,large_id,10)
	check(not ten.is_empty() and int(ten.station)==large_station_id,"All ten portions stay assigned to one table")
	check("Готово 10/10" in ten.view.caption.text,"Final portion visibly reaches 10/10 before the guest leaves")
	check(int(ten.order_paid)==unit*10 and service.revenue==unit*10,"Order total equals the sum of ten ordinary portion prices")

	print("4/8: a fully completed ten-portion order counts as one guest and one completed order")
	for i in range(30): service.advance(0.05)
	check(service.served==1,"Ten portions count as one served guest for campaign semantics")
	check(int(service.order_stats.orders_completed)==1,"Ten portions count as one completed order")
	check(int(service.order_stats.portions_served)==10,"Portion statistics count all ten actual servings")
	check(service.by_id(large_station_id).state=="idle","Table releases only after the final portion is eaten")

	print("5/8: large orders visibly queue when all compatible trained tables are occupied")
	check(service.spawn_customer("sausage",false,false,{},10),"Second large order starts")
	var partial: Dictionary=customer_by_portions(service,10)
	var partial_id: int=int(partial.id)
	settle_at_station(service,partial)
	var partial_station_id: int=int(partial.station)
	var other_station=second if partial_station_id==first.station_id else first
	other_station.state="waiting"
	other_station.customer_id=999
	check(service.spawn_customer("sausage",false,false,{},10),"Another ten-portion guest joins the visible queue")
	var queued: Dictionary={}
	for customer in service.customers:
		if int(customer.id)!=partial_id and int(customer.get("portions_total",1))==10 and customer.state=="auto_queue":
			queued=customer
			break
	check(not queued.is_empty() and "Очередь к свободному столу" in queued.view.caption.text,"Queued large order shows quantity, progress and remaining wait")
	if not queued.is_empty():
		queued.wait_limit=float(queued.order_age)+0.01
		service.advance(0.02)
		check(queued.state=="leaving","Queued order leaves after its arrival-based wait expires")
	other_station.state="idle"
	other_station.customer_id=-1

	print("6/8: leaving after seven portions preserves seven payments and records three unserved portions")
	var baseline_revenue: int=service.revenue
	var baseline_partial: int=int(service.order_stats.orders_partial)
	var baseline_unserved: int=int(service.order_stats.portions_unserved)
	var seven: Dictionary=advance_until_state(service,partial_id,"cooking",7)
	check(not seven.is_empty() and int(seven.order_paid)==unit*7,"Seven delivered portions have exactly seven payments")
	seven.wait_limit=float(seven.order_age)
	service.advance(0.02)
	check(seven.state=="leaving","Customer leaves before the eighth portion after the deadline")
	check(service.revenue==baseline_revenue+unit*7,"Partial order keeps payment for seven accepted portions")
	check(int(service.order_stats.orders_partial)==baseline_partial+1,"Partial completion is counted as one partial order")
	check(int(service.order_stats.portions_unserved)==baseline_unserved+3,"The missing three portions are reflected in statistics")
	check(service.by_id(partial_station_id).state=="idle","Partial departure releases the assigned table")

	print("7/8: v18 save preserves portion payments and counters without duplicate accounting")
	var saved_revenue: int=service.revenue
	var saved_cash: int=p.cash
	var saved_stats: Dictionary=service.order_stats.duplicate(true)
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(saved.version==18,"Multi-order save format is v18")
	check(service.load_data(saved),"v18 cafe reloads")
	check(service.revenue==saved_revenue and service.progress.cash==saved_cash,"Reload preserves already paid portions exactly once")
	check(service.order_stats==saved_stats,"Guest/order/portion counters survive reload")
	for i in range(30): service.advance(0.05)
	check(service.revenue==saved_revenue and service.order_stats==saved_stats,"Continuing the cafe does not re-pay completed or abandoned portions")

	print("8/8: stage-4 v17 saves migrate to one-portion statistics")
	var legacy: Dictionary=bytes_to_var(var_to_bytes(saved))
	legacy.version=17
	legacy.erase("guests_arrived")
	legacy.erase("order_stats")
	check(service.load_data(legacy),"v17 cafe remains loadable")
	check(service.save_data().version==18,"Migrated cafe writes the current v18 format")
	check(int(service.order_stats.portions_served)==service.served,"Legacy completed guests migrate as one portion each")

	game._shutdown_tree(game)
	game.free()
	print("PASS: one-table multi-portion orders, neighbor throughput, partial payment, queue wait and persistent portion stats" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
