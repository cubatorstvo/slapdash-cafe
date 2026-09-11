extends SceneTree
const View = preload("res://scripts/station_view.gd")
func _initialize() -> void:
	var view = View.new()
	view._build_countertop_structure(Color.WHITE, Color.BROWN, Color.BLACK)
	var counter: MeshInstance3D = view.get_node("Countertop")
	var top: Array = counter.mesh.surface_get_arrays(0)
	var sides: Array = counter.mesh.surface_get_arrays(1)
	var failed := false
	# Generated normals must face outward, including the sloped top.
	for normal in top[Mesh.ARRAY_NORMAL]:
		if normal.y <= 0.8: failed = true
	var vertices: PackedVector3Array = sides[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = sides[Mesh.ARRAY_NORMAL]
	for i in range(vertices.size()):
		if i < 9:
			if normals[i].y >= -0.8: failed = true
		else:
			var outward := Vector3(vertices[i].x, 0, vertices[i].z)
			if normals[i].dot(outward) <= 0: failed = true
	for surface in range(2):
		if counter.get_surface_override_material(surface).cull_mode != BaseMaterial3D.CULL_BACK: failed = true
	view.free()
	print("PASS: countertop top, bottom and walls face outward with backface culling" if not failed else "FAIL: inward countertop face")
	quit(1 if failed else 0)
