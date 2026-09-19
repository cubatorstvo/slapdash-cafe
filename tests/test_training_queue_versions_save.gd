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

func record_for(station: Node3D,id: int,dish: String,name: String)->Dictionary:
	station.model.reset(dish)
	var frames:=repeated(station.model.snapshot(),120)
	return Library.make_record(id,dish,station.type_id,[{"group":1,"frames":frames}],2.0,station.model.quality(),name)

func prepare(station: Node3D)->void:
	station.staffed=1
	station.equipment=["jug","cup","plates","pan","sauce","rag"]
	station.apply_equipment()

func teach(station: Node3D,record: Dictionary)->void:
	station.recipes[str(record.dish)]={"tracks":record.tracks.duplicate(true),"duration":record.duration,"quality":record.quality.duplicate(true)}
	station.method_sources[str(record.dish)]={"id":int(record.id),"name":str(record.name)}

func make_game():
	var game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	game.service.progress.stars=2
	game.service.progress.shift="open"
	game.service.open_for_business=false
	if "television" not in game.service.progress.lounge_items: game.service.progress.lounge_items.append("television")
	return game

func run_until(service: Node3D,predicate: Callable,seconds := 90.0)->bool:
	for i in range(ceili(seconds/0.1)):
		service.advance(0.1)
		await process_frame
		if predicate.call(): return true
	return false

func dispose(game)->void:
	game._shutdown_tree(game)
	game.free()

func training_events(service: Node3D)->int:
	var result:=0
	for entry in service.analytics.feed:
		if str(entry.get("kind",""))=="training": result+=int(entry.get("count",1))
	return result

func _initialize()->void:
	run.call_deferred()

func run()->void:
	print("T13: waiting assignment is replaced, running film remains frozen")
	var game=await make_game()
	var service=game.service
	var station=service.add_station("counter",1,false)
	prepare(station)
	var old_potato=record_for(station,1401,"potato","Версия A")
	var new_potato=record_for(station,1402,"potato","Версия B")
	var final_potato=record_for(station,1403,"potato","Версия C")
	service.masterclasses=[old_potato,new_potato,final_potato]
	service.progress.lounge_items.erase("television")
	var waiting_old: Dictionary=service.queue_training_course([{"record_id":1401,"station_ids":[2]}],"together","t13-wait-a",1)
	service.training_queue.advance(0.0)
	var old_course=service.training_queue._course(int(waiting_old.course_id))
	var old_lesson=service.training_queue._lesson(int(service.training_queue._batch(int(old_course.batch_ids[0])).lesson_ids[0]))
	check(str(old_lesson.state)=="blocked","T13 old waiting lesson is blocked without TV")
	var waiting_new: Dictionary=service.queue_training_course([{"record_id":1402,"station_ids":[2]}],"together","t13-wait-b",1)
	check(old_lesson.station_ids.is_empty() and str(old_lesson.state)=="superseded","T13 newer waiting assignment removes the old target")
	var pending: Dictionary=service.training_queue.pending_source(2,"potato")
	check(int(pending.get("id",0))==1402,"T13 queue exposes only the current waiting record")
	service.progress.lounge_items.append("television")
	check(await run_until(service,func():return int(station.method_sources.get("potato",{}).get("id",0))==1402),"T13 replacement waiting record is learned")
	var active_old: Dictionary=service.queue_training_course([{"record_id":1401,"station_ids":[2]}],"together","t13-live-a",1)
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==1401),"T13 old film starts with frozen record")
	var active_new: Dictionary=service.queue_training_course([{"record_id":1403,"station_ids":[2]}],"together","t13-live-c",1)
	check(str(active_new.error).is_empty(),"T13 new plan can be confirmed during the old film")
	check(await run_until(service,func():return int(station.method_sources.get("potato",{}).get("id",0))==1401 and not service.staff_training.is_active(),60.0),"T13 finishing old film records old knowledge first")
	check(int(service.training_queue.pending_source(2,"potato").get("id",0))==1403,"T13 new version remains necessary after old film completes")
	check(await run_until(service,func():return int(station.method_sources.get("potato",{}).get("id",0))==1403,90.0),"T13 new version eventually retrains the station")
	dispose(game)

	print("T14: assigned deleted recording survives through frozen lesson content")
	game=await make_game()
	service=game.service
	station=service.add_station("counter",1,false)
	prepare(station)
	var deleted_record=record_for(station,1411,"wine","Удаляемая запись")
	service.masterclasses=[deleted_record]
	service.progress.lounge_items.erase("television")
	var assigned: Dictionary=service.queue_training_course([{"record_id":1411,"station_ids":[2]}],"together","t14",1)
	check(str(assigned.error).is_empty(),"T14 lesson can be assigned before deletion")
	var assigned_course: Dictionary=service.training_queue._course(int(assigned.course_id))
	var assigned_lesson: Dictionary=service.training_queue._lesson(int(service.training_queue._batch(int(assigned_course.batch_ids[0])).lesson_ids[0]))
	check(service.rename_masterclass(1411,"Переименованная запись").is_empty() and str(assigned_lesson.record.name)=="Переименованная запись","T14 assigned lesson follows record rename by stable id")
	check(service.delete_masterclass(1411).is_empty(),"T14 recording is removed from visible library")
	service.progress.lounge_items.append("television")
	check(await run_until(service,func():return int(station.method_sources.get("wine",{}).get("id",0))==1411,90.0),"T14 frozen assigned content still teaches after library deletion")
	var invalid: Dictionary=service.queue_training_course([{"record_id":1411,"station_ids":[2]}],"together","t14-new",1)
	check(not str(invalid.error).is_empty(),"T14 deleted recording cannot create a new assignment")
	dispose(game)

	print("T15: v22 restores queue transitions and resumes a movie exactly once")
	game=await make_game()
	service=game.service
	station=service.add_station("counter",1,false)
	prepare(station)
	var wine=record_for(station,1421,"wine","Сохранение · напиток")
	var sausage=record_for(station,1422,"sausage","Сохранение · сосиска")
	service.masterclasses=[wine,sausage]
	service.progress.lounge_items.erase("television")
	var saved_course: Dictionary=service.queue_training_course([{"record_id":1421,"station_ids":[2]},{"record_id":1422,"station_ids":[2]}],"together","t15",1)
	var course_id:=int(saved_course.course_id)
	var queued_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(queued_save.version==22 and queued_save.training_queue.courses.size()==1,"T15 queued course is serialized in v22")
	check(service.load_data(queued_save),"T15 queued save reloads")
	station=service.by_id(2)
	service.training_queue.advance(0.0)
	var t15_batch: Dictionary=service.training_queue._batch(int(service.training_queue._course(course_id).batch_ids[0]))
	check(str(t15_batch.state)=="blocked","T15 no-TV course reaches blocked")
	var blocked_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(blocked_save) and str(service.training_queue._batch(int(service.training_queue._course(course_id).batch_ids[0])).state)=="blocked","T15 blocked phase reloads")
	station=service.by_id(2)
	service.progress.lounge_items.append("television")
	service.training_queue.advance(0.0)
	t15_batch=service.training_queue._batch(int(service.training_queue._course(course_id).batch_ids[0]))
	check(str(t15_batch.state)=="draining","T15 ready course enters draining")
	var draining_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(draining_save) and str(service.training_queue._batch(int(service.training_queue._course(course_id).batch_ids[0])).state)=="draining","T15 draining phase reloads")
	station=service.by_id(2)
	service.advance(0.1)
	await process_frame
	check(service.staff_training.phase=="gathering","T15 idle drained party begins gathering")
	var gathering_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(gathering_save) and service.staff_training.phase=="gathering","T15 gathering phase reloads")
	station=service.by_id(2)
	check(await run_until(service,func():return service.staff_training.phase=="walking"),"T15 restored gathering reaches walking")
	var walking_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(walking_save.staff_training.active and walking_save.staff_training.actors.size()>0,"T15 walking actors and paths are serialized")
	check(service.load_data(walking_save),"T15 walking save reloads")
	check(service.staff_training.is_active() and service.staff_training.phase=="walking","T15 walking phase restores before next tick")
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==1421),"T15 restored actors reach first movie")
	service.movie_state.elapsed=float(service.movie_state.duration)*0.45
	var saved_elapsed:=float(service.movie_state.elapsed)
	var movie_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(movie_save),"T15 mid-movie save reloads")
	station=service.by_id(2)
	check(service.staff_training.phase=="watching" and absf(float(service.movie_state.elapsed)-saved_elapsed)<0.001,"T15 same film resumes from saved elapsed time")
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==1422,60.0),"T15 remainder continues directly to second lesson")
	check(int(station.method_sources.get("wine",{}).get("id",0))==1421,"T15 first lesson is applied once before lesson two")
	check(await run_until(service,func():return service.staff_training.phase=="returning",60.0),"T15 reaches returning after second movie")
	var returning_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(returning_save),"T15 returning phase reloads")
	station=service.by_id(2)
	check(await run_until(service,func():return str(service.training_queue._course(course_id).get("state",""))=="completed",60.0),"T15 restored return completes the course")
	check(int(station.method_sources.get("wine",{}).get("id",0))==1421 and int(station.method_sources.get("sausage",{}).get("id",0))==1422,"T15 both lessons remain learned after all reloads")
	var final_batch=service.training_queue._batch(int(service.training_queue._course(course_id).batch_ids[0]))
	check(int(final_batch.movies)==2 and training_events(service)==2,"T15 knowledge and training events are committed exactly once")
	dispose(game)

	print("T15 migration: v20 desired plans become queued lessons once")
	game=await make_game()
	service=game.service
	station=service.add_station("counter",1,false)
	prepare(station)
	var migration_old=record_for(station,1430,"potato","Миграция · старый")
	var migration_new=record_for(station,1431,"potato","Миграция · новый")
	teach(station,migration_old)
	service.masterclasses=[migration_old,migration_new]
	check(service._apply_group_plan(1431,[2]).size()==1,"Migration fixture has a desired method different from learned")
	var legacy20: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	legacy20.version=20
	legacy20.erase("training_queue")
	legacy20.erase("staff_training")
	legacy20.erase("movie")
	legacy20.erase("remote_movie_record")
	check(service.load_data(legacy20),"T15 v20 save migrates")
	station=service.by_id(2)
	check(service.training_queue.has_pending() and int(service.training_queue.pending_source(2,"potato").get("id",0))==1431,"T15 migration creates a pending lesson from the old desired plan")
	var migrated21: Dictionary=service.save_data()
	check(migrated21.version==22 and migrated21.training_queue.courses.size()==1,"T15 migration persists once in v22")
	dispose(game)

	print("PASS: T13-T15 assignment versions, deleted records and save recovery" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
