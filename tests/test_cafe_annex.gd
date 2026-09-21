extends SceneTree
const Annex=preload("res://scripts/cafe_annex.gd")
const Lounge=preload("res://scripts/lounge_layout.gd")
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",text)
func run() -> void:
	var game=preload("res://scenes/cafe.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false)
	var lab=game.laboratory
	var operator: Vector3=lab.operator_position()
	check(operator.z>Annex.CAFE_BACK_Z+1.0,"Laboratory operator stands behind original cafe wall")
	check(operator.x>Annex.LAB_X_MIN and operator.x<Annex.LAB_X_MAX,"Laboratory remains opposite station row")
	check(lab.inside(operator),"Moved laboratory interaction volume follows transform")
	check(game.shop.lab_position(1).z>Annex.CAFE_BACK_Z,"Laboratory deliveries target rear room")
	check(Annex.rest_spot(0).position.z>Annex.CAFE_BACK_Z,"Clone rest spots are behind cafe")
	check(Annex.REST_AREA>100.0,"Rest room is roughly triple the previous area")
	check(Annex.player_bed_center(3).x<Annex.REST_X_MAX,"Shared chef bed fits inside the room")
	check(game.annex.doors.has("lab"),"Stage 1 has the laboratory sliding door")
	var lab_door: Dictionary=game.annex.doors.get("lab",{})
	for leaf_data in lab_door.leaves:
		var leaf: Node3D=leaf_data.node
		check(leaf is AnimatableBody3D,"Laboratory door leaf is the moving collision body")
		check(leaf.rotation.length()<0.01,"Laboratory door leaf stays axis-aligned")
		check(not bool(leaf.sync_to_physics),"Scripted door leaves are not physics-interpolated")
	game.player.global_position=Annex.LAB_DOOR_CAFE
	game.annex.advance_doors(0.30)
	check(game.annex.door_openness("lab")>0.9,"Laboratory door opens for approaching player")
	await physics_frame
	await physics_frame
	var doorway:=PhysicsShapeQueryParameters3D.new()
	var probe:=SphereShape3D.new(); probe.radius=0.22
	doorway.shape=probe
	doorway.transform=Transform3D(Basis.IDENTITY,Vector3(Annex.LAB_DOOR_X,1.15,Annex.CAFE_BACK_Z))
	doorway.collision_mask=1
	doorway.collide_with_bodies=true
	var blockers: Array=[]
	for hit in game.get_world_3d().direct_space_state.intersect_shape(doorway,12):
		var collider=hit.get("collider")
		if is_instance_valid(collider): blockers.append(str(collider.get_path()))
	check(blockers.is_empty(),"Open laboratory doorway is physically clear at stage 1, not %s"%str(blockers))
	game.player.global_position=Vector3(0,0,0)
	for i in range(8): game.annex.advance_doors(0.25)
	check(game.annex.door_openness("lab")<0.1,"Laboratory door closes after player leaves")
	game.service.progress.stars=1
	game._refresh_cafe_layout(true)
	game.player.global_position=Annex.REST_DOOR_CAFE
	game.annex.advance_doors(0.30)
	check(game.annex.door_openness("rest")>0.9,"Rest door opens for approaching player")
	var rest_door: Dictionary=game.annex.doors.get("rest",{})
	if not rest_door.is_empty():
		for leaf_data in rest_door.leaves:
			var leaf: Node3D=leaf_data.node
			check(leaf is AnimatableBody3D,"Sliding rest door uses an AnimatableBody3D collision")
			check(leaf.rotation.length()<0.01,"Rest door leaf stays axis-aligned")
	game.player.global_position=Vector3(0,0,0)
	for i in range(8): game.annex.advance_doors(0.25)
	check(game.annex.door_openness("rest")<0.1,"Rest door closes after player leaves")
	var clone:=Node3D.new(); game.add_child(clone); clone.add_to_group("automatic_door_actor"); clone.global_position=Annex.LAB_DOOR_ROOM
	game.annex.advance_doors(0.30)
	check(game.annex.door_openness("lab")>0.9,"Laboratory door opens for approaching clone")
	clone.queue_free()
	var station=game.service.add_station("counter",1,false,true)
	game.service.progress.stars=1; game.service.progress.lab_stage=3
	game.service.create_clone(1.0,true)
	game.service.create_clone(1.0,true)
	check(game.service.progress.free_workers.size()==1,"Extra clone remains dormant in laboratory inventory")
	check(game.evening.workers().size()==1,"Dormant free clone does not join lounge life")
	game.service.progress.shift="night"; game.service.progress.night_elapsed=25.0
	game.evening._process(1.0/60.0)
	check(game.evening.performers.size()==1,"Night worker gets a rear rest route")
	if game.evening.performers.size()==1:
		var performer: Dictionary=game.evening.performers.values()[0]
		check(performer.actor.global_position.z>Annex.CAFE_BACK_Z,"Night worker settles behind cafe in rest room")
		check(performer.actor.global_position.x>Annex.REST_X_MIN,"Night worker settles in expanded rest room")
		check(performer.get("settled",false) and not str(performer.get("item","")).is_empty(),"Settled worker occupies a lounge activity")
	var planned: Array=game.evening.route_for({"home":station.global_position,"from_lab":false},Annex.rest_spot(0).position)
	check(Annex.REST_DOOR_CAFE in planned and Annex.REST_DOOR_ROOM in planned,"Night route explicitly crosses automatic rest door")
	var day_before: int=game.service.progress.day
	game.session.members={1:"Хост",7:"Гость"}
	game.player.global_position=Annex.player_bed_center(0)
	var guest_bed:=Annex.player_bed_center(0)
	game.session.player_poses[7]={"position":[guest_bed.x,guest_bed.y,guest_bed.z],"yaw":0.0,"pitch":0.0}
	game.session.execute_action(1,{"action":"sleep","bed":0})
	check(game.service.progress.shift=="night" and game.session.sleeping_peers.has(1),"First player lies down and waits")
	check(game.session.sleep_status_text()=="Спят 1/2","Sleep status counts connected players")
	game.session.execute_action(7,{"action":"sleep","bed":0})
	check(game.session.sleeping_peers.get(7,-1)==1,"Second player occupies the next stack layer")
	check(game.service.progress.day==day_before and game.session.sleep_scene_active(),"Readiness starts the shared scene before morning")
	game.session.execute_action(1,{"action":"skip_sleep"})
	game.session.advance(0.1)
	check(game.service.progress.day==day_before,"One vote cannot skip a multiplayer scene")
	game.session.execute_action(7,{"action":"skip_sleep"})
	game.session.advance(0.1)
	check(game.service.progress.day==day_before+1 and game.service.progress.shift=="open","All connected players sleeping starts next day")
	check(game.session.sleep_scene_active() and game.session.sleep_scene_phase()=="wake","Morning keeps a synchronized wake scene active")
	check(not game.session.sleeping_peers.is_empty(),"Players remain in the shared bed during the wake shot")
	game.evening._process(0.0)
	check(game.evening.performers.size()==1,"Worker actor survives into the morning run-back scene")
	game.session.execute_action(1,{"action":"skip_sleep"})
	game.session.execute_action(7,{"action":"skip_sleep"})
	game.session.advance(0.1)
	check(not game.session.sleep_scene_active() and game.session.sleeping_peers.is_empty(),"Unanimous morning skip completes the cinematic and clears sleepers")
	check(game.service.open_for_business,"Morning automatically opens cafe")
	var sofa_slots:=Lounge.activity_slots(0,["sofa"]).filter(func(spot): return spot.item=="sofa")
	check(sofa_slots.size()==2,"Starter sofa has exactly two leisure seats")
	check(Lounge.sleep_spot(sofa_slots[0],1,0).sleep_kind=="back" and Lounge.sleep_spot(sofa_slots[1],6,0).sleep_kind=="back","Both sofa sleepers lie face-up in the stack")
	var comic_sleep:=Lounge.sleep_spot(Lounge.overflow_slot(0,2,[]),2,2)
	check(comic_sleep.sleep_kind=="headstand","Some clones use the upside-down comic sleep pose")
	var floor_a:=Lounge.overflow_slot(0,2,[])
	var floor_b:=Lounge.overflow_slot(1,2,[])
	check(absf(float(floor_a.yaw)-float(floor_b.yaw))>0.05,"Floor lounge spots face different directions around social groups")
	game._shutdown_tree(game); game.free()
	print("PASS: rear annex, expanded rest room, automatic doors, clone route and multiplayer bed sleep" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
