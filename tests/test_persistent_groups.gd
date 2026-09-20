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

func group_with(service: Node3D,ids: Array)->Dictionary:
	for group in service.table_groups():
		if group.stations==ids: return group
	return {}

func _initialize()->void:
	run.call_deferred()

func run()->void:
	var game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var service=game.service
	service.progress.stars=2
	service.progress.shift="open"
	service.open_for_business=false
	var tables: Array=[]
	for slot in range(1,6):
		var station=service.add_station("counter",slot,false)
		station.staffed=1
		station.equipment=["jug","cup","plates","pan","sauce","rag"]
		station.apply_equipment()
		tables.append(station)
	var wine:=record_for(tables[0],800,"wine","Бокал")
	var potato_a:=record_for(tables[0],900,"potato","Картошка A")
	var potato_b:=record_for(tables[0],901,"potato","Картошка B")
	service.masterclasses=[wine,potato_a,potato_b]

	print("G01: groups exist only after explicit player action")
	check(service.table_groups().is_empty(),"Fresh production tables have no singleton groups")
	check(service.create_table_group([2,3],"Левая").is_empty(),"First manual group is created")
	check(service.create_table_group([4,5],"Правая").is_empty(),"Second manual group is created")
	var left:=group_with(service,[2,3])
	var right:=group_with(service,[4,5])
	check(not left.is_empty() and not right.is_empty() and left.id!=right.id,"Explicit groups keep separate IDs")
	var left_id:=str(left.id)
	var right_id:=str(right.id)
	check(service.rename_table_group(left_id,"Левая игрока").is_empty(),"Manual group can be renamed")

	print("G02: regrouping selected groups dissolves them into the new group")
	check(service._apply_group_plan(800,[2,3]).size()==2,"Training intent is assigned directly to both tables")
	check(service._apply_group_plan(900,[4,5]).size()==2,"Other tables can have a different direct intent")
	check(service.create_table_group([2,3,4,5],"Общая").is_empty(),"Selecting tables from existing groups creates one new group")
	check(service.table_group_by_id(left_id).is_empty() and service.table_group_by_id(right_id).is_empty(),"Source groups disappear automatically during explicit regrouping")
	var combined:=group_with(service,[2,3,4,5])
	check(not combined.is_empty() and combined.name=="Общая","New combined group owns all selected tables")
	var combined_id:=str(combined.id)
	check(int(service.by_id(2).method_plan.wine.id)==800 and int(service.by_id(4).method_plan.potato.id)==900,"Regrouping does not rewrite per-table training intent")
	check(service.training_course_views().is_empty(),"Grouping itself never schedules training")

	print("G03: training a subset never mutates group structure")
	check(service._apply_group_plan(901,[2]).size()==1,"One selected table can receive a new desired record")
	check(service.table_group_by_id(combined_id).stations==[2,3,4,5],"Per-table training does not split its organizational group")
	check(int(service.by_id(2).method_plan.potato.id)==901 and not service.by_id(3).method_plan.has("potato"),"Only the explicitly targeted table changes")

	print("G04: dissolve leaves standalone tables and preserves state")
	service.set_group_dish_active(combined_id,"wine",true)
	check(service.dissolve_table_groups([combined_id]).is_empty(),"Explicit group dissolves")
	check(service.table_groups().is_empty(),"Dissolve creates no singleton replacement groups")
	check(service.group_id_for_station(2).is_empty() and service.group_id_for_station(5).is_empty(),"Former members are standalone")
	check(service.by_id(2).dish_active("wine") and int(service.by_id(2).method_plan.wine.id)==800,"Menu and training intent survive dissolve")
	var saved:=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(saved),"Current save reloads")
	check(service.table_groups().is_empty(),"Reload does not synthesize groups")

	print("G05: old saves no longer auto-migrate inferred groups")
	var legacy:=bytes_to_var(var_to_bytes(service.save_data()))
	legacy.version=19
	legacy.erase("table_group_registry")
	legacy.table_group_names={"2-3":"Старая авто-группа"}
	for entry in legacy.stations:
		entry.erase("active_dishes")
		entry.erase("active_menu_initialized")
	check(service.load_data(legacy),"Legacy save still loads")
	check(service.table_groups().is_empty(),"Legacy data is not converted into automatic groups")

	game._shutdown_tree(game)
	game.free()
	print("PASS: groups are explicit and independent from training" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
