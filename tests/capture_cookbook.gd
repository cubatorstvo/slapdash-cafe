extends SceneTree
## Rendered inspection helper. Run with a display: xvfb-run godot --path . --script tests/capture_cookbook.gd
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

func look_at_point(game: Node, camera_at: Vector3, target: Vector3) -> void:
	game.player.global_position = Vector3(camera_at.x, camera_at.y - 1.70, camera_at.z)
	var offset: Vector3 = target - camera_at
	game.player.rotation.y = atan2(-offset.x, -offset.z)
	game.camera.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())

func wait_frames(seconds: float) -> void:
	var wait := 0.0
	while wait < seconds:
		await process_frame
		wait += 1.0 / 60.0

func reset_reader(game: Node) -> void:
	game.player.global_position = Vector3(0, 0.02, 2.4)
	game.player.rotation.y = 0
	game.camera.rotation.x = -0.12
	game.camera.fov = 78.0

func apply_partial_meal(kitchen: Node) -> void:
	# Both kitchen zones stay live so inactive-zone restore does not zero pasta.
	kitchen.model.meat_sides = [1.0, 0.15]
	kitchen.model.meat_salt = 0.0
	kitchen.model.cooked = 0.0
	kitchen.model.pasta = 40
	kitchen.model.pasta_salt = 1.2
	kitchen.model.stirred = 0.0

func shot_clone(game: Node, tint: Color, page: String, filename: String, peer_view: bool) -> void:
	var clone := preload("res://scripts/cook_avatar.gd").new()
	clone.tint = tint
	game.add_child(clone)
	clone.perform({"position": [6.4, 0.0, 3.6], "yaw": 0.2, "pitch": -0.28, "presentation": {"book": true, "page": page}}, Vector3.ZERO, false)
	var origin: Vector3 = clone.global_position
	var right: Vector3 = clone.global_transform.basis.x
	var forward: Vector3 = -clone.global_transform.basis.z
	if peer_view:
		look_at_point(game, origin - forward * 2.15 + right * 1.85 + Vector3(0, 1.52, 0), origin + Vector3(0, 1.05, 0) + forward * 0.12)
	else:
		look_at_point(game, origin + right * 2.35 - forward * 0.35 + Vector3(0, 1.42, 0), origin + Vector3(0, 1.02, 0) + forward * 0.18)
	game.camera.fov = 50.0
	await wait_frames(0.4)
	await snap(filename)
	clone.queue_free()
	game.camera.fov = 78.0

func run() -> void:
	await set_view(Vector2i(1280, 800))
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.service.open_for_business = false
	reset_reader(game)
	game.cookbook.toggle()
	await wait_frames(0.3)
	await snap("playtest_index_1280")
	await snap("seq_01_open_index")
	for dish in ["wine", "potato", "sausage", "meal"]:
		game.cookbook.select(dish)
		await wait_frames(0.25)
		await snap("playtest_%s_1280" % dish)
		if dish == "meal": await snap("seq_02_select_recipe")
	game.cookbook.close()
	await wait_frames(0.15)
	await snap("seq_03_closed")
	var kitchen = game.service.by_id(4)
	game.service.request_training(kitchen, "meal", 1)
	kitchen.training.start_pass([1, 2])
	game.bind_training()
	game.menu.close()
	game.set_physics_process(false)
	apply_partial_meal(kitchen)
	reset_reader(game)
	game.player.global_position = kitchen.to_global(Vector3(-1.2, 0.02, 1.7))
	game.player.rotation.y = kitchen.global_rotation.y
	game.camera.rotation.x = -0.12
	game.cookbook.toggle()
	await wait_frames(0.35)
	apply_partial_meal(kitchen)
	game.cookbook.physical.set_live(kitchen.model)
	await wait_frames(0.05)
	print("LIVE: ", str(preload("res://scripts/cookbook_data.gd").components("meal", kitchen.model)))
	await snap("playtest_live_meal_1280")
	await snap("seq_04_lesson_open")
	game.cookbook.close()
	var bell_at: Vector3 = kitchen.bell.global_position
	look_at_point(game, game.player.global_position + Vector3(0, 1.70, 0), bell_at)
	apply_partial_meal(kitchen)
	game.refresh_hud()
	await wait_frames(0.08)
	await snap("playtest_bell_1280")
	await snap("seq_05_bell")
	kitchen.training.close()
	game.bind_training()
	game.hud.hide()
	game.service.hide()
	await shot_clone(game, Color("789fce"), "meal", "playtest_peer_book_1280", true)
	await shot_clone(game, Color("6cac9b"), "potato", "playtest_clone_replay_1280", false)
	game.hud.show()
	game.service.show()
	await set_view(Vector2i(1920, 1080))
	reset_reader(game)
	game.cookbook.toggle()
	await wait_frames(0.25)
	await snap("playtest_index_1920")
	game.cookbook.select("meal")
	await wait_frames(0.25)
	await snap("playtest_meal_1920")
	print("PASS: cookbook captures")
	quit(0)
