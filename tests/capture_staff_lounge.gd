extends SceneTree
## Run with a graphics driver: captures player-height daytime and occupied evening views.
var game: Node3D
var camera: Camera3D
var destination := "user://lounge_preview"
func _initialize() -> void: run.call_deferred()
func shot(name: String, eye: Vector3, target: Vector3) -> void:
	camera.global_position=eye
	camera.look_at(target,Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(destination.path_join(name+".png"))
	if error!=OK: push_error("Screenshot save failed: "+name)
	else: print("CAPTURE: ",ProjectSettings.globalize_path(destination.path_join(name+".png")))

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty(): destination=args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	root.size=Vector2i(1440,900)
	game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.service.progress.lounge_tier=2
	game.service.progress.lounge_items=preload("res://scripts/lounge_progression.gd").GOODS.keys()
	game.annex.refresh_shell()
	await process_frame
	game.hud.hide(); game.menu.hide()
	game.player.position=Vector3(-6,0,5)
	camera=Camera3D.new()
	game.add_child(camera)
	camera.current=true
	camera.fov=78
	camera.near=0.04
	game.service.progress.shift="open"
	await shot("01_entrance_day",Vector3(10.4,1.72,11.5),Vector3(10.0,1.1,20.8))
	await shot("02_tv_and_reading",Vector3(10.0,1.72,17.0),Vector3(5.8,1.0,14.3))
	await shot("03_games_and_tea",Vector3(10.5,1.72,20.2),Vector3(15.0,1.0,15.0))
	await shot("04_sleeping_alcove",Vector3(10.4,1.72,23.8),Vector3(10.4,0.8,25.7))
	var p=game.service.progress
	p.stars=1; p.lab_stage=3
	for i in range(20): game.service.create_clone(1.0,true)
	p.shift="night"; p.night_elapsed=90.0
	game.daylight.light_energy=0.12
	game.room_environment.environment.ambient_light_energy=0.26
	game.evening._process(1.0/60.0)
	await shot("05_entrance_night_occupied",Vector3(10.4,1.72,11.5),Vector3(10.0,1.0,20.8))
	await shot("06_tv_evening",Vector3(9.7,1.72,13.1),Vector3(6.4,1.0,14.7))
	await shot("07_games_evening",Vector3(11.0,1.72,17.0),Vector3(14.8,1.0,15.3))
	await shot("08_reading_evening",Vector3(10.2,1.72,20.0),Vector3(5.0,1.0,20.0))
	game._shutdown_tree(game); game.free()
	quit()
