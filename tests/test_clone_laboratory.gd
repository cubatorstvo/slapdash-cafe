extends SceneTree
const DT := 1.0/60.0
var failed := false
var game
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failed=true; printerr("FAIL: ",text)
func cycle(good := true, target_id := 0) -> void:
	var lab=game.laboratory
	lab.reset(); lab.state.selected=target_id
	check(lab.press(1,lab.state.revision).is_empty(),"Start laboratory cycle")
	for i in range(1100):
		if lab.state.phase!="fill": break
		# Deliberately poor attempt keeps filling; good input balances in the green band.
		lab.advance_balance(DT, true if not good and i<180 else float(lab.state.level)<0.32)
	check(lab.state.phase=="fill_ready","Balance phase completes")
	lab.press(1,lab.state.revision)
	lab.advance((0.5 if good else 0.97)/(0.42 if lab.state.damper else 1.2))
	lab.press(1,lab.state.revision)
	check(lab.state.phase=="ready","Needle accepts any zone")
func run() -> void:
	game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game); await process_frame
	game.set_physics_process(false)
	var lab=game.laboratory
	var p=game.service.progress
	game.player.position=Vector3(0,0.02,7)
	check(not lab.press(1,lab.state.revision).is_empty(),"First star gate")
	p.stars=1; p.lab_stage=3; p.cash=1000
	var counter=game.service.add_station("counter",1,false,true)
	check("rag" in counter.equipment,"Bare table includes rag")
	cycle(false)
	check(lab.state.tempo>=0.7 and lab.state.tempo<0.9,"Poor performance yields slower clone")
	var original: float=lab.state.tempo
	var rev: int=lab.state.revision
	lab.press(1,rev); lab.press(1,rev)
	check(p.cash==940 and counter.staffed==1 and is_equal_approx(counter.crew_tempo(),original),"One payment; individual tempo assigned")
	var id: int=counter.crew[0].clone_id
	cycle(true,id)
	check(not counter.ready_crew(),"Calibration reserves only target's station")
	check(is_equal_approx(lab.state.tempo,1.0),"Perfect base clone is 100 percent")
	lab.press(1,lab.state.revision)
	check(p.cash==920 and counter.crew_tempo()==1.0 and counter.ready_crew(),"Recalibration upgrades existing worker")
	cycle(false,id); lab.press(1,lab.state.revision)
	check(p.cash==920 and counter.crew_tempo()==1.0,"Worse recalibration preserves previous result without payment")
	lab.reset(); p.stars=2
	check(not game.shop.order("lab_power_2",0).is_empty(),"Turbo requires installed amplifier")
	for item in ["lab_power","lab_damper"]:
		check(game.shop.order(item,0).is_empty(),"Order lab upgrade")
		game.shop.advance(9)
		var parcel: Dictionary=p.deliveries.back()
		game.player.position=Vector3(parcel.position[0],0,parcel.position[2])
		game.shop.action(1,{"action":"take_parcel","id":parcel.id})
		game.player.position=lab.upgrade_position(item)-Vector3.UP
		check(game.shop.action(1,{"action":"install_parcel","id":parcel.id}).is_empty(),"Install delivered lab equipment")
	game.player.position=Vector3(0,0.02,7)
	cycle(true)
	check(lab.state.tempo==1.5 and lab.state.damper,"Power increases ceiling; damper helps separately")
	lab.press(1,lab.state.revision)
	check(p.free_workers.size()==1 and p.free_workers[0].tempo==1.5,"Free clone remembers individual result")
	var free_id: int=p.free_workers[0].id
	cycle(true,free_id)
	var second=game.service.add_station("counter",2,false,true)
	check(second.staffed==0,"Worker in calibration is not auto-assigned")
	lab.selection_action(1,{"action":"lab_restart","revision":lab.state.revision})
	check(second.staffed==1 and second.crew[0].tempo==1.5,"Cancelled free clone returns to allocation")
	var kitchen=game.service.add_station("kitchen",3,false,true)
	game.service.create_clone(2.0); game.service.create_clone(0.7)
	check(kitchen.crew_tempo()==0.7,"Brigade uses slowest of two independent workers")
	check(kitchen.crew[0].tempo==2.0 and kitchen.crew[1].tempo==0.7,"Faster worker's own tempo is retained")
	var save: Dictionary=game.service.save_data()
	check(game.service.load_data(save),"Save reload")
	check(game.service.by_id(4).crew_tempo()==0.7 and "lab_damper" in game.service.progress.lab_upgrades,"Individual rates and lab upgrades persist")
	game.player.position=Vector3(0,0.02,7)
	lab.reset(); lab.state.selected=0
	game.session.members[7]="Guest"; game.session.player_poses[7]={"position":[0,0.02,7]}
	game.session.execute_action(7,{"action":"lab_press","revision":lab.state.revision})
	check(lab.state.owner==7,"Remote player owns cycle")
	game.session.player_poses[7].lab_hold=true; game.session.player_poses[7].received_at=Time.get_ticks_msec()
	lab.advance(0.2)
	var raised: float=lab.state.level
	check(raised>0,"Host applies guest hold input")
	game.session.player_poses[7].received_at=Time.get_ticks_msec()-500
	lab.advance(0.1)
	check(lab.state.level<raised,"Stale hold input releases valve")
	check(not lab.press(1,lab.state.revision).is_empty(),"Another participant cannot interrupt")
	game.session.members.erase(7); lab.advance(DT)
	check(lab.state.phase=="idle","Disconnect releases laboratory")
	game._shutdown_tree(game); game.free()
	print("PASS: balance scoring, individual tempo, calibration, upgrades, persistence and ownership" if not failed else "FAILED")
	quit(1 if failed else 0)
