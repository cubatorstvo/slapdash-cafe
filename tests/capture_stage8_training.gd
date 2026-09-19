extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Library=preload("res://scripts/masterclass_library.gd")
var game: Node3D
var destination: String="/tmp/stage8-training-visuals"

func _initialize()->void:
	run.call_deferred()

func repeated(value: Dictionary,count: int)->Array:
	var result: Array=[]
	for i in range(count): result.append(value.duplicate(true))
	return result

func prepare(station: Node3D)->void:
	station.staffed=1
	station.equipment=["rag","plates","sauce"]
	station.apply_equipment()

func shot(name: String,eye: Vector3,target: Vector3)->void:
	game.camera.global_position=eye
	game.camera.look_at(target,Vector3.UP)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String=destination.path_join(name+".png")
	var image: Image=root.get_texture().get_image()
	var error: Error=image.save_png(path)
	if error!=OK: push_error("Screenshot failed: "+path)
	else: print("CAPTURE: ",path," ",image.get_width(),"x",image.get_height())

func find_text_control(node: Node,needle: String)->Control:
	if node is Label or node is Button:
		if needle in str(node.text): return node
	for child in node.get_children():
		var found: Control=find_text_control(child,needle)
		if found!=null: return found
	return null

func training_actor_center()->Vector3:
	var sum:=Vector3.ZERO
	var count:=0
	for actor in game.service.staff_training.actors.values():
		if actor is Node3D and is_instance_valid(actor):
			sum+=actor.global_position
			count+=1
	return sum/float(count) if count>0 else Vector3(7.0,0.0,13.5)

func run()->void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	if not args.is_empty(): destination=args[0]
	DirAccess.make_dir_recursive_absolute(destination)
	root.size=Vector2i(1440,900)
	game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	game.hud.hide()
	game.menu.hide()
	var service=game.service
	var p=service.progress
	p.stars=5
	p.shift="open"
	p.lounge_tier=2
	p.lounge_items=["sofa","television","rocking_chair","foosball","arcade","table_tennis","board_games","bookcase","beanbag","tea_station","jukebox","aquarium","plants","floor_lamp","snack_fridge","textiles","ambient"]
	service.open_for_business=false
	game.annex.refresh_shell()
	await process_frame

	var ids: Array=[]
	var source: Node3D
	for slot in range(1,20):
		var station=service.add_station("counter",slot,false,true)
		prepare(station)
		ids.append(station.station_id)
		if source==null: source=station
	source.model.reset("sausage")
	var frames:=repeated(source.model.snapshot(),900)
	var record: Dictionary=Library.make_record(9901,"sausage","counter",[{"group":1,"frames":frames}],15.0,source.model.quality(),"Вся смена у телевизора")
	service.masterclasses=[record]
	service.next_masterclass_id=9902
	var queued: Dictionary=service.queue_training_course([{"record_id":9901,"station_ids":ids}],"together","stage8-visual",1)
	if not str(queued.get("error","")).is_empty(): push_error("Visual course failed: "+str(queued.error))
	var spots: Array=preload("res://scripts/lounge_layout.gd").training_viewer_spots(ids.size(),p.lounge_tier,p.lounge_items)
	var people: Array=[]
	for index in range(ids.size()):
		var station: Node3D=service.by_id(int(ids[index]))
		var member: Dictionary=station.crew[0]
		var spot: Vector3=Vector3(spots[index])
		people.append({"key":"%d:0"%station.station_id,"name":str(member.get("name","Клон")),"position":service.to_local(spot),"yaw":0.0,"watching":true,"meta":{"station":station.station_id,"role":0,"clone_id":int(member.get("clone_id",0)),"home":station.global_position,"target":spot,"name":str(member.get("name","Клон"))},"path":[]})
	service.staff_training.apply_snapshot({"active":true,"revision":1,"phase":"watching","dish":"sausage","record_id":9901,"record":{"id":9901,"name":"Вся смена у телевизора","dish":"sausage"},"stations":ids.duplicate(),"targets":ids.duplicate(),"queue_owned":true,"lesson_id":1,"actors":people})
	await process_frame
	await process_frame

	var crowd_center: Vector3=training_actor_center()
	await shot("01_nineteen_workers_at_tv",crowd_center+Vector3(5.2,2.4,4.8),crowd_center+Vector3(0.0,0.85,0.0))

	game.office.open("groups")
	game.office.select_group_stations(ids)
	game.office.course_editor_open()
	await process_frame
	await process_frame
	var scale_label: Control=find_text_control(game.office.content,"Масштаб кафе: 19/19")
	if scale_label==null:
		push_error("Course editor scale label is missing from visual capture")
	else:
		game.office.scroll.scroll_vertical=maxi(0,roundi(scale_label.position.y)-120)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var ui_path: String=destination.path_join("02_course_editor_19_of_19.png")
	var ui_error: Error=image.save_png(ui_path)
	if ui_error!=OK: push_error("Screenshot failed: "+ui_path)
	else: print("CAPTURE: ",ui_path," ",image.get_width(),"x",image.get_height())
	game.office.close()

	game._shutdown_tree(game)
	game.free()
	quit()
