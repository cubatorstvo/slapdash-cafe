extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	get_root().size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.075, 0.085, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.78)
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	world.add_child(environment_node)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(13.0, 13.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.16, 0.17, 0.18)
	floor_material.roughness = 0.96
	floor.material_override = floor_material
	world.add_child(floor)

	var station := preload("res://scripts/station_view.gd").new()
	world.add_child(station)
	station.build(false)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	key.light_energy = 1.65
	key.shadow_enabled = true
	world.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.3, 3.7, 3.0)
	fill.light_energy = 4.2
	fill.omni_range = 8.0
	world.add_child(fill)

	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.current = true
	camera.position = Vector3(-5.7, 3.3, 5.4)
	camera.look_at(Vector3(-0.35, 0.68, 0.25), Vector3.UP)
	world.add_child(camera)

	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var result := image.save_png("/tmp/counter_runtime.png")
	if result != OK:
		push_error("Failed to save runtime counter preview")
		quit(1)
		return
	print("PASS: runtime counter preview saved")
	quit()
