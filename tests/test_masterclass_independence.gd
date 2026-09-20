extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Library=preload("res://scripts/masterclass_library.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func option_ids(options: Array)->Array:
	var result: Array=[]
	for option in options: result.append(str(option.id))
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

	print("Masterclass independence 1/3: chef only exposes currently available items")
	p.stars=1
	chef.equipment=["rag","plates","sauce"]
	chef.upgrades=[]
	chef.apply_equipment()
	var counter_options:=option_ids(service.masterclass_equipment_options("sausage"))
	check("sauce" in counter_options and "plates" in counter_options,"Chef exposes installed counter equipment")
	check("pan" not in counter_options and "jug" not in counter_options and "sauce_ramp" not in counter_options,"Chef does not expose unavailable counter equipment or future upgrades")

	print("Masterclass independence 2/3: a cuisine can be recorded without a production kitchen")
	p.stars=2
	p.expanded=true
	var kitchen_options:=option_ids(service.masterclass_equipment_options("meal"))
	check("meat_kit" in kitchen_options and "pasta_kit" in kitchen_options,"Unlocked cuisine exposes its chef masterclass kit")
	var production_kitchens:=service.stations.filter(func(station):return not station.manual_station and station.type_id=="kitchen")
	check(production_kitchens.is_empty(),"Fixture has no installed production kitchen")
	var bad:=service.request_masterclass("meal",1,["grill_kit"])
	check(not bad.is_empty(),"Chef rejects equipment from another or still-locked cuisine")
	var error:=service.request_masterclass("meal",1,["meat_kit"])
	check(error.is_empty(),"Chef starts the meal masterclass without an installed production kitchen")
	var stage=service.masterclass_station
	check(stage!=null and stage.type_id=="kitchen","Chef station temporarily takes the cuisine type")
	check(stage!=null and stage.equipment==["meat_kit"],"Temporary recording scene uses exactly the selected equipment")

	print("Masterclass independence 3/3: the recording owns execution requirements")
	if stage!=null:
		var tracks: Array=[]
		for role in range(stage.role_count()):
			tracks.append({"group":role+1,"frames":[stage.model.zone_snapshot(role)]})
		check(service.save_masterclass_from_run(stage,"meal",tracks),"Masterclass record can be saved")
		var record: Dictionary=service.masterclasses.back()
		check(Library.required_equipment(record)==["meat_kit"],"Saved record owns the selected required equipment")
		check(record.get("scene_config",{}).get("required_equipment",[])==["meat_kit"],"Scene config preserves selected equipment for replay/debug")
		service.cancel_masterclass()

	game._shutdown_tree(game)
	game.free()
	print("PASS: masterclass recording, staff learning and execution requirements are independent" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
