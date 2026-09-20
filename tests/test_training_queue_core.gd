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

func record_for(station: Node3D,id: int,dish: String,name: String,frames_count := 120)->Dictionary:
	station.model.reset(dish)
	var frames:=repeated(station.model.snapshot(),frames_count)
	return Library.make_record(id,dish,station.type_id,[{"group":1,"frames":frames}],float(frames_count)/60.0,station.model.quality(),name)

func prepare(station: Node3D)->void:
	station.staffed=1
	station.equipment=["jug","cup","plates","pan","sauce","rag","meat_kit","pasta_kit"]
	station.apply_equipment()

func teach(station: Node3D,record: Dictionary)->void:
	station.recipes[str(record.dish)]={"tracks":record.tracks.duplicate(true),"duration":record.duration,"quality":record.quality.duplicate(true)}
	station.method_sources[str(record.dish)]={"id":int(record.id),"name":str(record.name)}

func serving_sausage_recipe(station: Node3D)->Dictionary:
	station.model.reset("sausage")
	var m=station.model
	m.plates[0].point=m.Layout.TRAY
	m.elevations.plate_0=m.Layout.TRAY_Y-m.BASE_Y
	m.sausage=m.Layout.TRAY
	m.sausage_state="plate_0"
	m.sausage_coating=1.0
	m.elevations.sausage=m.Layout.TRAY_Y-m.BASE_Y+0.035
	m._store_food("sausage")
	var frame: Dictionary=m.snapshot()
	return {"tracks":[{"group":1,"frames":repeated(frame,60)}],"duration":1.0,"quality":m.quality()}

func course_state(queue: Node,id: int)->String:
	return str(queue._course(id).get("state",""))

func feed_count(service: Node3D,kind: String,course_id := 0)->int:
	var count:=0
	for entry in service.analytics.feed:
		if str(entry.get("kind",""))!=kind: continue
		if course_id>0 and int(entry.get("course",0))!=course_id: continue
		count+=1
	return count

func run_until(service: Node3D,predicate: Callable,seconds := 90.0)->bool:
	var steps:=ceili(seconds/0.1)
	for i in range(steps):
		service.advance(0.1)
		await process_frame
		if predicate.call(): return true
	return false

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
	for slot in range(1,10):
		var station=service.add_station("counter",slot,false)
		prepare(station)
		stations.append(station)
	var wine:=record_for(stations[0],1201,"wine","Курс · напиток")
	var potato:=record_for(stations[0],1202,"potato","Курс · картошка")
	var sausage:=record_for(stations[0],1203,"sausage","Курс · сосиска")
	var potato_new:=record_for(stations[0],1204,"potato","Курс · новая картошка")
	service.masterclasses=[wine,potato,sausage,potato_new]
	service.next_masterclass_id=1205

	print("T04: one together batch watches three films and returns once")
	var t04: Dictionary=service.queue_training_course([
		{"record_id":1201,"station_ids":[2,3]},
		{"record_id":1202,"station_ids":[2,3]},
		{"record_id":1203,"station_ids":[2,3]}
	],"together","t04",1)
	check(str(t04.error).is_empty(),"T04 course is accepted")
	var t04_id:=int(t04.course_id)
	var duplicate: Dictionary=service.queue_training_course([{"record_id":1201,"station_ids":[2,3]},{"record_id":1202,"station_ids":[2,3]},{"record_id":1203,"station_ids":[2,3]}],"together","t04",1)
	check(int(duplicate.course_id)==t04_id and bool(duplicate.duplicate),"Repeated host command returns the same course")
	check(await run_until(service,func():return course_state(queue,t04_id)=="completed"),"T04 course completes")
	var t04_course: Dictionary=queue._course(t04_id)
	var t04_batch: Dictionary=queue._batch(int(t04_course.batch_ids[0]))
	check(int(t04_batch.gathers)==1 and int(t04_batch.movies)==3 and int(t04_batch.returns)==1,"T04 performs one gather, three movies and one return")
	check(int(service.by_id(2).method_sources.wine.id)==1201 and int(service.by_id(2).method_sources.potato.id)==1202 and int(service.by_id(2).method_sources.sausage.id)==1203,"T04 all three lessons are learned")
	check(absf(float(wine.highlight_duration)-float(wine.duration)*0.30)<0.05 and absf(float(potato.highlight_duration)-float(potato.duration)*0.30)<0.05,"T04 films use the 30 percent highlight duration")

	print("T05: by-groups batches keep the next group at work")
	check(service.create_table_group([4,5],"Первая смена").is_empty(),"T05 first explicit group")
	check(service.create_table_group([6,7],"Вторая смена").is_empty(),"T05 second explicit group")
	var t05: Dictionary=service.queue_training_course([{"record_id":1201,"station_ids":[4,5,6,7]}],"by_groups","t05",1)
	check(str(t05.error).is_empty(),"T05 by-groups course accepted")
	var t05_id:=int(t05.course_id)
	service.advance(0.1)
	await process_frame
	var t05_course: Dictionary=queue._course(t05_id)
	var first_batch: Dictionary=queue._batch(int(t05_course.batch_ids[0]))
	var second_batch: Dictionary=queue._batch(int(t05_course.batch_ids[1]))
	check(int(queue.active_batch_id)==int(first_batch.id),"T05 first group is selected first")
	check(service.by_id(6).group_training_state.is_empty() and service.by_id(6).ready_crew(),"T05 second group keeps serving while first leaves")
	check(await run_until(service,func():return str(first_batch.state)=="completed" and int(queue.active_batch_id)==int(second_batch.id),90.0),"T05 second group starts only after first returns")
	check(service.by_id(4).group_training_state.is_empty(),"T05 first group is available when second learns")
	check(await run_until(service,func():return course_state(queue,t05_id)=="completed"),"T05 both group batches finish")

	print("T06: missing equipment does not block learning and only blocks execution")
	stations[6].equipment.erase("pan")
	stations[6].apply_equipment()
	var t06_course: Dictionary=service.queue_training_course([{"record_id":1202,"station_ids":[8]}],"together","t06-independent",1)
	check(str(t06_course.error).is_empty(),"T06 course is accepted without required production equipment")
	var t06_id:=int(t06_course.course_id)
	var t06_batch: Dictionary=queue._batch(int(queue._course(t06_id).batch_ids[0]))
	service.advance(0.1)
	await process_frame
	check(str(t06_batch.state)!="blocked" or "оборудование" not in str(t06_batch.blocked_reason),"T06 missing pan never becomes a training block reason")
	check(await run_until(service,func():return course_state(queue,t06_id)=="completed"),"T06 lesson completes without pan")
	var learned_station=service.by_id(8)
	check(learned_station.recipes.has("potato"),"T06 station learns the potato method")
	check("pan" in learned_station.recipe_requirements("potato"),"T06 learned method keeps its recorded equipment requirements")
	check(not learned_station.can_execute("potato"),"T06 learned station cannot execute the method without pan")
	for candidate in stations:
		var candidate_group: String=service.group_id_for_station(candidate.station_id)
		if not candidate_group.is_empty(): service.set_group_dish_active(candidate_group,"potato",candidate.station_id==8)
	check(str(service.problem_context("potato").reason)=="equipment","T06 service reports execution equipment as the blocker when this is the active learned kitchen")
	check("Кухня 8" in service.equipment_warning_text(4) and "Дырявая сковорода" in service.equipment_warning_text(4),"T06 persistent warning names the affected kitchen and missing item")
	learned_station.equipment.append("pan")
	learned_station.apply_equipment()
	check(learned_station.can_execute("potato"),"T06 installing pan immediately enables execution without retraining")
	check("Кухня 8" not in service.equipment_warning_text(4),"T06 warning disappears after equipment is installed")

	print("T09: selected station drains the whole accepted ten-portion order")
	var order_station: Node3D=stations[8]
	order_station.recipes.sausage=serving_sausage_recipe(order_station)
	order_station.method_sources.sausage={"id":1203,"name":"Курс · сосиска"}
	var order_group: String=service.group_id_for_station(order_station.station_id)
	service.set_group_dish_active(order_group,"sausage",true)
	check(service.spawn_customer("sausage",false,false,{},10),"T09 ten-portion order is accepted")
	var order: Dictionary={}
	for customer in service.customers:
		if int(customer.get("station",-1))==order_station.station_id: order=customer; break
	check(not order.is_empty(),"T09 order stays attached to its station")
	order.path.clear()
	order.view.global_position=order_station.to_global(Vector3(0,0,-1.85))
	service.advance(0.02)
	check(order.state=="cooking","T09 order begins cooking on the selected table")
	check(await run_until(service,func():return int(order.get("portions_done",0))>=3,30.0),"T09 first three portions are served")
	var before_done:=int(order.portions_done)
	var t09: Dictionary=service.queue_training_course([{"record_id":1204,"station_ids":[order_station.station_id]}],"together","t09",1)
	service.advance(0.1)
	await process_frame
	var t09_batch: Dictionary=queue._batch(int(queue._course(int(t09.course_id)).batch_ids[0]))
	check(str(t09_batch.state)=="draining","T09 course enters draining instead of interrupting the order")
	check(int(order.portions_done)>=before_done,"T09 accepted order is not rolled back")
	check(await run_until(service,func():return int(order.get("portions_done",0))==10 and str(t09_batch.state) in ["gathering","watching","returning","completed"],60.0),"T09 all ten portions finish before staff leaves")
	check(await run_until(service,func():return course_state(queue,int(t09.course_id))=="completed"),"T09 training completes after the order releases the station")

	game._shutdown_tree(game)
	game.free()
	print("PASS: T04-T06 and T09 training queue controller" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
