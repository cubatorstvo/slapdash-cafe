extends RefCounted
## Small original procedural props: the prototype has no external asset dependency.

static var shared_meshes: Dictionary = {}

static func _shared_box(size: Vector3) -> BoxMesh:
	var key := "b|%.4f|%.4f|%.4f" % [size.x, size.y, size.z]
	if shared_meshes.has(key): return shared_meshes[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	shared_meshes[key] = mesh
	return mesh

static func _shared_cylinder(radius: float, height: float, top: float) -> CylinderMesh:
	var cap := radius if top < 0.0 else top
	var key := "c|%.4f|%.4f|%.4f" % [radius, height, cap]
	if shared_meshes.has(key): return shared_meshes[key]
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = cap
	mesh.height = height
	mesh.radial_segments = 32
	shared_meshes[key] = mesh
	return mesh

static func _shared_ball(radius: float) -> SphereMesh:
	var key := "s|%.4f" % radius
	if shared_meshes.has(key): return shared_meshes[key]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	shared_meshes[key] = mesh
	return mesh

static func material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.68
	result.metallic = metallic
	return result

static func box(parent: Node3D, size: Vector3, point: Vector3, color: Color) -> MeshInstance3D:
	var node := preload("res://scenes/runtime/box_mesh.tscn").instantiate() as MeshInstance3D
	node.mesh = _shared_box(size)
	node.material_override = material(color)
	parent.add_child(node)
	node.position = point
	return node

static func solid_box(parent: Node3D, size: Vector3, point: Vector3, color: Color) -> StaticBody3D:
	box(parent, size, point, color)
	return collision_box(parent, size, point)

static func collision_box(parent: Node3D, size: Vector3, point: Vector3) -> StaticBody3D:
	var body := preload("res://scenes/runtime/collision_box.tscn").instantiate() as StaticBody3D
	var collider := body.get_node("CollisionShape3D") as CollisionShape3D
	collider.shape = collider.shape.duplicate()
	(collider.shape as BoxShape3D).size = size
	parent.add_child(body)
	body.position = point
	return body

static func moving_solid_box(parent: Node3D, size: Vector3, point: Vector3, color: Color) -> AnimatableBody3D:
	var body := preload("res://scenes/runtime/moving_box.tscn").instantiate() as AnimatableBody3D
	var visual := body.get_node("Mesh") as MeshInstance3D
	visual.mesh = _shared_box(size)
	visual.material_override = material(color)
	var collider := body.get_node("CollisionShape3D") as CollisionShape3D
	collider.shape = collider.shape.duplicate()
	(collider.shape as BoxShape3D).size = size
	parent.add_child(body)
	body.position = point
	return body

static func cylinder(parent: Node3D, radius: float, height: float, point: Vector3, color: Color, top := -1.0) -> MeshInstance3D:
	var node := preload("res://scenes/runtime/cylinder_mesh.tscn").instantiate() as MeshInstance3D
	node.mesh = _shared_cylinder(radius, height, top)
	node.material_override = material(color)
	parent.add_child(node)
	node.position = point
	return node

static func ball(parent: Node3D, radius: float, point: Vector3, color: Color) -> MeshInstance3D:
	var node := preload("res://scenes/runtime/sphere_mesh.tscn").instantiate() as MeshInstance3D
	node.mesh = _shared_ball(radius)
	node.material_override = material(color)
	parent.add_child(node)
	node.position = point
	return node

static func shape(parent: Node3D, mesh: Mesh, point: Vector3, color: Color) -> MeshInstance3D:
	var node := preload("res://scenes/runtime/mesh_instance.tscn").instantiate() as MeshInstance3D
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = point
	return node

static func text(parent: Node3D, value: String, point: Vector3, size := 40, color := Color("f6e6c9")) -> Label3D:
	var node := preload("res://scenes/runtime/label3d.tscn").instantiate() as Label3D
	node.text = value
	node.font_size = size
	node.modulate = color
	parent.add_child(node)
	node.position = point
	return node

static func line(parent: Node3D, start: Vector3, end: Vector3, width: float, color: Color) -> MeshInstance3D:
	var result := cylinder(parent, width, maxf(start.distance_to(end), 0.001), (start + end) * 0.5, color)
	align_line(result, start, end)
	return result

static func align_line(node: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	node.position = (start + end) * 0.5
	var length := start.distance_to(end)
	if node.mesh is CylinderMesh:
		node.scale.y = maxf(length, 0.001) / maxf((node.mesh as CylinderMesh).height, 0.001)
	elif node.mesh is BoxMesh:
		node.scale.y = maxf(length, 0.001) / maxf((node.mesh as BoxMesh).size.y, 0.001)
	if length > 0.001:
		node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
