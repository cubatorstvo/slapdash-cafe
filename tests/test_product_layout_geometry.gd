extends SceneTree
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
const Station=preload("res://scripts/work_station.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func floor_cell(point: Vector3)->Vector2i:
	return Vector2i(floori(point.x/Expansion.TILE),floori(point.z/Expansion.TILE))

func hall_contains(point: Vector3,stage: int)->bool:
	return Expansion.hall_cells_for_stage(stage).has(floor_cell(point))

func station_clearance(a: Vector3,b: Vector3)->float:
	var dx:=absf(a.x-b.x)-Station.SLOT_WIDTH
	var dz:=absf(a.z-b.z)-Station.SLOT_DEPTH
	return maxf(dx,dz)

func point_clear_of_station(point: Vector3,center: Vector3,margin:=0.55)->bool:
	return absf(point.x-center.x)>Station.SLOT_WIDTH*0.5+margin or absf(point.z-center.z)>Station.SLOT_DEPTH*0.5+margin

func route_clear_of_other_slots(route: Array,own_slot: int,stage: int)->bool:
	for index in range(route.size()-1):
		var a:=Vector3(route[index])
		var b:=Vector3(route[index+1])
		var steps:=maxi(1,ceili(a.distance_to(b)/0.15))
		for step in range(steps+1):
			var point:=a.lerp(b,float(step)/float(steps))
			for slot in range(Expansion.SLOT_COUNT):
				if slot==own_slot or Expansion.unlock_stage_for_slot(slot)>stage: continue
				if not point_clear_of_station(point,Expansion.position(slot),0.15): return false
	return true

func _initialize()->void:
	run.call_deferred()

func run()->void:
	print("1/6: all twenty station footprints have product-scale breathing room")
	for a in range(Expansion.SLOT_COUNT):
		for b in range(a+1,Expansion.SLOT_COUNT):
			var clearance:=station_clearance(Expansion.position(a),Expansion.position(b))
			check(clearance>=1.75,"Slots %d and %d need >=1.75 m clearance, got %.2f"%[a+1,b+1,clearance])

	print("2/6: main service aisles and the transverse aisle stay outside station footprints")
	for slot in range(Expansion.SLOT_COUNT):
		var center:=Expansion.position(slot)
		for aisle_x in Expansion.AISLE_XS:
			for z in [-24.0,-16.0,-8.0,0.0]:
				check(point_clear_of_station(Vector3(float(aisle_x),0,z),center),"Service aisle %.1f intersects slot %d"%[float(aisle_x),slot+1])
		for side_aisle_x in [Expansion.LEFT_AISLE_X,Expansion.RIGHT_AISLE_X]:
			check(point_clear_of_station(Vector3(float(side_aisle_x),0,8.0),center),"Rear service aisle %.1f intersects slot %d"%[float(side_aisle_x),slot+1])
		check(point_clear_of_station(Expansion.CHEF_FLOW_POINT,center),"Central transverse aisle intersects slot %d"%(slot+1))

	print("3/6: every slot footprint and working side is supported by its unlock-stage floor")
	for slot in range(Expansion.SLOT_COUNT):
		var stage:=Expansion.unlock_stage_for_slot(slot)
		var center:=Expansion.position(slot)
		var points=[
			center,
			center+Vector3(-Station.SLOT_WIDTH*0.5+0.1,0,-Station.SLOT_DEPTH*0.5+0.1),
			center+Vector3(Station.SLOT_WIDTH*0.5-0.1,0,Station.SLOT_DEPTH*0.5-0.1),
			center+Vector3(0,0,-3.0),
			center+Vector3(0,0,3.0)
		]
		for point in points:
			check(hall_contains(point,stage),"Slot %d footprint point %s is outside stage %d floor"%[slot+1,str(point),stage])

	print("4/6: staged entrances move forward with expansions and keep a useful lobby")
	check(is_equal_approx(Expansion.entrance_z(1),Expansion.entrance_z(2)),"First-star expansion keeps the original entrance")
	check(Expansion.entrance_z(3)<Expansion.entrance_z(2)-6.0,"Third stage moves the front wall forward")
	check(Expansion.entrance_z(4)<Expansion.entrance_z(3)-8.0,"Final stage adds a deeper front lobby")
	for stage in range(1,5):
		check(hall_contains(Expansion.player_spawn(stage),stage),"Player spawn is supported at stage %d"%stage)
		check(hall_contains(Expansion.customer_spawn(stage),stage),"Customer spawn is supported at stage %d"%stage)

	print("5/6: traffic uses the aisles instead of cutting through other stations")
	for slot in range(Expansion.SLOT_COUNT):
		var stage:=Expansion.unlock_stage_for_slot(slot)
		var center:=Expansion.position(slot)
		var customer:=center+Vector3(0,0,-1.85)
		var worker:=center+Vector3(0,0,1.85)
		check(route_clear_of_other_slots(Expansion.route_from_entrance(customer,stage),slot,stage),"Entrance route cuts through another station for slot %d"%(slot+1))
		check(route_clear_of_other_slots(Expansion.route_to_exit(customer,stage),slot,stage),"Exit route cuts through another station for slot %d"%(slot+1))
		check(route_clear_of_other_slots(Expansion.route_to_rear(worker,Vector3(0,0,13.1)),slot,stage),"Rear route cuts through another station for slot %d"%(slot+1))

	print("6/6: permanent fixtures stay grounded and clear of every production footprint")
	for slot in range(Expansion.SLOT_COUNT):
		var center:=Expansion.position(slot)
		check(point_clear_of_station(Expansion.MARKET_POSITION,center,0.85),"Market computer intersects production slot %d"%(slot+1))
		for plant in Expansion.DECOR_PLANT_POINTS:
			check(point_clear_of_station(Vector3(plant.x,0,plant.y),center,0.50),"Cafe plant intersects production slot %d"%(slot+1))
	for stage in range(1,5):
		for id in range(1,10):
			check(is_equal_approx(Expansion.delivery_position(stage,id).y,0.25),"Delivery box base height drifted at stage %d"%stage)

	print("PASS: spacious station grid, clear aisles and staged floor geometry" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
