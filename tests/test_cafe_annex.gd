extends SceneTree
const Annex=preload("res://scripts/cafe_annex.gd")
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",text)
func run() -> void:
	var game=preload("res://scenes/cafe.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false)
	var lab=game.laboratory
	var operator: Vector3=lab.operator_position()
	check(operator.x<Annex.CAFE_WEST_X-1.0,"Laboratory operator stands outside original cafe footprint")
	check(lab.inside(operator),"Moved laboratory interaction volume follows transform")
	check(game.shop.lab_position(1).x<Annex.CAFE_WEST_X,"Laboratory deliveries target annex")
	check(Annex.rest_spot(0).position.x<Annex.CAFE_WEST_X,"Rest spots are outside original cafe footprint")
	check(absf(Annex.rest_spot(0).position.z-Annex.REST_DOOR_Z)<3.0,"Rest spots belong to rest room")
	game.player.global_position=Annex.REST_DOOR_CAFE
	game.annex.advance_doors(0.30)
	check(game.annex.door_openness("rest")>0.9,"Rest door opens for approaching player")
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
	game.service.progress.shift="night"; game.service.progress.night_elapsed=25.0
	game.evening._process(1.0/60.0)
	check(game.evening.performers.size()==1,"Night worker gets an external rest route")
	if game.evening.performers.size()==1:
		var performer: Dictionary=game.evening.performers.values()[0]
		check(performer.actor.global_position.x<Annex.CAFE_WEST_X,"Night worker settles outside cafe in rest room")
		check("Отдых" in performer.actor.caption.text,"Settled worker exposes rest quality")
	var planned: Array=game.evening.route_for({"home":station.global_position,"from_lab":false},Annex.rest_spot(0).position)
	check(Annex.REST_DOOR_CAFE in planned and Annex.REST_DOOR_ROOM in planned,"Night route explicitly crosses automatic rest door")
	game._shutdown_tree(game); game.free()
	print("PASS: external annex geometry, transformed lab targets, proximity doors and night route" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
