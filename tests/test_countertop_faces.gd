extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var station := preload("res://scenes/stations/counter_station.tscn").instantiate()
	root.add_child(station)
	await process_frame

	var failed := false
	var top := station.get_node_or_null("ProductVisual/IntactCountertop") as MeshInstance3D
	var corner := station.get_node_or_null("ProductVisual/BrokenCornerFlap") as MeshInstance3D
	var body := station.get_node_or_null("Table/MainBody") as StaticBody3D
	var collider := station.get_node_or_null("Table/MainBody/CollisionShape3D") as CollisionShape3D

	if top == null or corner == null or body == null or collider == null:
		failed = true
	if top != null:
		if not (top.mesh is ArrayMesh):
			failed = true
		elif top.mesh.get_surface_count() != 2:
			failed = true
	if corner != null:
		if not (corner.mesh is ArrayMesh):
			failed = true
		else:
			var bounds := corner.mesh.get_aabb()
			if bounds.size.y < 0.50:
				failed = true
			if corner.mesh.get_surface_count() != 2:
				failed = true
	if collider != null and not (collider.shape is BoxShape3D):
		failed = true
	if station.get_node_or_null("ProductVisual/UnderBraceBroken") == null:
		failed = true
	if station.get_node_or_null("ProductVisual/DamagedFrontLeg") == null:
		failed = true

	print("PASS: product countertop uses custom broken-corner geometry and keeps authored collision" if not failed else "FAIL: product countertop geometry")
	station.queue_free()
	await process_frame
	quit(1 if failed else 0)
