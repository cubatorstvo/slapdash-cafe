extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Library=preload("res://scripts/masterclass_library.gd")
const Layout=preload("res://scripts/lounge_layout.gd")
const Annex=preload("res://scripts/cafe_annex.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func repeated(value: Dictionary,count: int)->Array:
	var result: Array=[]
	for i in range(count): result.append(value.duplicate(true))
	return result

func prepare(station: Node3D)->void:
	station.staffed=1
	station.equipment=["rag","plates","sauce"]
	station.apply_equipment()

func record_for(station: Node3D)->Dictionary:
	station.model.reset("sausage")
	var frames:=repeated(station.model.snapshot(),120)
	return Library.make_record(8801,"sausage","counter",[{"group":1,"frames":frames}],2.0,station.model.quality(),"Массовый курс")

func run_until(service: Node3D,predicate: Callable,seconds := 120.0)->bool:
	for i in range(ceili(seconds/0.1)):
		service.advance(0.1)
		await process_frame
		if predicate.call(): return true
	return false

func tree_text(node: Node)->String:
	var result: String=""
	if node is Label or node is Button: result+=str(node.text)+"\n"
	for child in node.get_children(): result+=tree_text(child)
	return result

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
	p.stars=5
	p.shift="open"
	p.lounge_tier=2
	p.lounge_items=["sofa","television","rocking_chair","foosball","arcade","table_tennis","board_games","bookcase","beanbag","tea_station","jukebox","aquarium","plants","floor_lamp","snack_fridge","textiles","ambient"]
	service.open_for_business=false

	print("T24 1/5: twenty total slots mean nineteen production places")
	var production: Array=[]
	for slot in range(1,20):
		var station=service.add_station("counter",slot,false,true)
		prepare(station)
		production.append(station)
	var record: Dictionary=record_for(production[0])
	service.masterclasses=[record]
	service.next_masterclass_id=8802
	var ids: Array=production.map(func(station):return station.station_id)
	var scale: Dictionary=service.production_scale_summary()
	check(service.stations.size()==20,"Cafe has twenty total slots including chef")
	check(ids.size()==19 and ids.front()==2 and ids.back()==20,"Production station ids occupy all nineteen non-chef slots")
	check(int(scale.max_places)==19 and int(scale.places)==19 and int(scale.assigned_workers)==19,"Scale summary excludes chef and counts all nineteen workers")

	print("T24 2/5: all available staff fit distinct walkable television places")
	var spots: Array=Layout.training_viewer_spots(19,p.lounge_tier,p.lounge_items)
	check(spots.size()==19,"Lounge allocator provides nineteen training places")
	var blockers:=Layout.obstacles(p.lounge_tier,p.lounge_items)
	for i in range(spots.size()):
		var point:=Vector3(spots[i])
		check(Layout.walkable(point,blockers,p.lounge_tier),"Training place %d is on walkable lounge floor"%i)
		check(point.distance_to(Annex.REST_DOOR_ROOM)>1.2,"Training place %d keeps the lounge doorway clear"%i)
		for j in range(i):
			check(point.distance_to(Vector3(spots[j]))>=0.54,"Training places %d and %d do not overlap"%[i,j])

	print("T24 3/5: one real course gathers all nineteen workers through the lounge doors")
	var queued: Dictionary=service.queue_training_course([{"record_id":8801,"station_ids":ids}],"together","t24-all-staff",1)
	check(str(queued.get("error","")).is_empty(),"Nineteen-table course is accepted")
	var duplicate: Dictionary=service.queue_training_course([{"record_id":8801,"station_ids":ids}],"together","t24-all-staff",1)
	check(bool(duplicate.get("duplicate",false)) and int(duplicate.get("course_id",0))==int(queued.get("course_id",0)),"Repeated command is idempotent")
	check(await run_until(service,func():return service.staff_training.phase=="walking",20.0),"Full party reaches physical walking phase")
	check(service.staff_training.actors.size()==19,"Exactly nineteen staff actors represent the training party")
	for key in service.staff_training.actor_paths:
		var path: Array=service.staff_training.actor_paths[key]
		var near_cafe_door:=false
		var near_room_door:=false
		for raw in path:
			var world: Vector3=service.to_global(Vector3(raw))
			if world.distance_to(Annex.REST_DOOR_CAFE)<0.08: near_cafe_door=true
			if world.distance_to(Annex.REST_DOOR_ROOM)<0.08: near_room_door=true
		check(near_cafe_door and near_room_door,"Worker route %s passes both real lounge door waypoints"%str(key))

	print("T24 4/5: the full party reaches the TV without overlapping furniture")
	check(await run_until(service,func():return service.staff_training.phase=="watching",45.0),"Nineteen workers reach the television")
	check(service.staff_training.actors.size()==19,"All nineteen physical viewers remain represented")
	for key in service.staff_training.actors:
		var actor: Node3D=service.staff_training.actors[key]
		check(Layout.walkable(actor.global_position,blockers,p.lounge_tier),"Viewer %s stands on walkable floor"%str(key))
	check(await run_until(service,func():return str(service.training_queue._course(int(queued.course_id)).get("state",""))=="completed",60.0),"Mass course returns and completes")
	for station in production:
		check(int(station.method_sources.get("sausage",{}).get("id",0))==8801,"Station %d learns the mass course exactly once"%station.station_id)

	print("T24 5/5: course editor reports the same real scale")
	game.office.open("groups")
	game.office.select_group_stations(ids)
	game.office.course_editor_open()
	var rendered:=tree_text(game.office.content)
	check("19/19 производственных мест" in rendered,"Course UI reports nineteen of nineteen production places")
	check("работников 19" in rendered,"Course UI reports nineteen actual workers")
	game.office.close()

	game._shutdown_tree(game)
	game.free()
	print("PASS: T24 nineteen-place full-staff training uses walkable lounge routes and honest UI counts" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
