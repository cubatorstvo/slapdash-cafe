extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Library=preload("res://scripts/masterclass_library.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func repeated(value: Dictionary,count: int)->Array:
	var out: Array=[]
	for i in range(count): out.append(value.duplicate(true))
	return out

func record_for(station: Node3D,id: int,dish: String,name: String,frames_count:=120)->Dictionary:
	station.model.reset(dish)
	var frames:=repeated(station.model.snapshot(),frames_count)
	return Library.make_record(id,dish,station.type_id,[{"group":1,"frames":frames}],float(frames_count)/60.0,station.model.quality(),name)

func prepare(service: Node3D,station: Node3D)->void:
	station.staffed=1
	station.crew[0].clone_id=1000+station.station_id
	station.equipment=["jug","cup","plates","pan","sauce","rag"]
	station.apply_equipment()

func run_until(service: Node3D,predicate: Callable,seconds:=120.0)->bool:
	for i in range(ceili(seconds/0.1)):
		service.advance(0.1)
		await process_frame
		if predicate.call(): return true
	return false

func course_state(queue: Node,id: int)->String:
	return str(queue._course(id).get("state",""))

func _initialize()->void:
	run.call_deferred()

func run()->void:
	var game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var service=game.service
	var queue=service.training_queue
	service.progress.stars=2
	service.progress.shift="open"
	service.open_for_business=false
	if "television" not in service.progress.lounge_items: service.progress.lounge_items.append("television")
	var stations: Array=[]
	for slot in range(1,8):
		var station=service.add_station("counter",slot,false)
		prepare(service,station)
		stations.append(station)
	var wine:=record_for(stations[0],1201,"wine","Напиток")
	var potato:=record_for(stations[0],1202,"potato","Картошка")
	var sausage:=record_for(stations[0],1203,"sausage","Сосиска")
	service.masterclasses=[wine,potato,sausage]
	service.progress.tutorial_served=["sausage","potato","wine"]
	service.progress.lab_stage=3
	service.progress.lab_formula_version=1
	service.progress.next_clone_id=2000
	service._refresh_progression()
	service.progression_director.observe("live_lesson_accepted",{"clone_id":1002,"dish":"wine"})
	service.progression_director.observe("masterclass_saved",{"dish":"wine"})
	service.progression_director.observe("video_training_completed",{"station_count":1})
	service._refresh_progression()
	check(bool(service.feature_state("group_training").get("unlocked",false)),"Mass queue test starts after the required first single-viewer video stage")

	print("T01: any requested mode becomes one together pass")
	var course: Dictionary=service.queue_training_course([
		{"record_id":1201,"station_ids":[2,3,4,5]},
		{"record_id":1202,"station_ids":[2,3,4,5]}
	],"by_groups","one-pass",1)
	check(str(course.error).is_empty(),"Course is accepted")
	var course_id:=int(course.course_id)
	var view: Dictionary=queue.course_view(course_id)
	check(str(view.mode)=="together" and view.batches.size()==1,"Group mode is removed and normalized to one pass")
	check(view.batches[0].stations==[2,3,4,5],"The single batch contains every selected table")
	check(int(queue.balanced_batch_size(8))==8,"Compatibility batch helper now means all tables")

	print("T02: assignments are per-table and never split or create groups")
	check(service.table_groups().is_empty(),"No automatic groups exist before training")
	check(int(stations[0].method_plan.get("wine",{}).get("id",0))==1201 and int(stations[3].method_plan.get("potato",{}).get("id",0))==1202,"Queue writes desired methods directly to selected tables")
	check(service.table_groups().is_empty(),"Assigning training does not synthesize groups")
	service.advance(0.1)
	await process_frame
	check(await run_until(service,func():return service.staff_training.phase=="watching",30.0),"Workers reach the TV as one group")
	check(absf(float(service.movie_state.duration)-Library.TRAINING_WATCH_SECONDS)<0.01,"Every lesson watches exactly the global fixed duration")
	check(bool(service.movie_state.loop),"Two-second film loops during the fixed viewing window")
	check(await run_until(service,func():return course_state(queue,course_id)=="completed",90.0),"Two fixed-time lessons finish")
	var stored: Dictionary=queue._course(course_id)
	var batch: Dictionary=queue._batch(int(stored.batch_ids[0]))
	check(int(batch.gathers)==1 and int(batch.movies)==2 and int(batch.returns)==1,"Workers gather once, watch both lessons, and return once")
	check(int(service.by_id(2).method_sources.wine.id)==1201 and int(service.by_id(5).method_sources.potato.id)==1202,"All selected tables learn both records")

	print("T03: no automatic training appears for new tables")
	var before_courses: int=queue.courses.size()
	var extra=service.add_station("counter",8,false)
	prepare(service,extra)
	for i in range(40): service.advance(0.1)
	check(queue.courses.size()==before_courses and service.group_id_for_station(extra.station_id).is_empty(),"New table remains standalone and does not create an automatic course")

	print("T04: equipment is not a learning blocker")
	stations[5].equipment.erase("pan")
	stations[5].apply_equipment()
	var equipment_course: Dictionary=service.queue_training_course([{"record_id":1202,"station_ids":[7]}],"balanced","equipment",1)
	check(str(equipment_course.error).is_empty(),"Missing pan does not reject the lesson")
	var equipment_id:=int(equipment_course.course_id)
	var equipment_done:=await run_until(service,func():return course_state(queue,equipment_id)=="completed",90.0)
	check(equipment_done,"Lesson completes without production equipment")
	check(service.by_id(7).recipes.has("potato") and not service.by_id(7).can_execute("potato"),"Knowledge is learned but cannot execute without the pan")

	game._shutdown_tree(game)
	game.free()
	print("PASS: one-pass per-table training queue" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
