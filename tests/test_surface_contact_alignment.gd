extends SceneTree

const KitchenProps = preload("res://scripts/kitchen_props.gd")
const Model = preload("res://scripts/cooking_model.gd")
const LoungeLayout = preload("res://scripts/lounge_layout.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func mesh_min_y(root_node: Node3D) -> float:
	var result := INF
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if not mesh.visible or mesh.mesh == null: continue
		var box := mesh.get_aabb()
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					result = minf(result, root_node.to_local(mesh.to_global(Vector3(x, y, z))).y)
	return result

func mesh_world_aabb(mesh: MeshInstance3D) -> AABB:
	var box := mesh.get_aabb()
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				var point := mesh.to_global(Vector3(x, y, z))
				minimum = Vector3(minf(minimum.x, point.x), minf(minimum.y, point.y), minf(minimum.z, point.z))
				maximum = Vector3(maxf(maximum.x, point.x), maxf(maximum.y, point.y), maxf(maximum.z, point.z))
	return AABB(minimum, maximum - minimum)

func aabb_overlap(a: AABB, b: AABB) -> Vector3:
	var minimum := Vector3(maxf(a.position.x, b.position.x), maxf(a.position.y, b.position.y), maxf(a.position.z, b.position.z))
	var maximum := Vector3(minf(a.end.x, b.end.x), minf(a.end.y, b.end.y), minf(a.end.z, b.end.z))
	return Vector3(maxf(0.0, maximum.x - minimum.x), maxf(0.0, maximum.y - minimum.y), maxf(0.0, maximum.z - minimum.z))

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var kitchen := KitchenProps.new()
	root.add_child(kitchen)
	await process_frame
	var model := Model.new()
	model.reset("potato")
	kitchen.update_view(model)
	var potato_holder := kitchen.potato_nodes[0] as Node3D
	var potato_surface := Model.food_surface("potato", model.potatoes[0].potato)
	var potato_bottom := potato_holder.position.y + mesh_min_y(potato_holder)
	check(absf(potato_bottom - potato_surface) < 0.025, "Potato visible bottom sits on shelf surface: bottom %.3f surface %.3f" % [potato_bottom, potato_surface])

	var orientations := [Quaternion.IDENTITY, Quaternion(Vector3(0, 0, 1), PI / 2.0), Quaternion(Vector3(1, 0, 1).normalized(), 0.75)]
	for q in orientations:
		model.potatoes[0].potato_orientation = q
		kitchen.update_view(model)
		potato_bottom = potato_holder.position.y + mesh_min_y(potato_holder)
		check(potato_bottom >= potato_surface - 0.025, "Rotated potato stays above support: %.3f >= %.3f" % [potato_bottom, potato_surface])
		check(potato_bottom <= potato_surface + 0.040, "Rotated potato remains visually in contact: %.3f <= %.3f" % [potato_bottom, potato_surface])

	model.reset("sausage")
	kitchen.update_view(model)
	var sausage_holder := kitchen.sausage_nodes[0] as Node3D
	var sausage_surface := Model.food_surface("sausage", model.sausages[0].sausage)
	var sausage_bottom := sausage_holder.position.y + mesh_min_y(sausage_holder)
	check(absf(sausage_bottom - sausage_surface) < 0.035, "Sausage visible bottom sits on shelf surface: bottom %.3f surface %.3f" % [sausage_bottom, sausage_surface])
	for angle in [0.0, 0.45, 0.9, PI / 2.0]:
		model.sausages[0].sausage_angle = angle
		kitchen.update_view(model)
		sausage_bottom = sausage_holder.position.y + mesh_min_y(sausage_holder)
		check(sausage_bottom >= sausage_surface - 0.035, "Tilted sausage stays above support: %.3f >= %.3f" % [sausage_bottom, sausage_surface])
		check(sausage_bottom <= sausage_surface + 0.060, "Tilted sausage remains visually in contact: %.3f <= %.3f" % [sausage_bottom, sausage_surface])

	var sofa_scene := preload("res://scenes/lounge/sofa.tscn").instantiate() as Node3D
	sofa_scene.position = LoungeLayout.item_position("sofa", 0)
	root.add_child(sofa_scene)
	var actor_scene := preload("res://scripts/cook_avatar.gd").new() as Node3D
	root.add_child(actor_scene)
	await process_frame
	var sofa_spot := LoungeLayout.rest_spot(0, 0, ["sofa"])
	actor_scene.call("lounge_pose", sofa_spot, 0.0, 0)
	await process_frame
	var seat_left := sofa_scene.get_node("SeatL") as MeshInstance3D
	var seat_right := sofa_scene.get_node("SeatR") as MeshInstance3D
	var left_bounds := mesh_world_aabb(seat_left)
	var right_bounds := mesh_world_aabb(seat_right)
	var seat_top := left_bounds.end.y
	var seat_front := minf(left_bounds.position.z, right_bounds.position.z)
	var body := actor_scene.get_node("Body") as MeshInstance3D
	var body_bottom := mesh_world_aabb(body).position.y
	check(absf(float(sofa_spot.position.y) - 0.03) < 0.001, "Sofa clone root is raised 3 cm above floor datum")
	check(absf(float(sofa_spot.position.z) - (sofa_scene.position.z - 0.37)) < 0.001, "Sofa clone root is shifted 12 cm toward the cushion edge")
	check(body_bottom >= seat_top - 0.005 and body_bottom <= seat_top + 0.06, "Seated clone torso stays just above sofa seat: body %.3f seat %.3f" % [body_bottom, seat_top])
	var sofa_legs := actor_scene.get("lounge_sofa_legs") as Node3D
	check(is_instance_valid(sofa_legs) and sofa_legs.visible, "Sofa-specific seated legs are active")
	if is_instance_valid(sofa_legs):
		var leg_meshes := sofa_legs.find_children("*", "MeshInstance3D", true, false)
		check(leg_meshes.size() == 6, "Sofa pose has two thighs, two shins and two shoes")
		for leg_mesh_raw in leg_meshes:
			var leg_mesh := leg_mesh_raw as MeshInstance3D
			var bounds := mesh_world_aabb(leg_mesh)
			for seat_bounds in [left_bounds, right_bounds]:
				var overlap := aabb_overlap(bounds, seat_bounds)
				if overlap.x > 0.001 and overlap.z > 0.001:
					check(overlap.y <= 0.006, "Sofa leg does not sink into cushion volume: overlap %s" % overlap)
		for index in [1, 2, 4, 5]:
			if index >= leg_meshes.size(): continue
			var front_part := mesh_world_aabb(leg_meshes[index] as MeshInstance3D)
			check(front_part.end.z <= seat_front + 0.015, "Sofa shin/shoe stays in front of cushion: %.3f <= %.3f" % [front_part.end.z, seat_front + 0.015])

	kitchen.free()
	sofa_scene.free()
	actor_scene.free()
	print("PASS: food contact origins and sofa clone seating align with authored surfaces" if failures == 0 else "FAILED: %d surface alignment checks" % failures)
	quit(1 if failures > 0 else 0)
