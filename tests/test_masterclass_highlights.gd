extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Highlights=preload("res://scripts/masterclass_highlights.gd")
const Library=preload("res://scripts/masterclass_library.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func marker_track(ticks: int)->Dictionary:
	var frames: Array=[]
	for i in range(ticks): frames.append({"marker":i})
	return {"group":1,"frames":frames}

func repeated(value: Dictionary,count: int)->Array:
	var result: Array=[]
	for i in range(count): result.append(value.duplicate(true))
	return result

func _initialize()->void:
	run.call_deferred()

func run()->void:
	print("1/6: highlight edit is exactly thirty percent")
	var track45:=marker_track(45*60)
	var edit45: Array=Highlights.build([track45])
	check(is_equal_approx(Highlights.duration([track45]),13.5),"45 seconds becomes 13.5 seconds")
	check(int(edit45.back().film_end)==810,"45-second edit contains exactly 810 film frames")
	var track32:=marker_track(32*60)
	var edit32: Array=Highlights.build([track32])
	check(is_equal_approx(Highlights.duration([track32]),9.6),"32 seconds becomes 9.6 seconds")
	check(int(edit32.back().film_end)==576,"32-second edit contains exactly 576 film frames")
	for film_tick in [0,100,575]:
		var chosen: Dictionary=Highlights.source_tick(edit32,film_tick)
		check(int(track32.frames[int(chosen.tick)].marker)==int(chosen.tick),"Highlight points to a real accepted source frame")

	print("2/6: fixed cinematic angles are independent and readable presets")
	var camera_positions: Array=[]
	for i in range(4):
		var pose: Dictionary=Highlights.camera_pose("kitchen",i)
		check(pose.position.is_finite() and pose.target.is_finite(),"Camera preset is finite")
		camera_positions.append(pose.position)
	var distinct:=true
	for i in range(camera_positions.size()):
		for j in range(i+1,camera_positions.size()):
			if camera_positions[i].is_equal_approx(camera_positions[j]): distinct=false
	check(distinct,"All four highlight angles are distinct")

	print("3/6: live masterclass creates audience and a moving comedy operator")
	var game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var service=game.service
	var p=service.progress
	p.stars=1
	p.shift="morning"
	var chef: Node3D=service.by_id(1)
	chef.equipment=["jug","cup","plates","pan","sauce","rag"]
	chef.apply_equipment()
	var kitchen=service.add_station("kitchen",3,false)
	check(service.request_masterclass("meal",1).is_empty(),"Complex chef masterclass starts")
	var stage=service.masterclass_station
	var live=service.masterclass_live_scene
	check(is_instance_valid(live) and live.audience.size()==4,"A small audience gathers around the chef station")
	check(stage.taster==null,"Masterclass audience replaces the old fake taster")
	var operator_before: Vector3=live.operator.position
	live.advance(1.0)
	check(live.operator.position.distance_to(operator_before)>0.05,"Camera operator visibly changes position")
	var fixed_before: Dictionary=Highlights.camera_pose("kitchen",0)
	live.advance(2.0)
	check(Highlights.camera_pose("kitchen",0)==fixed_before,"Operator movement does not alter film camera presets")
	service.cancel_masterclass()
	check(not service.masterclass_active(),"Chef returns after live show cancellation")

	print("4/6: accepted frames produce compact real-frame movie payload")
	kitchen=service.by_id(4)
	kitchen.model.reset("meal")
	var tracks: Array=[]
	for role in range(2): tracks.append({"group":role+1,"frames":repeated(kitchen.model.zone_snapshot(role),60)})
	var record: Dictionary=Library.make_record(77,"meal","kitchen",tracks,1.0,kitchen.model.quality(),"Телевизионный тест")
	check(is_equal_approx(float(record.highlight_duration),0.3),"One-second accepted performance produces a 0.3-second film")
	var payload: Dictionary=Library.movie_payload(record)
	check(payload.tracks[0].frames.size()==18 and payload.tracks[1].frames.size()==18,"Network movie payload contains only the 30% selected frames")
	check(is_equal_approx(float(payload.highlight_duration),0.3),"Compact payload keeps exact film duration")

	print("5/6: existing lounge television plays highlights without blocking cafe simulation")
	service.masterclasses=[record]
	service.next_masterclass_id=78
	if "television" not in p.lounge_items: p.lounge_items.append("television")
	game.annex.refresh_shell()
	await process_frame
	var lounge=get_first_node_in_group("staff_lounge")
	check(is_instance_valid(lounge) and lounge.television_node()!=null,"Existing lounge television is the playback device")
	check(service.start_highlights(77,1).is_empty(),"Saved film starts on the television")
	check(bool(service.movie_state.playing) and is_equal_approx(float(service.movie_state.duration),0.3),"Playback state uses the exact highlight duration")
	lounge._process(0.016)
	check(lounge.movie_player.active and lounge.movie_player.record_id==77,"TV renders the accepted performance through its movie viewport")
	p.shift="open"
	service.open_for_business=true
	var shift_before: float=p.shift_elapsed
	service.advance(0.10)
	check(p.shift_elapsed>shift_before,"Cafe simulation continues while a player watches highlights")
	service.advance(0.25)
	check(not bool(service.movie_state.playing),"Film ends at its fixed duration")
	lounge._process(0.016)
	check(not lounge.movie_player.active,"Television returns to idle after the film")

	print("6/6: v14 libraries migrate to stage-2 highlight metadata")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(saved.version==15,"Stage 2 save format is v15")
	var old: Dictionary=saved.duplicate(true)
	old.version=14
	for old_record in old.masterclasses:
		old_record.erase("highlight_segments")
		old_record.erase("highlight_duration")
	check(service.load_data(old),"Stage 1 v14 cafe loads")
	check(service.masterclasses[0].has("highlight_segments") and is_equal_approx(float(service.masterclasses[0].highlight_duration),0.3),"Old library gains deterministic highlights on load")

	game._shutdown_tree(game)
	game.free()
	print("PASS: operator, fixed-angle 30 percent highlights and lounge TV" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
