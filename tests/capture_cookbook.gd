extends SceneTree
## Rendered inspection helper. Run with a display: xvfb-run godot --path . --script tests/capture_cookbook.gd
const OUT := "/opt/cursor/artifacts/screenshots"

func _initialize() -> void: run.call_deferred()

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUT)
	image.save_png("%s/%s.png" % [OUT, name])
	print("CAPTURE: %s/%s.png" % [OUT, name])

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.service.open_for_business = false
	game.player.global_position = Vector3(0, 0.02, 2.4)
	game.player.rotation.y = 0
	game.camera.rotation.x = -0.15
	game.cookbook.toggle()
	await process_frame
	await snap("book_index_1280")
	game.cookbook.select("meal")
	await process_frame
	await snap("book_meal_1280")
	game.cookbook.close()
	var station = game.service.by_id(1)
	game.service.request_training(station, "wine", 1)
	station.training.start_pass([1])
	game.bind_training()
	game.menu.close()
	game.sync_mouse_mode()
	await process_frame
	await snap("hud_training_1280")
	game.menu.show_station(station)
	await process_frame
	await snap("menu_roles_1280")
	game.menu.close()
	game.cookbook.toggle()
	await process_frame
	await snap("book_during_lesson_1280")
	game.cookbook.close()
	var clone := preload("res://scripts/cook_avatar.gd").new()
	game.add_child(clone)
	clone.global_position = station.to_global(Vector3(0, 0, 1.6))
	clone.perform({"position": [clone.position.x, clone.position.y, clone.position.z], "yaw": PI, "pitch": -0.25, "presentation": {"book": true, "page": "potato"}}, Vector3.ZERO, false)
	game.player.global_position = clone.global_position + Vector3(0.2, 0.35, 1.4)
	game.player.look_at(clone.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	game.camera.rotation.x = -0.12
	await process_frame
	await snap("clone_reading_1280")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	game.cookbook.toggle()
	game.cookbook.select("wine")
	await process_frame
	await snap("book_wine_1920")
	print("PASS: cookbook captures")
	quit(0)
