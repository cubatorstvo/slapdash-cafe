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

func run() -> void:
	await set_view(Vector2i(1280, 800))
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
	game.hud.hide()
	game.service.hide()
	var clone := preload("res://scripts/cook_avatar.gd").new()
	game.add_child(clone)
	clone.perform({"position": [6.2, 0.0, 3.4], "yaw": 0.55, "pitch": -0.3, "presentation": {"book": true, "page": "potato"}}, Vector3.ZERO, false)
	var book_at: Vector3 = clone.book.global_position
	var right: Vector3 = clone.global_transform.basis.x
	var forward: Vector3 = -clone.global_transform.basis.z
	# Beside the reader, looking down onto the spread so page text is readable.
	var camera_at: Vector3 = clone.global_position + Vector3(0, 1.62, 0) + right * 0.82 + forward * 0.28
	look_at_point(game, camera_at, book_at + Vector3(0, 0.02, 0))
	game.camera.fov = 52.0
	await wait_frames(0.5)
	await snap("clone_reading_1280")
	clone.queue_free()
	game.hud.show()
	game.service.show()
	game.camera.fov = 78.0
	await set_view(Vector2i(1920, 1080))
	game.player.global_position = Vector3(0, 0.02, 2.4)
	game.player.rotation.y = 0
	game.camera.rotation.x = -0.15
	game.cookbook.toggle()
	await process_frame
	await snap("book_index_1920")
	game.cookbook.select("meal")
	await process_frame
	await snap("book_meal_1920")
	print("PASS: cookbook captures")
	quit(0)
