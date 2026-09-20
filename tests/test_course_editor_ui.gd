extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Library=preload("res://scripts/masterclass_library.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func tree_text(node: Node)->String:
	var result: String=""
	if node is Label or node is Button: result+=str(node.text)+"\n"
	for child in node.get_children(): result+=tree_text(child)
	return result

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
	game.player.global_position=game.shop.computer.global_position
	return game

func add_counter(service: Node3D,slot: int)->Node3D:
	var station=service.add_station("counter",slot,false)
	prepare(station)
	return station

func find_button(node: Node,prefix: String)->Button:
	if node is Button and str(node.text).begins_with(prefix): return node
	for child in node.get_children():
		var found:=find_button(child,prefix)
		if found!=null: return found
	return null

func press(office: CanvasLayer,prefix: String)->bool:
	office.rebuild()
	var target:=find_button(office.content,prefix)
	if target==null:
		printerr("Missing UI button: ",prefix)
		return false
	target.emit_signal("pressed")
	return true

func run_until(service: Node3D,predicate: Callable,seconds := 90.0)->bool:
	for i in range(ceili(seconds/0.1)):
		service.advance(0.1)
		await process_frame
		if predicate.call(): return true
	return false

func dispose(game)->void:
	game.office.close()
	game._shutdown_tree(game)
	game.free()

func _initialize()->void:
	run.call_deferred()

func run()->void:
	print("UI T04: build a three-lesson together course from Groups")
	var game=await make_game()
	var service=game.service
	var a=add_counter(service,1)
	var b=add_counter(service,2)
	var wine=record_for(a,2101,"wine","UI · напиток")
	var potato=record_for(a,2102,"potato","UI · картошка")
	var sausage=record_for(a,2103,"sausage","UI · сосиска")
	service.masterclasses=[wine,potato,sausage]
	check(service.create_table_group([2,3],"UI линия").is_empty(),"UI T04 explicit group exists")
	game.office.open("groups")
	var overview_text: String=tree_text(game.office.content)
	check("UI линия" in overview_text and "Стол 2 ·" not in overview_text and "Стол 3 ·" not in overview_text,"UI T04 groups start collapsed and show only aggregate rows")
	var group_id_overview: String=service.group_id_for_station(2)
	game.office.toggle_group_expanded(group_id_overview)
	overview_text=tree_text(game.office.content)
	check("Стол 2 ·" in overview_text and "Стол 3 ·" in overview_text,"UI T04 expanding a group reveals per-table details")
	game.office.toggle_group_expanded(group_id_overview)
	game.office.select_group_stations([2,3])
	check(press(game.office,"Обучение"),"UI T04 opens the separate training workspace")
	check(game.office.groups_mode=="training" and "МАСТЕР-КЛАССЫ" in tree_text(game.office.content) and "РАСПИСАНИЕ" in tree_text(game.office.content),"UI T04 workspace separates library from schedule")
	game.office.course_editor_add_record(2101)
	game.office.course_editor_add_record(2102)
	game.office.course_editor_add_record(2103)
	check(game.office.course_editor.records==[2101,2102,2103],"UI T04 draft keeps three ordered lessons")
	game.office.course_editor_move_record(2,-1)
	check(game.office.course_editor.records==[2101,2103,2102],"UI T04 arrows change lesson order")
	game.office.course_editor_move_record(1,1)
	check(game.office.course_editor.records==[2101,2102,2103],"UI T04 lesson order can be restored")
	var preview: Dictionary=service.training_course_preview(game.office.course_editor_assignments(),"together",game.office.course_group_order)
	check(str(preview.error).is_empty() and int(preview.places)==2 and preview.lessons.size()==3,"UI T04 preview reports selected tables and lessons")
	check(press(game.office,"Поставить курс в очередь"),"UI T04 queue button exists")
	await process_frame
	var views: Array=service.training_course_views()
	check(views.size()==1 and views[0].assignments.size()==3 and str(views[0].mode)=="together","UI T04 button creates one three-lesson course")
	var course_id:=int(views[0].id)
	var batch_id:=int(views[0].batches[0].id)
	check(await run_until(service,func():return str(service.training_queue._course(course_id).get("state",""))=="completed"),"UI T04 course completes")
	var batch: Dictionary=service.training_queue._batch(batch_id)
	check(int(batch.gathers)==1 and int(batch.movies)==3 and int(batch.returns)==1,"UI T04 results in one gather, three films and one return")
	dispose(game)

	print("UI T05: choose group order and send a course by groups")
	game=await make_game()
	service=game.service
	var c1=add_counter(service,1)
	var c2=add_counter(service,2)
	var c3=add_counter(service,3)
	var c4=add_counter(service,4)
	potato=record_for(c1,2201,"potato","UI · группы")
	service.masterclasses=[potato]
	check(service.create_table_group([2,3],"Группа A").is_empty(),"UI T05 group A")
	check(service.create_table_group([4,5],"Группа B").is_empty(),"UI T05 group B")
	var group_a: String=service.group_id_for_station(2)
	var group_b: String=service.group_id_for_station(4)
	game.office.open("groups")
	game.office.select_group_stations([2,3,4,5])
	check(press(game.office,"Обучение"),"UI T05 opens training workspace")
	game.office.course_editor_add_record(2201)
	game.office.course_editor_set_mode("by_groups")
	game.office._sync_course_group_order()
	check(game.office.course_group_order==[group_a,group_b],"UI T05 default group order follows editor order")
	game.office.course_editor_move_group(group_b,-1)
	check(game.office.course_group_order==[group_b,group_a],"UI T05 arrows change group order")
	preview=service.training_course_preview(game.office.course_editor_assignments(),"by_groups",game.office.course_group_order)
	check(str(preview.error).is_empty() and preview.batches.size()==2 and str(preview.batches[0].name)=="Группа B","UI T05 preview reflects chosen first group")
	check(press(game.office,"Поставить курс в очередь"),"UI T05 queues course")
	await process_frame
	views=service.training_course_views()
	check(views.size()==1 and str(views[0].mode)=="by_groups","UI T05 creates by-groups course")
	var first_batch: Dictionary=views[0].batches[0]
	var second_batch: Dictionary=views[0].batches[1]
	check(first_batch.stations==[4,5] and second_batch.stations==[2,3],"UI T05 backend preserves UI group order")
	service.advance(0.1)
	await process_frame
	check(int(service.training_queue.active_batch_id)==int(first_batch.id) and service.by_id(2).group_training_state.is_empty(),"UI T05 second group keeps working while chosen first group learns")
	check(await run_until(service,func():return str(service.training_queue._batch(int(first_batch.id)).get("state",""))=="completed" and int(service.training_queue.active_batch_id)==int(second_batch.id)),"UI T05 second party starts after first returns")
	dispose(game)

	print("UI T05 partial: group order survives a preview split")
	game=await make_game()
	service=game.service
	var p1=add_counter(service,1)
	var p2=add_counter(service,2)
	var p3=add_counter(service,3)
	var p4=add_counter(service,4)
	var p5=add_counter(service,5)
	potato=record_for(p1,2251,"potato","UI · частичная группа")
	service.masterclasses=[potato]
	check(service.create_table_group([2,3,4],"Частичная A").is_empty(),"UI T05 partial group A")
	check(service.create_table_group([5,6],"Полная B").is_empty(),"UI T05 partial group B")
	group_a=service.group_id_for_station(2)
	group_b=service.group_id_for_station(5)
	game.office.open("groups")
	game.office.select_group_stations([2,5,6])
	check(press(game.office,"Обучение"),"UI T05 partial opens training workspace")
	game.office.course_editor_add_record(2251)
	game.office.course_editor_set_mode("by_groups")
	game.office.course_group_order=[group_a,group_b]
	preview=service.training_course_preview(game.office.course_editor_assignments(),"by_groups",game.office.course_group_order)
	check(str(preview.error).is_empty() and preview.batches.size()==2 and preview.batches[0].stations==[2] and preview.batches[1].stations==[5,6],"UI T05 partial preview preserves source-group order after split")
	check(press(game.office,"Поставить курс в очередь"),"UI T05 partial queues split course")
	await process_frame
	views=service.training_course_views()
	check(views.size()==1 and views[0].batches.size()==2 and views[0].batches[0].stations==[2] and views[0].batches[1].stations==[5,6],"UI T05 partial actual queue matches preview order after new group id appears")
	dispose(game)

	print("UI T13: replace a waiting record by editing the queued course")
	game=await make_game()
	service=game.service
	var station=add_counter(service,1)
	var old_potato=record_for(station,2301,"potato","UI · версия A")
	var new_potato=record_for(station,2302,"potato","UI · версия B")
	var extra_sausage=record_for(station,2303,"sausage","UI · дополнительный урок")
	service.masterclasses=[old_potato,new_potato,extra_sausage]
	service.progress.lounge_items.erase("television")
	game.office.open("groups")
	game.office.select_group_stations([2])
	check(press(game.office,"Обучение"),"UI T13 opens training workspace")
	game.office.course_editor_add_record(2301)
	check(press(game.office,"Поставить курс в очередь"),"UI T13 queues old version")
	await process_frame
	service.training_queue.advance(0.0)
	views=service.training_course_views()
	course_id=int(views[0].id)
	check(str(views[0].state)=="blocked","UI T13 waiting course is visible as blocked")
	game.office.rebuild()
	game.office.toggle_training_course_expanded(course_id)
	check(press(game.office,"Настройки курса"),"UI T13 settings button opens the queued course")
	game.office.course_editor_add_record(2302)
	check(game.office.course_editor.records==[2302],"UI T13 second version replaces the same-dish draft row")
	game.office.course_editor_add_record(2303)
	game.office.course_editor_move_record(1,-1)
	check(game.office.course_editor.records==[2303,2302],"UI T13 queued-course editor can change composition and lesson order")
	check(press(game.office,"Сохранить изменения"),"UI T13 saves queued-course replacement")
	await process_frame
	var edited_view: Dictionary=service.training_queue.course_view(course_id)
	check(edited_view.assignments.size()==2 and int(edited_view.assignments[0].record_id)==2303 and int(edited_view.assignments[1].record_id)==2302,"UI T13 edited course persists the new lesson order")
	check(int(service.training_queue.pending_source(2,"potato").get("id",0))==2302,"UI T13 queue now points to the new record version")
	dispose(game)

	print("UI T13 active: a new UI assignment waits behind the old frozen film")
	game=await make_game()
	service=game.service
	station=add_counter(service,1)
	old_potato=record_for(station,2311,"potato","UI · активная A")
	new_potato=record_for(station,2312,"potato","UI · активная B")
	service.masterclasses=[old_potato,new_potato]
	game.office.open("groups")
	game.office.select_group_stations([2])
	check(press(game.office,"Обучение"),"UI T13 active opens first training workspace")
	game.office.course_editor_add_record(2311)
	check(press(game.office,"Поставить курс в очередь"),"UI T13 active queues old film")
	await process_frame
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==2311),"UI T13 active old film starts")
	game.office.course_editor_open(2312)
	game.office.course_editor_select_group(service.group_id_for_station(2),true)
	check(press(game.office,"Поставить курс в очередь"),"UI T13 active queues the newer version while old film is running")
	await process_frame
	check(int(service.desired_source(service.group_id_for_station(2),"potato").get("id",0))==2312,"UI T13 active updates the desired version while the old frozen film remains current")
	var live_views: Array=service.training_course_views()
	check(live_views.any(func(view):return view.assignments.any(func(item):return int(item.record_id)==2312)),"UI T13 active keeps the newer UI-created assignment in the queue")
	check(await run_until(service,func():return int(station.method_sources.get("potato",{}).get("id",0))==2311 and not service.staff_training.is_active(),60.0),"UI T13 active old film commits old knowledge first")
	check(int(service.training_queue.pending_source(2,"potato").get("id",0))==2312,"UI T13 active still requires the newer version after old film completion")
	check(await run_until(service,func():return int(station.method_sources.get("potato",{}).get("id",0))==2312,90.0),"UI T13 active eventually retrains through the UI-created follow-up course")
	dispose(game)

	print("UI T12: cancel an active course and resume its suspended plan from the queue page")
	game=await make_game()
	service=game.service
	station=add_counter(service,1)
	var old_method=record_for(station,2400,"potato","UI · старый способ")
	var first=record_for(station,2401,"sausage","UI · первый урок")
	var second=record_for(station,2402,"potato","UI · второй урок")
	station.recipes.potato={"tracks":old_method.tracks.duplicate(true),"duration":old_method.duration,"quality":old_method.quality.duplicate(true)}
	station.method_sources.potato={"id":2400,"name":"UI · старый способ"}
	service.masterclasses=[old_method,first,second]
	game.office.open("groups")
	game.office.select_group_stations([2])
	check(press(game.office,"Обучение"),"UI T12 opens training workspace")
	game.office.course_editor_add_record(2401)
	game.office.course_editor_add_record(2402)
	check(press(game.office,"Поставить курс в очередь"),"UI T12 queues course")
	await process_frame
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==2402),"UI T12 reaches second film")
	game.office.open("groups")
	check(press(game.office,"Очередь обучения"),"UI T12 opens queue workspace without preselecting tables")
	check(press(game.office,"Отменить курс"),"UI T12 cancellation button is available")
	check(await run_until(service,func():return not service.staff_training.is_active(),60.0),"UI T12 workers return after UI cancellation")
	check(int(station.method_sources.get("sausage",{}).get("id",0))==2401 and int(station.method_sources.get("potato",{}).get("id",0))==2400,"UI T12 completed first lesson stays learned and interrupted second stays old")
	game.office.rebuild()
	check(press(game.office,"Продолжить"),"UI T12 exposes resume button for the suspended desired assignment")
	await process_frame
	check(int(service.training_queue.pending_source(2,"potato").get("id",0))==2402,"UI T12 resume creates the required pending lesson")
	dispose(game)

	print("UI draft: host rejection keeps the course draft and explains why")
	game=await make_game()
	service=game.service
	station=add_counter(service,1)
	wine=record_for(station,2491,"wine","UI · черновик")
	service.masterclasses=[wine]
	game.office.open("groups")
	game.office.select_group_stations([2])
	check(press(game.office,"Обучение"),"UI draft opens training workspace")
	game.office.course_editor_add_record(2491)
	game.player.global_position=game.shop.computer.global_position+Vector3(20,0,0)
	check(press(game.office,"Поставить курс в очередь"),"UI draft submit button exists while away from computer")
	check(not game.office.course_editor.is_empty() and game.office.course_editor.records==[2491],"UI draft survives a rejected host confirmation")
	check(game.office.course_editor_message.contains("Подойди к компьютеру"),"UI draft shows the concrete host rejection reason")
	game.player.global_position=game.shop.computer.global_position
	check(press(game.office,"Поставить курс в очередь"),"UI draft can be confirmed after returning to the computer")
	await process_frame
	check(service.training_course_views().size()==1,"UI draft successful retry creates exactly one course")
	dispose(game)

	print("UI video entry: Add to course opens the same editor")
	game=await make_game()
	service=game.service
	station=add_counter(service,1)
	wine=record_for(station,2501,"wine","UI · из видеотеки")
	service.masterclasses=[wine]
	game.office.open("videos")
	check(press(game.office,"Добавить в курс"),"Videotheque has Add to course")
	check(game.office.tab=="groups" and game.office.groups_mode=="training" and game.office.course_editor.records==[2501] and str(game.office.course_editor.type_id)=="counter","Videotheque opens the training workspace with the record prefilled")
	dispose(game)

	print("PASS: stage 3 course editor and queue management UI" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
