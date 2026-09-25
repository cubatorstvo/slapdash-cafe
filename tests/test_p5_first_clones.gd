extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Journey=preload("res://scripts/cafe_journey.gd")
const DT:=1.0/60.0
var failures:=0
var game

func _initialize()->void: run.call_deferred()
func check(ok: bool,text: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",text)

func has_milestone(service,id: String)->bool:
	return service.progression_director.has_milestone(id)

func ready_food(model,dish: String)->void:
	model.reset(dish)
	if dish=="wine":
		model.cup=model.Layout.TRAY; model.elevations.cup=model.Layout.TRAY_Y-model.BASE_Y; model.filled=225.0; model.wine=775.0
	elif dish=="potato":
		model.held=""; model.plates[0].point=model.Layout.TRAY; model.elevations.plate_0=model.Layout.TRAY_Y-model.BASE_Y; model.potato=model.Layout.TRAY; model.potato_heat=[1.0,1.0,1.0,1.0,1.0,1.0]; model.potato_state="plate_0"; model.elevations.potato=model.Layout.TRAY_Y-model.BASE_Y+0.035
	else:
		model.held=""; model.plates[0].point=model.Layout.TRAY; model.elevations.plate_0=model.Layout.TRAY_Y-model.BASE_Y; model.sausage=model.Layout.TRAY; model.sausage_coating=1.0; model.sausage_state="plate_0"; model.elevations.sausage=model.Layout.TRAY_Y-model.BASE_Y+0.035
	check(model.quality().present and str(model.quality().grade) in ["B","A","S"],"B+ fixture for "+dish)

func teach_direct(service,station,dish: String,clone_id: int,model,tag: String)->void:
	ready_food(model,dish)
	var tracks: Array=[{"group":1,"frames":[model.snapshot()],"events":[]}]
	var method_id: int=service.learning_state.register_method(dish,"counter",tracks,model.quality(),service.Definition.DISH_EQUIPMENT[dish],{})
	var learned: Dictionary=service.learning_state.grant_method_to_role(clone_id,0,method_id,{"kind":"live","record_id":0,"record_name":""},tag,service.progress.day)
	check(bool(learned.get("ok",false)),"Direct lesson fixture grants "+dish)
	service.rebuild_station_binding(station.station_id,dish)

func teach_live(service,chef,station,dish: String,clone_id: int)->void:
	check(service.request_live_lesson(dish,clone_id,1).is_empty(),"Specific clone can be called to personal lesson")
	for i in range(500):
		service.live_training.advance(0.05)
		if service.live_training.phase=="ready": break
	check(service.live_training.phase=="ready" and service.live_training.attendance_valid,"Clone physically arrives before lesson")
	check(service.begin_live_lesson(1).is_empty(),"Personal demonstration starts")
	ready_food(chef.model,dish)
	chef.training.advance(DT); chef.training.finish_pass(true)
	check(chef.training.accept(),"Personal lesson is accepted")
	for i in range(500):
		service.live_training.advance(0.05)
		if not service.live_training.is_active(): break
	check(station.recipes.has(dish),"Accepted skill binds to current clone station")

func run()->void:
	game=Scene.instantiate(); root.add_child(game); await process_frame; game.set_physics_process(false)
	game.new_cafe(); await process_frame
	var service=game.service
	var p=service.progress
	var chef=service.by_id(1)
	chef.equipment=["jug","cup","plates","pan","sauce","rag"]; chef.apply_equipment()
	p.stars=1; p.shift="open"; p.phase="none"; p.tutorial_served=["sausage","potato","wine"]; p.manual_served=15; p.cash=1000
	p.lab_stage=0; p.lab_formula_tempo=0.70; p.lab_formula_version=0
	service._refresh_progression()

	print("[1/5] Sequential lab and standard formula")
	check(Journey.next_step(p,service.stations,service.served,true,service).item=="lab_0","1★ starts with lab_0")
	p.lab_stage=1; service._refresh_progression(); check(Journey.next_step(p,service.stations,service.served,true,service).item=="lab_1","lab_1 follows installed lab_0")
	p.lab_stage=2; service._refresh_progression(); check(Journey.next_step(p,service.stations,service.served,true,service).item=="lab_2","lab_2 follows installed lab_1")
	p.lab_stage=3; service._refresh_progression()
	check(is_equal_approx(p.lab_formula_tempo,1.0) and p.lab_formula_version==1,"Completed base lab provides standard 100% formula")
	check(has_milestone(service,"standard_formula_available"),"Standard formula fact is recorded")
	check(not bool(service.feature_state("formula_research").get("unlocked",false)),"Formula research stays hidden before 2★")

	print("[2/5] First clone, table, personal lesson and auto serve")
	check(service.create_clone(1.0,true).is_empty(),"First clone grows without research minigame")
	check(has_milestone(service,"first_manual_clone_growth_completed"),"First manual growth cycle fact is recorded")
	check(bool(service.feature_state("production_tables").get("unlocked",false)),"Production table shop unlocks after first clone")
	check(bool(service.feature_state("rest_basics").get("unlocked",false)),"Basic sofa rest unlocks with first worker")
	var station_a=service.add_station("counter",1,false,true)
	station_a.equipment=["jug","cup","plates","pan","sauce","rag"]; station_a.apply_equipment(); service.assign_clones(); service._refresh_progression()
	var clone_a:=int(station_a.crew[0].get("clone_id",0))
	check(clone_a>0,"First clone is assigned to first production table")
	teach_live(service,chef,station_a,"sausage",clone_a)
	check(has_milestone(service,"first_live_lesson_accepted"),"Personal lesson has its own progression fact")
	check(service.masterclasses.is_empty(),"Personal lesson creates no masterclass film")
	service._count_completed_customer({"dish":"sausage","automatic_serving":true},station_a); service._refresh_progression()
	check(p.journey_auto_served==1 and has_milestone(service,"first_auto_served"),"First auto fact comes from completed automatic service")

	print("[3/5] Familiar cycle requires second clone knowledge")
	check(service.create_clone(1.0,true).is_empty(),"Second clone uses the familiar 100% formula")
	check(has_milestone(service,"repeat_manual_clone_growth_completed"),"Repeat manual growth cycle fact is recorded")
	var station_b=service.add_station("counter",2,false,true)
	station_b.equipment=["jug","cup","plates","pan","sauce","rag"]; station_b.apply_equipment(); service.assign_clones(); service._refresh_progression()
	var clone_b:=int(station_b.crew[0].get("clone_id",0))
	check(clone_b>0 and service.clone_skill(clone_b,"counter","sausage","cook").is_empty(),"Second clone does not inherit first clone knowledge")
	teach_direct(service,station_b,"sausage",clone_b,chef.model,"p5:second:sausage")
	teach_direct(service,station_a,"potato",clone_a,chef.model,"p5:first:potato")
	teach_direct(service,station_b,"wine",clone_b,chef.model,"p5:second:wine")

	print("[4/5] Second star is film-free and three autos are guidance only")
	p.popularity=p.STAR_POPULARITY; service.served=p.REQUIRED_SERVED; p.journey_auto_served=1
	var requirements: Array=p.star_requirements(service.stations,service.served)
	check(requirements.all(func(row): return bool(row.done)),"Current workers satisfy all 2★ requirements with B+ live skills")
	check(p.can_attempt(service.stations,service.served),"Three auto serves are not a hidden second-star gate")
	check(service.masterclasses.is_empty() and "television" not in p.lounge_items,"2★ is reachable with empty masterclasses and no television")
	check(not bool(service.feature_state("video_recording").get("unlocked",false)),"Video recording remains hidden during 1★ chapter")

	print("[5/5] Rest fact and save/load persistence")
	p.rest_report={"workers":2,"places":2,"covered":2,"bonus":0.08,"multiplier":1.08}; service._refresh_progression()
	check(has_milestone(service,"first_staff_rest_completed"),"First night rest with workers is recorded from host rest report")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(saved),"Current save reloads")
	check(is_equal_approx(p.lab_formula_tempo,1.0) and has_milestone(service,"standard_formula_available") and has_milestone(service,"repeat_manual_clone_growth_completed"),"Formula and chapter facts survive current save/load")
	p.stars=2; service._refresh_progression()
	check(bool(service.feature_state("video_recording").get("unlocked",false)),"Video chapter may unlock only after 2★")

	game._shutdown_tree(game); game.free()
	print("PASS: P5.02 first clones to film-free 2★" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
