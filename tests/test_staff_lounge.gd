extends SceneTree
const Layout=preload("res://scripts/lounge_layout.gd")
const Annex=preload("res://scripts/cafe_annex.gd")
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",message)

func run() -> void:
	print("STAGE 1/4: room construction and walkable routes")
	var game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	await physics_frame
	var lounge: Node3D=get_first_node_in_group("staff_lounge")
	check(lounge!=null and lounge.fixtures.size()==15,"Fifteen full-size lounge furnishings constructed")
	check(Annex.REST_AREA>240.0,"Largest lounge shell is active")
	check(Layout.activity_slots().size()==20,"Twenty individual activity places")
	var sphere:=SphereShape3D.new()
	sphere.radius=0.28
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=sphere
	query.collision_mask=1
	var space: PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
	for spot in Layout.activity_slots():
		var route:=Layout.approach_path(spot.approach)
		check(route.size()>1,"Reachable approach: "+str(spot.id))
		for i in range(1,route.size()):
			var from: Vector3=route[i-1]
			var to: Vector3=route[i]
			var samples:=maxi(1,ceili(from.distance_to(to)/0.18))
			for sample in range(samples+1):
				var point:=from.lerp(to,float(sample)/samples)
				query.transform=Transform3D(Basis.IDENTITY,point+Vector3(0,0.90,0))
				check(space.intersect_shape(query,1).is_empty(),"Clear physical route: "+str(spot.id))
	for index in range(4):
		check(Annex.player_bed_exit(index).z<Annex.player_bed_center(index).z,"Bed exit remains in front of its mattress")
		check(Layout.approach_path(Annex.player_bed_exit(index)).size()>1,"Player bed has reachable access")

	print("STAGE 2/4: daily assignment, capacity and overflow")
	var p=game.service.progress
	p.stars=1; p.lab_stage=3; p.shift="night"
	for i in range(24): check(game.service.create_clone(1.0,true).is_empty(),"Create preview worker")
	var assignments: Array=game.evening.plan()
	var ids: Array=[]
	var destinations: Array=[]
	var before: Dictionary={}
	for assignment in assignments:
		check(int(assignment.worker.id) not in ids,"One activity per worker")
		check(str(assignment.spot.id) not in destinations,"Exclusive activity destination")
		ids.append(int(assignment.worker.id))
		destinations.append(str(assignment.spot.id))
		before[int(assignment.worker.id)]=str(assignment.spot.id)
	check(assignments.size()>=24,"Every worker receives a place, including overflow")
	game.service.create_clone(1.0,true)
	for assignment in game.evening.plan():
		var id:=int(assignment.worker.id)
		if before.has(id): check(before[id]==str(assignment.spot.id),"Adding a worker preserves existing evening choices")
	p.day+=1
	var changed:=false
	for assignment in game.evening.plan():
		var id:=int(assignment.worker.id)
		if before.has(id) and before[id]!=str(assignment.spot.id): changed=true
	check(changed,"Activities vary between days")

	print("STAGE 3/4: leisure poses, morning and cooking isolation")
	var records: Array=[]
	for station in game.service.stations: records.append(var_to_bytes(station.recipes))
	p.night_elapsed=90.0
	game.evening._process(1.0/60.0)
	lounge._process(1.0/60.0)
	for performer in game.evening.performers.values():
		check(performer.settled and performer.actor.visible,"Worker stays visible at its activity")
		check(not performer.actor.hat.visible and performer.hat.visible,"Thrown hat remains separate from leisure pose")
		check(performer.actor.position.is_finite(),"Leisure pose has finite position")
	game.evening.apply_rest()
	for worker in game.evening.workers():
		check(is_equal_approx(float(game.service.clone_data(worker.id).rest),1.0),"Preview supplies no productivity bonus")
	for index in range(game.service.stations.size()):
		check(records[index]==var_to_bytes(game.service.stations[index].recipes),"Leisure preserves recorded recipes")
	p.shift="open"
	game.evening._process(1.0/60.0)
	check(game.evening.performers.is_empty(),"Morning removes leisure doubles")

	print("STAGE 4/4: result")
	game._shutdown_tree(game)
	game.free()
	print("PASS: furnished lounge, physical routes, daily places, overflow and neutral preview" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
