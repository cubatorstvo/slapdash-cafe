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
	print("UI T04: compact groups feed one flat training schedule")
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
	var workspace_text:=tree_text(game.office.content)
	check("МАСТЕР-КЛАССЫ" in workspace_text and "РАСПИСАНИЕ ОБУЧЕНИЯ" in workspace_text,"UI T04 workspace separates library from schedule")
	check("Вместе" not in workspace_text and "По группам" not in workspace_text and "Курс" not in workspace_text,"UI T04 exposes no schedule or launch-mode settings")
	game.office._training_library_click({"record_id":2101},false,false)
	game.office._training_library_click({"record_id":2103},true,false)
	check(game.office.training_library_selection==[2101,2103],"UI T04 Ctrl adds a non-adjacent masterclass to selection")
	game.office._training_library_click({"record_id":2101},false,false)
	game.office._training_library_click({"record_id":2103},false,true)
	check(game.office.training_library_selection==[2101,2102,2103],"UI T04 Shift selects the contiguous masterclass range")
	game.office.training_add_selected_to_draft()
	check(game.office.course_editor.records==[2101,2102,2103],"UI T04 multi-selection becomes one ordered schedule draft")
	game.office._training_drop({"kind":"queue_lessons","course_id":0,"indices":[2]},{"zone":"draft","course_id":0,"index":0},false)
	check(game.office.course_editor.records==[2103,2101,2102],"UI T04 drag can reorder dishes before scheduling")
	game.office._training_drop({"kind":"queue_lessons","course_id":0,"indices":[0]},{"zone":"draft","course_id":0,"index":2},true)
	check(game.office.course_editor.records==[2101,2102,2103],"UI T04 drag can restore dish order")
	var preview: Dictionary=service.training_course_preview(game.office._draft_assignments(),"balanced",[])
	check(str(preview.error).is_empty() and int(preview.places)==2 and preview.lessons.size()==3 and preview.batches.size()==6,"UI T04 preview uses automatic one-table batches for two selected tables")
	check(press(game.office,"Добавить в расписание"),"UI T04 schedule button exists")
	await process_frame
	var views: Array=service.training_course_views()
	check(views.size()==1 and views[0].assignments.size()==3 and str(views[0].mode)=="balanced","UI T04 creates one internal balanced schedule block")
	check(views[0].batches.size()==6 and views[0].batches.all(func(batch):return batch.stations.size()<=1),"UI T04 actual queue follows the fixed twenty-percent batching")
	var schedule_id:=int(views[0].id)
	check(await run_until(service,func():return str(service.training_queue._course(schedule_id).get("state",""))=="completed"),"UI T04 scheduled dishes complete")
	dispose(game)

	print("UI T05: automatic batch size is rounded by table count")
	game=await make_game()
	service=game.service
	var ids: Array=[]
	var first_station: Node3D
	for slot in range(1,9):
		var created=add_counter(service,slot)
		if first_station==null: first_station=created
		ids.append(created.station_id)
	potato=record_for(first_station,2201,"potato","UI · двадцать процентов")
	service.masterclasses=[potato]
	game.office.open("groups")
	game.office.select_group_stations(ids)
	check(press(game.office,"Обучение"),"UI T05 opens training workspace")
	game.office.course_editor_add_record(2201)
	preview=service.training_course_preview(game.office._draft_assignments(),"balanced",[])
	check(str(preview.error).is_empty() and preview.batches.size()==4 and preview.batches.all(func(batch):return batch.stations.size()==2),"UI T05 eight tables become four two-table training batches")
	check("автоматически по 2 за раз" in tree_text(game.office.content),"UI T05 explains the automatic table batch size")
	check(press(game.office,"Добавить в расписание"),"UI T05 adds the dish to the schedule")
	await process_frame
	views=service.training_course_views()
	check(views.size()==1 and str(views[0].mode)=="balanced" and views[0].batches.size()==4,"UI T05 backend stores four balanced batches")
	service.advance(0.1)
	await process_frame
	var first_batch: Dictionary=views[0].batches[0]
	check(first_batch.stations.size()==2 and service.by_id(int(ids[2])).group_training_state.is_empty(),"UI T05 only the first twenty-percent table batch leaves production")
	dispose(game)

	print("UI T13: replace a waiting record by editing the queued schedule")
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
	check(press(game.office,"Добавить в расписание"),"UI T13 queues old version")
	await process_frame
	service.training_queue.advance(0.0)
	views=service.training_course_views()
	schedule_id=int(views[0].id)
	check(str(views[0].state)=="blocked","UI T13 waiting schedule is visible as blocked")
	game.office.rebuild()
	check("Курс" not in tree_text(game.office.content),"UI T13 waiting queue stays flat and exposes no schedule wrapper")
	game.office._training_drop({"kind":"masterclass_records","record_ids":[2302,2303]},{"zone":"course","course_id":schedule_id,"index":0},false)
	await process_frame
	var edited_view: Dictionary=service.training_queue.course_view(schedule_id)
	check(edited_view.assignments.size()==2 and int(edited_view.assignments[0].record_id)==2302 and int(edited_view.assignments[1].record_id)==2303,"UI T13 dropping records replaces the dish version and inserts another dish directly into the schedule")
	game.office._training_drop({"kind":"queue_lessons","course_id":schedule_id,"indices":[1]},{"zone":"course","course_id":schedule_id,"index":0},false)
	await process_frame
	edited_view=service.training_queue.course_view(schedule_id)
	check(int(edited_view.assignments[0].record_id)==2303 and int(edited_view.assignments[1].record_id)==2302,"UI T13 drag reorders existing schedule rows")
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
	check(press(game.office,"Добавить в расписание"),"UI T13 active queues old film")
	await process_frame
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==2311),"UI T13 active old film starts")
	game.office.course_editor_open(2312)
	game.office.course_editor_select_group(service.group_id_for_station(2),true)
	check(press(game.office,"Добавить в расписание"),"UI T13 active queues the newer version while old film is running")
	await process_frame
	check(int(service.desired_source(service.group_id_for_station(2),"potato").get("id",0))==2312,"UI T13 active updates the desired version while the old frozen film remains current")
	var live_views: Array=service.training_course_views()
	check(live_views.any(func(view):return view.assignments.any(func(item):return int(item.record_id)==2312)),"UI T13 active keeps the newer UI-created assignment in the queue")
	check(await run_until(service,func():return int(station.method_sources.get("potato",{}).get("id",0))==2311 and not service.staff_training.is_active(),60.0),"UI T13 active old film commits old knowledge first")
	check(int(service.training_queue.pending_source(2,"potato").get("id",0))==2312,"UI T13 active still requires the newer version after old film completion")
	check(await run_until(service,func():return int(station.method_sources.get("potato",{}).get("id",0))==2312,90.0),"UI T13 active eventually retrains through the UI-created follow-up schedule")
	dispose(game)

	print("UI T12: cancel an active schedule and resume its suspended plan from the queue page")
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
	check(press(game.office,"Добавить в расписание"),"UI T12 queues schedule")
	await process_frame
	check(await run_until(service,func():return service.staff_training.phase=="watching" and service.staff_training.record_id==2402),"UI T12 reaches second film")
	game.office.open("groups")
	check(press(game.office,"Очередь обучения"),"UI T12 opens queue workspace without preselecting tables")
	check(press(game.office,"Отменить текущее обучение"),"UI T12 cancellation button is available")
	check(await run_until(service,func():return not service.staff_training.is_active(),60.0),"UI T12 workers return after UI cancellation")
	check(int(station.method_sources.get("sausage",{}).get("id",0))==2401 and int(station.method_sources.get("potato",{}).get("id",0))==2400,"UI T12 completed first lesson stays learned and interrupted second stays old")
	game.office.rebuild()
	check(press(game.office,"Продолжить"),"UI T12 exposes resume button for the suspended desired assignment")
	await process_frame
	check(int(service.training_queue.pending_source(2,"potato").get("id",0))==2402,"UI T12 resume creates the required pending lesson")
	dispose(game)

	print("UI draft: host rejection keeps the schedule draft and explains why")
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
	check(press(game.office,"Добавить в расписание"),"UI draft submit button exists while away from computer")
	check(not game.office.course_editor.is_empty() and game.office.course_editor.records==[2491],"UI draft survives a rejected host confirmation")
	check(game.office.course_editor_message.contains("Подойди к компьютеру"),"UI draft shows the concrete host rejection reason")
	game.player.global_position=game.shop.computer.global_position
	check(press(game.office,"Добавить в расписание"),"UI draft can be confirmed after returning to the computer")
	await process_frame
	check(service.training_course_views().size()==1,"UI draft successful retry creates exactly one schedule")
	dispose(game)

	print("UI video entry: Add to schedule opens the same editor")
	game=await make_game()
	service=game.service
	station=add_counter(service,1)
	wine=record_for(station,2501,"wine","UI · из видеотеки")
	service.masterclasses=[wine]
	game.office.open("videos")
	check(press(game.office,"Добавить в обучение"),"Videotheque has Add to schedule")
	check(game.office.tab=="groups" and game.office.groups_mode=="training" and game.office.course_editor.records==[2501] and str(game.office.course_editor.type_id)=="counter","Videotheque opens the training workspace with the record prefilled")
	dispose(game)

	print("PASS: player-facing flat training schedule UI" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
