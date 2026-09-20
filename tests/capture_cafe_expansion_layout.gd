extends SceneTree
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
const LoungeProgress=preload("res://scripts/lounge_progression.gd")
const LabPolicy=preload("res://scripts/laboratory_progression.gd")
var game: Node3D
var camera: Camera3D
var destination:="user://cafe_expansion_preview"

func _initialize()->void: run.call_deferred()

func set_stage(stage: int)->void:
	var p=game.service.progress
	p.stars=[0,0,1,2,4][stage]
	p.expanded=stage>=3
	p.specialized_expanded=stage>=4
	p.orchestration_expanded=stage>=4
	p.lab_tier=clampi(stage-1,0,2)
	p.lab_stage=3
	p.lab_upgrades=[]
	for id in LabPolicy.ITEMS:
		if int(LabPolicy.ITEMS[id].tier)<=p.lab_tier and int(LabPolicy.ITEMS[id].star)<=p.stars:
			p.lab_upgrades.append(id)
	p.lounge_tier=clampi(stage-2,0,2)
	p.lounge_items=LoungeProgress.GOODS.keys()
	game._refresh_cafe_layout(true)
	for slot in range(1,Expansion.SLOT_COUNT):
		var station=game.service.by_id(slot+1)
		if Expansion.slot_available(slot,stage):
			if station==null: game.service.add_station("counter",slot,false,true)
		elif station!=null:
			station.queue_free()
			game.service.stations.erase(station)
	game.annex.refresh_shell()
	game.development.refresh()
	await process_frame
	await process_frame

func shot(name: String,eye: Vector3,target: Vector3,fov:=62.0)->void:
	camera.fov=fov
	camera.global_position=eye
	camera.look_at(target,Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	var path:=destination.path_join(name+".png")
	var error:=root.get_texture().get_image().save_png(path)
	if error!=OK: push_error("Screenshot save failed: "+name)
	else: print("CAPTURE: ",ProjectSettings.globalize_path(path))

func run()->void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty(): destination=args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	root.size=Vector2i(1600,1000)
	game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	game.hud.hide(); game.menu.hide()
	camera=Camera3D.new(); game.add_child(camera); camera.current=true; camera.near=0.05
	game.daylight.light_energy=0.9
	game.room_environment.environment.ambient_light_energy=0.42
	for stage in range(1,5):
		await set_stage(stage)
		var front:=Expansion.entrance_z(stage)
		await shot("stage_%d_overview"%stage,Vector3(31,35,front-16),Vector3(0,0.7,7.5),55.0)
		await shot("stage_%d_player_flow"%stage,Vector3(0,2.0,front+1.2),Vector3(0,1.0,7.0),74.0)
		await shot("stage_%d_lab_room"%stage,Vector3(-6.8,2.65,29.2),Vector3(-6.2,1.0,17.3),69.0)
		if stage>=2:
			await shot("stage_%d_lounge_room"%stage,Vector3(minf(7.4,LoungeProgress.GOODS.size()+2.0),2.65,29.2),Vector3(5.0,1.0,17.3),69.0)
	game._shutdown_tree(game); game.free()
	quit()
