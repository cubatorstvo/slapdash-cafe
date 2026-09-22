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

	print("1/5: expansion preserves base places and exposes twenty-five prepared repeat slots")
	check(service.SLOT_COUNT==31 and Expansion.SLOT_COUNT==31,"Cafe capacity is thirty-one stations")
	check(service.slot_position(4)==Vector3(24.0,0,6.0) and service.slot_position(5)==Vector3(13.0,0,6.0),"Fifth and sixth base places keep the accepted Zone A coordinates")
	var free: Array=Expansion.free_slot_ids(service)
	check(free.size()==25 and free.front()==7 and free.back()==31,"Expansion offers exactly twenty-five prepared station places")
	var unique_positions: Array=[]
	for station_id in free:
		var position: Vector3=service.slot_position(int(station_id)-1)
		var duplicate:=false
		for old in unique_positions:
			if Vector3(old).is_equal_approx(position): duplicate=true
		check(not duplicate,"Prepared places do not overlap")
		unique_positions.append(position)

	print("2/5: batch purchase chooses places and equipment at ordinary prices")
	var source=service.add_station("counter",1,false,false)
	source.staffed=1
	source.crew[0].clone_id=50
	source.equipment=["rag","pan"]
	source.apply_equipment()
	var before_cash: int=p.cash
	var expected_unit: int=int(game.shop.ITEMS.counter.price)+int(game.shop.ITEMS.pan.price)+int(game.shop.ITEMS.sauce.price)+int(game.shop.ITEMS.plates.price)
	var error: String=game.shop.order_station_batch("counter",[7,8,9],["pan","sauce","plates"],"")
	check(error.is_empty(),"Three equipped stations can be ordered together")
	check(p.cash==before_cash-expected_unit*3,"Batch price is exactly the ordinary goods price")
	var batch: Array=p.deliveries.filter(func(parcel):return int(parcel.station) in [7,8,9])
	check(batch.size()==3,"Three selected places create three separate boxes")
	for parcel in batch:
		check(parcel.items==["counter","pan","sauce","plates"],"Each box contains its station and selected equipment")

	print("3/5: new tables have no employees yet, so the player installs their boxes")
	game.shop.advance(9.0)
	for parcel in batch.duplicate():
		check(not game.shop.clone_delivery_claimed(parcel),"Unbuilt station delivery stays player-owned")
		check(game.shop._install_parcel(parcel).is_empty(),"Player installation path can build the delivered station")
	for id in [7,8,9]:
		var station=service.by_id(id)
		check(station!=null,"Installed station %d exists"%id)
		if station==null: continue
		check("pan" in station.equipment and "sauce" in station.equipment and "plates" in station.equipment and "rag" in station.equipment,"Installed station %d has the chosen equipment"%id)

	print("4/5: once a clone is assigned, later equipment deliveries are installed by that table's own worker")
	var target=service.by_id(7)
	target.staffed=1
	target.equipment.erase("sauce_ramp")
	check(game.shop.order("sauce_ramp",7).is_empty(),"Existing staffed table can order later equipment")
	game.shop.advance(8.1)
	var later:=delivery_by_station(service,7)
	check(game.shop.clone_delivery_claimed(later),"Assigned clone claims its own table's arrived box")
	for i in range(600):
		game.shop.advance(0.10)
		game.shop._process(0.02)
		if delivery_by_station(service,7).is_empty(): break
	check(delivery_by_station(service,7).is_empty() and "sauce_ramp" in target.upgrades,"Clone installs later equipment without a separate courier")

	print("5/5: v22 and older stage saves remain loadable")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(saved.version==22,"Scaling save format is v22")
	check(service.load_data(saved),"v22 scaling cafe reloads")
	check(service.by_id(7)!=null,"Installed batch station survives reload")
	var legacy: Dictionary=bytes_to_var(var_to_bytes(saved))
	legacy.version=16
	for entry in legacy.stations: entry.erase("method_plan")
	check(service.load_data(legacy),"v16 cafe migrates into the current slot format")
	check(service.save_data().version==22,"Migrated cafe writes the current v22 format")

	game._shutdown_tree(game)
	game.free()
	print("PASS: thirty-one-slot expansion, batch boxes, manual new-table setup and clone self-installation" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
