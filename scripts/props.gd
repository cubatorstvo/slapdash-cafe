extends RefCounted
## Small original procedural props: the prototype has no external asset dependency.

static func material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.68
	result.metallic = metallic
	return result

static func box(parent: Node3D, size: Vector3, point: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return shape(parent, mesh, point, color)

static func solid_box(parent: Node3D, size: Vector3, point: Vector3, color: Color) -> StaticBody3D:
	box(parent, size, point, color)
	return collision_box(parent, size, point)

static func collision_box(parent: Node3D, size: Vector3, point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	parent.add_child(body)
	body.position = point
	var collider := CollisionShape3D.new()
	var shape_box := BoxShape3D.new()
	shape_box.size = size
	collider.shape = shape_box
	body.add_child(collider)
	return body

static func cylinder(parent: Node3D, radius: float, height: float, point: Vector3, color: Color, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	return shape(parent, mesh, point, color)

static func ball(parent: Node3D, radius: float, point: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return shape(parent, mesh, point, color)

static func shape(parent: Node3D, mesh: Mesh, point: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = point
	return node

static func text(parent: Node3D, value: String, point: Vector3, size := 40, color := Color("f6e6c9")) -> Label3D:
	var node := Label3D.new()
	node.text = value
	node.font_size = size
	node.pixel_size = 0.009
	node.modulate = color
	node.outline_size = 4
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
	node.scale.y = maxf(length, 0.001) / (node.mesh as CylinderMesh).height
	if length > 0.001:
		node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
