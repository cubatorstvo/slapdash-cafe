extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Insights=preload("res://scripts/cafe_insights.gd")
const Journey=preload("res://scripts/cafe_journey.gd")
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
	var result: Array=[]
	for i in range(count): result.append(value.duplicate(true))
	return result

func sausage_recipe(station: Node3D)->Dictionary:
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

func prepare_counter(station: Node3D,recipe: Dictionary,record_id := 700)->void:
	station.staffed=1
	station.equipment=["rag","plates","sauce"]
	station.apply_equipment()
	station.recipes.sausage=recipe.duplicate(true)
	station.method_sources.sausage={"id":record_id,"name":"Сетевая сосиска"}

func fake_customer()->Dictionary:
	return {"dish":"sausage","portions_total":1,"portions_done":0,"stats_finalized":false}

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
	service.open_for_business=false
	p.stars=1
	p.shift="open"
	p.cash=500

	var first=service.add_station("counter",1,false,true)
	var second=service.add_station("counter",2,false,true)
	var recipe: Dictionary=sausage_recipe(first)
	prepare_counter(first,recipe)
	prepare_counter(second,recipe)
	var record: Dictionary=Library.make_record(700,"sausage","counter",recipe.tracks.duplicate(true),1.0,recipe.quality.duplicate(true),"Сетевая сосиска")
	service.masterclasses=[record]
	service.next_masterclass_id=701
	check(service.create_table_group([2,3],"Сервисная линия").is_empty(),"Two counters form an explicit service group")
	check(service._apply_group_plan(700,[2,3]).size()==1,"Explicit service group receives its desired sausage record")
	check(service.set_group_dish_active(service.group_id_for_station(2),"sausage",true).is_empty(),"Service group has sausage explicitly enabled for diagnostics")
	var service_group: Dictionary=service.table_groups().filter(func(value):return value.stations==[2,3])[0]
	var service_group_id: String=str(service_group.id)

	print("1/9: repeated same-dish losses merge by reason and retain drill-down context")
	first.state="cooking"; first.customer_id=501
	second.state="cooking"; second.customer_id=502
	for i in range(4): service._record_failed_order(fake_customer(),"busy")
	check(int(service.analytics.losses.get("busy",0))==4,"Busy losses count four cases")
	check(service.analytics.feed.size()==1 and int(service.analytics.feed[0].count)==4,"Four matching departures merge into one feed event")
	check("4 гостя ушли" in service.feed_text(service.analytics.feed[0]) and "заняты" in service.feed_text(service.analytics.feed[0]),"Merged event shows correct count and reason")
	var busy_detail: Dictionary=service.analytics.loss_details.values()[0]
	check(str(busy_detail.group)==service_group_id and busy_detail.stations==[2,3],"Loss drill-down links the dish to its persistent group and tables")

	print("2/9: service diagnostics distinguish concrete operational causes")
	first.state="idle"; first.customer_id=-1
	second.state="idle"; second.customer_id=-1
	first.recipes.erase("sausage"); second.recipes.erase("sausage")
	check(str(service.problem_context("sausage").reason)=="unlearned","Unlearned dish is distinguished even when equipment is incomplete")
	prepare_counter(first,recipe); prepare_counter(second,recipe)
	first.equipment=["rag","plates"]; second.equipment=["rag","plates"]
	first.apply_equipment(); second.apply_equipment()
	check(str(service.problem_context("sausage").reason)=="equipment","Missing equipment is distinguished only after the method is learned")
	first.equipment=["rag","plates","sauce"]; second.equipment=["rag","plates","sauce"]
	first.staffed=0; second.staffed=0
	check(str(service.problem_context("sausage").reason)=="workers","Missing workers are distinguished")
	first.staffed=1; second.staffed=1
	first.group_training_state="watching"
	check(str(service.problem_context("sausage").reason)=="training","Workers at training are distinguished")
	first.group_training_state=""
	check(str(service.problem_context("meal").reason)=="no_station","Missing suitable kitchen is distinguished")
	check(Insights.reason_label("chef_wait").contains("личный заказ") and Insights.reason_label("closing").contains("закрытии"),"Chef timeout and closing have explicit labels")

	print("3/9: station and group performance connect methods to real service outcomes")
	prepare_counter(first,recipe)
	prepare_counter(second,recipe)
	Insights.arrival(service.analytics,"sausage",3)
	for i in range(3): Insights.portion(service.analytics,"sausage",2,25)
	Insights.complete(service.analytics,"sausage",2)
	Insights.complete(service.analytics,"sausage",2)
	var group: Dictionary=service.table_group_by_id(service_group_id)
	var performance: Dictionary=service.group_performance(group)
	check(int(performance.orders_completed)==2 and int(performance.portions_served)==3 and int(performance.revenue)==75,"Group reports orders, portions and revenue")
	check(int(performance.losses)==4 and int(performance.loss_reasons.get("busy",0))==4,"Group reports its linked historical bottleneck")
	check(service.source_label(2,"sausage")=="Сетевая сосиска","Group can resolve the masterclass used by the dish")
	var bottleneck: Dictionary=service.top_bottleneck()
	check(str(bottleneck.reason)=="busy" and str(bottleneck.suggestion).contains("Добавь подходящие столы"),"Observed bottleneck produces a concrete recommendation")

	print("4/9: player and system entries are visibly distinct")
	service.feed_player(1,"masterclass",{"dish":"sausage"})
	service.feed_system("batch",{"stations":[7,8]},2)
	check(service.analytics.feed.any(func(entry):return str(entry.get("source",""))=="player"),"Player action is marked as player feed")
	check(service.analytics.feed.any(func(entry):return str(entry.get("source",""))=="system"),"System action is marked as system feed")

	print("5/10: after first star the guide walks through masterclass -> TV -> course -> real work -> mass mode")
	service.analytics=Insights.blank()
	service.training_queue.reset()
	service.masterclasses.clear()
	first.recipes.erase("sausage"); second.recipes.erase("sausage")
	first.method_sources.erase("sausage"); second.method_sources.erase("sausage")
	p.journey_auto_served=0
	p.training_intro_mass_seen=false
	p.lounge_items=["sofa"]
	var goal: Dictionary=Journey.current(p,service.stations,service.served,true,service)
	check(str(goal.key)=="training_intro_masterclass" and int(goal.station)==1 and str(goal.title).begins_with("1/5"),"Post-star onboarding starts with the chef masterclass")
	service.masterclasses=[record]
	goal=Journey.current(p,service.stations,service.served,true,service)
	check(str(goal.key)=="training_intro_tv" and str(goal.title).begins_with("2/5"),"Saved masterclass leads to preparing the lounge TV")
	p.lounge_items.append("television")
	goal=Journey.current(p,service.stations,service.served,true,service)
	check(str(goal.key)=="training_intro_course" and int(goal.station) in [2,3] and str(goal.title).begins_with("3/5"),"TV leads to building the first course from a production table")
	var intro_course: Dictionary=service.queue_training_course([{"record_id":700,"station_ids":[2]}],"together","intro-course",1)
	check(str(intro_course.get("error","")).is_empty(),"Intro course can be queued through the real controller")
	goal=Journey.current(p,service.stations,service.served,true,service)
	check(str(goal.key)=="training_intro_wait" and str(goal.title).begins_with("4/5"),"Queued course becomes a wait-for-completion onboarding goal")
	first.recipes.sausage=recipe.duplicate(true)
	first.method_sources.sausage={"id":700,"name":"Сетевая сосиска"}
	goal=Journey.current(p,service.stations,service.served,true,service)
	check(str(goal.key)=="training_intro_first_work" and int(goal.station)==2,"Learned course still requires seeing the trained station work")
	p.journey_auto_served=1
	goal=Journey.current(p,service.stations,service.served,true,service)
	check(str(goal.key)=="training_intro_mass" and str(goal.detail).contains("20%") and not str(goal.detail).contains("По группам"),"Second compatible table explains automatic twenty-percent table batches")
	game.office.open("groups")
	game.office.select_group_stations([2])
	game.office.course_editor_open()
	check(p.training_intro_mass_seen,"Opening the mass-capable course editor acknowledges the final onboarding step")
	game.office.close()

	print("6/9: approximately twenty-table cafe keeps grouping and mass selection readable")
	second.recipes.sausage=recipe.duplicate(true)
	second.method_sources.sausage={"id":700,"name":"Сетевая сосиска"}
	for slot_index in range(3,20):
		var station=service.add_station("counter",slot_index,false,true)
		prepare_counter(station,recipe)
	check(service.stations.size()==20,"Cafe contains one chef station and nineteen production tables")
	var scale_summary: Dictionary=service.production_scale_summary()
	check(int(scale_summary.max_places)==19 and int(scale_summary.places)==19 and int(scale_summary.workers)==19,"Scale summary reports nineteen production places and nineteen assigned workers, excluding chef station")
	var compatible: Array=service.compatible_training_station_ids(700)
	check(compatible.size()==19 and compatible.front()==2 and compatible.back()==20,"One masterclass can select all nineteen compatible production tables without auto-merging them")
	check(service._apply_group_plan(700,compatible).size()>=1,"All compatible source groups can first receive the same desired record")
	var prepared_group_ids: Array=[]
	for station_id in compatible:
		var prepared_group_id: String=service.group_id_for_station(int(station_id))
		if prepared_group_id not in prepared_group_ids:
			prepared_group_ids.append(prepared_group_id)
			check(service.set_group_dish_active(prepared_group_id,"sausage",true).is_empty(),"Source group keeps sausage active before explicit merge")
	check(service.create_table_group(compatible,"Массовая линия").is_empty(),"Player can explicitly combine nineteen tables once their plans and menu match")
	check(int(service.desired_source(service.group_id_for_station(2),"sausage").id)==700,"Large explicit group keeps the shared desired record")
	var groups: Array=service.table_groups()
	var large_group: Dictionary={}
	for value in groups:
		if value.stations.size()==19: large_group=value; break
	check(not large_group.is_empty(),"Twenty-table layout is manageable as one explicit group when the player chooses it")
	Insights.portion(service.analytics,"sausage",20,25)
	Insights.complete(service.analytics,"sausage",20)
	var large_performance: Dictionary=service.group_performance(large_group)
	check(int(large_performance.portions_served)>=1 and int(large_performance.revenue)>=25,"Large group performance remains readable")

	game.office.open("groups")
	game.office.select_group_stations(compatible)
	game.office.course_editor_open()
	var scale_rendered: String=tree_text(game.office.content)
	check("19/19 производственных мест" in scale_rendered and "работников 19" in scale_rendered,"Course editor reports honest production-place and worker counts at full scale")
	game.office.close()

	print("7/10: statistics and group UI render the same drill-down data")
	service.feed_system("batch",{"stations":[2,3]},2)
	game.refresh_hud()
	check(game.hud.event_feed_panel.visible and "СИСТЕМА:" in game.hud.event_feed_text.text,"Recent system events are visible in the in-game HUD feed")
	game.office.open("stats")
	var rendered: String=tree_text(game.office.content)
	check("ЛЕНТА И СТАТИСТИКА" in rendered and "[СИСТЕМА]" in rendered,"Statistics tab renders system feed")
	service.analytics.losses.busy=maxi(1,int(service.analytics.losses.get("busy",0)))
	game.office.set_stats_focus({"reason":"busy","dish":"sausage","stations":[2,3],"group":str(large_group.id)})
	rendered=tree_text(game.office.content)
	check("ПОДРОБНОСТИ" in rendered and "Сетевая сосиска" in rendered and "Столы: 2, 3" in rendered,"Event drill-down renders dish, tables and masterclass")
	var linked: Dictionary=service.queue_training_course([{"record_id":700,"station_ids":[2]}],"together","problem-link",1)
	check(str(linked.get("error","")).is_empty(),"Problem navigation fixture queues a concrete course")
	game.office.set_stats_focus({"reason":"training","dish":"sausage","stations":[2],"group":str(large_group.id)})
	rendered=tree_text(game.office.content)
	check("Открыть связанное обучение #" in rendered,"Problem card offers a direct link to the concrete pending training entry")
	game.office.open_problem_group([2],int(linked.get("course_id",0)))
	rendered=tree_text(game.office.content)
	check("→ " in rendered and "Сетевая сосиска" in rendered,"Problem link opens the flat schedule and highlights the linked training row")
	game.office.groups_mode="overview"
	game.office.group_expanded[str(large_group.id)]=true
	game.office.tab="groups"; game.office.stamp=""; game.office.rebuild()
	rendered=tree_text(game.office.content)
	check("МЕНЮ И СОСТОЯНИЕ ОБУЧЕНИЯ" in rendered and "Сетевая сосиска" in rendered,"Expanded group cards render desired masterclass and active-menu state beside service results")
	game.office.close()

	print("8/10: feed aggregation window separates later identical events")
	var before: int=service.analytics.feed.size()
	Insights.loss(service.analytics,"sausage","busy",1,0,[2,3],str(large_group.id))
	Insights.tick(service.analytics,Insights.FEED_WINDOW+0.1)
	Insights.loss(service.analytics,"sausage","busy",1,0,[2,3],str(large_group.id))
	check(service.analytics.feed.size()==before+2,"Same event outside the short aggregation window creates a new feed row")

	print("9/10: v22 persists analytics and v18 migrates cleanly")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(saved.version==22 and saved.analytics.get("feed",[]).size()>0,"Current v22 save writes analytics with persistent groups")
	var feed_size: int=saved.analytics.feed.size()
	check(service.load_data(saved),"v22 cafe reloads")
	check(service.analytics.feed.size()==feed_size and int(service.analytics.losses.get("busy",0))>=2,"v22 reload preserves feed and loss totals")
	var legacy: Dictionary=bytes_to_var(var_to_bytes(saved))
	legacy.version=18
	legacy.erase("analytics")
	check(service.load_data(legacy),"v18 cafe remains loadable")
	check(service.analytics.feed.is_empty() and service.save_data().version==22,"v18 migrates with blank historical analytics and writes v22")

	print("10/10: completion percentages preserve absolute and relative meaning")
	check(is_equal_approx(Insights.completion_percent(180,200),90.0),"180 of 200 renders as 90 percent")
	check(is_equal_approx(Insights.completion_percent(0,0),0.0),"Empty cafe percentage is safe")

	game._shutdown_tree(game)
	game.free()
	print("PASS: stage-8 onboarding, actionable feed drill-down, honest nineteen-place scale and v22 analytics" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
