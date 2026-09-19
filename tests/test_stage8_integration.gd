extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Library=preload("res://scripts/masterclass_library.gd")
const Annex=preload("res://scripts/cafe_annex.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func repeated(value: Dictionary,count: int)->Array:
	var result: Array=[]
	for i in range(count): result.append(value.duplicate(true))
	return result

func serving_sausage_frame(station: Node3D)->Dictionary:
	station.model.reset("sausage")
	var m=station.model
	m.plates[0].point=m.Layout.TRAY
	m.elevations.plate_0=m.Layout.TRAY_Y-m.BASE_Y
	m.sausage=m.Layout.TRAY
	m.sausage_state="plate_0"
	m.sausage_coating=1.0
	m.elevations.sausage=m.Layout.TRAY_Y-m.BASE_Y+0.035
	m._store_food("sausage")
	return m.snapshot()

func make_record(station: Node3D,id: int,dish: String,name: String,frame: Dictionary)->Dictionary:
	var frames:=repeated(frame,900)
	return Library.make_record(id,dish,"counter",[{"group":1,"frames":frames}],15.0,station.model.quality(),name)

func teach_source(station: Node3D,record: Dictionary,frames_count: int,frame: Dictionary)->void:
	station.recipes[str(record.dish)]={"tracks":[{"group":1,"frames":repeated(frame,frames_count)}],"duration":float(frames_count)/60.0,"quality":record.quality.duplicate(true)}
	station.method_sources[str(record.dish)]={"id":int(record.id),"name":str(record.name)}

func run_until(service: Node3D,predicate: Callable,seconds := 120.0)->bool:
	for i in range(ceili(seconds/0.1)):
		service.advance(0.1)
		await process_frame
		if predicate.call(): return true
	return false

func automatic_course(service: Node3D)->Dictionary:
	for course in service.training_queue.courses:
		if bool(course.get("automatic",false)): return course
	return {}

func active_large_order(service: Node3D)->Dictionary:
	for customer in service.customers:
		if int(customer.get("portions_total",1))==10 and str(customer.get("state",""))!="leaving": return customer
	return {}

func feed_has(service: Node3D,kind: String)->bool:
	for entry in service.analytics.feed:
		if str(entry.get("kind",""))==kind: return true
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
	var p=service.progress
	p.stars=4
	p.expanded=true
	p.specialized_expanded=true
	p.orchestration_expanded=true
	p.shift="open"
	p.cash=10000
	p.lounge_tier=2
	p.lounge_items=["sofa","television","rocking_chair","foosball","arcade","table_tennis","board_games","bookcase","beanbag","tea_station","jukebox","aquarium","plants","floor_lamp","snack_fridge","textiles","ambient"]
	service.open_for_business=false

	print("Stage8 integration 1/7: developed cafe buys two equipped stations into an existing group")
	var source=service.add_station("counter",1,false,false)
	source.staffed=1
	source.equipment=["rag","plates","sauce","jug","cup"]
	source.apply_equipment()
	var sausage_frame: Dictionary=serving_sausage_frame(source)
	var sausage_record: Dictionary=make_record(source,9101,"sausage","Линия · сосиска",sausage_frame)
	source.model.reset("wine")
	var wine_frame: Dictionary=source.model.snapshot()
	var wine_record: Dictionary=make_record(source,9102,"wine","Линия · напиток",wine_frame)
	service.masterclasses=[sausage_record,wine_record]
	service.next_masterclass_id=9103
	teach_source(source,sausage_record,30,sausage_frame)
	teach_source(source,wine_record,30,wine_frame)
	check(service._apply_group_plan(9101,[2]).size()==1,"Source group accepts sausage masterclass plan")
	check(service._apply_group_plan(9102,[2]).size()==1,"Source group accepts wine masterclass plan")
	var group_id: String=service.group_id_for_station(2)
	check(service.set_group_dish_active(group_id,"sausage",true).is_empty(),"Source group enables sausage")
	check(service.set_group_dish_active(group_id,"wine",true).is_empty(),"Source group enables wine")
	p.free_workers=[{"id":501,"tempo":1.0,"rest":1.0},{"id":502,"tempo":1.0,"rest":1.0}]
	p.free_clones=2
	service.normalize_workers()
	var purchase_error: String=game.shop.order_station_batch("counter",[7,8],["sauce","plates","jug","cup"],group_id,true)
	check(purchase_error.is_empty(),"Mass group purchase uses the real shop command")
	for i in range(240):
		game.shop.advance(0.5)
		game.shop._process(0.016)
		if service.by_id(7)!=null and service.by_id(8)!=null: break
	check(service.by_id(7)!=null and service.by_id(8)!=null,"Both purchased stations are physically installed")
	check(service.by_id(7).staffed==1 and service.by_id(8).staffed==1,"Existing autofill assigns both free workers")
	check(service.group_id_for_station(7)==group_id and service.group_id_for_station(8)==group_id,"Purchased stations join the chosen persistent group")

	print("Stage8 integration 2/7: installation creates one automatic two-lesson course")
	service.advance(0.1)
	await process_frame
	var course: Dictionary=automatic_course(service)
	check(not course.is_empty(),"Automatic reconciliation creates a course for the two new stations")
	var course_id: int=int(course.get("id",0))
	check(course.get("assignments",[]).size()==2,"Automatic course carries both desired masterclass lessons")
	check(service.training_queue._course_station_ids(course_id)==[7,8],"Automatic course targets only the two untrained new stations")
	check(feed_has(service,"group_training"),"Automatic course appears in the significant-event feed")

	print("Stage8 integration 3/7: another station accepts a real ten-portion order while the course gathers")
	service.open_for_business=true
	check(service.spawn_customer("sausage",false,false,{},10),"Large order is accepted through normal customer flow")
	check(await run_until(service,func():
		var order:=active_large_order(service)
		return not order.is_empty() and str(order.state)=="cooking" and int(order.station)==2
	,20.0),"Large order naturally reaches the independent source station")
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==9101,45.0),"Automatic course reaches its first real television film")
	var before_close: Dictionary=active_large_order(service)
	check(not before_close.is_empty() and int(before_close.get("portions_done",0))<10,"Large order is still active when training film begins")

	print("Stage8 integration 4/7: close during film, then save/load restores both active systems")
	var saved_order_id: int=int(before_close.get("order_id",0))
	var saved_done: int=int(before_close.get("portions_done",0))
	service.end_shift()
	check(p.shift=="closing" and service.staff_training.phase=="watching","Closing marks the current movie to finish before deferring the remainder")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(saved),"Combined closing/movie/order state reloads")
	p=service.progress
	var restored_order: Dictionary={}
	for customer in service.customers:
		if int(customer.get("order_id",0))==saved_order_id: restored_order=customer; break
	check(not restored_order.is_empty() and int(restored_order.get("portions_done",0))==saved_done,"Same large-order customer and progress survive load")
	check(service.staff_training.phase=="watching" and bool(service.movie_state.get("playing",false)),"Same training movie resumes after load")

	print("Stage8 integration 5/7: closing finishes the current film and large order, then defers remaining lesson to morning")
	check(await run_until(service,func():return service.progress.shift=="night",90.0),"Cafe reaches night without manual state edits")
	check(service.served>=1 and int(service.order_stats.portions_served)>=10,"Independent ten-portion order completes during closing")
	var restored_course: Dictionary=service.training_queue._course(course_id)
	check(str(restored_course.get("state",""))=="deferred","Automatic course remainder is deferred after the current film")
	check(int(service.by_id(7).method_sources.get("sausage",{}).get("id",0))==9101 and int(service.by_id(7).method_sources.get("wine",{}).get("id",0))!=9102,"First lesson is learned and second remains pending")
	check(feed_has(service,"training_deferred"),"Morning deferral is visible in the event feed")

	print("Stage8 integration 6/7: host sleeps through the real night transition")
	game.player.global_position=Annex.player_bed_center(0,p.lounge_tier)
	var sleep_error: String=game.session._sleep_action(1,{"action":"sleep","bed":0})
	check(sleep_error.is_empty() and game.session.sleep_scene_active(),"Host enters the real shared sleep scene")
	for i in range(100):
		game.session.advance(0.2)
		await process_frame
		if service.progress.shift=="open" and not game.session.sleep_scene_active(): break
	check(service.progress.shift=="open" and service.progress.day==2,"Sleep advances to the next working day")

	print("Stage8 integration 7/7: next day resumes and completes remaining lessons")
	check(await run_until(service,func():return str(service.training_queue._course(course_id).get("state",""))=="completed",90.0),"Deferred automatic course resumes and completes next day")
	for station_id in [7,8]:
		var station=service.by_id(station_id)
		check(int(station.method_sources.get("sausage",{}).get("id",0))==9101,"Station %d retains first learned lesson"%station_id)
		check(int(station.method_sources.get("wine",{}).get("id",0))==9102,"Station %d learns the deferred second lesson"%station_id)
	check(feed_has(service,"training_course_complete"),"Course completion is visible in the significant-event feed")
	var deferred_text: String=""
	for entry in service.analytics.feed:
		if str(entry.get("kind",""))=="training_deferred": deferred_text=service.feed_text(entry); break
	check("утро" in deferred_text and "ещё" in deferred_text,"Deferred feed text explains that lessons continue tomorrow")

	game._shutdown_tree(game)
	game.free()
	print("PASS: developed cafe -> group purchase -> automatic course -> large order -> closing film -> save/load -> sleep -> next-day completion" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
