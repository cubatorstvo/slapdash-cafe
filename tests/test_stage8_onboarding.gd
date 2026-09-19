extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

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
	var station=service.add_station("counter",1,false)
	station.staffed=1
	station.equipment=["rag","plates","sauce","pan","jug","cup"]
	station.apply_equipment()

	print("Stage8 onboarding 1/3: pre-star local lesson may cross the first-star boundary")
	p.stars=0
	check(service.request_training(station,"sausage",1),"Early local station training remains available before first star")
	check(station.training.active(),"Early local lesson is really active")
	p.stars=1
	check(service.request_training(station,"sausage",1),"Already active old lesson remains controllable after gaining first star")
	station.training.close()

	print("Stage8 onboarding 2/3: post-star new local teaching is rejected by service and host path")
	check(not service.request_training(station,"sausage",1),"Service rejects a new local lesson after first star")
	game.player.global_position=station.to_global(Vector3(0,0.02,1.8))
	game.session.execute_action(1,{"action":"open","station":2,"dish":"sausage"})
	check(not station.training.active(),"Host-authoritative action path also leaves local lesson closed after first star")

	print("Stage8 onboarding 3/3: station UI directs player into the group/course editor")
	game.menu.show_station(station)
	var rendered:=tree_text(game.menu.panel)
	check("Обучение и группа" in rendered and "Обучить здесь" not in rendered,"Production station replaces old local-training action after first star")
	game.menu.close()

	game._shutdown_tree(game)
	game.free()
	print("PASS: local teaching is pre-star only, active legacy lessons survive the boundary, and post-star UI routes to courses" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
