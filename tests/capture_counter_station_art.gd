extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	get_root().size = Vector2i(1280, 720)

	var world := Node3D.new()
	world.name = "PreviewWorld"
	root.add_child(world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.075, 0.085, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.78)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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

	var station := preload("res://scenes/stations/counter_station.tscn").instantiate()
	world.add_child(station)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	key.light_energy = 1.65
	key.shadow_enabled = true
	world.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.3, 3.7, 3.0)
	fill.light_energy = 4.2
	fill.omni_range = 8.0
	fill.shadow_enabled = true
	world.add_child(fill)

	var rim := OmniLight3D.new()
	rim.position = Vector3(4.0, 2.4, -3.5)
	rim.light_energy = 2.8
	rim.omni_range = 8.0
	world.add_child(rim)

	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.current = true
	world.add_child(camera)

	var output_dir := ProjectSettings.globalize_path("res://artifacts/counter_station")
	DirAccess.make_dir_recursive_absolute(output_dir)

	await process_frame
	await process_frame
	await process_frame

	var views := [
		{"name": "01_chef_broken_corner", "pos": Vector3(-5.7, 3.3, 5.4), "target": Vector3(-0.35, 0.68, 0.25)},
		{"name": "02_customer_side", "pos": Vector3(5.7, 2.8, -5.0), "target": Vector3(-0.25, 0.70, 0.15)},
		{"name": "03_high_detail", "pos": Vector3(-4.6, 5.6, 2.8), "target": Vector3(-0.40, 0.68, 0.20)}
	]

	for view in views:
		camera.position = view.pos
		camera.look_at(view.target, Vector3.UP)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := get_root().get_texture().get_image()
		var result := image.save_png(output_dir.path_join(view.name + ".png"))
		if result != OK:
			push_error("Failed to save preview %s: %s" % [view.name, result])
			quit(1)
			return

	print("PASS: counter station previews saved")
	quit()
