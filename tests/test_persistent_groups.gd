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

func record_for(station: Node3D,id: int,dish: String,name: String)->Dictionary:
	station.model.reset(dish)
	var frames: Array=repeated(station.model.snapshot(),60)
	return Library.make_record(id,dish,station.type_id,[{"group":1,"frames":frames}],1.0,station.model.quality(),name)

func teach_actual(station: Node3D,record: Dictionary)->void:
	station.recipes[str(record.dish)]={"tracks":record.tracks.duplicate(true),"duration":record.duration,"quality":record.quality.duplicate(true)}
	station.method_sources[str(record.dish)]={"id":int(record.id),"name":str(record.name)}

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
	var p=service.progress
	p.stars=2
	p.shift="open"
	service.open_for_business=false
	if "television" not in p.lounge_items: p.lounge_items.append("television")

	var tables: Array=[]
	for slot in range(1,6):
		var station=service.add_station("counter",slot,false)
		station.staffed=1
		station.equipment=["jug","cup","plates","pan","sauce","rag"]
		station.apply_equipment()
		tables.append(station)
	var wine:=record_for(tables[0],800,"wine","Одинаковый бокал")
	var potato_old:=record_for(tables[0],900,"potato","Старая картошка")
	var potato_new:=record_for(tables[0],901,"potato","Новая картошка")
	var sausage:=record_for(tables[0],910,"sausage","Сосиска линии")
	service.masterclasses=[wine,potato_old,potato_new,sausage]
	service.next_masterclass_id=911
	for station in tables:
		teach_actual(station,wine)
		teach_actual(station,potato_old)
		teach_actual(station,sausage)

	print("T01: explicit groups stay separate despite identical type, recipes and plans")
	check(service.create_table_group([2,3],"Левая линия").is_empty(),"First explicit group can be created")
	check(service.create_table_group([4,5],"Правая линия").is_empty(),"Second explicit group can be created")
	var left:=group_with(service,[2,3])
	var right:=group_with(service,[4,5])
	check(not left.is_empty() and not right.is_empty() and left.id!=right.id,"Two organizational groups have different permanent IDs")
	var left_id: String=str(left.id)
	var right_id: String=str(right.id)
	check(service._apply_group_plan(800,[2,3]).size()==1 and service._apply_group_plan(800,[4,5]).size()==1,"Both groups can receive the identical desired record")
	check(service._apply_group_plan(900,[2,3]).size()==1 and service._apply_group_plan(900,[4,5]).size()==1,"Both groups can receive the same second record")
	left=service.table_group_by_id(left_id)
	right=service.table_group_by_id(right_id)
	check(left.stations==[2,3] and right.stations==[4,5],"Identical plans do not auto-merge explicit groups")
	check(service.rename_table_group(left_id,"Левая линия · имя игрока").is_empty(),"Group can be renamed")
	check(service.set_table_group_members(left_id,[2,3,6]).is_empty(),"A compatible table can be added to an existing group")
	left=service.table_group_by_id(left_id)
	right=service.table_group_by_id(right_id)
	check(left.name=="Левая линия · имя игрока" and left.stations==[2,3,6],"Adding a member preserves group ID and custom name")
	check(right.id==right_id and right.name=="Правая линия","Unrelated identical group keeps its own identity")
	var saved_t01: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(saved_t01.version==20 and saved_t01.table_group_registry.groups.size()>=2,"v20 stores explicit group registry")
	check(service.load_data(saved_t01),"v20 persistent groups reload")
	left=service.table_group_by_id(left_id)
	right=service.table_group_by_id(right_id)
	check(left.name=="Левая линия · имя игрока" and left.stations==[2,3,6],"T01 reload preserves first group identity and membership")
	check(right.name=="Правая линия" and right.stations==[4,5],"T01 reload preserves second identical group separately")

	print("T02: partial plan change previews and creates a new group while inherited dishes remain")
	check(service.create_table_group([2,3,4,5],"Общая линия").is_empty(),"Four-table group can be formed explicitly")
	var four:=group_with(service,[2,3,4,5])
	check(not four.is_empty(),"Four-table group exists")
	var four_id: String=str(four.id)
	check(service.set_group_dish_active(four_id,"wine",true).is_empty() and service.set_group_dish_active(four_id,"potato",true).is_empty(),"Existing learned dishes are explicitly active for the production scenario")
	check(service._apply_group_plan(800,[2,3,4,5]).size()==1 and service._apply_group_plan(900,[2,3,4,5]).size()==1,"Four-table group has two desired dishes")
	var preview: Array=service.preview_table_groups(901,[2])
	var preview_source: Dictionary={}
	var preview_new: Dictionary={}
	for group in preview:
		if str(group.id)==four_id: preview_source=group
		elif group.stations==[2]: preview_new=group
	check(preview_source.stations==[3,4,5] and preview_source.name=="Общая линия","Preview keeps source ID/name and three untouched tables")
	check(not preview_new.is_empty() and preview_new.name=="Общая линия · 2","Preview proposes a distinct inherited subgroup for the one changed table")
	var preview_wine: Array=preview_new.curriculum.filter(func(item):return str(item.dish_id)=="wine")
	check(preview_wine.size()==1 and int(preview_wine[0].record_id)==800,"Preview subgroup inherits other dish assignment")
	check(service._apply_group_plan(901,[2]).size()==1,"Partial plan change applies")
	var source_after: Dictionary=service.table_group_by_id(four_id)
	var split_after: Dictionary=group_with(service,[2])
	check(source_after.stations==[3,4,5] and source_after.name=="Общая линия","Source group keeps its permanent identity after split")
	check(not split_after.is_empty() and split_after.id!=four_id,"Selected table receives a new permanent group ID")
	check(int(service.desired_source(split_after.id,"wine").id)==800 and int(service.desired_source(split_after.id,"potato").id)==901,"New group inherits wine and changes only potato")
	check(service.by_id(2).recipes.has("potato") and int(service.by_id(2).method_sources.potato.id)==900,"Changing desired plan leaves old learned potato working")
	check(service.station_group_status(2,"potato").contains("старому"),"Card distinguishes existing method from desired retraining")

	print("T03: merging different plans resolves conflicts without replacing actual knowledge early")
	var merge_preview: Dictionary=service.preview_group_merge([four_id,str(split_after.id)])
	check(not merge_preview.is_empty() and merge_preview.differences.has("potato"),"Merge preview exposes differing potato assignments")
	check(service.merge_table_groups([four_id,str(split_after.id)],{"wine":800,"potato":901},["wine","potato"]).is_empty(),"Player-selected final assignments merge the groups")
	var merged: Dictionary=service.table_group_by_id(four_id)
	check(merged.stations==[2,3,4,5] and merged.name=="Общая линия","First selected group keeps permanent ID/name after merge")
	check(service.table_group_by_id(str(split_after.id)).is_empty(),"Merged organizational record is removed")
	check(int(service.desired_source(four_id,"potato").id)==901,"Merged group uses the chosen desired potato record")
	for id in [2,3,4,5]:
		check(int(service.by_id(id).method_sources.potato.id)==900 and service.by_id(id).recipes.has("potato"),"Table %d keeps old production knowledge until retraining"%id)
	check(service.station_group_status(3,"potato").contains("старому"),"Differing tables are visibly awaiting retraining rather than losing production")

	print("T18: disabling a dish blocks only future assignments and reports the exact reason")
	check(service.set_group_dish_active(four_id,"sausage",true).is_empty(),"Sausage is active before accepting the order")
	check(service.spawn_customer("sausage",false,false,{},1),"An active learned dish receives a new order")
	var accepted: Dictionary={}
	for customer in service.customers:
		if str(customer.dish)=="sausage" and customer.state!="leaving": accepted=customer; break
	check(not accepted.is_empty(),"Accepted sausage customer exists")
	var accepted_station: int=int(accepted.station)
	check(service.set_group_dish_active(four_id,"sausage",false).is_empty(),"Dish can be disabled while its accepted order exists")
	var station=service.by_id(accepted_station)
	accepted.path.clear()
	accepted.view.global_position=station.to_global(Vector3(0,0,-1.85))
	service.advance(0.02)
	check(accepted.state=="cooking" and station.order_dish=="sausage","Already accepted order continues after menu toggle")
	var before_menu_losses: int=int(service.analytics.losses.get("menu_off",0))
	check(not service.spawn_customer("sausage",false,false,{},1),"A new guest is not assigned when all compatible groups disable the dish")
	check(int(service.analytics.losses.get("menu_off",0))==before_menu_losses+1,"Statistics use the exact «Блюдо выключено в меню» reason")
	check(InsightsLabel(),"Reason label is human-readable")
	check(service.by_id(accepted_station).recipes.has("sausage"),"Disabling menu never deletes learned recipe")

	print("T23 migration part: v19 derived groups and method_plan become persistent groups once")
	service.by_id(6).method_sources.potato={"id":901,"name":"Новая картошка"}
	var legacy: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	legacy.version=19
	legacy.erase("table_group_registry")
	for entry in legacy.stations:
		entry.erase("active_dishes")
		entry.erase("active_menu_initialized")
	legacy.table_group_names={"2-3-4-5":"Старая линия игрока"}
	# Make the four migrated counters identical by actual learned sources, as v19 grouping did.
	check(service.load_data(legacy),"v19 developed cafe migrates")
	var migrated: Dictionary=service.table_group_by_id("2-3-4-5")
	check(not migrated.is_empty() and migrated.name=="Старая линия игрока","Migration preserves old displayed group ID and custom name")
	check(int(service.desired_source("2-3-4-5","potato").id)==901,"Legacy method_plan becomes explicit desired curriculum")
	check(service.by_id(2).recipes.has("potato") and int(service.by_id(2).method_sources.potato.id)==900,"Migration preserves actual learned recipe and source separately")
	check(service.by_id(2).active_menu_initialized and "potato" in service.by_id(2).active_dishes,"Migration initializes explicit active menu from prior working behavior")
	var migrated_save: Dictionary=service.save_data()
	check(migrated_save.version==20 and migrated_save.table_group_registry.groups.has("2-3-4-5"),"Migrated cafe subsequently saves only the persistent v20 group identity")

	game._shutdown_tree(game)
	game.free()
	print("PASS: T01-T03 T18 and T23 migration — persistent groups, explicit plans, active menu and learned-method separation" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)

func InsightsLabel()->bool:
	return preload("res://scripts/cafe_insights.gd").reason_label("menu_off")=="Блюдо выключено в меню"
