extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Annex=preload("res://scripts/cafe_annex.gd")
var game: Node3D
var destination: String="/tmp/stage7-installer-visuals"

func _initialize()->void:
	run.call_deferred()

func installer_job(id: int)->Dictionary:
	for value in game.service.progress.installer_jobs:
		if int(value.get("id",0))==id: return value
	return {}

func job_position(id: int)->Vector3:
	var value: Dictionary=installer_job(id)
	var raw: Array=value.get("position",[0.0,0.0,0.0])
	return Vector3(float(raw[0]),float(raw[1]),float(raw[2]))

func step(delta:=0.05)->void:
	game.shop.advance(delta)
	game.shop._process(delta)

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

func wait_for_phase(id: int,phase: String,max_steps:=900)->bool:
	for _i in range(max_steps):
		step()
		if str(installer_job(id).get("phase",""))==phase: return true
	return false

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
	var p=game.service.progress
	p.stars=2
	p.cash=10000
	p.next_delivery_id=4
	var station: Node3D=game.service.add_station("counter",1,false,false)
	station.equipment=["rag"]
	station.apply_equipment()
	station.state="cooking"
	station.customer_id=900
	if not game.shop.order("sauce",2,true).is_empty(): push_error("Clock installer order failed")
	if not game.shop.order("rest_television",0,true).is_empty(): push_error("Lounge installer order failed")
	if not game.shop.order("rest_rocking_chair",0,true).is_empty(): push_error("Lounge filler order failed")
	if not game.shop.order("plates",2,true).is_empty(): push_error("Angry installer order failed")

	var door_captured:=false
	for _i in range(900):
		step()
		var lounge_job: Dictionary=installer_job(5)
		if lounge_job.is_empty(): continue
		var point:=job_position(5)
		if str(lounge_job.get("phase",""))=="carrying" and (point.distance_to(Annex.REST_DOOR_CAFE)<0.75 or point.distance_to(Annex.REST_DOOR_ROOM)<0.75):
			await shot("01_carrying_through_rest_door",Annex.REST_DOOR_CAFE+Vector3(3.0,1.75,-3.0),Annex.REST_DOOR_CAFE+Vector3.UP*1.0)
			door_captured=true
			break
	if not door_captured: push_error("Installer never reached the real rest-room doorway")

	var clock_ready: bool=wait_for_phase(4,"waiting")
	var angry_ready: bool=wait_for_phase(7,"waiting")
	if not clock_ready or not angry_ready: push_error("Busy-station installers did not reach waiting state")
	var clock_job: Dictionary=installer_job(4)
	var angry_job: Dictionary=installer_job(7)
	clock_job.phase_age=1.15
	angry_job.phase_age=3.40
	game.shop._process(0.05)
	await process_frame
	var clock_at:=job_position(4)
	var angry_at:=job_position(7)
	var waiting_center: Vector3=(clock_at+angry_at)*0.5+Vector3.UP*1.0
	await shot("02_clock_and_angry_waiting",waiting_center+Vector3(3.8,2.1,4.4),waiting_center)

	if is_instance_valid(station.view.worker): station.view.worker.position.x+=1.25
	game.shop._process(0.20)
	await process_frame
	angry_at=job_position(7)
	await shot("03_angry_tracks_real_cook",angry_at+Vector3(3.0,1.8,3.2),station.view.worker.global_position+Vector3.UP*1.25 if is_instance_valid(station.view.worker) else station.global_position+Vector3.UP*1.25)

	station.state="idle"
	station.customer_id=-1
	var leaving_ready: bool=wait_for_phase(4,"leaving")
	if not leaving_ready: push_error("Installer did not enter leaving state after installation")
	var leave_at:=job_position(4)
	await shot("04_leaving_after_install",leave_at+Vector3(2.8,1.75,3.1),leave_at+Vector3.UP*1.0)

	game._shutdown_tree(game)
	game.free()
	quit()
