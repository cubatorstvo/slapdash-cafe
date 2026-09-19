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

func add_counter(service: Node3D,slot: int)->Node3D:
	var station=service.add_station("counter",slot,false)
	station.staffed=1
	station.equipment=["jug","cup","plates","pan","sauce","rag"]
	station.apply_equipment()
	return station

func run_until(service: Node3D,predicate: Callable,seconds := 80.0)->bool:
	for i in range(ceili(seconds/0.1)):
		service.advance(0.1)
		await process_frame
		if predicate.call(): return true
	return false

func dispose(game)->void:
	game._shutdown_tree(game)
	game.free()

func _initialize()->void:
	run.call_deferred()

func run()->void:
	print("T10: pre-film closure defers and walking actors hand off to evening")
	var game=await make_game()
	var service=game.service
	var station=add_counter(service,1)
	var wine=record_for(station,1301,"wine","Ночь · напиток")
	service.masterclasses=[wine]
	var queued: Dictionary=service.queue_training_course([{"record_id":1301,"station_ids":[2]}],"together","t10-queued",1)
	service.end_shift()
	var batch=service.training_queue._batch(int(service.training_queue._course(int(queued.course_id)).batch_ids[0]))
	check(str(batch.state)=="deferred" and not service.staff_training.is_active(),"T10 queued course defers before physical gathering")
	dispose(game)

	game=await make_game()
	service=game.service
	station=add_counter(service,1)
	wine=record_for(station,1302,"wine","Ночь · путь")
	service.masterclasses=[wine]
	var walking: Dictionary=service.queue_training_course([{"record_id":1302,"station_ids":[2]}],"together","t10-walking",1)
	check(await run_until(service,func():return service.staff_training.phase=="walking"),"T10 party reaches walking phase")
	service.end_shift()
	batch=service.training_queue._batch(int(service.training_queue._course(int(walking.course_id)).batch_ids[0]))
	check(str(batch.state)=="deferred" and not service.staff_training.is_active(),"T10 walking course hands off and defers")
	var clone_id:=int(station.crew[0].clone_id)
	check(not service.training_queue.handoff_for_clone(clone_id).is_empty(),"T10 current training position is transferred by clone id")
	service.advance_shift(0.1)
	await process_frame
	check(service.progress.shift=="night","T10 sleep-compatible deferred queue reaches night")
	check(not game.evening.performers.has(clone_id) or not service.staff_training.actors.has("2:0"),"T10 clone is never represented by both training and evening actors")
	dispose(game)

	print("T11: closing on the film boundary learns one lesson and defers the next")
	game=await make_game()
	service=game.service
	station=add_counter(service,1)
	var potato=record_for(station,1311,"potato","Ночь · картошка")
	var sausage=record_for(station,1312,"sausage","Ночь · сосиска")
	service.masterclasses=[potato,sausage]
	var boundary: Dictionary=service.queue_training_course([{"record_id":1311,"station_ids":[2]},{"record_id":1312,"station_ids":[2]}],"together","t11",1)
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==1311),"T11 first film starts")
	service.movie_state.elapsed=maxf(0.0,float(service.movie_state.duration)-0.05)
	service.progress.shift_elapsed=service.Progression.SHIFT_SECONDS-0.05
	service.open_for_business=true
	service.advance(0.1)
	await process_frame
	batch=service.training_queue._batch(int(service.training_queue._course(int(boundary.course_id)).batch_ids[0]))
	check(int(station.method_sources.get("potato",{}).get("id",0))==1311,"T11 first film knowledge is committed on the closing tick")
	check(int(station.method_sources.get("sausage",{}).get("id",0))!=1312,"T11 second film does not start after closing")
	check(str(batch.state)=="deferred" and not service.staff_training.is_active(),"T11 remainder is deferred and training actor is released")
	service.advance(0.1)
	await process_frame
	check(service.progress.shift=="night","T11 reaches night after active film handoff")
	clone_id=int(station.crew[0].clone_id)
	await process_frame
	check(service.staff_training.actors.is_empty() and game.evening.performers.keys().count(clone_id)<=1,"T11 exactly one physical owner remains for the clone")
	dispose(game)

	print("T12: cancelling during lesson two preserves lesson one and suspends the current assignment")
	game=await make_game()
	service=game.service
	station=add_counter(service,1)
	var old_potato=record_for(station,1320,"potato","Старый способ")
	potato=record_for(station,1321,"potato","Новый способ")
	sausage=record_for(station,1322,"sausage","Первый урок")
	teach(station,old_potato)
	service.masterclasses=[old_potato,potato,sausage]
	var cancel: Dictionary=service.queue_training_course([{"record_id":1322,"station_ids":[2]},{"record_id":1321,"station_ids":[2]}],"together","t12",1)
	var cancel_id:=int(cancel.course_id)
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==1321,90.0),"T12 reaches second film after completing first")
	service.movie_state.elapsed=float(service.movie_state.duration)*0.5
	check(service.cancel_training_course(cancel_id).is_empty(),"T12 current course can be cancelled")
	check(await run_until(service,func():return not service.staff_training.is_active(),60.0),"T12 workers return after cancellation")
	check(int(station.method_sources.get("sausage",{}).get("id",0))==1322,"T12 completed first lesson remains learned")
	check(int(station.method_sources.get("potato",{}).get("id",0))==1320,"T12 interrupted second lesson keeps the old production method")
	check(service.training_queue.assignment_suspended(2,"potato"),"T12 cancelled plan version is marked suspended")
	dispose(game)

	print("T12 extra: cancelling one current lesson keeps the party at the TV for the remainder")
	game=await make_game()
	service=game.service
	station=add_counter(service,1)
	var lesson_wine=record_for(station,1331,"wine","Урок · напиток")
	var lesson_potato=record_for(station,1332,"potato","Урок · отменить")
	var lesson_sausage=record_for(station,1333,"sausage","Урок · продолжить")
	service.masterclasses=[lesson_wine,lesson_potato,lesson_sausage]
	var partial_cancel: Dictionary=service.queue_training_course([{"record_id":1331,"station_ids":[2]},{"record_id":1332,"station_ids":[2]},{"record_id":1333,"station_ids":[2]}],"together","t12-one-lesson",1)
	var partial_course: Dictionary=service.training_queue._course(int(partial_cancel.course_id))
	var partial_batch: Dictionary=service.training_queue._batch(int(partial_course.batch_ids[0]))
	var partial_lessons: Array=partial_batch.lesson_ids.duplicate()
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==1332,90.0),"T12 individual cancellation fixture reaches the second film")
	check(service.cancel_training_lesson(int(partial_lessons[1])).is_empty(),"T12 current individual lesson can be cancelled")
	check(service.staff_training.is_active() and service.staff_training.phase=="watching" and service.staff_training.record_id==1333,"T12 party remains at the TV and immediately starts the next lesson")
	check(int(partial_batch.gathers)==1 and int(partial_batch.returns)==0,"T12 individual cancellation causes no extra gather or early return")
	check(await run_until(service,func():return str(service.training_queue._course(int(partial_cancel.course_id)).get("state",""))=="completed",90.0),"T12 remainder completes after cancelling one film")
	check(int(station.method_sources.get("wine",{}).get("id",0))==1331 and int(station.method_sources.get("potato",{}).get("id",0))==0 and int(station.method_sources.get("sausage",{}).get("id",0))==1333,"T12 cancelled film stays unlearned while surrounding lessons remain learned")
	check(int(partial_batch.gathers)==1 and int(partial_batch.movies)==2 and int(partial_batch.returns)==1,"T12 one gather and one return survive an individual lesson cancellation")
	dispose(game)

	print("PASS: T10-T12 shift boundary, evening handoff and cancellation" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
