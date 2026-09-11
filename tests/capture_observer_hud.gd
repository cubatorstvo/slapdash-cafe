extends SceneTree
const OUT := "/opt/cursor/artifacts/screenshots"
func _initialize() -> void: run.call_deferred()
func set_view(size: Vector2i) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(size)
	root.size = size
	await process_frame
	await process_frame
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute("/workspace/captures")
	image.save_png("%s/%s.png" % [OUT, name])
	image.save_png("/workspace/captures/%s.png" % name)
	print("CAPTURE: %s/%s.png %dx%d" % [OUT, name, image.get_width(), image.get_height()])
func wait_frames(seconds: float) -> void:
	var wait := 0.0
	while wait < seconds:
		await process_frame
		wait += 1.0 / 60.0
func look_at_station(game, station: Node3D) -> void:
	game.player.global_position = station.to_global(Vector3(0, 0.02, 1.85))
	game.player.rotation.y = station.global_rotation.y
	game.camera.rotation.x = -0.18
	game.camera.fov = 70.0
func run() -> void:
	await set_view(Vector2i(1280, 800))
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.service.open_for_business = false
	game.set_physics_process(false)
	game.service.clear_world()
	game.service.initial_stations(true)
	var station = game.service.by_id(1)
	game.service.request_training(station, "wine", 1)
	station.training.start_pass([1])
	game.bind_training()
	game.menu.close()
	game.cookbook.close()
	look_at_station(game, station)
	game.service.refresh_views(0.016)
	game.refresh_hud()
	await wait_frames(0.25)
	await snap("observer_training_book_closed_1280")
	station.training.close()
	game.bind_training()
	var quality: Dictionary = station.model.quality()
	quality.grade = "C"
	station.recipes["wine"] = {"tracks": [{"group": 1, "frames": [station.model.snapshot()]}], "duration": 55.0, "quality": quality}
	station.order_dish = "wine"
	station.state = "cooking"
	station.show_tracks(station.recipes.wine.tracks, 0)
	look_at_station(game, station)
	game.service.refresh_views(0.016)
	game.refresh_hud()
	await wait_frames(0.35)
	await snap("observer_clone_record_1280")
	print("PASS: observer HUD captures")
	quit(0)
