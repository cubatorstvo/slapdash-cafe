extends RefCounted

static func instantiate(path: String, script: Script = null) -> Node:
	var packed: PackedScene = load(path)
	assert(packed != null, "Missing authored scene: " + path)
	var node := packed.instantiate()
	if script != null:
		node.set_script(script)
	return node

static func mesh(node: Node, path: NodePath) -> MeshInstance3D:
	return node.get_node(path) as MeshInstance3D

static func node3d(node: Node, path: NodePath) -> Node3D:
	return node.get_node(path) as Node3D

static func label3d(node: Node, path: NodePath) -> Label3D:
	return node.get_node(path) as Label3D

static func colorize(mesh: MeshInstance3D, color: Color) -> void:
	if mesh == null:
		return
	var material: Material = mesh.material_override
	if material == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		material = mesh.mesh.surface_get_material(0)
	if material is StandardMaterial3D:
		var instance := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		instance.albedo_color = color
		mesh.material_override = instance

static func ensure_children(target: Node, path: String) -> void:
	if target.get_child_count() > 0:
		return
	var source := instantiate(path)
	for child in source.get_children().duplicate():
		source.remove_child(child)
		child.owner = null
		target.add_child(child)
	source.free()
