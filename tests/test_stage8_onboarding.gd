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
	var chef=service.by_id(1)
	chef.equipment=["rag","plates","sauce","pan","jug","cup"]
	chef.apply_equipment()
	var station=service.add_station("counter",1,false)
	station.staffed=1
	station.equipment=["rag","plates","sauce","pan","jug","cup"]
	station.apply_equipment()

	print("Stage8 onboarding 1/3: production stations never record cooking methods")
	p.stars=0
	game.player.global_position=station.to_global(Vector3(0,0.02,1.8))
	game.session.execute_action(1,{"action":"open","station":station.station_id,"dish":"sausage"})
	check(not station.training.active(),"Legacy production-station open action cannot start a recording before the first star")
	game.menu.show_station(station)
	var rendered:=tree_text(game.menu.panel)
	check("Обучить здесь" not in rendered and "только на Шеф-станции" in rendered,"Pre-star production UI explains the single chef-station recording path")
	game.menu.close()
	check(not bool(service.masterclass_access("sausage").available),"Masterclasses remain locked before the first star")

	print("Stage8 onboarding 2/3: first star unlocks recording only at the chef station")
	p.stars=1
	check(bool(service.masterclass_access("sausage").available),"First star unlocks a sausage masterclass at the equipped chef station")
	game.player.global_position=chef.to_global(Vector3(0,0.02,1.8))
	game.menu.show_station(chef)
	rendered=tree_text(game.menu.panel)
	check("Провести мастер-класс" in rendered,"Chef-station UI exposes masterclass recording after the first star")
	game.menu.close()
	p.shift="closing"
	check(not bool(service.masterclass_access("sausage").available),"Masterclass access is unavailable outside working hours")
	game.menu.show_station(chef)
	rendered=tree_text(game.menu.panel)
	check("Провести мастер-класс" not in rendered and "только в рабочее время" in rendered,"Chef-station UI hides masterclass buttons outside working hours")
	game.menu.close()
	p.shift="morning"

	print("Stage8 onboarding 3/3: production stations only assign saved masterclasses")
	game.player.global_position=station.to_global(Vector3(0,0.02,1.8))
	game.session.execute_action(1,{"action":"open","station":station.station_id,"dish":"sausage"})
	check(not station.training.active(),"Legacy host action still cannot create a production-station recording after the first star")
	game.menu.show_station(station)
	rendered=tree_text(game.menu.panel)
	check("Обучение и группа" in rendered and "Обучить здесь" not in rendered,"Production station routes only to group/course assignment")
	game.menu.close()

	game._shutdown_tree(game)
	game.free()
	print("PASS: cooking methods are recorded only at the chef station and production tables only assign courses" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
