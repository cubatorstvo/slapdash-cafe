extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Library=preload("res://scripts/masterclass_library.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func repeated(value: Dictionary,count: int)->Array:
	var result: Array=[]
	for i in range(count): result.append(value.duplicate(true))
	return result

func record_for(station: Node3D,id: int,dish: String,name: String,seconds := 1.0)->Dictionary:
	station.model.reset(dish)
	var frames: Array=repeated(station.model.snapshot(),roundi(seconds*60.0))
	return Library.make_record(id,dish,station.type_id,[{"group":1,"frames":frames}],seconds,station.model.quality(),name)

func advance_until(service: Node3D,target: String,limit := 160)->void:
	for i in range(limit):
		if not service.staff_training.is_active() or service.staff_training.phase==target: return
		service.advance(0.25)

func finish_session(service: Node3D,limit := 240)->void:
	for i in range(limit):
		if not service.staff_training.is_active(): return
		service.advance(0.25)

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
	p.stars=1
	p.shift="morning"
	if "television" not in p.lounge_items: p.lounge_items.append("television")
	game.annex.refresh_shell()
	await process_frame

	var first=service.add_station("counter",1,false)
	var second=service.add_station("counter",2,false)
	for station in [first,second]:
		station.staffed=1
		station.equipment=["jug","cup","plates","pan","sauce","rag"]
		station.apply_equipment()

	var wine:=record_for(first,800,"wine","Старый бокал")
	var potato:=record_for(first,900,"potato","Картошка шефа")
	service.masterclasses=[wine,potato]
	service.next_masterclass_id=901
	for station in [first,second]:
		station.recipes.wine={"tracks":wine.tracks.duplicate(true),"duration":wine.duration,"quality":wine.quality.duplicate(true)}
		station.method_sources.wine={"id":800,"name":"Старый бокал"}

	print("1/7: compatible tables form a readable group and partial selection previews a split")
	var groups: Array=service.table_groups()
	var counter_group: Dictionary={}
	for group in groups:
		if group.stations==[2,3]: counter_group=group
	check(not counter_group.is_empty(),"Two compatible counters with identical assignments appear in one group")
	var preview: Array=service.preview_table_groups(900,[2])
	var preview_sets: Array=[]
	for group in preview: preview_sets.append(group.stations)
	check([2] in preview_sets and [3] in preview_sets,"Selecting part of a group previews two resulting groups")
	check(service.source_label(2,"wine")=="Старый бокал","Other-dish assignment remains visible in the group")

	print("2/7: assigned crew finishes its current order before leaving")
	first.state="cooking"
	first.order_dish="wine"
	check(service.start_group_training(900,[2]).is_empty(),"One selected table accepts the lesson")
	check(not first.ready_crew() and second.ready_crew(),"Only selected table stops accepting new orders")
	check(service.station_group_status(2,"potato")=="назначено","Assignment status is visible immediately")
	service.staff_training.advance(0.01)
	check(service.staff_training.phase=="gathering" and service.station_group_status(2,"potato")=="собираются","Assigned crew enters gathering state")
	service.staff_training.advance(0.5)
	check(service.staff_training.phase=="gathering","Crew remains at a busy table until its order is done")
	first.state="idle"
	first.order_dish=""
	service.staff_training.advance(0.01)
	check(service.staff_training.phase=="walking" and service.staff_training.actors.size()==1,"Finished crew leaves for the television with one visible worker")
	var worker=service.staff_training.actors.values()[0]
	check(worker.notebook.visible,"Worker carries the notebook to training")

	print("3/7: employees watch the same 30-percent film regardless of selected group size")
	advance_until(service,"watching")
	check(service.staff_training.phase=="watching","Worker reaches the television")
	check(service.station_group_status(2,"potato")=="смотрят","Group status reports watching")
	check(is_equal_approx(float(service.movie_state.duration),float(potato.highlight_duration)) and is_equal_approx(float(service.movie_state.duration),0.3),"Single-table lesson uses exactly 30% of the original one-second method")
	finish_session(service)
	check(not service.staff_training.is_active(),"Worker returns after the film")
	check(first.recipes.has("potato") and first.method_sources.potato.id==900,"Selected table learns the full accepted method")
	check(var_to_bytes(first.recipes.potato.tracks)==var_to_bytes(potato.tracks),"Learned production recipe keeps the complete source tracks")
	check(first.method_sources.wine.id==800 and first.recipes.has("wine"),"Learning potato preserves the wine assignment")
	check(not second.recipes.has("potato"),"Unselected table keeps its previous method set")

	check(service.start_group_training(900,[2,3]).is_empty(),"Both compatible tables can be selected together")
	service.staff_training.advance(0.01)
	service.staff_training.advance(0.01)
	advance_until(service,"watching")
	check(service.staff_training.actors.size()==2,"Both crews attend one shared viewing")
	check(is_equal_approx(float(service.movie_state.duration),0.3),"Two-table lesson still takes exactly 30% of source time")
	finish_session(service)
	check(second.recipes.has("potato") and second.method_sources.potato.id==900,"Second table learns after the shared viewing")

	print("4/7: cross-group assignment recomposes groups while preserving other dishes")
	groups=service.table_groups()
	counter_group={}
	for group in groups:
		if group.stations==[2,3]: counter_group=group
	check(not counter_group.is_empty(),"Tables merge into one group again when their full assignment maps match")
	check(service.source_label(2,"wine")=="Старый бокал" and service.source_label(2,"potato")=="Картошка шефа","Group table keeps independent dish-to-record mappings")

	print("5/7: groups can be renamed and deleted films remain learned")
	check(service.rename_table_group(str(counter_group.id),"Картофельная линия").is_empty(),"Current group can be renamed")
	check(service.table_group_by_id(str(counter_group.id)).name=="Картофельная линия","Custom group name is immediately visible")
	check(service.delete_masterclass(900).is_empty(),"Film can be removed from the videotheque after training")
	check(first.recipes.has("potato") and second.recipes.has("potato"),"Deleting the film keeps learned production methods")
	check(service.source_label(2,"potato").contains("Запись удалена"),"Group clearly marks a missing source film")

	print("6/7: equipment and vacancies are explicit readiness states")
	second.equipment.erase("pan")
	check(service.station_group_status(3,"potato")=="требуется оборудование","Missing equipment is shown in group readiness")
	second.equipment.append("pan")
	second.staffed=0
	check(service.station_group_status(3,"potato")=="требуются работники","Vacancy is shown in group readiness")
	second.staffed=1

	print("7/7: v17 persists group names, learned source links and working recipes")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(saved.version==17 and saved.table_group_names.get(str(counter_group.id),"")=="Картофельная линия","Current save writes group metadata in v17")
	check(service.load_data(saved),"v17 cafe reloads")
	check(service.by_id(2).recipes.has("potato") and service.by_id(2).method_sources.potato.id==900,"Reload preserves learned full method and deleted source id")
	check(service.table_group_by_id("2-3").name=="Картофельная линия","Reload preserves group name")
	check(service.source_label(2,"potato").contains("Запись удалена"),"Deleted-film marker survives reload")

	game._shutdown_tree(game)
	game.free()
	print("PASS: table groups, partial selection, TV staff training and learned-method persistence" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
