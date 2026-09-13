extends SceneTree
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failed=true; printerr("FAIL: ",text)
func run() -> void:
	var game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game); await process_frame
	game.set_physics_process(false)
	var lab=game.laboratory
	var p=game.service.progress
	check("rag" in game.service.by_id(1).equipment,"New bare chef table includes rag")
	check(not game.shop.ITEMS.has("rag"),"Rag is not a purchase")
	game.player.position=Vector3(0,0.02,7)
	check(not lab.press(1,lab.state.revision).is_empty(),"First star still required")
	p.stars=1; p.lab_stage=3; p.cash=300
	var counter=game.service.add_station("counter",1,false,true)
	check("rag" in counter.equipment and counter.staffed==0,"Bare clone station includes rag without worker")
	game.session.execute_action(1,{"action":"create_clone"})
	check(counter.staffed==0 and p.cash==300,"Old action cannot bypass minigame")
	game.session.request_action({"action":"lab_press","revision":lab.state.revision})
	check(lab.state.phase=="fill" and p.cash==300,"Begin without charging")
	lab.advance(0.5); lab.press(1,lab.state.revision)
	check(lab.state.phase=="fill" and p.cash==300,"Underfill retries without cost")
	lab.advance(7)
	check(lab.state.level==0 and lab.state.phase=="fill","Overflow recovers")
	lab.advance(4); lab.press(1,lab.state.revision)
	check(lab.state.phase=="tune","Filled flask advances to stabilizer")
	lab.press(1,lab.state.revision)
	check(lab.state.phase=="tune" and p.cash==300,"Missed needle is harmless")
	lab.advance(2.5); lab.press(1,lab.state.revision)
	check(lab.state.phase=="ready","Needle can be caught in green zone")
	var revision: int=lab.state.revision
	game.session.request_action({"action":"lab_press","revision":revision})
	game.session.request_action({"action":"lab_press","revision":revision})
	check(lab.state.phase=="done" and counter.staffed==1 and p.cash==240,"Exactly one clone and one charge, automatically staffed")
	lab.advance(3)
	check(lab.state.phase=="idle","Next clone needs a new cycle")
	lab.press(1,lab.state.revision)
	game.player.position=Vector3(0,0,3); lab.advance(0.1)
	check(lab.state.phase=="idle" and p.cash==240,"Leaving cancels unpaid cycle")
	game.session.members[7]="Guest"; game.session.player_poses[7]={"position":[0,0.02,7]}
	game.session.execute_action(7,{"action":"lab_press","revision":lab.state.revision})
	check(lab.state.owner==7 and lab.state.phase=="fill","Guest can start through authoritative action")
	game.player.position=Vector3(0,0.02,7)
	check(not lab.press(1,lab.state.revision).is_empty(),"Another player cannot take over")
	game.session.members.erase(7); lab.advance(0.1)
	check(lab.state.phase=="idle","Disconnected operator releases apparatus")
	var save: Dictionary=game.service.save_data()
	save.stations[0].equipment=[]
	save.progression.deliveries=[{"id":90,"item":"rag","station":1,"remaining":1.0,"owner":0,"position":[0,0,0]}]
	check(game.service.load_data(save),"Load previous save")
	check("rag" in game.service.by_id(1).equipment and game.service.progress.deliveries.is_empty() and game.service.progress.cash==252,"Old rag delivery refunded and default rag installed")
	game._shutdown_tree(game); game.free()
	print("PASS: laboratory cycle, retries, authority, duplicate guard and rag migration" if not failed else "FAILED")
	quit(1 if failed else 0)
