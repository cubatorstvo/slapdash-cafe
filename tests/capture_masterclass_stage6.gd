extends SceneTree
const Model=preload("res://scripts/cooking_model.gd")
const Library=preload("res://scripts/masterclass_library.gd")
const MoviePlayer=preload("res://scripts/masterclass_movie_player.gd")
var destination: String="/tmp/stage6-masterclass-visuals"

func _initialize()->void:
	run.call_deferred()

func make_track(ticks: int,event_tick: int=-1)->Dictionary:
	var model=Model.new()
	model.equipment=["jug","cup","plates","pan","sauce","rag"]
	model.reset("wine")
	var frames: Array=[]
	for i in range(ticks):
		var phase: float=float(i)/maxf(1.0,float(ticks-1))
		model.actor_position=Vector3(sin(phase*TAU)*0.45,0.0,1.8)
		model.actor_yaw=sin(phase*TAU)*0.18
		model.jug=Vector2(-0.85+phase*0.75,0.15+sin(phase*PI)*0.18)
		model.cup=Vector2(0.45,0.28)
		model.filled=minf(220.0,phase*235.0)
		model.wine=maxf(0.0,750.0-model.filled)
		model.tomato_flying=false
		model.tomato_hit=false
		if event_tick>=0 and i>=event_tick-26 and i<=event_tick+26:
			var trick_phase: float=float(i-(event_tick-26))/52.0
			model.tomato_flying=true
			model.tomato=Vector2(lerpf(-1.15,0.15,trick_phase),lerpf(0.25,-1.30,trick_phase))
			model.elevations.tomato=0.18+sin(trick_phase*PI)*0.95
		elif event_tick>=0 and i>event_tick+26:
			model.tomato_hit=true
			model.tomato=Vector2(0.0,-1.30)
			model.elevations.tomato=0.36
		frames.append(model.snapshot())
	var track: Dictionary={"group":1,"frames":frames}
	if event_tick>=0: track.events=[{"tick":event_tick,"role":0,"kind":"trick","object":"tomato","importance":100}]
	return track

func film_tick_for_source(segments: Array,source_tick: int)->int:
	for segment in segments:
		if source_tick>=int(segment.source_start) and source_tick<int(segment.source_end):
			return int(segment.film_start)+(source_tick-int(segment.source_start))
	return -1

func shot(player: Node,record: Dictionary,film_tick: int,name: String)->void:
	var state: Dictionary={"playing":true,"id":int(record.id),"elapsed":float(film_tick)/60.0,"duration":float(record.highlight_duration),"started_by":1}
	player.sync(state,record)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image=player.viewport.get_texture().get_image()
	var path: String=destination.path_join(name+".png")
	var error: Error=image.save_png(path)
	if error!=OK: push_error("Screenshot save failed: "+path)
	else: print("CAPTURE: ",path," ",image.get_width(),"x",image.get_height())

func run()->void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	if not args.is_empty(): destination=args[0]
	DirAccess.make_dir_recursive_absolute(destination)
	var holder:=Node3D.new()
	root.add_child(holder)
	var screen:=MeshInstance3D.new()
	holder.add_child(screen)
	var player=MoviePlayer.new()
	holder.add_child(player)
	player.setup(screen)
	await process_frame
	var config: Dictionary={"equipment":["jug","cup","plates","pan","sauce","rag"],"upgrades":[],"roles":["Повар"]}
	var calm_track: Dictionary=make_track(600)
	var calm: Dictionary=Library.make_record(901,"wine","counter",[calm_track],10.0,{},"Спокойная готовка",false,1,config)
	var calm_tick: int=clampi(roundi(float(calm.highlight_duration)*30.0),0,maxi(0,roundi(float(calm.highlight_duration)*60.0)-1))
	await shot(player,calm,calm_tick,"01_calm_cooking")
	var trick_source:=480
	var late_track: Dictionary=make_track(600,trick_source)
	var late: Dictionary=Library.make_record(902,"wine","counter",[late_track],10.0,{},"Поздний трюк",false,1,config)
	var trick_film_tick: int=film_tick_for_source(late.highlight_segments,trick_source)
	if trick_film_tick<0:
		push_error("Late trick was not selected into the visual montage")
		trick_film_tick=0
	await shot(player,late,trick_film_tick,"02_late_trick")
	await shot(player,late,maxi(0,roundi(float(late.highlight_duration)*60.0)-1),"03_final_result")
	holder.queue_free()
	await process_frame
	quit()
