extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
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

func masterclass_for(station: Node3D,id: int,dish: String,name: String)->Dictionary:
	station.model.reset(dish)
	var frames: Array=repeated(station.model.snapshot(),60)
	return Library.make_record(id,dish,station.type_id,[{"group":1,"frames":frames}],1.0,station.model.quality(),name)

func delivery_by_station(service: Node3D,station_id: int)->Dictionary:
	for parcel in service.progress.deliveries:
		if int(parcel.get("station",0))==station_id: return parcel
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
	p.stars=4
	p.expanded=true
	p.specialized_expanded=true
	p.orchestration_expanded=true
	p.cash=5000

	print("1/8: expansion preserves legacy places and exposes fourteen prepared repeat slots")
	check(service.SLOT_COUNT==20 and Expansion.SLOT_COUNT==20,"Cafe capacity is twenty stations")
	check(service.slot_position(4)==Vector3(10.2,0,4.75) and service.slot_position(5)==Vector3(3.2,0,4.75),"Legacy fifth and sixth places keep their old coordinates")
	var free: Array=Expansion.free_slot_ids(service)
	check(free.size()==14 and free.front()==7 and free.back()==20,"Expansion offers exactly fourteen prepared station places")
	var unique_positions: Array=[]
	for station_id in free:
		var position: Vector3=service.slot_position(int(station_id)-1)
		var duplicate:=false
		for old in unique_positions:
			if Vector3(old).is_equal_approx(position): duplicate=true
		check(not duplicate,"Prepared places do not overlap")
		unique_positions.append(position)

	print("2/8: batch purchase chooses places, equipment and a group's training plan at ordinary prices")
	var source=service.add_station("counter",1,false,false)
	source.staffed=1
	source.crew[0].clone_id=50
	source.equipment=["rag","pan"]
	source.apply_equipment()
	var record: Dictionary=masterclass_for(source,700,"potato","Картошка для линии")
	service.masterclasses=[record]
	service.next_masterclass_id=701
	source.recipes.potato={"tracks":record.tracks.duplicate(true),"duration":record.duration,"quality":record.quality.duplicate(true)}
	source.method_sources.potato={"id":700,"name":"Картошка для линии"}
	var group: Dictionary=service.table_groups().filter(func(value):return value.stations==[2])[0]
	var before_cash: int=p.cash
	var expected_unit: int=int(game.shop.ITEMS.counter.price)+int(game.shop.ITEMS.pan.price)+int(game.shop.ITEMS.sauce.price)+int(game.shop.ITEMS.plates.price)
	var error: String=game.shop.order_station_batch("counter",[7,8,9],["pan","sauce","plates"],str(group.id),true)
	check(error.is_empty(),"Three equipped stations can be ordered together")
	check(p.cash==before_cash-expected_unit*3,"Free assemblers do not change the ordinary goods price")
	var batch: Array=p.deliveries.filter(func(parcel):return int(parcel.station) in [7,8,9])
	check(batch.size()==3,"Three selected places create three separate boxes")
	for parcel in batch:
		check(bool(parcel.installer),"Every selected box has its own assembler")
		check(parcel.items==["counter","pan","sauce","plates"],"Each box contains its station and selected equipment")
		check(int(parcel.method_plan.get("potato",{}).get("id",0))==700,"Selected group copies a training plan into every box")

	print("3/8: one visible assembler arrives per box and installs its own station")
	p.free_workers=[
		{"id":101,"tempo":1.0,"rest":1.0},
		{"id":102,"tempo":1.0,"rest":1.0},
		{"id":103,"tempo":1.0,"rest":1.0}
	]
	p.free_clones=3
	service.normalize_workers()
	game.shop.advance(9.0)
	game.shop._process(0.016)
	check(game.shop.installers.size()==3,"Arrived three-box order creates three assembler actors")
	for i in range(60):
		game.shop.advance(0.5)
		game.shop._process(0.016)
	check(delivery_by_station(service,7).is_empty() and delivery_by_station(service,8).is_empty() and delivery_by_station(service,9).is_empty(),"Each assembler completes and removes its own box")
	check(p.delivery_history.size()>=3 and p.delivery_history.slice(0,3).all(func(entry):return bool(entry.get("installer",false))),"Completed assembler installations remain visible in delivery history")
	game.shop._process(0.016)
	check(game.shop.installers.is_empty(),"Assemblers leave after installation")
	for id in [7,8,9]:
		var station=service.by_id(id)
		check(station!=null,"Installed station %d exists"%id)
		if station==null: continue
		check("pan" in station.equipment and "sauce" in station.equipment and "plates" in station.equipment and "rag" in station.equipment,"Installed station %d has the chosen equipment"%id)
		check(not station.recipes.has("potato") and int(station.method_plan.get("potato",{}).get("id",0))==700,"New station %d receives a lesson plan rather than free knowledge"%id)
		check(station.staffed==1,"Existing auto-assignment fills the vacancy on station %d"%id)
	check(p.free_workers.is_empty() and p.free_clones==0,"Three free clones were consumed by three new vacancies")

	print("4/8: assembler waits nervously while an existing kitchen place is busy")
	source.state="cooking"
	var wait_cash: int=p.cash
	check(game.shop.order("sauce",2,true).is_empty(),"Existing station equipment can use a free assembler")
	check(p.cash==wait_cash-int(game.shop.ITEMS.sauce.price),"Assembler equipment delivery costs only the equipment")
	var waiting: Dictionary=delivery_by_station(service,2)
	game.shop.advance(8.1)
	for i in range(48):
		if str(waiting.get("installer_state",""))=="waiting": break
		game.shop.advance(0.25)
	check(str(waiting.get("installer_state",""))=="waiting","Busy station makes its assembler wait instead of interrupting the order")
	game.shop._process(0.1)
	var visual=game.shop.installers.get(waiting.id)
	check(is_instance_valid(visual),"Waiting assembler remains visibly tied to its box")
	var captions: Array=[]
	var positions: Array=[]
	if is_instance_valid(visual):
		for i in range(12):
			game.shop._process(0.55)
			captions.append(str(visual.actor.caption.text))
			positions.append(visual.actor.global_position)
		var moved:=false
		for pos in positions:
			if Vector3(pos).distance_to(Vector3(positions[0]))>0.12: moved=true
		check(moved,"Waiting assembler paces nervously near the occupied place")
		check(captions.any(func(text):return "час" in text or "домой" in text or "взгляд" in text or "когда" in text),"Waiting behavior visibly complains about the delay")
	var raw: Array=waiting.installer_position
	var parcel_at:=Vector3(raw[0],raw[1],raw[2])
	game.camera.global_position=parcel_at+Vector3(0,1.15,2.0)
	game.camera.look_at(parcel_at,Vector3.UP)
	var target: Dictionary=game.shop.target(game.camera,1)
	check(str(target.get("hint",""))=="Этой доставкой займется сборщик","Assembler-owned box shows the exact no-touch hint")
	check(game.shop.action(1,{"action":"installer_owned_parcel","id":waiting.id})=="Этой доставкой займется сборщик.","Player cannot take an assembler-owned box")

	print("5/8: assembler finishes as soon as the current kitchen work releases the place")
	source.state="idle"
	game.shop.advance(0.1)
	check(str(waiting.get("installer_state",""))=="installing","Waiting assembler begins installation after the station becomes idle")
	game.shop.advance(2.0)
	check("sauce" in source.equipment and delivery_by_station(service,2).is_empty(),"Assembler installs the equipment and leaves the delivery queue")

	print("6/8: manual deliveries still use the original carry-and-install flow")
	var manual_cash: int=p.cash
	check(game.shop.order("plates",2,false).is_empty(),"Manual equipment delivery can coexist with assembler deliveries")
	check(p.cash==manual_cash-int(game.shop.ITEMS.plates.price),"Manual and assembler delivery use the same item price")
	var manual: Dictionary=delivery_by_station(service,2)
	game.shop.advance(8.1)
	game.player.global_position=Vector3(manual.position[0],manual.position[1],manual.position[2])
	check(game.shop.action(1,{"action":"take_parcel","id":manual.id}).is_empty() and game.shop.carried(1)==int(manual.id),"Player can pick up a manual box")
	game.player.global_position=game.shop.installation_position(manual)
	check(game.shop.action(1,{"action":"install_parcel","id":manual.id}).is_empty(),"Player manually installs the box")
	check("plates" in source.equipment and delivery_by_station(service,2).is_empty(),"Manual installation still updates the station")
	check(p.delivery_history.any(func(entry):return not bool(entry.get("installer",false)) and str(entry.get("item",""))=="plates"),"Completed manual installation is also recorded with its installation method")

	print("7/8: v18 persists twenty-slot stations and their unlearned lesson plans")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(saved.version==18,"Scaling save format is v18")
	check(service.load_data(saved),"v18 scaling cafe reloads")
	check(service.by_id(7)!=null and int(service.by_id(7).method_plan.get("potato",{}).get("id",0))==700,"New place and planned masterclass survive reload")
	check(not service.by_id(7).recipes.has("potato"),"Reload does not turn a training plan into learned knowledge")

	print("8/8: stage-3 v16 saves remain loadable")
	var legacy: Dictionary=bytes_to_var(var_to_bytes(saved))
	legacy.version=16
	for entry in legacy.stations: entry.erase("method_plan")
	check(service.load_data(legacy),"v16 cafe migrates into the twenty-slot format")
	check(service.save_data().version==18,"Migrated cafe writes the current v18 format")

	game._shutdown_tree(game)
	game.free()
	print("PASS: twenty-slot expansion, equipped bundles, free assemblers, nervous waiting, manual boxes and clone autofill" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
