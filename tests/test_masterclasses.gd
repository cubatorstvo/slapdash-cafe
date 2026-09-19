extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Inputs=preload("res://tests/recipe_inputs.gd")
const DT:=1.0/60.0
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func feed(station: Node3D,role: int,commands: Array)->void:
	for command in commands:
		var motion: Dictionary=command.duplicate(true)
		var event:={}
		for key in ["grab","drop"]:
			if motion.has(key):
				event[key]=motion[key]
				motion.erase(key)
		station.training.inputs[role]=motion
		if not event.is_empty(): station.training.queue_event(role,event)
		station.training.advance(DT)

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
	p.stars=1
	p.shift="morning"
	var chef: Node3D=service.by_id(1)
	chef.equipment=["jug","cup","plates","pan","sauce","rag"]
	chef.apply_equipment()

	print("1/6: access belongs to the single chef station and follows installed kitchens")
	check(bool(service.masterclass_access("wine").available),"Starter masterclass uses learned chef equipment")
	check(not bool(service.masterclass_access("meal").available),"Complex dish stays locked without its production kitchen")
	var kitchen=service.add_station("kitchen",3,false)
	check(bool(service.masterclass_access("meal").available),"Installed equipped kitchen unlocks its dish at the chef station")

	print("2/6: a complex chef masterclass supports sequential solo role takes")
	check(service.request_masterclass("meal",1).is_empty(),"Chef accepts the complex masterclass")
	check(service.masterclass_active(),"Chef swaps into the selected kitchen layout")
	var stage=service.masterclass_station
	check(stage.station_id==1 and stage.masterclass_station and stage.type_id=="kitchen" and stage.training.purpose=="masterclass","The single chef station owns the temporary lesson layout")
	check(stage.training.start_pass([1,0]),"First solo role starts")
	var meat:=Inputs.new(); meat.meat_role(); feed(stage,0,meat.commands)
	stage.training.finish_pass(); check(stage.training.phase=="review","First role take reaches review")
	stage.training.keep_pass(); check(stage.training.phase=="ready","First role is kept for the joint method")
	check(stage.training.start_pass([0,1]),"Second solo role starts against the recorded first role")
	var pasta:=Inputs.new(); pasta.pasta_role(); feed(stage,1,pasta.commands)
	check(stage.model.success(),"Sequential roles combine into one complete dish")
	stage.training.finish_pass(); stage.training.keep_pass()
	check(stage.training.can_accept(),"All roles form one accepted execution")
	check(stage.training.accept(),"Accepted execution is saved as a masterclass")

	print("3/6: saving restores normal chef work and multiple methods coexist")
	check(not service.masterclass_active() and service.by_id(1).manual_station and service.by_id(1).type_id=="counter","Chef returns to the normal counter after saving")
	check(service.masterclasses.size()==1 and service.masterclasses[0].dish=="meal","First masterclass appears in the shared library")
	var first: Dictionary=service.masterclasses[0]
	check(float(first.duration)>0.0 and str(first.quality.grade)!="" and first.effectiveness.has("label"),"Card stores time, grade and effectiveness")
	check(service.request_masterclass("meal",1).is_empty(),"Same dish can be recorded again")
	stage=service.masterclass_station
	stage.training.tracks=first.tracks.duplicate(true)
	stage.training.phase="ready"
	check(stage.training.accept(),"Second accepted method saves separately")
	check(service.masterclasses.size()==2 and service.masterclasses[0].id!=service.masterclasses[1].id,"Two methods of one dish have independent records")

	print("4/6: rename and delete affect the library without breaking the chef")
	var second_id: int=int(service.masterclasses[1].id)
	check(service.rename_masterclass(second_id,"Быстрый обед").is_empty() and service.masterclass_by_id(second_id).name=="Быстрый обед","Masterclass can be renamed")
	var first_id: int=int(service.masterclasses[0].id)
	check(service.delete_masterclass(first_id).is_empty() and service.masterclasses.size()==1,"Masterclass can be deleted independently")
	chef=service.by_id(1)
	check(service.request_manual(chef,"wine",1),"Normal chef cooking still starts after masterclasses")
	chef.training.close()

	print("5/6: v18 persists the shared library")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(saved.version==18 and saved.masterclasses.size()==1,"Current save writes masterclass library v18")
	check(service.load_data(saved),"v18 save reloads")
	check(service.masterclasses.size()==1 and service.masterclasses[0].name=="Быстрый обед","Library survives save/load")

	print("6/6: v13 working recipes migrate to archive records")
	kitchen=service.by_id(4)
	kitchen.recipes.meal={"tracks":service.masterclasses[0].tracks.duplicate(true),"duration":service.masterclasses[0].duration,"quality":service.masterclasses[0].quality.duplicate(true)}
	var legacy: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	legacy.version=13
	legacy.erase("masterclasses")
	legacy.erase("next_masterclass_id")
	check(service.load_data(legacy),"Old v13 cafe still loads")
	var archives: Array=service.masterclasses.filter(func(record):return bool(record.get("archived",false)) and record.dish=="meal")
	check(archives.size()>=1 and str(archives[0].name).contains("Архив"),"Old production method appears as an archive masterclass")
	check(service.by_id(4).recipes.has("meal"),"Migrated station keeps its original working recipe")

	game._shutdown_tree(game)
	game.free()
	print("PASS: chef masterclasses and videotheque stage 1" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
