extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Masterclasses=preload("res://scripts/masterclass_library.gd")
const DT:=1.0/60.0
var failures:=0
var game

func _initialize()->void: run.call_deferred()
func check(ok: bool,text: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",text)

func ready_food(model,dish: String)->void:
	model.reset(dish)
	if dish=="wine":
		model.cup=model.Layout.TRAY; model.elevations.cup=model.Layout.TRAY_Y-model.BASE_Y; model.filled=225.0; model.wine=775.0
	elif dish=="potato":
		model.held=""; model.plates[0].point=model.Layout.TRAY; model.elevations.plate_0=model.Layout.TRAY_Y-model.BASE_Y; model.potato=model.Layout.TRAY; model.potato_heat=[1.0,1.0,1.0,1.0,1.0,1.0]; model.potato_state="plate_0"; model.elevations.potato=model.Layout.TRAY_Y-model.BASE_Y+0.035
	else:
		model.held=""; model.plates[0].point=model.Layout.TRAY; model.elevations.plate_0=model.Layout.TRAY_Y-model.BASE_Y; model.sausage=model.Layout.TRAY; model.sausage_coating=1.0; model.sausage_state="plate_0"; model.elevations.sausage=model.Layout.TRAY_Y-model.BASE_Y+0.035
	check(model.quality().present and str(model.quality().grade) in ["B","A","S"],"Fixture is B+ for "+dish)

func make_method(service,dish: String,model)->int:
	ready_food(model,dish)
	var tracks: Array=[{"group":1,"frames":[model.snapshot()],"events":[]}]
	return service.learning_state.register_method(dish,"counter",tracks,model.quality(),service.Definition.DISH_EQUIPMENT[dish],{})

func teach_direct(service,station,dish: String,clone_id: int,model,tag: String)->int:
	var method_id:=make_method(service,dish,model)
	check(method_id>0,"Method created for "+dish)
	var result: Dictionary=service.learning_state.grant_method_to_role(clone_id,0,method_id,{"kind":"live","record_id":0,"record_name":""},tag,service.progress.day)
	check(bool(result.get("ok",false)),"Skill granted for "+dish)
	service.rebuild_station_binding(station.station_id,dish)
	return method_id

func run()->void:
	game=Scene.instantiate(); root.add_child(game); await process_frame; game.set_physics_process(false)
	game.new_cafe(); await process_frame
	var service=game.service
	var p=service.progress
	var chef=service.by_id(1)
	chef.equipment=["jug","cup","plates","pan","sauce","rag"]; chef.apply_equipment()
	p.stars=1; p.shift="morning"; p.phase="none"; p.lab_stage=3; p.lab_formula_tempo=1.0; p.lab_formula_version=1; p.tutorial_served=["sausage","potato","wine"]; p.cash=1000
	var station_a=service.add_station("counter",1,false,true)
	station_a.equipment=["jug","cup","plates","pan","sauce","rag"]; station_a.apply_equipment()
	service._refresh_progression()
	check(service.create_clone(1.0,true).is_empty(),"1★ standard formula can create first clone without research minigame")
	var clone_a:=int(station_a.crew[0].get("clone_id",0))
	check(clone_a>0 and station_a.staffed==1,"First clone is assigned to production counter")
	service._refresh_progression()
	check(bool(service.feature_state("live_training").get("unlocked",false)),"Personal training unlocks at 1★")
	check(not bool(service.feature_state("video_recording").get("unlocked",false)),"Video recording remains locked at 1★")
	check(service.masterclasses.is_empty() and "television" not in p.lounge_items,"Fresh 1★ cafe has no film or TV dependency")

	print("[1/5] Physical live lesson")
	check(service.request_live_lesson("sausage",clone_a,1).is_empty(),"Chef calls a specific clone to a live lesson")
	check(station_a.pending_teacher==clone_a and chef.pending_teacher==clone_a,"Clone and chef counter are reserved")
	for i in range(500):
		service.live_training.advance(0.05)
		if service.live_training.phase=="ready": break
	check(service.live_training.phase=="ready" and service.live_training.attendance_valid,"Clone physically reaches the viewer point before recording")
	check(service.begin_live_lesson(1).is_empty(),"Demonstration starts only after arrival")
	check(chef.training.purpose=="live_lesson" and chef.training.phase=="recording","Chef records the shared low-level cooking sequence")
	ready_food(chef.model,"sausage")
	chef.training.advance(DT); chef.training.finish_pass(true)
	check(chef.training.phase=="ready","Finished live demo reaches accept/repeat result")
	var previous_masterclasses: int=service.masterclasses.size()
	check(chef.training.accept(),"Accepted live lesson grants the skill")
	var skill_a: Dictionary=service.clone_skill(clone_a,"counter","sausage","cook")
	check(not skill_a.is_empty() and int(skill_a.method_id)>0,"Knowledge belongs to clone_id")
	check(service.masterclasses.size()==previous_masterclasses,"Live lesson does not create a film")
	check(station_a.recipes.has("sausage") and str(station_a.method_sources.sausage.kind)=="live","Assigned clone drives station runtime method")
	for i in range(500):
		service.live_training.advance(0.05)
		if not service.live_training.is_active(): break
	check(not service.live_training.is_active(),"Student returns to the work station")

	print("[2/5] Cancellation, replacement and pinned orders")
	var old_method:=int(skill_a.method_id)
	check(service.request_live_lesson("sausage",clone_a,1).is_empty(),"Second lesson can be scheduled")
	for i in range(500):
		service.live_training.advance(0.05)
		if service.live_training.phase=="ready": break
	check(service.begin_live_lesson(1).is_empty(),"Second demonstration starts")
	ready_food(chef.model,"sausage")
	chef.training.advance(DT); chef.training.finish_pass(true)
	game.session.execute_action(1,{"action":"cancel","station":chef.station_id,"revision":chef.training.revision})
	var skill_after_cancel: Dictionary=service.clone_skill(clone_a,"counter","sausage","cook")
	check(int(skill_after_cancel.get("method_id",0))==old_method and service.live_training.phase=="returning","Cancelling from the result screen ends the whole lesson and preserves the previous skill")
	for i in range(500):
		service.live_training.advance(0.05)
		if not service.live_training.is_active(): break
	check(service.request_live_lesson("sausage",clone_a,1).is_empty(),"Delivery interruption fixture can schedule another lesson")
	for i in range(500):
		service.live_training.advance(0.05)
		if service.live_training.phase=="ready": break
	check(service.begin_live_lesson(1).is_empty(),"Delivery interruption demonstration starts")
	ready_food(chef.model,"sausage")
	chef.training.advance(DT); chef.training.finish_pass(true)
	station_a.delivery_celebration_active=true
	check(not chef.training.accept(),"A clone pulled into delivery cannot receive the pending lesson result")
	station_a.delivery_celebration_active=false
	check(int(service.clone_skill(clone_a,"counter","sausage","cook").get("method_id",0))==old_method,"Delivery interruption preserves the previous accepted skill")
	service.cancel_live_lesson(1)
	for i in range(500):
		service.live_training.advance(0.05)
		if not service.live_training.is_active(): break
	station_a.crew[0].clone_id=999
	service.rebuild_station_binding(station_a.station_id,"sausage")
	check(not station_a.recipes.has("sausage"),"Replacement clone does not inherit station knowledge")
	station_a.crew[0].clone_id=clone_a
	service.rebuild_station_binding(station_a.station_id,"sausage")
	check(station_a.recipes.has("sausage"),"Original trained clone restores its own method")

	var fake_order: Dictionary={"dish":"sausage","portions_total":1,"portions_done":0,"order_paid":0,"state":"waiting"}
	station_a.customer_id=4242
	service._start_automatic_order(station_a,fake_order)
	var pinned_method:=int(station_a.execution_method_id)
	check(pinned_method==old_method,"Accepted automatic order pins the current learned method")
	var replacement_method:=make_method(service,"sausage",chef.model)
	service.learning_state.grant_method_to_role(clone_a,0,replacement_method,{"kind":"live","record_id":0,"record_name":""},"replace-during-order",p.day)
	service.rebuild_station_binding(station_a.station_id,"sausage")
	check(int(service.execution_record(station_a).get("method_id",0))==pinned_method,"Retraining cannot replace the method of an already accepted order")
	check(int(station_a.recipes.get("sausage",{}).get("method_id",0))==pinned_method,"Runtime recipe cache also stays pinned until the accepted order ends")
	service._release_order_station(station_a,4242)
	check(int(station_a.recipes.get("sausage",{}).get("method_id",0))==replacement_method,"Next order uses the newly accepted skill after the pinned order ends")
	old_method=replacement_method

	print("[3/5] Second star has no film/TV prerequisite")
	var station_b=service.add_station("counter",2,false,true)
	station_b.equipment=["jug","cup","plates","pan","sauce","rag"]; station_b.apply_equipment()
	service.create_clone(1.0,true)
	var clone_b:=int(station_b.crew[0].get("clone_id",0))
	teach_direct(service,station_a,"potato",clone_a,chef.model,"direct:potato")
	teach_direct(service,station_b,"wine",clone_b,chef.model,"direct:wine")
	p.popularity=p.STAR_POPULARITY
	service.served=p.REQUIRED_SERVED
	var requirements: Array=p.star_requirements(service.stations,service.served)
	check(requirements.all(func(row): return bool(row.done)),"All 2★ requirements can be satisfied using personal skills only")
	check(service.masterclasses.is_empty() and "television" not in p.lounge_items,"No film or television was used on the path to 2★")

	print("[4/5] Video arrives after 2★ and teaches another clone")
	p.stars=2; service._refresh_progression()
	check(bool(service.feature_state("video_recording").get("unlocked",false)),"Recording unlocks after 2★ once live training and real work are known")
	var live_method: Dictionary=service.learning_state.method_ref(old_method)
	var record:=Masterclasses.make_record(1,"sausage","counter",live_method.tracks,float(live_method.duration_ticks)/60.0,live_method.quality,"Поздний фильм",false,1,{"required_equipment":live_method.required_equipment})
	service.masterclasses.append(record); service.next_masterclass_id=2; service._ensure_masterclass_method(record)
	service.progression_director.observe("masterclass_saved",{"dish":"sausage"}); service._refresh_progression()
	check(bool(service.feature_state("video_training").get("unlocked",false)),"After first film, single-viewer video training unlocks")
	var premature_mass: Dictionary=service.queue_training_course([{"record_id":1,"station_ids":[station_a.station_id,station_b.station_id]}],"together","before-first-view",1)
	check(not str(premature_mass.get("error","")).is_empty(),"Mass assignment stays locked until one clone has completed a video lesson")
	var before_video: Dictionary=service.clone_skill(clone_b,"counter","sausage","cook")
	check(before_video.is_empty(),"Second clone does not know the filmed dish before watching")
	var learned: Array=service.complete_video_lesson(77,record,[{"station":station_b.station_id,"role":0,"clone_id":clone_b}])
	var after_video: Dictionary=service.clone_skill(clone_b,"counter","sausage","cook")
	check(clone_b in learned and str(after_video.get("source",{}).get("kind",""))=="video","Completed film teaches only the attending clone")
	check(service.clone_skill(999,"counter","sausage","cook").is_empty(),"Absent replacement clone receives no video skill")
	service._refresh_progression()
	check(bool(service.feature_state("group_training").get("unlocked",false)),"Mass assignment follows the first completed video lesson when compatible tables exist")

	var team=service.add_station("kitchen",3,false,true)
	team.equipment=["meat_kit","pasta_kit"]; team.apply_equipment()
	check(service.create_clone(1.0,true).is_empty() and service.create_clone(1.0,true).is_empty(),"Two real clones staff the later two-role kitchen")
	var team_a:=int(team.crew[0].get("clone_id",0)); var team_b:=int(team.crew[1].get("clone_id",0))
	team.model.reset("meal")
	var team_tracks: Array=[]
	for role in range(2): team_tracks.append({"group":1,"frames":[team.model.zone_snapshot(role)],"events":[]})
	var team_quality: Dictionary={"present":true,"grade":"B","style_count":0,"style_tricks":[]}
	var team_method: int=service.learning_state.register_method("meal","kitchen",team_tracks,team_quality,["meat_kit","pasta_kit"],{})
	var team_record:=Masterclasses.make_record(2,"meal","kitchen",team_tracks,1.0,team_quality,"Парный фильм",false,1,{"required_equipment":["meat_kit","pasta_kit"]})
	team_record.method_id=team_method
	service.complete_video_lesson(88,team_record,[{"station":team.station_id,"role":0,"clone_id":team_a}])
	check(not team.recipes.has("meal"),"One watched role does not magically teach the whole multi-role station")
	service.complete_video_lesson(88,team_record,[{"station":team.station_id,"role":1,"clone_id":team_b}])
	check(team.recipes.has("meal") and int(team.recipes.meal.method_id)==team_method,"Later multi-role video works when each current clone learned its own role of one method")

	print("[5/5] Save and current-save migration")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(int(saved.get("version",0))==26 and saved.get("learning",{}) is Dictionary,"Current save persists canonical methods and clone skills")
	check(service.load_data(saved),"Current learning save reloads")
	var restored_a=service.by_id(2)
	check(not service.clone_skill(clone_a,"counter","sausage","cook").is_empty() and restored_a.recipes.has("sausage"),"Current save rebuilds station runtime cache from clone skills")
	var legacy: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	legacy.version=25
	legacy.erase("learning")
	legacy.erase("live_training")
	for entry in legacy.stations:
		var current=service.by_id(int(entry.slot)+1)
		if current!=null and not current.manual_station:
			entry.recipes=current.recipes.duplicate(true)
			entry.method_sources=current.method_sources.duplicate(true)
	check(service.load_data(legacy),"Previous current-format save migrates")
	check(not service.clone_skill(clone_a,"counter","sausage","cook").is_empty(),"Migration restores existing employee knowledge from accepted working configuration")

	var vacancy_legacy: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	vacancy_legacy.version=25
	vacancy_legacy.erase("learning")
	vacancy_legacy.erase("live_training")
	var vacancy_entry: Dictionary={}
	for entry in vacancy_legacy.stations:
		if int(entry.slot)==1: vacancy_entry=entry; break
	check(not vacancy_entry.is_empty(),"Legacy vacancy fixture finds the first production counter")
	var vacancy_method: Dictionary=service.learning_state.method_ref(int(service.clone_skill(clone_a,"counter","sausage","cook").get("method_id",0)))
	vacancy_entry.staffed=0
	vacancy_entry.recipes={"sausage":{"tracks":vacancy_method.tracks.duplicate(true),"duration":float(vacancy_method.duration_ticks)/60.0,"quality":vacancy_method.quality.duplicate(true),"required_equipment":vacancy_method.required_equipment.duplicate()}}
	vacancy_entry.method_sources={"sausage":{"id":0,"name":"Ранее освоенный способ"}}
	vacancy_legacy.progression.free_workers=[{"id":777,"tempo":1.0,"rest":1.0}]
	vacancy_legacy.progression.free_clones=1
	vacancy_legacy.progression.next_clone_id=778
	check(service.load_data(vacancy_legacy),"Legacy vacancy save migrates before automatic assignment")
	var vacancy_station=service.by_id(2)
	check(int(vacancy_station.crew[0].get("clone_id",0))==777,"Free legacy worker is assigned only after migration captured the old occupied roles")
	check(service.clone_skill(777,"counter","sausage","cook").is_empty() and not vacancy_station.recipes.has("sausage"),"Newly assigned legacy worker does not inherit the empty table's historical method")

	game._shutdown_tree(game); game.free()
	print("PASS: live clone skills, film-free 2★ and post-2★ video training" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
