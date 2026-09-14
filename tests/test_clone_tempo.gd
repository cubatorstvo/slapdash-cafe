extends SceneTree
const DT := 1.0/60.0
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failed=true; printerr("FAIL: ",text)
func run() -> void:
	var game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game); await process_frame
	game.set_physics_process(false)
	var service=game.service
	service.progress.stars=2; service.open_for_business=false
	var station=service.add_station("counter",1)
	var m=station.model
	m.reset("wine")
	var start: Dictionary=m.snapshot()
	m.cup=m.Layout.TRAY; m.elevations.cup=m.Layout.TRAY_Y-m.BASE_Y
	m.filled=225; m.wine=775
	var end: Dictionary=m.snapshot()
	var frames: Array=[]
	for i in range(60): frames.append(start.duplicate(true))
	frames.append(end)
	station.recipes.wine={"tracks":[{"frames":frames}],"duration":61.0/60.0,"quality":m.quality()}
	var record_hash:=hash(var_to_bytes(station.recipes.wine))
	for tempo in [0.7,1.0,2.0,10.0]:
		station.crew[0].tempo=tempo
		check(service.spawn_customer("wine"),"Route replay customer")
		var c: Dictionary=service.customers.back()
		var person=c.view
		# Walking never inherits the brigade speed.
		person.position=Vector3.ZERO; person.walk_to(Vector3(5,0,0),DT)
		check(is_equal_approx(person.position.x,1.65*DT) and person.playback_speed==1,"Normal arrival speed")
		c.path.clear(); service.advance(DT)
		check(station.order_tempo==tempo,"Tempo captured at order start")
		var ticks:=0
		while station.state=="cooking" and ticks<150:
			service.advance(DT); service.refresh_views(DT); ticks+=1
			if station.state=="cooking": check(person.playback_speed==tempo,"Guest animation shares replay tempo")
		check(absi(ticks-ceili(61.0/tempo))<=1,"Order duration follows tempo")
		check(person.caption.text.begins_with("S · +25"),"Final frame and price preserved at every speed")
		check(person.playback_speed==1,"Departure uses normal speed")
		check(hash(var_to_bytes(station.recipes.wine))==record_hash,"Replay never mutates recorded snapshots")
	check(service.served==4,"Every speed serves exactly once")
	game._shutdown_tree(game); game.free()
	print("PASS: slow/fast replay, final frame, guest timing, normal routes and record integrity" if not failed else "FAILED")
	quit(1 if failed else 0)
