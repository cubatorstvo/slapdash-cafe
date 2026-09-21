extends Node3D
const Props = preload("res://scripts/props.gd")
const Model = preload("res://scripts/cooking_model.gd")
var pan_supports: Array = []
var sauce_nodes: Array = []
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
var sausage_segments: Array = []
var potato_set: Node3D
var sausage_set: Node3D
var pan: Node3D
var potato: Node3D
var potato_body: Node3D
var potato_sides: Array[MeshInstance3D] = []
var sausage: Node3D
var sausage_skin: MeshInstance3D

func _ready() -> void:
	var runtime = preload("res://scripts/scene_runtime.gd")
	potato_set = Node3D.new()
	add_child(potato_set)
	sausage_set = Node3D.new()
	add_child(sausage_set)
	var support := runtime.instantiate("res://scenes/props/pan_support.tscn") as Node3D
	potato_set.add_child(support)
	support.position = Vector3(Model.PAN_CENTER.x, 0, Model.PAN_CENTER.y)
	pan = runtime.instantiate("res://scenes/props/holed_pan.tscn") as Node3D
	potato_set.add_child(pan)
	pan.position = point(Model.PAN_CENTER, Model.PAN_LIFT)
	pan_supports = [support, pan]
	var sauce := runtime.instantiate("res://scenes/props/sauce_bowl.tscn") as Node3D
	sausage_set.add_child(sauce)
	sauce.position = point(Model.SAUCE_CENTER, 0.0)
	sauce_nodes = [sauce]
	for i in range(3):
		var potato_holder := Node3D.new()
		potato_set.add_child(potato_holder)
		var potato_scene := runtime.instantiate("res://scenes/props/potato.tscn") as Node3D
		potato_holder.add_child(potato_scene)
		potato_nodes.append(potato_holder)
		potato_bodies.append(potato_scene)
		var patches: Array = []
		for face in range(6):
			var patch := potato_scene.get_node("SidePatch%d" % (face + 1)) as MeshInstance3D
			var mat := patch.material_override.duplicate() as StandardMaterial3D
			patch.material_override = mat
			patches.append(patch)
		potato_patches.append(patches)
		var sausage_holder := Node3D.new()
		sausage_set.add_child(sausage_holder)
		var sausage_scene := runtime.instantiate("res://scenes/props/sausage.tscn") as Node3D
		sausage_holder.add_child(sausage_scene)
		var segments: Array = [sausage_scene.get_node("LeftSegment"), sausage_scene.get_node("CenterSegment"), sausage_scene.get_node("RightSegment")]
		for segment in segments:
			var mat := (segment as MeshInstance3D).material_override.duplicate() as StandardMaterial3D
			(segment as MeshInstance3D).material_override = mat
		sausage_nodes.append(sausage_holder)
		sausage_segments.append(segments)
		sausage_skins.append(segments[1])
	potato = potato_nodes[0]
	potato_body = potato_bodies[0]
	sausage = sausage_nodes[0]
	sausage_skin = sausage_skins[0]

func point(at: Vector2, height := 0.0) -> Vector3:
	return Vector3(at.x, Model.BASE_Y + height, at.y)

func _bend_sausage(index: int, phase: float, amplitude: float) -> void:
	var segments: Array = sausage_segments[index]
	for part in range(segments.size()):
		var t: float = float(part - 1) * 0.20
		var node := segments[part] as MeshInstance3D
		node.position.y = sin(phase + part * 0.9) * amplitude
		node.position.z = cos(phase * 0.7 + part * 0.8) * amplitude
		node.rotation.z = sin(phase + part) * amplitude * 1.8

func update_view(model) -> void:
	potato_set.visible = true
	sausage_set.visible = true
	for node in pan_supports: node.visible = model.item_available("pan")
	for node in sauce_nodes: node.visible = "sauce" in model.equipment
	pan.rotation = Vector3(model.pan_tilt.y, 0, -model.pan_tilt.x)
	model._store_food("potato")
	model._store_food("sausage")
	for i in range(3):
		potato_nodes[i].visible = model.item_available("potato_%d" % i)
		sausage_nodes[i].visible = model.item_available("sausage_%d" % i)
		var p: Dictionary = model.potatoes[i]
		potato_nodes[i].position = point(p.potato, p.elevation)
		potato_bodies[i].quaternion = p.potato_orientation
		for face in range(6): potato_patches[i][face].material_override.albedo_color = Color("dcaf70").lerp(Color("875034"), float(p.potato_heat[face]))
		var f: Dictionary = model.sausages[i]
		sausage_nodes[i].position = point(f.sausage, f.elevation)
		sausage_nodes[i].rotation.z = f.sausage_angle
		sausage_nodes[i].position.y += absf(sin(f.sausage_angle)) * 0.30
		_bend_sausage(i, f.sausage_phase, 0.018 + f.sausage_slip * 0.05)
		for segment in sausage_segments[i]:
			(segment as MeshInstance3D).material_override.albedo_color = Color("cd8869").lerp(Color("b8324a"), f.sausage_coating)
	potato = potato_nodes[model.potato_index]
	potato_body = potato_bodies[model.potato_index]
	sausage = sausage_nodes[model.sausage_index]
	sausage_skin = sausage_skins[model.sausage_index]

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
		if not node.visible: continue
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

