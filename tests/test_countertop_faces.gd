extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var failed := false
	var station := preload("res://scenes/stations/counter_station.tscn").instantiate()
	root.add_child(station)
	await process_frame

	if station.get_script() != null:
		failed = true
	var visual := station.get_node_or_null("ProductVisual") as MeshInstance3D
	if visual == null or visual.mesh == null:
		failed = true
	else:
		var bounds := visual.mesh.get_aabb()
		if bounds.size.x < 4.2 or bounds.size.z < 2.2 or bounds.size.y < 0.9:
			failed = true
		if visual.mesh.get_surface_count() < 4:
			failed = true

	var collider := station.get_node_or_null("Table/MainBody/CollisionShape3D") as CollisionShape3D
	if collider == null or not (collider.shape is BoxShape3D):
		failed = true
	elif (collider.shape as BoxShape3D).size != Vector3(4.3, 0.18, 2.25):
		failed = true

	var gameplay_station := preload("res://scripts/station_view.gd").new()
	root.add_child(gameplay_station)
	gameplay_station.build(false)
	await process_frame
	var runtime_visual := gameplay_station.get_node_or_null("ProductVisual") as MeshInstance3D
	if runtime_visual == null or runtime_visual.mesh == null:
		failed = true

	print("PASS: counter station art is authored in the scene and survives runtime scene composition" if not failed else "FAIL: counter station scene-authored visual")
	gameplay_station.queue_free()
	station.queue_free()
	await process_frame
	quit(1 if failed else 0)
