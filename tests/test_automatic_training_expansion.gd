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
	game.service.progress.cash=100000
	if "television" not in game.service.progress.lounge_items: game.service.progress.lounge_items.append("television")
	return game

func add_source(service: Node3D,slot := 1)->Node3D:
	var station=service.add_station("counter",slot,false)
	prepare(station)
	return station

func workers(service: Node3D,count: int,start_id := 500)->void:
	service.progress.free_workers=[]
	for i in range(count): service.progress.free_workers.append({"id":start_id+i,"tempo":1.0,"rest":1.0})
	service.progress.free_clones=count
	service.progress.next_clone_id=maxi(service.progress.next_clone_id,start_id+count)

func automatic_courses(queue: Node,include_done := false)->Array:
	var result: Array=[]
	for course in queue.courses:
		if not bool(course.get("automatic",false)): continue
		if not include_done and str(course.get("state","")) in ["completed","cancelled"]: continue
		result.append(course)
	return result

func run_until(service: Node3D,predicate: Callable,seconds := 120.0)->bool:
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
	print("T07/T08: three purchased equipped tables form one automatic two-lesson course")
	var game=await make_game()
	var service=game.service
	var source=add_source(service)
	var wine=record_for(source,3101,"wine","Авто · напиток")
	var potato=record_for(source,3102,"potato","Авто · картошка")
	service.masterclasses=[wine,potato]
	teach(source,wine)
	teach(source,potato)
	check(service.create_table_group([2],"Новая линия").is_empty(),"T07 source group is explicit")
	var group_id: String=service.group_id_for_station(2)
	check(service._apply_group_plan(3101,[2]).size()==1,"T07 wine becomes first plan lesson")
	check(service._apply_group_plan(3102,[2]).size()==1,"T07 potato becomes second plan lesson")
	check(service.set_group_dish_active(group_id,"wine",true).is_empty() and service.set_group_dish_active(group_id,"potato",true).is_empty(),"T07 both planned dishes are active")
	workers(service,3)
	var equipment: Array=["jug","cup","pan","plates"]
	check(game.shop.order_station_batch("counter",[7,8,9],equipment,group_id,false).is_empty(),"T07 three equipped station kits are ordered into one group")
	check(service.progress.deliveries.size()==3,"T07 three physical deliveries exist")
	for parcel in service.progress.deliveries.duplicate():
		check(game.shop._install_parcel(parcel).is_empty(),"T07 delivered station installs")
	for station_id in [7,8,9]:
		var station=service.by_id(station_id)
		check(station!=null and station.staffed==1,"T07 installed station %d receives its worker"%station_id)
		check(service.group_id_for_station(station_id)==group_id,"T07 installed station %d joins the purchased persistent group"%station_id)
	service.training_queue.reconcile_automatic_needs()
	var auto:=automatic_courses(service.training_queue)
	check(auto.size()==1,"T07 one automatic course is created for all three ready stations")
	var course: Dictionary=auto[0] if auto.size()==1 else {}
	check(course.get("assignments",[]).size()==2,"T07 automatic course contains both remaining plan lessons")
	if not course.is_empty():
		check(course.assignments[0].station_ids==[7,8,9] and course.assignments[1].station_ids==[7,8,9],"T07 all three identically prepared tables share both lessons")
	# T08: repeated readiness/install-style reconciliation and staffing events must not duplicate the assignment.
	for i in range(4):
		service.assign_clones()
		service.request_auto_training_reconcile()
		service.training_queue.reconcile_automatic_needs()
	check(automatic_courses(service.training_queue).size()==1,"T08 repeated staffing and reconciliation keep exactly one required automatic course")
	var network_once: Dictionary=service.queue_training_course([{"record_id":3101,"station_ids":[7,8,9]},{"record_id":3102,"station_ids":[7,8,9]}],"together","t08-repeat-network",1)
	var network_twice: Dictionary=service.queue_training_course([{"record_id":3101,"station_ids":[7,8,9]},{"record_id":3102,"station_ids":[7,8,9]}],"together","t08-repeat-network",1)
	check(bool(network_once.get("duplicate",false)) and bool(network_twice.get("duplicate",false)) and int(network_once.get("course_id",0))==int(course.id) and int(network_twice.get("course_id",0))==int(course.id),"T08 repeated host assignment command resolves to the same automatic course")
	check(automatic_courses(service.training_queue).size()==1,"T08 repeated host command creates no duplicate automatic course")
	var course_id:=int(course.get("id",0))
	check(await run_until(service,func():return str(service.training_queue._course(course_id).get("state",""))=="completed"),"T07 automatic course completes without manual Train action")
	var batch: Dictionary=service.training_queue._batch(int(course.batch_ids[0]))
	check(int(batch.gathers)==1 and int(batch.movies)==2 and int(batch.returns)==1,"T07 one gather, two films and one return are used")
	for station_id in [7,8,9]:
		var station=service.by_id(station_id)
		check(station.recipes.has("wine") and station.recipes.has("potato"),"T07 station %d learns both planned dishes"%station_id)
		check(station.dish_active("wine") and station.dish_active("potato"),"T07 station %d can serve both active dishes"%station_id)
	dispose(game)

	print("Ready stations merge into a waiting auto party, but not into a started one")
	game=await make_game()
	service=game.service
	source=add_source(service)
	wine=record_for(source,3151,"wine","Авто · поздняя готовность")
	service.masterclasses=[wine]
	teach(source,wine)
	check(service.create_table_group([2],"Постепенная готовность").is_empty(),"Incremental readiness group exists")
	group_id=service.group_id_for_station(2)
	check(service._apply_group_plan(3151,[2]).size()==1 and service.set_group_dish_active(group_id,"wine",true).is_empty(),"Incremental readiness plan is active")
	for station_id in [7,8,9]:
		var station=service.add_station("counter",station_id-1,false,true)
		station.equipment=["jug","cup","rag"]
		station.apply_equipment()
		check(service.add_station_to_group(group_id,station_id).is_empty(),"Incremental station %d joins the group"%station_id)
	workers(service,1,550)
	service.assign_clones()
	service.training_queue.reconcile_automatic_needs()
	auto=automatic_courses(service.training_queue)
	check(auto.size()==1 and auto[0].assignments[0].station_ids==[7],"First ready station creates one waiting automatic course")
	var waiting_course_id: int=int(auto[0].id)
	service.progress.free_workers.append({"id":551,"tempo":1.0,"rest":1.0}); service.progress.free_clones=1
	service.assign_clones()
	service.training_queue.reconcile_automatic_needs()
	auto=automatic_courses(service.training_queue)
	check(auto.size()==1 and int(auto[0].id)==waiting_course_id and auto[0].assignments[0].station_ids==[7,8],"Second station joins the same still-waiting automatic party")
	service.training_queue.advance(0.0)
	var started_batch: Dictionary=service.training_queue._batch(int(service.training_queue._course(waiting_course_id).batch_ids[0]))
	check(int(service.training_queue.active_batch_id)==int(started_batch.id) and started_batch.station_ids==[7,8],"Started automatic party freezes its two-station composition")
	service.progress.free_workers.append({"id":552,"tempo":1.0,"rest":1.0}); service.progress.free_clones=1
	service.assign_clones()
	service.training_queue.reconcile_automatic_needs()
	auto=automatic_courses(service.training_queue)
	check(auto.size()==2,"Late-ready station gets a second automatic course instead of joining the started party")
	check(started_batch.station_ids==[7,8],"Started party remains unchanged after a later station becomes ready")
	var late_found:=false
	for auto_course in auto:
		if int(auto_course.id)==waiting_course_id: continue
		if auto_course.assignments.size()==1 and auto_course.assignments[0].station_ids==[9]: late_found=true
	check(late_found,"Second automatic course targets only the late-ready station")
	dispose(game)

	print("Plan changes while delivery is in flight use the current group plan")
	game=await make_game()
	service=game.service
	source=add_source(service)
	var old_wine=record_for(source,3201,"wine","Доставка · старая версия")
	var new_wine=record_for(source,3202,"wine","Доставка · новая версия")
	service.masterclasses=[old_wine,new_wine]
	teach(source,old_wine)
	check(service.create_table_group([2],"Живая группа").is_empty(),"Delivery-plan group exists")
	group_id=service.group_id_for_station(2)
	check(service._apply_group_plan(3201,[2]).size()==1 and service.set_group_dish_active(group_id,"wine",true).is_empty(),"Old plan is active when purchase is made")
	workers(service,1,600)
	check(game.shop.order_station_batch("counter",[7],["jug","cup"],group_id,false).is_empty(),"Station is ordered against old plan")
	var changing_parcel: Dictionary=service.progress.deliveries[0]
	check(int(changing_parcel.get("planned_group_snapshot",{}).get("plan_revision",0))==int(service.table_group_by_id(group_id).plan_revision),"Purchase stores group snapshot")
	teach(source,new_wine)
	check(service._apply_group_plan(3202,[2]).size()==1,"Group plan changes before delivery installation")
	check("изменился" in game.shop.parcel_plan_note(changing_parcel),"Delivery card explains that the group plan changed")
	check(game.shop._install_parcel(changing_parcel).is_empty(),"In-flight station installs after plan change")
	var delivered=service.by_id(7)
	check(service.group_id_for_station(7)==group_id,"Installed station still joins the selected persistent group")
	check(int(delivered.method_plan.get("wine",{}).get("id",0))==3202,"Installed station receives current plan, not purchase-time record")
	service.training_queue.reconcile_automatic_needs()
	auto=automatic_courses(service.training_queue)
	check(auto.size()==1 and int(auto[0].assignments[0].record_id)==3202 and auto[0].assignments[0].station_ids==[7],"Automatic course uses the current record version after delivery")
	dispose(game)

	print("Deleted purchase target creates one standalone group from the saved plan")
	game=await make_game()
	service=game.service
	var first_source=add_source(service,1)
	var second_source=add_source(service,2)
	wine=record_for(first_source,3301,"wine","Снимок удалённой группы")
	service.masterclasses=[wine]
	teach(first_source,wine)
	teach(second_source,wine)
	check(service.create_table_group([2],"Группа заказа").is_empty(),"Fallback source group exists")
	var purchased_group: String=service.group_id_for_station(2)
	check(service._apply_group_plan(3301,[2]).size()==1 and service.set_group_dish_active(purchased_group,"wine",true).is_empty(),"Fallback purchase group has a plan")
	check(service.create_table_group([3],"Группа-приёмник").is_empty(),"Merge target group exists")
	var survivor_group: String=service.group_id_for_station(3)
	check(service._apply_group_plan(3301,[3]).size()==1 and service.set_group_dish_active(survivor_group,"wine",true).is_empty(),"Merge target has matching plan")
	workers(service,1,700)
	check(game.shop.order_station_batch("counter",[7],["jug","cup"],purchased_group,false).is_empty(),"Station is ordered to group that will disappear")
	var orphan_parcel: Dictionary=service.progress.deliveries[0]
	check(service.merge_table_groups([survivor_group,purchased_group],{},null).is_empty(),"Purchased group is deleted by merge")
	check(service.table_group_by_id(purchased_group).is_empty(),"Original purchased group ID is gone")
	check("удалена" in game.shop.parcel_plan_note(orphan_parcel),"Delivery card explains deleted target group fallback")
	check(game.shop._install_parcel(orphan_parcel).is_empty(),"Station with deleted target still installs")
	var fallback_group_id: String=service.group_id_for_station(7)
	var fallback_group: Dictionary=service.table_group_by_id(fallback_group_id)
	check(not fallback_group.is_empty() and fallback_group_id!=survivor_group and "отдельная" in str(fallback_group.name),"Deleted target produces a separate persistent group")
	check(int(service.desired_source(fallback_group_id,"wine").get("id",0))==3301,"Fallback group preserves purchase-time curriculum")
	service.training_queue.reconcile_automatic_needs()
	check(automatic_courses(service.training_queue).size()==1,"Fallback planned station enters automatic training once")
	dispose(game)

	print("Waiting equipment survives save/load and starts automatically after installation")
	game=await make_game()
	service=game.service
	source=add_source(service)
	potato=record_for(source,3401,"potato","После сковороды")
	service.masterclasses=[potato]
	teach(source,potato)
	check(service.create_table_group([2],"Ожидание оборудования").is_empty(),"Equipment-wait group exists")
	group_id=service.group_id_for_station(2)
	check(service._apply_group_plan(3401,[2]).size()==1 and service.set_group_dish_active(group_id,"potato",true).is_empty(),"Potato plan is active")
	workers(service,1,800)
	check(game.shop.order_station_batch("counter",[7],["plates"],group_id,false).is_empty(),"New station is intentionally ordered without a pan")
	var incomplete: Dictionary=service.progress.deliveries[0]
	check(game.shop._install_parcel(incomplete).is_empty(),"Incomplete station installs")
	service.training_queue.reconcile_automatic_needs()
	check(automatic_courses(service.training_queue).is_empty(),"No automatic course is created before required equipment exists")
	check(service.station_group_status(7,"potato")=="ждёт оснащение","Station card exposes equipment prerequisite")
	var waiting_save: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(waiting_save),"Save reloads while automatic training waits for equipment")
	service.training_queue.reconcile_automatic_needs()
	check(automatic_courses(service.training_queue).is_empty(),"Reload does not invent training before equipment is installed")
	service.progress.cash=100000
	check(game.shop.order_bundle(["pan"],7,false).is_empty(),"Missing pan is ordered after reload")
	var pan_parcel: Dictionary=service.progress.deliveries.back()
	check(game.shop._install_parcel(pan_parcel).is_empty(),"Missing pan installs")
	service.training_queue.reconcile_automatic_needs()
	auto=automatic_courses(service.training_queue)
	check(auto.size()==1 and auto[0].assignments[0].station_ids==[7],"Installing final prerequisite automatically creates the same required course")
	dispose(game)

	print("T08 cancellation suppression: cancelled plan version stays suspended, new version may auto-queue")
	game=await make_game()
	service=game.service
	var target=add_source(service)
	var cancel_old=record_for(target,3501,"wine","Отменяемая версия")
	var cancel_new=record_for(target,3502,"wine","Новая версия после отмены")
	service.masterclasses=[cancel_old,cancel_new]
	check(service.create_table_group([2],"Отмена автоматики").is_empty(),"Cancellation group exists")
	group_id=service.group_id_for_station(2)
	check(service._apply_group_plan(3501,[2]).size()==1 and service.set_group_dish_active(group_id,"wine",true).is_empty(),"Old desired version is set")
	service.progress.lounge_items.erase("television")
	service.training_queue.reconcile_automatic_needs()
	auto=automatic_courses(service.training_queue)
	check(auto.size()==1,"Automatic course exists before cancellation")
	course_id=int(auto[0].id)
	service.training_queue.advance(0.0)
	check(service.cancel_training_course(course_id).is_empty(),"Automatic course can be cancelled")
	for i in range(5): service.training_queue.reconcile_automatic_needs()
	check(automatic_courses(service.training_queue).is_empty(),"Cancelled assignment version is not resurrected by repeated automatic checks")
	check(service.training_queue.assignment_suspended(2,"wine"),"Cancelled desired version is visibly suspended")
	check(service._apply_group_plan(3502,[2]).size()==1,"A new desired record creates a new plan version")
	service.training_queue.reconcile_automatic_needs()
	auto=automatic_courses(service.training_queue)
	check(auto.size()==1 and int(auto[0].assignments[0].record_id)==3502,"New plan version is allowed to create a fresh automatic course")
	dispose(game)

	print("PASS: T07-T08 expansion automation, delivery plan changes, fallback groups and save recovery" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
