extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func settle(frames := 10) -> void:
	for _i in range(frames):
		await process_frame

func shot(game: Node3D, station: Node3D, name: String, local_camera: Vector3, local_target: Vector3) -> void:
	game.camera.global_position = station.to_global(local_camera)
	game.camera.look_at(station.to_global(local_target), Vector3.UP)
	await settle(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/" + name + ".png")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var game := preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_physics_process(false)
	game.hud.hide()
	game.menu.close()
	game.cookbook.close()
	game.office.close()
	game.service.clear_world()
	game.service.initial_stations(true)
	game._refresh_cafe_layout(true)
	await settle()
	var station: Node3D = game.service.by_id(1)
	if station == null:
		printerr("FAIL: station 1 not found")
		quit(1)
		return
	await shot(game, station, "counter-station-cook", Vector3(-4.6, 3.15, 5.4), Vector3(-0.4, 0.82, 0.15))
	await shot(game, station, "counter-station-break", Vector3(-4.0, 2.15, 3.6), Vector3(-1.15, 0.78, 0.58))
	game._shutdown_tree(game)
	game.free()
	await process_frame
	quit()
