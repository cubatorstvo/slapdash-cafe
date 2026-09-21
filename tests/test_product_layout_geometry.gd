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

func station_axes(slot: int)->Array[Vector2]:
	var yaw:=Expansion.rotation_y(slot)
	var x_axis:=Vector3.RIGHT.rotated(Vector3.UP,yaw)
	var z_axis:=Vector3.BACK.rotated(Vector3.UP,yaw)
	return [Vector2(x_axis.x,x_axis.z),Vector2(z_axis.x,z_axis.z)]

func station_overlap(a: int,b: int,margin:=0.0)->bool:
	var a_center:=Vector2(Expansion.position(a).x,Expansion.position(a).z)
	var b_center:=Vector2(Expansion.position(b).x,Expansion.position(b).z)
	var a_axes:=station_axes(a)
	var b_axes:=station_axes(b)
	var half_w:=Station.SLOT_WIDTH*0.5
	var half_d:=Station.SLOT_DEPTH*0.5
	for axis in [a_axes[0],a_axes[1],b_axes[0],b_axes[1]]:
		var ra:=half_w*absf(a_axes[0].dot(axis))+half_d*absf(a_axes[1].dot(axis))
		var rb:=half_w*absf(b_axes[0].dot(axis))+half_d*absf(b_axes[1].dot(axis))
		if absf((b_center-a_center).dot(axis))>=ra+rb+margin: return false
	return true

func point_clear_of_station(point: Vector3,slot: int,margin:=0.0)->bool:
	var local: Vector3=(point-Expansion.position(slot)).rotated(Vector3.UP,-Expansion.rotation_y(slot))
	return absf(local.x)>Station.SLOT_WIDTH*0.5+margin or absf(local.z)>Station.SLOT_DEPTH*0.5+margin

func station_support_points(slot: int)->Array[Vector3]:
	var center:=Expansion.position(slot)
	var yaw:=Expansion.rotation_y(slot)
	var x_axis:=Vector3.RIGHT.rotated(Vector3.UP,yaw)
	var z_axis:=Vector3.BACK.rotated(Vector3.UP,yaw)
	var half_w:=Station.SLOT_WIDTH*0.5-0.08
	var half_d:=Station.SLOT_DEPTH*0.5-0.08
	var points: Array[Vector3]=[center]
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]: points.append(center+x_axis*half_w*sx+z_axis*half_d*sz)
	return points

func route_clear_of_other_slots(route: Array,own_slot: int,stage: int)->bool:
	for index in range(route.size()-1):
		var a:=Vector3(route[index])
		var b:=Vector3(route[index+1])
		var steps:=maxi(1,ceili(a.distance_to(b)/0.12))
		for step in range(steps+1):
			var point:=a.lerp(b,float(step)/float(steps))
			for slot in range(1,Expansion.SLOT_COUNT):
				if slot==own_slot or Expansion.unlock_stage_for_slot(slot)>stage: continue
				if not point_clear_of_station(point,slot,0.10): return false
	return true

func _initialize()->void: run.call_deferred()

func run()->void:
	print("1/7: production slots preserve the documented Zone A-D progression")
	var counts: Dictionary={"Zone A":0,"Zone B":0,"Zone C":0,"Zone D":0}
	for slot in range(1,Expansion.SLOT_COUNT): counts[Expansion.zone_for_slot(slot)]=int(counts.get(Expansion.zone_for_slot(slot),0))+1
	check(counts["Zone A"]==5,"Zone A keeps five production places")
	check(counts["Zone B"]==7,"Zone B keeps seven production places")
	check(counts["Zone C"]==8 and counts["Zone D"]==10,"Full prototype courts contain eight and ten places")

	print("2/7: A and B begin on the Chef row instead of behind him")
	var rear_a:=-INF
	for point in Expansion.ZONE_A_POSITIONS: rear_a=maxf(rear_a,point.z)
	var rear_b:=-INF
	for point in Expansion.ZONE_B_POSITIONS: rear_b=maxf(rear_b,point.z)
	check(absf(rear_a-Expansion.CHEF_POSITION.z)<=1.25,"Zone A rear edge aligns with Chef")
	check(absf(rear_b-Expansion.CHEF_POSITION.z)<=1.25,"Zone B rear edge aligns with Chef")

	print("3/7: full training footprints do not overlap despite the asymmetric courts")
	for a in range(1,Expansion.SLOT_COUNT):
		for b in range(a+1,Expansion.SLOT_COUNT): check(not station_overlap(a,b,0.20),"Zone layout overlaps station footprints %d and %d"%[a+1,b+1])

	print("4/7: every court faces visitors inward and cooks outward")
	for slot in range(1,Expansion.SLOT_COUNT):
		var center:=Expansion.position(slot)
		var yaw:=Expansion.rotation_y(slot)
		var customer:=center+Vector3(0,0,-1.85).rotated(Vector3.UP,yaw)
		var worker:=center+Vector3(0,0,1.85).rotated(Vector3.UP,yaw)
		var zone_center:=Expansion.zone_center(slot)
		check(customer.distance_to(zone_center)<worker.distance_to(zone_center),"Slot %d must keep visitors inside its zone and cooks outside"%(slot+1))

	print("5/7: each station footprint is supported when its zone opens")
	for slot in range(Expansion.SLOT_COUNT):
		var stage:=Expansion.unlock_stage_for_slot(slot)
		for point in station_support_points(slot): check(hall_contains(point,stage),"Slot %d footprint point %s is outside stage %d floor"%[slot+1,str(point),stage])

	print("6/7: guest routes enter courts through their visitor pockets instead of cutting through tables")
	for slot in range(1,Expansion.SLOT_COUNT):
		var stage:=Expansion.unlock_stage_for_slot(slot)
		var center:=Expansion.position(slot)
		var customer:=center+Vector3(0,0,-1.85).rotated(Vector3.UP,Expansion.rotation_y(slot))
		var arriving: Array=[Expansion.customer_spawn(stage)]
		arriving.append_array(Expansion.cafe_route(arriving[0],customer,stage))
		var leaving:=Expansion.route_to_exit(customer,stage)
		check(arriving.has(Expansion.zone_center(slot)),"Entrance route to slot %d passes through its visitor pocket"%(slot+1))
		check(leaving.has(Expansion.zone_center(slot)),"Exit route from slot %d passes through its visitor pocket"%(slot+1))
		check(route_clear_of_other_slots(arriving,slot,stage),"Entrance route cuts through another production table for slot %d"%(slot+1))
		check(route_clear_of_other_slots(leaving,slot,stage),"Exit route cuts through another production table for slot %d"%(slot+1))

	print("7/7: central fixtures stay clear and deliveries remain grounded")
	for slot in range(1,Expansion.SLOT_COUNT):
		check(point_clear_of_station(Expansion.MARKET_POSITION,slot,0.25),"Market computer intersects production slot %d"%(slot+1))
		for plant in Expansion.DECOR_PLANT_POINTS: check(point_clear_of_station(Vector3(plant.x,0,plant.y),slot,0.20),"Cafe plant intersects production slot %d"%(slot+1))
	for stage in range(1,5):
		for id in range(1,10): check(is_equal_approx(Expansion.delivery_position(stage,id).y,0.25),"Delivery box base height drifted at stage %d"%stage)

	print("PASS: documented Zone A-D topology, Chef-row visibility and clear guest routes" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
