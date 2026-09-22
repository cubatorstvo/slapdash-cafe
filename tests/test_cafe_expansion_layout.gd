extends SceneTree
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
const Annex=preload("res://scripts/cafe_annex.gd")
const Lounge=preload("res://scripts/lounge_layout.gd")
var failures:=0

func _initialize()->void: run.call_deferred()
func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func floor_cell(point: Vector3)->Vector2i:
	return Vector2i(floori(point.x/Expansion.TILE),floori(point.z/Expansion.TILE))
func hall_contains(point: Vector3,stage: int)->bool:
	return Expansion.hall_cells_for_stage(stage).has(floor_cell(point))
func segment_inside(a: Vector3,b: Vector3,stage: int)->bool:
	var steps:=maxi(1,ceili(a.distance_to(b)/0.15))
	for i in range(steps+1):
		if not hall_contains(a.lerp(b,float(i)/float(steps)),stage): return false
	return true
func route_inside(route: Array,stage: int)->bool:
	if route.size()<2: return false
	for i in range(route.size()-1):
		if not segment_inside(Vector3(route[i]),Vector3(route[i+1]),stage): return false
	return true
func set_stage(game: Node3D,stage: int)->void:
	var p=game.service.progress
	p.stars=0 if stage==1 else stage
	p.expanded=stage>=3
	p.specialized_expanded=stage>=3
	p.orchestration_expanded=stage>=4
	p.lab_tier=clampi(stage-1,0,2)
	p.lounge_tier=clampi(stage-2,0,2)
	game._refresh_cafe_layout(true)

func run()->void:
	print("1/5: staged prototype floor is cumulative and keeps Chef fixed")
	var previous: Dictionary={}
	for stage in range(1,5):
		var cells:=Expansion.hall_cells_for_stage(stage)
		check(not cells.is_empty(),"Stage %d has walkable cafe cells"%stage)
		for cell in previous: check(cells.has(cell),"Stage %d keeps every previous cell"%stage)
		check(hall_contains(Expansion.CHEF_POSITION,stage),"Chef stays inside stage %d"%stage)
		check(hall_contains(Expansion.player_spawn(stage),stage),"Player spawn is inside stage %d"%stage)
		check(hall_contains(Expansion.customer_spawn(stage),stage),"Customer spawn is inside stage %d"%stage)
		previous=cells
	check(is_equal_approx(Expansion.entrance_z(1),Expansion.entrance_z(2)) and is_equal_approx(Expansion.entrance_z(2),Expansion.entrance_z(3)),"Stages 1-3 share the early entrance")
	check(Expansion.entrance_z(4)<Expansion.entrance_z(3)-10.0,"Final expansion moves entrance to C/D")

	print("2/5: every production slot and working side sits on its unlocked floor")
	for slot in range(Expansion.SLOT_COUNT):
		var stage:=Expansion.unlock_stage_for_slot(slot)
		var station:=Expansion.position(slot)
		var yaw:=Expansion.rotation_y(slot)
		var customer:=station+Vector3(0,0,-1.85).rotated(Vector3.UP,yaw)
		var worker:=station+Vector3(0,0,1.85).rotated(Vector3.UP,yaw)
		check(hall_contains(station,stage),"Slot %d center is inside stage %d"%[slot+1,stage])
		check(hall_contains(customer,stage),"Slot %d customer side stays inside stage %d"%[slot+1,stage])
		check(hall_contains(worker,stage),"Slot %d worker side stays inside stage %d"%[slot+1,stage])
		var rear:=Expansion.route_to_rear(worker,Annex.REST_DOOR_CAFE)
		check(route_inside(rear,stage),"Worker route from slot %d reaches rear rooms on opened floor"%(slot+1))
		if slot>0:
			check(route_inside(Expansion.route_from_entrance(customer,stage),stage),"Customer route to slot %d stays on opened floor"%(slot+1))

	print("3/5: delivery staging follows active entrance")
	for stage in range(1,5):
		for id in range(1,10): check(hall_contains(Expansion.delivery_position(stage,id),stage),"Delivery %d is on opened floor at stage %d"%[id,stage])
		check(hall_contains(Expansion.delivery_vehicle_spawn(stage),stage),"Delivery truck staging is on opened floor at stage %d"%stage)

	print("4/5: real cafe rebuilds through all four stages and rear-room doors stay reachable")
	var game=preload("res://scenes/cafe.tscn").instantiate(); root.add_child(game); await process_frame; game.set_physics_process(false); game.new_cafe()
	for stage in range(1,5):
		set_stage(game,stage); await process_frame
		check(game.layout_stage==stage,"Cafe shell switches to stage %d"%stage)
		var to_lab:=Expansion.route_to_rear(Expansion.CHEF_POSITION,Annex.LAB_DOOR_CAFE)
		check(to_lab.has(Expansion.REAR_SPINE_POINT),"Lab route crosses rear spine at stage %d"%stage)
		if stage>=2:
			var p=game.service.progress
			var lounge_target: Vector3=Vector3(Lounge.rest_spot(0,p.lounge_tier,p.lounge_items).position)
			check(Lounge.path_between(Annex.REST_DOOR_ROOM,lounge_target,p.lounge_tier,p.lounge_items).size()>=2,"Lounge path exists at stage %d"%stage)

	print("5/5: stage transitions expose only production slots that physically exist")
	for stage in range(1,5):
		for slot in range(Expansion.SLOT_COUNT): check(Expansion.slot_available(slot,stage)==(Expansion.unlock_stage_for_slot(slot)<=stage),"Slot %d availability matches stage %d"%[slot+1,stage])
	game._shutdown_tree(game); game.free()
	print("PASS: staged zoned cafe, spawns and rear-room routes" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
