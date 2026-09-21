extends SceneTree
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
const TYPES=["counter","kitchen","grill_kitchen","solyanka_kitchen"]
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func _initialize()->void: run.call_deferred()

func set_stage(game: Node3D,stage: int)->void:
	var p=game.service.progress
	p.stars=0 if stage==1 else stage
	p.expanded=stage>=3
	p.specialized_expanded=stage>=3
	p.orchestration_expanded=stage>=4
	p.lab_tier=clampi(stage-1,0,2)
	p.lounge_tier=clampi(stage-2,0,2)
	game.service.clear_world()
	for slot in range(Expansion.SLOT_COUNT):
		if Expansion.slot_available(slot,stage): game.service.add_station(TYPES[slot%TYPES.size()],slot,slot==0,true)
	game._refresh_cafe_layout(true)
	game.development.refresh()

func blocking_bodies(game: Node3D,point: Vector3)->Array[String]:
	var shape:=SphereShape3D.new(); shape.radius=0.32
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape; query.transform=Transform3D(Basis.IDENTITY,point); query.collision_mask=1; query.collide_with_bodies=true; query.collide_with_areas=false
	var names: Array[String]=[]
	for hit in game.get_world_3d().direct_space_state.intersect_shape(query,24):
		var collider=hit.get("collider")
		if is_instance_valid(collider): names.append(str(collider.get_path()))
	return names

func check_segment(game: Node3D,name: String,a: Vector3,b: Vector3)->void:
	var steps:=maxi(1,ceili(a.distance_to(b)/0.4))
	for i in range(steps+1):
		var point:=a.lerp(b,float(i)/float(steps))
		var hits:=blocking_bodies(game,point)
		check(hits.is_empty(),"%s blocked at %s by %s"%[name,str(point),str(hits)])

func floor_rects(shell: Node3D)->Array[Rect2]:
	var result: Array[Rect2]=[]
	for child in shell.get_children():
		if child is not MeshInstance3D: continue
		var mesh: Mesh=child.mesh
		if mesh is not BoxMesh: continue
		var size: Vector3=(mesh as BoxMesh).size
		var top: float=child.position.y+size.y*0.5
		if absf(top)>0.002 or absf(size.y-0.10)>0.002: continue
		result.append(Rect2(Vector2(child.position.x-size.x*0.5,child.position.z-size.z*0.5),Vector2(size.x,size.z)))
	return result

func overlap_area(a: Rect2,b: Rect2)->float:
	var x: float=maxf(0.0,minf(a.end.x,b.end.x)-maxf(a.position.x,b.position.x))
	var y: float=maxf(0.0,minf(a.end.y,b.end.y)-maxf(a.position.y,b.position.y))
	return x*y

func run()->void:
	var game=preload("res://scenes/cafe.tscn").instantiate(); root.add_child(game); await process_frame; game.set_physics_process(false)
	print("1/5: final cafe keeps the entrance-to-Chef promenade physically clear")
	set_stage(game,4); await physics_frame; await process_frame
	check_segment(game,"final central promenade",Vector3(0,1.35,Expansion.entrance_z(4)+1.2),Vector3(0,1.35,1.35))
	print("2/5: visitor pockets for all four documented zones stay open from the central hall")
	check_segment(game,"Zone A mouth",Vector3(0,1.35,Expansion.CHEF_FLOW_POINT.z),Vector3(Expansion.ZONE_A_CENTER.x,1.35,Expansion.ZONE_A_CENTER.z))
	check_segment(game,"Zone B mouth",Vector3(0,1.35,Expansion.CHEF_FLOW_POINT.z),Vector3(Expansion.ZONE_B_CENTER.x,1.35,Expansion.ZONE_B_CENTER.z))
	check_segment(game,"Zone C mouth",Vector3(0,1.35,Expansion.FRONT_FLOW_POINT.z),Vector3(Expansion.ZONE_C_CENTER.x,1.35,Expansion.ZONE_C_CENTER.z))
	check_segment(game,"Zone D mouth",Vector3(0,1.35,Expansion.FRONT_FLOW_POINT.z),Vector3(Expansion.ZONE_D_CENTER.x,1.35,Expansion.ZONE_D_CENTER.z))
	print("3/5: starter cafe keeps a clear approach to fixed Chef")
	set_stage(game,1); await physics_frame; await process_frame
	check_segment(game,"starter central approach",Vector3(0,1.35,Expansion.entrance_z(1)+1.2),Vector3(0,1.35,1.35))
	check(game.service.by_id(1).global_position.distance_to(Expansion.CHEF_POSITION)<0.05,"Chef remains at the same spatial anchor")
	print("4/5: irregular staged floor has no coplanar slab overlap")
	set_stage(game,4); await physics_frame; await process_frame
	var rects:=floor_rects(game.room_shell); check(rects.size()>5,"Irregular A-D floor uses multiple row runs")
	for i in range(rects.size()):
		for j in range(i+1,rects.size()): check(overlap_area(rects[i],rects[j])<0.001,"Floor slabs %d and %d overlap"%[i,j])
	print("5/5: training bounds stay hidden outside active training")
	for station in game.service.stations:
		for edge in station.zone_edges: check(not edge.visible,"Station %d shows a training-zone edge while idle"%station.station_id)
		for wall in station.walls: check(not wall.visible,"Station %d shows a training wall while idle"%station.station_id)
	game._shutdown_tree(game); game.free()
	print("PASS: zoned physical courts, Chef visibility and floor surfaces" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
