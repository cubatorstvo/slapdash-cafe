extends SceneTree
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
const TYPES=["counter","kitchen","grill_kitchen","solyanka_kitchen"]
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func _initialize()->void:
	run.call_deferred()

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
		if Expansion.slot_available(slot,stage):
			game.service.add_station(TYPES[slot%TYPES.size()],slot,slot==0,true)
	game._refresh_cafe_layout(true)
	game.development.refresh()

func blocking_bodies(game: Node3D,point: Vector3)->Array[String]:
	var shape:=SphereShape3D.new()
	shape.radius=0.36
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,point)
	query.collision_mask=1
	query.collide_with_bodies=true
	query.collide_with_areas=false
	var names: Array[String]=[]
	for hit in game.get_world_3d().direct_space_state.intersect_shape(query,16):
		var collider=hit.get("collider")
		if is_instance_valid(collider): names.append(str(collider.get_path()))
	return names

func check_corridor(game: Node3D,name: String,x: float,z0: float,z1: float)->void:
	var z:=z0
	while z<=z1+0.01:
		var point:=Vector3(x,1.0,z)
		var hits:=blocking_bodies(game,point)
		check(hits.is_empty(),"%s blocked at %s by %s"%[name,str(point),str(hits)])
		z+=0.5

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
	var game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)

	print("1/4: final cafe has physically clear main aisles")
	set_stage(game,4)
	await physics_frame
	await process_frame
	check_corridor(game,"central promenade",0.0,Expansion.entrance_z(4)+1.2,4.0)
	check_corridor(game,"left service aisle",Expansion.LEFT_AISLE_X,Expansion.entrance_z(4)+1.2,11.0)
	check_corridor(game,"right service aisle",Expansion.RIGHT_AISLE_X,Expansion.entrance_z(4)+1.2,11.0)

	print("2/4: starter cafe keeps a clear route from entrance to Chef")
	set_stage(game,1)
	await physics_frame
	await process_frame
	check_corridor(game,"starter central route",0.0,Expansion.entrance_z(1)+1.2,4.0)

	print("3/4: walkable floor slabs meet at edges without coplanar overlap")
	set_stage(game,4)
	await physics_frame
	await process_frame
	var rects:=floor_rects(game.room_shell)
	check(rects.size()==5,"Expected five non-overlapping stage-4 floor slabs, got %d"%rects.size())
	for i in range(rects.size()):
		for j in range(i+1,rects.size()):
			check(overlap_area(rects[i],rects[j])<0.001,"Floor slabs %d and %d overlap by %.3f m²"%[i,j,overlap_area(rects[i],rects[j])])

	print("4/4: training bounds stay hidden outside active training")
	for station in game.service.stations:
		for edge in station.zone_edges:
			check(not edge.visible,"Station %d shows a training-zone edge while idle"%station.station_id)
		for wall in station.walls:
			check(not wall.visible,"Station %d shows a training wall while idle"%station.station_id)

	game._shutdown_tree(game)
	game.free()
	print("PASS: physical aisles, floor surfaces and idle training visuals" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
