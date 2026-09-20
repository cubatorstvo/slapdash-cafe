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

func record_for(station: Node3D,id: int,dish: String,name: String,frames_count:=120)->Dictionary:
	station.model.reset(dish)
	var frames:=repeated(station.model.snapshot(),frames_count)
	return Library.make_record(id,dish,station.type_id,[{"group":1,"frames":frames}],float(frames_count)/60.0,station.model.quality(),name)

func prepare(station: Node3D)->void:
	station.staffed=station.role_count()
	station.equipment=["jug","cup","plates","pan","sauce","rag","meat_kit","pasta_kit","grill_kit","assembly_kit","fire_kit","stir_kit","salt_kit"]
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

func add_station(service: Node3D,type_id: String,slot: int)->Node3D:
	var station=service.add_station(type_id,slot,false)
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
	if target==null or target.disabled:
		printerr("Missing or disabled UI button: ",prefix)
		return false
	target.emit_signal("pressed")
	return true

func dispose(game)->void:
	game.office.close()
	game._shutdown_tree(game)
	game.free()

func _initialize()->void:
	run.call_deferred()

func run()->void:
	var game=await make_game()
	var service=game.service
	var a=add_station(service,"counter",1)
	var b=add_station(service,"counter",2)
	var kitchen=add_station(service,"kitchen",3)
	var wine=record_for(a,2101,"wine","UI · напиток")
	var potato=record_for(a,2102,"potato","UI · картошка")
	var long_wine=record_for(a,2103,"wine","UI · длинная запись",2400)
	service.masterclasses=[wine,potato]

	print("UI T01: tables never auto-group and actions explain disabled state")
	check(service.table_groups().is_empty(),"New production tables stay ungrouped")
	game.office.open("groups")
	var overview:=tree_text(game.office.content)
	check("ОТДЕЛЬНЫЕ СТОЛЫ" in overview and "Стол 2" in overview and "Стол 3" in overview,"Ungrouped tables are visible in the list")
	game.office.select_group_stations([2])
	game.office.rebuild()
	var ungroup_button:=find_button(game.office.content,"Разгруппировать")
	check(ungroup_button!=null and ungroup_button.disabled and "нет группы" in ungroup_button.tooltip_text.to_lower(),"Ungroup button explains that only elements are selected")
	game.office.select_group_stations([2,4])
	game.office.rebuild()
	var train_button:=find_button(game.office.content,"Обучение")
	var group_button:=find_button(game.office.content,"Сгруппировать")
	check(train_button!=null and train_button.disabled and "одного типа" in train_button.tooltip_text.to_lower(),"Mixed table types disable training with a reason")
	check(group_button!=null and group_button.disabled and "одного типа" in group_button.tooltip_text.to_lower(),"Mixed table types disable grouping with a reason")

	print("UI T02: group and dissolve are the only structural operations")
	game.office.select_group_stations([2,3])
	check(press(game.office,"Сгруппировать"),"Two same-type tables can be grouped")
	await process_frame
	var groups: Array=service.table_groups()
	check(groups.size()==1 and groups[0].stations==[2,3],"Manual grouping creates one explicit group")
	var group_id:=str(groups[0].id)
	game.office.set_group_all_selected(group_id,true)
	game.office.rebuild()
	ungroup_button=find_button(game.office.content,"Разгруппировать")
	check(ungroup_button!=null and not ungroup_button.disabled,"Selecting a group enables dissolve")
	check(press(game.office,"Разгруппировать"),"Selected group can be dissolved")
	await process_frame
	check(service.table_groups().is_empty() and service.group_id_for_station(2).is_empty() and service.group_id_for_station(3).is_empty(),"Dissolve leaves standalone tables instead of singleton groups")

	print("UI T03: library drops directly into one flat queue")
	game.office.select_group_stations([2,3])
	check(press(game.office,"Обучение"),"Same-type selection opens training")
	var workspace:=tree_text(game.office.content)
	check("МАСТЕР-КЛАССЫ" in workspace and "ОЧЕРЕДЬ ОБУЧЕНИЯ" in workspace,"Training workspace has library and queue")
	check("РАСПИСАНИЕ" not in workspace and "По группам" not in workspace and "20%" not in workspace,"Old schedule and batching controls are gone")
	game.office._training_library_click({"record_id":2101},false,false)
	game.office._training_library_click({"record_id":2102},true,false)
	game.office.training_add_selected_to_draft()
	await process_frame
	var views: Array=service.training_course_views()
	check(views.size()==1 and views[0].assignments.size()==2 and str(views[0].mode)=="together","Direct add creates one together queue block")
	check(views[0].batches.size()==1 and views[0].batches[0].stations==[2,3],"All selected tables leave in one pass")
	game.office.rebuild()
	workspace=tree_text(game.office.content)
	check("Бокал вина, столы 2, 3" in workspace and "Жареный картофель, столы 2, 3" in workspace,"Queue rows show dish and tables")
	var course_id:=int(views[0].id)
	var row=game.office.training_queue_rows.get("%d:0"%course_id)
	check(row!=null and row.title_text=="Бокал вина, столы 2, 3" and row.subtitle_text.is_empty(),"Queue row itself contains only dish and tables")
	check(row!=null and bool(row.context_highlight),"Rows for the current table selection are outlined")
	game.office._training_drop({"kind":"queue_lessons","course_id":course_id,"indices":[1]},{"zone":"course","course_id":course_id,"index":0},false)
	await process_frame
	var edited: Dictionary=service.training_queue.course_view(course_id)
	check(int(edited.assignments[0].record_id)==2102 and int(edited.assignments[1].record_id)==2101,"Queue order changes directly by drag")

	print("UI T04: highlight duration is fixed and short recordings stay uncut")
	check(absf(float(wine.highlight_duration)-float(wine.duration))<0.01,"Short recording keeps its full duration")
	check(wine.highlight_segments.size()>=2,"Short recording still changes camera angles")
	check(absf(float(long_wine.highlight_duration)-Library.TRAINING_WATCH_SECONDS)<0.01,"Long recording produces exactly the global fixed highlight duration")
	var long_highlight_ticks:=0
	for segment in long_wine.highlight_segments:
		long_highlight_ticks+=int(segment.film_end)-int(segment.film_start)
	check(long_highlight_ticks==roundi(Library.TRAINING_WATCH_SECONDS*60.0),"Long highlight timeline contains exactly N seconds instead of 30 percent")
	var cursor:=0
	for segment in wine.highlight_segments:
		check(int(segment.source_start)==cursor,"Uncut short film has no source gap")
		cursor=int(segment.source_end)
	check(cursor==120,"Uncut short film reaches the final source frame")
	service.training_queue.reset()
	var queued: Dictionary=service.queue_training_course([{"record_id":2101,"station_ids":[2,3]}],"by_groups","ui-fixed-time",1)
	check(str(queued.error).is_empty(),"Legacy mode input is accepted but normalized")
	service.advance(0.1)
	await process_frame
	for i in range(300):
		service.advance(0.1)
		await process_frame
		if service.staff_training.phase=="watching": break
	check(service.staff_training.phase=="watching","Training reaches TV watching phase")
	check(absf(float(service.movie_state.duration)-Library.TRAINING_WATCH_SECONDS)<0.01 and bool(service.movie_state.loop),"Training watches for the global 30 seconds and loops a short film")

	dispose(game)
	print("PASS: manual groups and direct training queue UI" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
