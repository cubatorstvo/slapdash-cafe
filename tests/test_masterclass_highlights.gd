extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Highlights=preload("res://scripts/masterclass_highlights.gd")
const Library=preload("res://scripts/masterclass_library.gd")
const Definition=preload("res://scripts/station_definition.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func marker_track(ticks: int)->Dictionary:
	var frames: Array=[]
	for i in range(ticks): frames.append({"marker":i})
	return {"group":1,"frames":frames}

func moving_track(ticks: int)->Dictionary:
	var frames: Array=[]
	for i in range(ticks):
		var x:=sin(float(i)/37.0)*0.7
		frames.append({"marker":i,"jug":[x,0.15],"cup":[0.5,0.3],"rag":[-0.5,0.3],"actor_position":[x*0.2,0.0,1.8]})
	return {"group":1,"frames":frames}

func event_track(ticks: int,event_tick: int)->Dictionary:
	var track:=moving_track(ticks)
	track.events=[{"tick":event_tick,"role":0,"kind":"trick","object":"tomato","importance":100}]
	return track

func repeated(value: Dictionary,count: int)->Array:
	var result: Array=[]
	for i in range(count): result.append(value.duplicate(true))
	return result

func contains_source_tick(segments: Array,tick: int)->bool:
	for segment in segments:
		if tick>=int(segment.source_start) and tick<int(segment.source_end): return true
	return false

func _initialize()->void:
	run.call_deferred()

func run()->void:
	print("1/8: highlight edit is exactly thirty percent")
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

	print("2/8: late accepted trick and final result survive event-driven edit")
	var late_tick:=1980
	var late:=event_track(40*60,late_tick)
	var late_events: Array=Highlights.extract_events([late])
	var late_edit: Array=Highlights.build([late],late_events)
	check(int(late_edit.back().film_end)==720,"Forty-second edit has exact 720-frame budget")
	check(contains_source_tick(late_edit,late_tick),"Late trick outside the former fixed windows is selected")
	var last: Dictionary=Highlights.source_tick(late_edit,719)
	check(int(last.tick)==2399,"Last film frame is the last accepted source frame")
	check(str(late_edit.back().kind)=="final","Recognizable final result is the final montage segment")
	check(late_edit.size()<=Highlights.MAX_SEGMENTS,"Event edit stays within the readability segment cap")

	print("3/8: calm cooking uses real motion and multi-role source shares one timeline")
	var calm:=moving_track(20*60)
	var calm_edit: Array=Highlights.build([calm])
	check(int(calm_edit.back().film_end)==360,"Calm twenty-second attempt still has exact 30 percent budget")
	check(int(Highlights.source_tick(calm_edit,359).tick)==1199,"Calm montage still ends on the actual result")
	var role_a:=marker_track(600)
	var role_b:=marker_track(420)
	check(Highlights.source_ticks([role_a,role_b])==600,"Multi-role source duration is the longest role, not the sum")
	check(Highlights.film_ticks([role_a,role_b])==180,"Multi-role montage budget is based on the shared timeline")
	var multi_record:=Library.make_record(70,"meal","kitchen",[role_a,role_b],10.0,{},"Синхронный тест")
	var multi_payload:=Library.movie_payload(multi_record)
	check(multi_payload.tracks[0].frames.size()==180 and multi_payload.tracks[1].frames.size()==180,"Both roles replay the same selected source moments on one film timeline")

	print("4/8: cinematic camera presets cover every existing kitchen type")
	for type_id in Definition.TYPES:
		var camera_positions: Array=[]
		for i in range(4):
			var pose: Dictionary=Highlights.camera_pose(str(type_id),i)
			check(pose.position.is_finite() and pose.target.is_finite(),"Camera preset is finite for "+str(type_id))
			camera_positions.append(pose.position)
		var distinct:=true
		for i in range(camera_positions.size()):
			for j in range(i+1,camera_positions.size()):
				if camera_positions[i].is_equal_approx(camera_positions[j]): distinct=false
		check(distinct,"All four highlight angles are distinct for "+str(type_id))
	check(Highlights.camera_pose("kitchen",0).position!=Highlights.camera_pose("grill_kitchen",0).position,"Meal and grill kitchens use tailored wide camera positions")
	check(Highlights.camera_pose("grill_kitchen",0).position!=Highlights.camera_pose("solyanka_kitchen",0).position,"Grill and solyanka kitchens use tailored wide camera positions")

	print("5/8: live masterclass creates audience and a moving comedy operator")
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

	print("6/8: accepted frames produce compact real-frame movie payload and preserve scene config")
	kitchen=service.by_id(4)
	kitchen.model.reset("meal")
	var tracks: Array=[]
	for role in range(2): tracks.append({"group":role+1,"frames":repeated(kitchen.model.zone_snapshot(role),60)})
	tracks[0].events=[{"tick":48,"role":0,"kind":"key_action","object":"steak","importance":82}]
	var scene_config: Dictionary={"equipment":["meat_kit","pasta_kit"],"upgrades":["recorded_test_upgrade"],"roles":["Мясо","Макароны"]}
	var record: Dictionary=Library.make_record(77,"meal","kitchen",tracks,1.0,kitchen.model.quality(),"Телевизионный тест",false,4,scene_config)
	check(is_equal_approx(float(record.highlight_duration),0.3),"One-second accepted performance produces a 0.3-second film")
	check(int(record.highlight_plan_version)==Highlights.PLAN_VERSION and not record.highlight_events.is_empty(),"Record stores deterministic montage version and accepted event data")
	check(record.scene_config==scene_config,"Record keeps meaningful equipment, upgrades and role configuration")
	var payload: Dictionary=Library.movie_payload(record)
	check(payload.tracks[0].frames.size()==18 and payload.tracks[1].frames.size()==18,"Network movie payload contains only the 30% selected frames")
	check(is_equal_approx(float(payload.highlight_duration),0.3),"Compact payload keeps exact film duration")

	print("7/8: existing lounge television restores recorded scene and does not block cafe simulation")
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
	check(lounge.movie_player.stage.equipment==scene_config.equipment and lounge.movie_player.stage.upgrades==scene_config.upgrades,"TV stage restores the configuration captured with the accepted masterclass")
	p.shift="open"
	service.open_for_business=true
	var shift_before: float=p.shift_elapsed
	service.advance(0.10)
	check(p.shift_elapsed>shift_before,"Cafe simulation continues while a player watches highlights")
	service.advance(0.25)
	check(not bool(service.movie_state.playing),"Film ends at its exact duration")
	lounge._process(0.016)
	check(not lounge.movie_player.active,"Television returns to idle after the film")

	print("8/8: old libraries rebuild event montage once and remain compatible")
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(saved.version==22,"Highlight metadata remains backward compatible with the current v22 save format")
	var old: Dictionary=saved.duplicate(true)
	old.version=14
	for old_record in old.masterclasses:
		old_record.erase("highlight_plan_version")
		old_record.erase("highlight_events")
		old_record.erase("highlight_segments")
		old_record.erase("highlight_duration")
		old_record.erase("scene_config")
	check(service.load_data(old),"Stage 1 v14 cafe loads")
	var migrated: Dictionary=service.masterclasses[0]
	check(int(migrated.highlight_plan_version)==Highlights.PLAN_VERSION and migrated.has("highlight_events"),"Old library gains the current deterministic event montage on load")
	check(is_equal_approx(float(migrated.highlight_duration),0.3),"Migrated old record keeps the exact 30 percent film duration")
	check(migrated.scene_config is Dictionary,"Old record gets a safe fallback scene configuration")

	game._shutdown_tree(game)
	game.free()
	print("PASS: event-driven exact-budget masterclass highlights, scene reconstruction and lounge TV" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
