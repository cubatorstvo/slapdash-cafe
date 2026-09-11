extends SceneTree
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cafe-"+name+".png")
func run() -> void:
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.service.clear_world()
	game.service.initial_stations(true)
	game.cookbook.toggle()
	await shot("index")
	game.cookbook.select("meal")
	await shot("recipe")
	game.cookbook.close()
	var station = game.service.by_id(1)
	game.menu.show_station(station)
	await shot("menu")
	game.menu.close()
	game.service.request_training(station,"wine",1)
	station.training.start_pass([1])
	game.bind_training()
	game.menu.close()
	game.camera.rotation.x = -0.35
	game.refresh_hud()
	await shot("hud")
	quit()
