extends Node3D

const TOP_Y := 1.015
const TOP_THICKNESS := 0.16
const BROKEN_DROP := 0.40

var mat_top: StandardMaterial3D
var mat_side: StandardMaterial3D
var mat_break: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_accent: StandardMaterial3D
var mat_tray: StandardMaterial3D
var mat_shelf: StandardMaterial3D
var mat_rubber: StandardMaterial3D

func _ready() -> void:
	build_into(self, true)

func build_into(parent: Node3D, include_accessories := true) -> void:
	if parent.has_node("ProductVisual"):
		return
	_make_materials()
	_build_station(parent, include_accessories)

func _make_materials() -> void:
	mat_top = _material(Color(0.929, 0.859, 0.714), 0.0, 0.82)
	mat_side = _material(Color(0.565, 0.345, 0.220), 0.0, 0.88)
	mat_break = _material(Color(0.285, 0.145, 0.085), 0.0, 0.95)
	mat_metal = _material(Color(0.125, 0.205, 0.225), 0.35, 0.56)
	mat_accent = _material(Color(0.93, 0.66, 0.24), 0.08, 0.62)
	mat_tray = _material(Color(0.43, 0.54, 0.56), 0.48, 0.44)
	mat_shelf = _material(Color(0.62, 0.405, 0.265), 0.0, 0.88)
	mat_rubber = _material(Color(0.055, 0.065, 0.067), 0.0, 0.96)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _build_station(parent: Node3D, include_accessories: bool) -> void:
	var visual := Node3D.new()
	visual.name = "ProductVisual"
	parent.add_child(visual)

	_build_countertop(visual)
	_build_frame(visual)
	if include_accessories:
		_build_serving_tray(visual)
		_build_crockery_shelf(visual)
		_build_product_shelf(parent)

func _build_countertop(parent: Node3D) -> void:
	var intact := PackedVector3Array([
		Vector3(-2.15, TOP_Y, -1.125),
		Vector3(2.04, TOP_Y, -1.125),
		Vector3(2.15, TOP_Y, -1.015),
		Vector3(2.15, TOP_Y, 1.015),
		Vector3(2.04, TOP_Y, 1.125),
		Vector3(0.10, TOP_Y, 1.125)
	])
	_add_extruded_polygon(parent, "IntactCountertop", intact, TOP_THICKNESS, mat_top, mat_side)

	var crack_normal := Vector3(-0.707106, 0.0, 0.707106) * 0.025
	var broken := PackedVector3Array([
		Vector3(-2.15, TOP_Y, -1.125) + crack_normal,
		Vector3(0.10, TOP_Y, 1.125) + crack_normal,
		Vector3(-2.15, TOP_Y - BROKEN_DROP, 1.125)
	])
	_add_extruded_polygon(parent, "BrokenCornerFlap", broken, TOP_THICKNESS, mat_top, mat_break)

	_add_beam(parent, "FractureShadow", Vector3(-2.02, 0.84, -0.99), Vector3(-0.05, 0.84, 0.98), 0.045, 0.075, mat_break)
	_add_beam(parent, "UnderBraceBroken", Vector3(-1.80, 0.36, 0.76), Vector3(-0.64, 0.84, 0.17), 0.075, 0.075, mat_metal)
	_add_bolt(parent, "BreakBoltA", Vector3(-1.68, 0.92, -0.64), 0.052, 0.035, mat_metal)
	_add_bolt(parent, "BreakBoltB", Vector3(-0.64, 0.99, 0.39), 0.052, 0.035, mat_metal)

func _build_frame(parent: Node3D) -> void:
	_add_tapered_leg(parent, "LeftRearLeg", Vector3(-1.86, 0.855, -0.88), Vector3(-1.93, 0.07, -0.92), 0.085, 0.065, mat_metal)
	_add_tapered_leg(parent, "RightRearLeg", Vector3(1.86, 0.855, -0.88), Vector3(1.93, 0.07, -0.92), 0.085, 0.065, mat_metal)
	_add_tapered_leg(parent, "RightFrontLeg", Vector3(1.86, 0.855, 0.88), Vector3(1.95, 0.07, 0.94), 0.085, 0.065, mat_metal)
	_add_tapered_leg(parent, "DamagedFrontLeg", Vector3(-1.83, 0.58, 0.90), Vector3(-2.02, 0.07, 1.02), 0.085, 0.065, mat_metal)

	_add_beam(parent, "RearUpperRail", Vector3(-1.82, 0.80, -0.90), Vector3(1.82, 0.80, -0.90), 0.075, 0.065, mat_metal)
	_add_beam(parent, "RightUpperRail", Vector3(1.88, 0.80, -0.82), Vector3(1.88, 0.80, 0.82), 0.075, 0.065, mat_metal)
	_add_beam(parent, "FrontUpperRail", Vector3(0.16, 0.79, 0.92), Vector3(1.84, 0.79, 0.92), 0.075, 0.065, mat_metal)
	_add_beam(parent, "RearLowerRail", Vector3(-1.86, 0.24, -0.90), Vector3(1.86, 0.24, -0.90), 0.065, 0.065, mat_metal)
	_add_beam(parent, "RightLowerRail", Vector3(1.92, 0.24, -0.86), Vector3(1.94, 0.24, 0.88), 0.065, 0.065, mat_metal)

	_add_box(parent, "FrontAccentPanel", Vector3(1.04, 0.765, 1.145), Vector3(1.92, 0.18, 0.07), mat_accent)
	_add_box(parent, "FrontAccentCap", Vector3(0.17, 0.765, 1.145), Vector3(0.22, 0.18, 0.07), mat_accent)
	_add_bolt(parent, "AccentBolt1", Vector3(0.35, 0.79, 1.187), 0.032, 0.022, mat_metal, Vector3.RIGHT)
	_add_bolt(parent, "AccentBolt2", Vector3(1.72, 0.79, 1.187), 0.032, 0.022, mat_metal, Vector3.RIGHT)

	for x in [-1.93, 1.93]:
		for z in [-0.92, 0.94]:
			if x < 0.0 and z > 0.0:
				continue
			_add_foot(parent, "Foot_%s_%s" % [x, z], Vector3(x, 0.035, z))

	_add_foot(parent, "Foot_Damaged", Vector3(-2.02, 0.035, 1.02))

func _build_serving_tray(parent: Node3D) -> void:
	var center := Vector3(1.35, 1.027, -0.15)
	_add_box(parent, "TrayBase", center, Vector3(1.16, 0.035, 1.54), mat_tray)
	_add_box(parent, "TrayLipLeft", center + Vector3(-0.57, 0.035, 0), Vector3(0.035, 0.085, 1.54), mat_tray)
	_add_box(parent, "TrayLipRight", center + Vector3(0.57, 0.035, 0), Vector3(0.035, 0.085, 1.54), mat_tray)
	_add_box(parent, "TrayLipRear", center + Vector3(0, 0.035, -0.76), Vector3(1.12, 0.085, 0.035), mat_tray)
	_add_box(parent, "TrayLipFront", center + Vector3(0, 0.035, 0.76), Vector3(1.12, 0.085, 0.035), mat_tray)
	_add_bolt(parent, "TrayRivetA", center + Vector3(-0.50, 0.070, -0.69), 0.025, 0.018, mat_metal)
	_add_bolt(parent, "TrayRivetB", center + Vector3(0.50, 0.070, 0.69), 0.025, 0.018, mat_metal)

func _build_crockery_shelf(parent: Node3D) -> void:
	var center := Vector3(1.50, 0.365, 1.35)
	_add_box(parent, "CrockeryShelf", center, Vector3(1.30, 0.07, 0.66), mat_shelf)
	_add_box(parent, "CrockeryFrontLip", center + Vector3(0, 0.055, 0.305), Vector3(1.30, 0.10, 0.05), mat_accent)
	_add_beam(parent, "CrockeryBracketL", Vector3(1.03, 0.08, 1.23), Vector3(1.03, 0.33, 1.48), 0.045, 0.045, mat_metal)
	_add_beam(parent, "CrockeryBracketR", Vector3(1.97, 0.08, 1.23), Vector3(1.97, 0.33, 1.48), 0.045, 0.045, mat_metal)

func _build_product_shelf(root_node: Node3D) -> void:
	var shelf := root_node.get_node_or_null("ProductShelf") as Node3D
	if shelf == null:
		return

	for y in [0.32, 0.82, 1.37]:
		_add_box(shelf, "ShelfBoard_%s" % y, Vector3(0, y, 0), Vector3(1.10, 0.06, 0.55), mat_shelf)
		_add_box(shelf, "ShelfLip_%s" % y, Vector3(0, y + 0.055, 0.255), Vector3(1.10, 0.07, 0.04), mat_accent)

	for x in [-0.49, 0.49]:
		for z in [-0.235, 0.235]:
			_add_tapered_leg(shelf, "ShelfPost_%s_%s" % [x, z], Vector3(x, 1.43, z), Vector3(x, 0.05, z), 0.035, 0.028, mat_metal)

	_add_beam(shelf, "ShelfBackBraceA", Vector3(-0.47, 0.12, -0.245), Vector3(0.47, 1.32, -0.245), 0.035, 0.03, mat_metal)
	_add_beam(shelf, "ShelfBackBraceB", Vector3(0.47, 0.12, -0.245), Vector3(-0.47, 1.32, -0.245), 0.035, 0.03, mat_metal)

func _add_extruded_polygon(parent: Node3D, node_name: String, top: PackedVector3Array, thickness: float, top_material: Material, side_material: Material) -> MeshInstance3D:
	var mesh := ArrayMesh.new()

	var top_surface := SurfaceTool.new()
	top_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, top.size() - 1):
		top_surface.add_vertex(top[0])
		top_surface.add_vertex(top[i + 1])
		top_surface.add_vertex(top[i])
	top_surface.generate_normals()
	top_surface.commit(mesh)

	var lower := PackedVector3Array()
	for point in top:
		lower.append(point - Vector3(0, thickness, 0))

	var side_surface := SurfaceTool.new()
	side_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, lower.size() - 1):
		side_surface.add_vertex(lower[0])
		side_surface.add_vertex(lower[i])
		side_surface.add_vertex(lower[i + 1])
	for i in range(top.size()):
		var next := (i + 1) % top.size()
		side_surface.add_vertex(top[i])
		side_surface.add_vertex(top[next])
		side_surface.add_vertex(lower[next])
		side_surface.add_vertex(top[i])
		side_surface.add_vertex(lower[next])
		side_surface.add_vertex(lower[i])
	side_surface.generate_normals()
	side_surface.commit(mesh)

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.set_surface_override_material(0, top_material)
	instance.set_surface_override_material(1, side_material)
	parent.add_child(instance)
	return instance

func _add_tapered_leg(parent: Node3D, node_name: String, top_center: Vector3, bottom_center: Vector3, top_half: float, bottom_half: float, material: Material) -> MeshInstance3D:
	var top := PackedVector3Array([
		top_center + Vector3(-top_half, 0, -top_half),
		top_center + Vector3(top_half, 0, -top_half),
		top_center + Vector3(top_half, 0, top_half),
		top_center + Vector3(-top_half, 0, top_half)
	])
	var bottom := PackedVector3Array([
		bottom_center + Vector3(-bottom_half, 0, -bottom_half),
		bottom_center + Vector3(bottom_half, 0, -bottom_half),
		bottom_center + Vector3(bottom_half, 0, bottom_half),
		bottom_center + Vector3(-bottom_half, 0, bottom_half)
	])

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.add_vertex(top[0]); surface.add_vertex(top[2]); surface.add_vertex(top[1])
	surface.add_vertex(top[0]); surface.add_vertex(top[3]); surface.add_vertex(top[2])
	surface.add_vertex(bottom[0]); surface.add_vertex(bottom[1]); surface.add_vertex(bottom[2])
	surface.add_vertex(bottom[0]); surface.add_vertex(bottom[2]); surface.add_vertex(bottom[3])
	for i in range(4):
		var next := (i + 1) % 4
		surface.add_vertex(top[i]); surface.add_vertex(top[next]); surface.add_vertex(bottom[next])
		surface.add_vertex(top[i]); surface.add_vertex(bottom[next]); surface.add_vertex(bottom[i])
	surface.generate_normals()

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _add_beam(parent: Node3D, node_name: String, from: Vector3, to: Vector3, width: float, depth: float, material: Material) -> MeshInstance3D:
	var direction := to - from
	var length := direction.length()
	var up := direction / maxf(length, 0.0001)
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.0001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var forward := side.cross(up).normalized()

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, length, depth)

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = (from + to) * 0.5
	instance.basis = Basis(side, up, forward)
	parent.add_child(instance)
	return instance

func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance

func _add_bolt(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, axis := Vector3.UP) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	if axis != Vector3.UP:
		var up := axis.normalized()
		var side := up.cross(Vector3.FORWARD)
		if side.length_squared() < 0.0001:
			side = up.cross(Vector3.RIGHT)
		side = side.normalized()
		instance.basis = Basis(side, up, side.cross(up).normalized())
	parent.add_child(instance)
	return instance

func _add_foot(parent: Node3D, node_name: String, position: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.095
	mesh.bottom_radius = 0.11
	mesh.height = 0.07
	mesh.radial_segments = 8
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = mat_rubber
	instance.position = position
	parent.add_child(instance)
