extends SceneTree
const DT := 1.0/60.0
const Layout=preload("res://scripts/laboratory_layout.gd")
const Policy=preload("res://scripts/laboratory_progression.gd")
var failed := false
var game
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failed=true; printerr("FAIL: ",text)

func research() -> void:
	var lab=game.laboratory
	game.player.global_position=lab.operator_position()
	check(lab.press(1,lab.state.revision).is_empty(),"Start paid research")
	for i in range(1100):
		if lab.state.phase!="fill": break
		lab.advance_balance(DT,float(lab.state.level)<0.32)
	check(lab.state.phase=="fill_ready","Balanced liquid waits for stabilizer")
	lab.press(1,lab.state.revision)
	lab.advance(0.5/(0.42 if lab.state.damper else 1.2))
	lab.press(1,lab.state.revision)
	check(not game.service.progress.lab_sample.is_empty(),"Research produces a sample, not a worker")

func examine() -> void:
	var lab=game.laboratory
	var p=game.service.progress
	game.player.global_position=lab.to_global(lab.SAMPLE)-Vector3.UP
	var serial: int=p.lab_sample.serial
	check(lab.action(1,{"action":"lab_sample","sample":serial}).is_empty(),"Pick up sample")
	game.player.global_position=Layout.MICROSCOPE
	check(lab.action(1,{"action":"lab_scan","sample":serial}).is_empty(),"Examine sample")
	lab.ui.close()

func use_pot(type: String) -> void:
	var nursery=game.laboratory.nursery
	var value: Dictionary=nursery.pot(0)
	game.player.global_position=Layout.pot_point(0)+Vector3(0,0,-1.2)
	nursery.hands[1]=type
	check(nursery.action(1,{"action":"lab_pot","pot":0,"revision":value.revision}).is_empty(),"Apply "+type)

func run() -> void:
	game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game); await process_frame
	game.set_physics_process(false)
	var lab=game.laboratory
	var p=game.service.progress
	var nursery=lab.nursery
	game.player.global_position=lab.operator_position()
	check(not lab.press(1,lab.state.revision).is_empty(),"First star gate")
	p.stars=1; p.lab_stage=3; p.cash=2000
	var station=game.service.add_station("counter",1,false,true)
	lab.press(1,lab.state.revision)
	var paid: int=p.cash
	lab.advance_balance(0.3,true); lab.advance_balance(0.3,false)
	check(lab.state.phase=="failed" and p.cash==paid,"Spoiled liquid retains research payment")
	lab.reset()
	research()
	check(p.lab_formula_version==0 and station.staffed==0,"Formula remains unknown until microscope")
	examine()
	check(p.lab_formula_tempo==1.0 and p.lab_formula_version==1,"Microscope records perfect base formula")
	var value: Dictionary=nursery.pot(0)
	use_pot("soil")
	paid=p.cash
	use_pot("liquid")
	check(p.cash==paid-60 and value.tempo==1.0,"Only formula drop pays for a worker")
	var stale: int=int(value.revision)-1
	nursery.action(1,{"action":"lab_pot","pot":0,"revision":stale})
	check(p.cash==paid-60,"Repeated stale drop cannot charge again")
	p.lab_formula_tempo=1.5; p.lab_formula_version=2
	use_pot("water")
	nursery.hands.clear()
	game.player.position=Vector3(-6,0,0)
	nursery.advance(75)
	check(value.phase=="feed" and value.tempo==1.0,"Growth captures formula and continues while player leaves")
	nursery.advance(60)
	check(value.phase=="feed","Feeding waits safely")
	use_pot("fertilizer"); nursery.hands.clear()
	nursery.advance(75)
	check(value.phase=="ready","Second growth stage finishes")
	paid=p.cash
	nursery.harvest(value); nursery.harvest(value)
	check(station.staffed==1 and p.cash==paid,"Harvest creates one prepaid worker")
	var identity: int=station.crew[0].clone_id
	check(not station.ready_crew(),"Newborn walks before accepting orders")
	nursery.advance(30)
	check(station.ready_crew(),"Arrived worker becomes available")
	var chair=lab.calibrator
	p.lab_upgrades.append("lab_chair")
	game.player.global_position=Layout.CHAIR+Vector3(0,0,-1.2)
	var option: Dictionary={}
	for item in game.service.clone_options():
		if int(item.id)==identity: option=item
	check(chair.start(option,1).is_empty(),"Start distinct recalibration")
	check(not station.ready_crew(),"Chair reserves target station")
	chair.advance(chair.route_duration(chair.state.route)+0.01)
	for beat in chair.BEATS:
		chair.state.age=beat
		chair.hit(1,chair.state.revision,beat)
	chair.finish_manual()
	check(game.service.clone_data(identity).tempo==1.5,"Perfect rhythm reaches exact formula cap")
	lab.ui.close()
	chair.advance(chair.route_duration(chair.state.route)+0.01)
	p.lab_formula_tempo=2.0
	option.tempo=1.5
	chair.start(option,1)
	chair.advance(chair.route_duration(chair.state.route)+0.01)
	chair.finish_manual()
	check(game.service.clone_data(identity).tempo==1.5,"Weak attempt preserves existing tempo")
	lab.ui.close(); chair.reset()
	check(not Policy.error(p,"lab_power_2").is_empty(),"Power upgrade respects progression")
	check(Policy.expand(p).is_empty() and p.lab_tier==1,"First room expansion")
	use_pot("soil"); use_pot("liquid"); use_pot("water"); nursery.hands.clear()
	nursery.advance(12)
	var remaining: float=nursery.pot(0).remaining
	var saved: Dictionary=game.service.save_data()
	check(game.service.load_data(saved),"New save restores")
	check(is_equal_approx(nursery.pot(0).remaining,remaining),"Growing pot retains remaining time")
	check(game.service.progress.lab_formula_tempo==2.0 and game.service.progress.lab_tier==1,"Formula and room persist")
	game.player.global_position=lab.operator_position()
	game.session.members[7]="Guest"
	var point: Vector3=lab.operator_position()
	game.session.player_poses[7]={"position":[point.x,point.y,point.z],"lab_hold":true,"received_at":Time.get_ticks_msec()}
	lab.press(7,lab.state.revision)
	lab.advance(0.2)
	check(lab.state.owner==7 and lab.state.level>0,"Host applies remote research input")
	check(not lab.press(1,lab.state.revision).is_empty(),"Research ownership excludes another operator")
	game.session.members.erase(7); lab.advance(0.01)
	check(lab.state.phase=="idle","Disconnect releases research")
	game._shutdown_tree(game); game.free()
	print("PASS: microscope, paid planting, persistent growth and separate recalibration" if not failed else "FAILED")
	quit(1 if failed else 0)
