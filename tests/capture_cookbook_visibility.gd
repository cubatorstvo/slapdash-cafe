extends SceneTree
var failed := false

func _initialize() -> void: run.call_deferred()

func wait_frames(count: int) -> void:
	for _i in range(count): await process_frame

func set_view(size: Vector2i) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(size)
	root.size = size
	await wait_frames(3)

func snap(name: String, expected: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != expected:
		failed = true
		printerr("FAIL capture size: ", name, " got ", image.get_size() if image != null else Vector2i.ZERO)
		return
	var path := "/tmp/cookbook-%s.png" % name
	var error := image.save_png(path)
	if error != OK:
		failed = true
		printerr("FAIL save: ", path, " error=", error)
	else:
		print("CAPTURE: ", path)

func run() -> void:
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await wait_frames(3)
	game.set_physics_process(false)
	game.menu.close()
	game.camera.rotation.x = 0.52
	game.service.progress.stars = 4
	game.service.feature_access.refresh_facts()
	game.cookbook.toggle()
	await create_timer(0.40).timeout
	await set_view(Vector2i(1280, 800))
	await snap("index-1280x800", Vector2i(1280, 800))
	await set_view(Vector2i(1920, 1080))
	await snap("index-1920x1080", Vector2i(1920, 1080))
	game.cookbook.select("solyanka")
	await create_timer(0.40).timeout
	if not game.cookbook.physical.surfaces[0].visible or not game.cookbook.physical.surfaces[1].visible:
		failed = true
		printerr("FAIL: readable surface hidden after page-turn animation")
	await set_view(Vector2i(1280, 800))
	await snap("solyanka-1280x800", Vector2i(1280, 800))
	await set_view(Vector2i(1920, 1080))
	await snap("solyanka-1920x1080", Vector2i(1920, 1080))
	game.queue_free()
	await process_frame
	print("PASS: cookbook captures" if not failed else "FAILED")
	quit(1 if failed else 0)
