extends SceneTree
var game: Node3D
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); print("FAIL: ",message)
func settle() -> void:
	for i in range(5): await process_frame
func inspect(node: Node, page: String) -> void:
	if node is Label and node.is_visible_in_tree() and node.size.x > 0 and node.text.length()>4:
		check(node.size.x>=55, page+" narrow text: "+node.text.left(60)+" width="+str(node.size.x))
	if node is Control and node.is_visible_in_tree() and node.get_parent() is HBoxContainer:
		check(node.position.x+node.size.x<=node.get_parent().size.x+2,page+" HBox overflow: "+node.name)
	for child in node.get_children(): inspect(child,page)
func run() -> void:
	root.size=Vector2i(1440,900)
	game=load("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.set_physics_process(false)
	game.service.set_process(false)
	game.shop.set_process(false)
	var office=game.office
	var p=game.service.progress
	p.cash=10000
	p.stars=4
	p.expanded=true
	p.specialized_expanded=true
	p.orchestration_expanded=true
	var cook: Node3D = game.service.add_station("counter",1)
	cook.staffed=1
	cook.equipment=["jug","cup","plates","pan","sauce","rag"]
	cook.apply_equipment()
	cook.model.reset("wine")
	var frames: Array=[]
	for i in range(120): frames.append(cook.model.snapshot())
	var record: Dictionary=preload("res://scripts/masterclass_library.gd").make_record(9801,"wine","counter",[{"group":1,"frames":frames}],2.0,cook.model.quality(),"Очень длинное название мастер-класса для проверки переноса текста в узкой колонке")
	game.service.masterclasses=[record]
	game.service.add_station("kitchen",3)
	office.open()
	check(not office.navigation.has("deliveries"),"delivery tab removed")
	for page in office.PAGE_NAMES:
		office.navigate(page)
		await settle()
		inspect(office.panel,page)
	for category in ["equipment","tables","rooms","lab","lounge","decor"]:
		office.open_shop(category)
		await settle()
		inspect(office.panel,category)
	for branch in ["formula","growing","calibration"]:
		office.lab_branch=branch
		office.open_shop("lab")
		await settle()
		inspect(office.panel,"lab-"+branch)
	office.details_open["shop-batch"]=true
	office.open_shop("tables")
	await settle()
	inspect(office.panel,"batch")
	office.navigate("groups")
	office.open_training_workspace()
	await settle()
	inspect(office.panel,"training")
	office._training_library_click({"record_id":9801},false,false)
	office.training_add_selected_to_draft()
	await settle()
	inspect(office.panel,"training-draft")
	office.details_open["record-9801"]=true
	office.navigate("videos")
	await settle()
	inspect(office.panel,"record-details")
	var parcel: Dictionary={"id":998,"item":"sauce_ramp","items":["sauce_ramp"],"station":2,"remaining":8.0,"position":[0.0,0.3,0.0],"owner":0,"worker_phase":"","worker_role":-1,"worker_position":[0.0,0.0,0.0]}
	p.deliveries.append(parcel)
	check(not office._item_parcel("sauce_ramp",2).is_empty(),"bundle item matches parcel")
	check(office._parcel_status(parcel)=="Доставляется","transit state")
	parcel.remaining=0
	parcel.worker_phase="carrying"
	check(office._parcel_status(parcel)=="Работники бегут за коробкой","worker carry state")
	parcel.worker_phase="installing"
	check(office._parcel_status(parcel)=="Работники устанавливают","worker install state")
	office.shop_station_id=2
	office.open_shop("equipment")
	await settle()
	var old_content: Node=office.content.get_child(0)
	parcel.worker_phase="carrying"
	office._refresh_delivery_labels()
	check(is_instance_valid(old_content) and old_content==office.content.get_child(0),"status update preserves controls")
	p.deliveries.erase(parcel)
	print("PC_UI_REVIEW ","PASS" if failures.is_empty() else str(failures))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
