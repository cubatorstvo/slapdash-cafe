extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func delivery(service: Node3D,id: int)->Dictionary:
	for parcel in service.progress.deliveries:
		if int(parcel.get("id",0))==id: return parcel
	return {}

func delivery_for(service: Node3D,station_id: int,item: String)->Dictionary:
	for parcel in service.progress.deliveries:
		if int(parcel.get("station",0))==station_id and str(parcel.get("item",""))==item: return parcel
	return {}

func advance_shop(game: Node3D,seconds: float,step:=0.05)->void:
	var elapsed:=0.0
	while elapsed<seconds:
		var delta:=minf(step,seconds-elapsed)
		game.shop.advance(delta)
		game.shop._process(minf(delta,0.05))
		elapsed+=delta

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
	p.cash=20000

	print("1/6: chef, laboratory and lounge deliveries always belong to the player")
	var chef=service.by_id(1)
	check(chef!=null and chef.manual_station,"Starter station is the chef table")
	check(game.shop.order("pan",1).is_empty(),"Chef can order equipment")
	check(game.shop.order("rest_television",0).is_empty(),"Lounge furniture can be ordered")
	check(game.shop.order("lab_0",0).is_empty(),"Laboratory part can be ordered")
	advance_shop(game,8.2)
	for parcel in p.deliveries:
		if int(parcel.station) in [0,1]: check(not game.shop.clone_delivery_claimed(parcel),"Chef/lab/lounge box remains a player installation")

	print("2/6: staffed clone table immediately claims arrived equipment and blocks the player")
	var kitchen=service.add_station("kitchen",3,false,true)
	kitchen.staffed=2
	kitchen.equipment=[]
	kitchen.apply_equipment()
	check(game.shop.order("meat_kit",4).is_empty(),"First kitchen box ordered")
	var meat_id: int=int(p.deliveries.back().id)
	advance_shop(game,8.05)
	var meat: Dictionary=delivery(service,meat_id)
	check(game.shop.clone_delivery_claimed(meat),"Two staffed clones claim their table delivery")
	check(kitchen.delivery_celebration_active and not kitchen.ready_crew(),"The crew abandons normal work while celebrating the delivery")
	var refusal: String=game.shop.action(1,{"action":"worker_owned_parcel","id":meat_id})
	check(refusal=="Не отбирай у ребят праздник — они сами хотят распаковать и установить обновку.","Player gets the playful no-stealing message")
	game.shop._process(0.05)
	check(game.shop.delivery_worker_states.size()==2,"Both workers leave the station for the delivery")
	var carrying: int=0
	var cheering: int=0
	for state in game.shop.delivery_worker_states.values():
		if str(state.phase)=="cheering": cheering+=1
		else: carrying+=1
	check(carrying==1 and cheering==1,"With one box, one worker carries while the spare worker fusses nearby")

	print("3/6: spare worker visibly runs around and cheers while a colleague handles the box")
	var cheer_key: String=""
	for key in game.shop.delivery_worker_states:
		if str(game.shop.delivery_worker_states[key].phase)=="cheering": cheer_key=str(key); break
	var before: Vector3=Vector3.ZERO
	if not cheer_key.is_empty():
		var raw: Array=game.shop.delivery_worker_states[cheer_key].position
		before=Vector3(raw[0],raw[1],raw[2])
	advance_shop(game,0.45)
	check(game.shop.delivery_worker_states.has(cheer_key),"Spare worker keeps celebrating until installation finishes")
	if game.shop.delivery_worker_states.has(cheer_key):
		var state: Dictionary=game.shop.delivery_worker_states[cheer_key]
		var raw: Array=state.position
		var after: Vector3=Vector3(raw[0],raw[1],raw[2])
		check(after.distance_to(before)>0.05,"Spare worker physically scurries around the station")
		game.shop._process(0.05)
		var visual: Node3D=game.shop.delivery_workers.get(cheer_key)
		check(is_instance_valid(visual) and ("ДАВАЙ" in str(visual.actor.caption.text) or "ПОМОГАЕТ" in str(visual.actor.caption.text) or "КОНТРОЛИРУЕТ" in str(visual.actor.caption.text) or "ОБНОВКА" in str(visual.actor.caption.text)),"Spare worker has a comic celebration caption")

	print("4/6: several boxes are carried in parallel, one per available worker")
	advance_shop(game,45.0)
	check("meat_kit" in kitchen.equipment and delivery(service,meat_id).is_empty(),"First box installs automatically")
	check(game.shop.order("pasta_kit",4).is_empty(),"Second kitchen box ordered")
	check(game.shop.order("meat_kit",4)=="Уже установлено.","Installed equipment cannot be reordered")
	# Use two independent boxes on a three-role station to verify parallel one-box-per-worker carrying.
	var sol: Node3D=service.add_station("solyanka_kitchen",5,false,true)
	sol.staffed=3
	sol.equipment=[]
	sol.apply_equipment()
	check(game.shop.order("fire_kit",6).is_empty(),"First solyanka equipment box ordered")
	check(game.shop.order("stir_kit",6).is_empty(),"Second solyanka equipment box ordered")
	advance_shop(game,8.1)
	var assigned: Dictionary={}
	var cheerers: int=0
	for state in game.shop.delivery_worker_states.values():
		if int(state.station)!=6: continue
		if str(state.phase)=="cheering": cheerers+=1
		else: assigned[int(state.parcel)]=true
	check(assigned.size()==2 and cheerers==1,"Two workers each take one of two boxes while the third celebrates")
	var sol_parcels: Array=p.deliveries.filter(func(parcel): return int(parcel.get("station",0))==6 and str(parcel.get("item","")) in ["fire_kit","stir_kit"])
	if sol_parcels.size()==2:
		var first: Dictionary=sol_parcels[0]
		var second: Dictionary=sol_parcels[1]
		var second_role:=int(second.get("worker_role",-1))
		var second_phase:=str(second.get("worker_phase",""))
		first.worker_phase="installing"
		first.worker_age=1.14
		game.shop._advance_clone_deliveries(0.02)
		check(int(second.get("worker_role",-1))==second_role and str(second.get("worker_phase",""))==second_phase,"Finishing one box does not steal or restart a colleague's in-flight box")

	print("5/6: an unstaffed clone table leaves its box available for manual installation")
	var empty_station: Node3D=service.add_station("counter",2,false,true)
	empty_station.staffed=0
	empty_station.equipment=["rag"]
	empty_station.apply_equipment()
	check(game.shop.order("sauce",3).is_empty(),"Equipment can be ordered for an empty clone table")
	var manual_id: int=int(p.deliveries.back().id)
	advance_shop(game,8.1)
	var manual: Dictionary=delivery(service,manual_id)
	check(not game.shop.clone_delivery_claimed(manual),"No employees means no automatic claim")
	game.player.global_position=Vector3(manual.position[0],manual.position[1],manual.position[2])
	check(game.shop.action(1,{"action":"take_parcel","id":manual_id}).is_empty(),"Player can take an unstaffed table's box")
	game.player.global_position=game.shop.installation_position(manual)
	check(game.shop.action(1,{"action":"install_parcel","id":manual_id}).is_empty(),"Player can install an unstaffed table's delivery")
	check("sauce" in empty_station.equipment,"Manual installation updates the empty table")

	print("6/6: worker delivery progress survives save/load without bringing couriers back")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(not saved.progression.has("installer_jobs"),"Save format no longer contains courier jobs")
	check(service.load_data(saved),"Delivery save reloads")
	p=service.progress
	for parcel in p.deliveries:
		check(not parcel.has("installer") and not parcel.has("installer_state"),"Reloaded parcels contain no courier ownership metadata")
	advance_shop(game,55.0)
	check("fire_kit" in service.by_id(6).equipment and "stir_kit" in service.by_id(6).equipment,"Reloaded clone deliveries still finish themselves")

	game._shutdown_tree(game)
	game.free()
	print("PASS: clone workers abandon work, carry boxes, cheer, block stealing and preserve manual player installs" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
