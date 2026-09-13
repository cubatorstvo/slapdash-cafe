extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Model=preload("res://scripts/cooking_model.gd")
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, title: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",title)
func run() -> void:
	var game=Scene.instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false)
	var service=game.service
	var p=service.progress
	check(not service.create_clone().is_empty(),"Clone requires star and lab")
	game.shop.reward_sauce()
	check(p.cash==20 and game.shop.pending("sauce",1),"First reward delivers sauce without spending start money")
	p.deliveries.clear(); p.stars=1; p.lab_stage=3; p.cash=1000
	var st=service.add_station("counter",1,false,true)
	check(st.staffed==0 and not service.request_training(st,"wine",1),"Empty station cannot teach or run")
	check(service.create_clone().is_empty() and st.staffed==1 and p.free_clones==0,"Free clone fills vacant station")
	check(service.create_clone().is_empty() and p.free_clones==1,"Additional clone stored freely")
	var second=service.add_station("counter",2,false,true)
	check(second.staffed==1 and p.free_clones==0,"New station consumes waiting clone")
	var before: int=p.cash
	check(game.shop.order_bundle(["pan","cup","plates"],st.station_id).is_empty(),"Order chosen equipment together")
	check(p.deliveries.size()==1 and p.cash==before-114,"One parcel and exact total")
	check(game.shop.pending("plates",st.station_id),"Every bundled item is reserved")
	check(not game.shop.order_bundle(["rag","plates"],st.station_id).is_empty() and p.cash==before-114,"Invalid bundle is atomic")
	game.shop.advance(8)
	var parcel: Dictionary=p.deliveries[0]
	game.player.position=Vector3(parcel.position[0],0,parcel.position[2])
	check(game.shop.action(1,{"action":"take_parcel","id":parcel.id}).is_empty(),"Carry bundle")
	game.player.position=game.shop.installation_position(parcel)-Vector3.UP
	check(game.shop.action(1,{"action":"install_parcel","id":parcel.id}).is_empty(),"Unpack whole bundle")
	check("pan" in st.equipment and "cup" in st.equipment and "plates" in st.equipment and p.deliveries.is_empty(),"All contents installed once")
	var saved: Dictionary=service.save_data()
	check(service.load_data(saved) and service.by_id(2).staffed==1 and service.progress.free_clones==0,"Staffing persists without duplicate clones")
	st=service.by_id(1)
	st.model.guest_serving.active=true
	st.model.equipment=["cup"]
	st.model.pick_up("cup"); st.model.cup=Vector2(0,-0.85); st.model.elevations.cup=0.135
	game.local_role=0
	game.camera.global_position=st.to_global(Vector3(0,1.7,2.9))
	game.camera.look_at(st.to_global(Model.GUEST_MOUTH))
	check(game.feed_target(st),"Food near guest enables feeding from behind counter")
	game.camera.rotation.y+=PI
	check(not game.feed_target(st),"Looking away disables feeding")
	var model=Model.new(); model.sauce_ramp=true; model.reset("sausage")
	var variants: Array=[]
	for n in range(4):
		model.pick_up("sausage_0"); model.move_item("sausage",Vector2(Model.RAMP_X,Model.RAMP_START)); model.elevations.sausage=1
		model.put_down(); variants.append(model.ramp_velocity)
	check(variants[0]!=variants[1],"New launch has a fresh target")
	var frame: Dictionary=model.snapshot()
	var replica=Model.new(); replica.restore(frame)
	check(replica.ramp_landing().is_equal_approx(model.ramp_landing()),"Recorded launch repeats identical target")
	for tab in ["overview","stations","star"]: game.office.open(tab); await process_frame
	game.office.close()
	game._shutdown_tree(game); game.free()
	print("PASS: starter grant, bundles, clone allocation, saved staffing, feeding aim and recorded flight" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
