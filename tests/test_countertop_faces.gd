extends SceneTree

func collect_vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var result := PackedVector3Array()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		result.append_array(vertices)
	return result

func _initialize() -> void:
	var station := preload("res://scenes/stations/counter_station.tscn").instantiate()
	var failed := false
	var top := station.get_node_or_null("Table/MainTop") as MeshInstance3D
	var corner := station.get_node_or_null("Table/BrokenCorner") as MeshInstance3D
	var frame := station.get_node_or_null("Table/FrameModel") as MeshInstance3D
	var shelf := station.get_node_or_null("ProductShelf/ShelfVisual") as MeshInstance3D
	var body := station.get_node_or_null("Table/MainBody") as StaticBody3D
	var collider := station.get_node_or_null("Table/MainBody/CollisionShape3D") as CollisionShape3D
	if top == null or corner == null or frame == null or shelf == null or body == null or collider == null: failed = true
	if top != null:
		if not (top.mesh is ArrayMesh): failed = true
		if top.mesh is BoxMesh: failed = true
		if top.material_override == null or top.material_override.cull_mode != BaseMaterial3D.CULL_BACK: failed = true
		var box := top.mesh.get_aabb()
		if box.size.x < 4.29 or box.size.z < 2.24 or box.size.y < 0.17: failed = true
	if corner != null:
		if not (corner.mesh is ArrayMesh): failed = true
		if corner.mesh is BoxMesh: failed = true
		if corner.material_override == null or corner.material_override.cull_mode != BaseMaterial3D.CULL_BACK: failed = true
		var vertices := collect_vertices(corner.mesh as ArrayMesh)
		var low := INF
		var high := -INF
		for vertex in vertices:
			low = minf(low, vertex.y)
			high = maxf(high, vertex.y)
		if high < 0.99 or low > 0.44 or high - low < 0.54: failed = true
	if frame != null:
		if not (frame.mesh is ArrayMesh): failed = true
		if (frame.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() < 100: failed = true
	if shelf != null:
		if not (shelf.mesh is ArrayMesh): failed = true
		if (shelf.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() < 100: failed = true
	if collider != null:
		if not (collider.shape is BoxShape3D): failed = true
		else:
			var shape := collider.shape as BoxShape3D
			if shape.size.distance_to(Vector3(4.3, 0.18, 2.25)) > 0.001: failed = true
			if collider.position.distance_to(Vector3(0.18, 0.925, 0)) > 0.001: failed = true
	station.free()
	print("PASS: product counter mesh keeps the authored broken corner and collision contract" if not failed else "FAIL: counter station product geometry")
	quit(1 if failed else 0)
