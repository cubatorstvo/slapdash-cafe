extends SceneTree

func _initialize() -> void:
	var station := preload("res://scenes/stations/counter_station.tscn").instantiate()
	var failed := false
	var top := station.get_node_or_null("Table/MainTop") as MeshInstance3D
	var corner := station.get_node_or_null("Table/BrokenCorner") as MeshInstance3D
	var body := station.get_node_or_null("Table/MainBody") as StaticBody3D
	var collider := station.get_node_or_null("Table/MainBody/CollisionShape3D") as CollisionShape3D
	if top == null or corner == null or body == null or collider == null: failed = true
	if top != null:
		if not (top.mesh is BoxMesh): failed = true
		if top.material_override == null or top.material_override.cull_mode != BaseMaterial3D.CULL_BACK: failed = true
	if corner != null:
		if not (corner.mesh is BoxMesh): failed = true
		if corner.material_override == null or corner.material_override.cull_mode != BaseMaterial3D.CULL_BACK: failed = true
		if absf(corner.rotation.z) < 0.01: failed = true
	if collider != null and not (collider.shape is BoxShape3D): failed = true
	station.free()
	print("PASS: authored countertop top, broken corner and collision use backface-culling scene geometry" if not failed else "FAIL: authored countertop scene geometry")
	quit(1 if failed else 0)
