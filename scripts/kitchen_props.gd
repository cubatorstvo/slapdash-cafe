extends Node3D
const Props = preload("res://scripts/props.gd")
const Model = preload("res://scripts/cooking_model.gd")
var pick_distance := 3.6
# Interaction bounds follow the visible pan: a close rectangular body plus a
# separate narrow handle. The old single AABB covered empty space around both.
const PAN_BODY_BOUNDS := AABB(Vector3(-0.80, -0.04, -0.65), Vector3(1.60, 0.10, 1.30))
const PAN_HANDLE_BOUNDS := AABB(Vector3(-0.08, -0.02, 0.60), Vector3(0.16, 0.09, 0.44))
var potato_nodes: Array = []
var potato_bodies: Array = []
var potato_patches: Array = []
var sausage_nodes: Array = []
var sausage_skins: Array = []
var sausage_meshes: Array = []
var potato_set: Node3D
var sausage_set: Node3D
var pan: Node3D
var potato: Node3D
var potato_body: Node3D
var potato_sides: Array[MeshInstance3D] = []
var sausage: Node3D
var sausage_skin: MeshInstance3D
var sausage_mesh := ArrayMesh.new()
var tube_indices := PackedInt32Array()

func _ready() -> void:
	potato_set = Node3D.new()
	add_child(potato_set)
	sausage_set = Node3D.new()
	add_child(sausage_set)
	_build_pan()
	for i in range(3):
		potato_sides = []
		_build_potato()
		potato_nodes.append(potato)
		potato_bodies.append(potato_body)
		potato_patches.append(potato_sides)
		sausage_mesh = ArrayMesh.new()
		tube_indices = PackedInt32Array()
		_build_sausage()
		sausage_nodes.append(sausage)
		sausage_skins.append(sausage_skin)
		sausage_meshes.append(sausage_mesh)

func point(at: Vector2, height := 0.0) -> Vector3:
	return Vector3(at.x, Model.BASE_Y + height, at.y)

func _build_pan() -> void:
	for x in [-0.65, 0.65]:
		for z in [-0.52, 0.52]: Props.box(potato_set, Vector3(0.12, 0.16, 0.12), point(Model.PAN_CENTER + Vector2(x, z), 0.08), Color("293d44"))
	var burner := TorusMesh.new()
	burner.inner_radius = 0.42
	burner.outer_radius = 0.47
	Props.shape(potato_set, burner, point(Model.PAN_CENTER, 0.06), Color("ec9459"))
	pan = Node3D.new()
	potato_set.add_child(pan)
	pan.position = point(Model.PAN_CENTER, Model.PAN_LIFT)
	# Actual missing bottom tiles: the holes remain open in the rendered geometry.
	for x in range(10):
		for z in range(8):
			var hole := (x in [2, 3] and z in [4, 5]) or (x in [6, 7] and z in [2, 3])
			if hole: continue
			Props.box(pan, Vector3(0.151, 0.035, 0.151), Vector3(-0.675 + x * 0.15, -0.018, -0.525 + z * 0.15), Color("53656b"))
	for x in [-0.77, 0.77]: Props.box(pan, Vector3(0.045, 0.07, 1.26), Vector3(x, 0.015, 0), Color("83928d"))
	for z in [-0.62, 0.62]: Props.box(pan, Vector3(1.58, 0.07, 0.045), Vector3(0, 0.015, z), Color("83928d"))
	Props.box(pan, Vector3(0.14, 0.07, 0.42), Vector3(0, 0.03, 0.82), Color("a77050"))
	for hole in Model.HOLES:
		for x in [-0.16, 0.16]: Props.box(pan, Vector3(0.016, 0.005, 0.32), Vector3(hole.x + x, 0.004, hole.y), Color("f0ae61"))
		for z in [-0.16, 0.16]: Props.box(pan, Vector3(0.32, 0.005, 0.016), Vector3(hole.x, 0.004, hole.y + z), Color("f0ae61"))

func _build_potato() -> void:
	potato = Node3D.new()
	potato_set.add_child(potato)
	potato_body = Node3D.new()
	potato.add_child(potato_body)
	potato_body.position.y = 0.14
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.radius = 1
	mesh.height = 2
	var body := Props.shape(potato_body, mesh, Vector3.ZERO, Color("d9ac68"))
	body.scale = Vector3(0.22, 0.14, 0.15)
	for index in range(6):
		var side: Vector3 = Model.FACES[index]
		var patch := Props.ball(potato_body, 0.085, side * Vector3(0.198, 0.128, 0.137), Color("dcaf70"))
		patch.scale = Vector3(0.25 if side.x else 1.0, 0.25 if side.y else 0.80, 0.25 if side.z else 0.9)
		potato_sides.append(patch)
	for index in range(9):
		var angle := index * 2.4
		Props.ball(potato_body, 0.009, Vector3(cos(angle) * 0.19, sin(angle * 1.7) * 0.085, sin(angle) * 0.13), Color("947049"))

func _build_sausage() -> void:
	if sausage_nodes.is_empty():
		Props.cylinder(sausage_set, 0.36, 0.07, point(Model.SAUCE_CENTER, 0.04), Color("e2c39a"))
		Props.cylinder(sausage_set, 0.325, 0.012, point(Model.SAUCE_CENTER, 0.082), Color("b63249"))
		var label := Props.text(sausage_set, "СОУС", point(Model.SAUCE_CENTER + Vector2(0, -0.43), 0.01), 18, Color("b53c50"))
		label.rotation.x = -PI / 2
	sausage = Node3D.new()
	sausage_set.add_child(sausage)
	sausage_skin = Props.shape(sausage, sausage_mesh, Vector3.ZERO, Color("cd8869"))
	for ring in range(16):
		for side in range(10):
			var a := ring * 10 + side
			var b := ring * 10 + (side + 1) % 10
			for index in [a, a + 10, b, b, a + 10, b + 10]: tube_indices.append(index)

func _bend_sausage(phase: float, amplitude: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for ring in range(17):
		var along := ring / 16.0
		var radius := maxf(0.001, pow(sin(along * PI), 0.3) * 0.072)
		var centre := Vector3(-0.3 + along * 0.6, 0.075 + sin(phase + along * 5) * amplitude, cos(phase * 0.7 + along * 5) * amplitude)
		for side in range(10):
			var angle := side / 10.0 * TAU
			var normal := Vector3(0, cos(angle), sin(angle))
			vertices.append(centre + normal * radius)
			normals.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = tube_indices
	sausage_mesh.clear_surfaces()
	sausage_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func update_view(model) -> void:
	potato_set.visible = true
	sausage_set.visible = true
	pan.rotation = Vector3(model.pan_tilt.y, 0, -model.pan_tilt.x)
	model._store_food("potato")
	model._store_food("sausage")
	for i in range(3):
		var p: Dictionary = model.potatoes[i]
		potato_nodes[i].position = point(p.potato, p.elevation)
		potato_bodies[i].quaternion = p.potato_orientation
		var orientation := Basis(p.potato_orientation)
		potato_bodies[i].position.y = Vector3(orientation.x.y * 0.22, orientation.y.y * 0.14, orientation.z.y * 0.15).length()
		for face in range(6): potato_patches[i][face].material_override.albedo_color = Color("dcaf70").lerp(Color("875034"), float(p.potato_heat[face]))
		var f: Dictionary = model.sausages[i]
		sausage_nodes[i].position = point(f.sausage, f.elevation)
		sausage_nodes[i].rotation.z = f.sausage_angle
		sausage_nodes[i].position.y += absf(sin(f.sausage_angle)) * 0.30
		sausage_mesh = sausage_meshes[i]
		_bend_sausage(f.sausage_phase, 0.018 + f.sausage_slip * 0.05)
		sausage_skins[i].material_override.albedo_color = Color("cd8869").lerp(Color("b8324a"), f.sausage_coating)
	potato = potato_nodes[model.potato_index]
	sausage = sausage_nodes[model.sausage_index]

func pick_item(camera: Camera3D, dish: String) -> String:
	var entries: Array = []
	for i in range(3):
		entries.append(["potato_%d" % i, potato_nodes[i], [AABB(Vector3(-0.25, 0, -0.22), Vector3(0.5, 0.40, 0.44))]])
		entries.append(["sausage_%d" % i, sausage_nodes[i], [AABB(Vector3(-0.37, -0.03, -0.13), Vector3(0.74, 0.25, 0.26))]])
	entries.append(["pan", pan, [PAN_BODY_BOUNDS, PAN_HANDLE_BOUNDS]])
	var selected := ""
	var nearest := 3.6
	for entry in entries:
		var node: Node3D = entry[1]
		var origin := node.to_local(camera.global_position)
		var direction := node.global_basis.inverse() * -camera.global_basis.z
		for bounds in entry[2]:
			var hit = bounds.intersects_ray(origin, direction)
			if hit == null: continue
			var distance := camera.global_position.distance_to(node.to_global(hit))
			if distance < nearest:
				nearest = distance
				selected = entry[0]
	pick_distance = nearest
	return selected
