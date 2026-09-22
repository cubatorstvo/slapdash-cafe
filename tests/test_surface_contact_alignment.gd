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
	var authored_sausage := kitchen.sausage_bodies[0] as Node3D
	var sausage_meshes := authored_sausage.find_children("*", "MeshInstance3D", true, false)
	check(sausage_meshes.size() == 1, "Sausage scene uses one continuous visible mesh")
	check(authored_sausage.get_node_or_null("Skin") != null, "Sausage continuous mesh is authored as Skin in sausage.tscn")
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
	var left_bounds := mesh_world_aabb(seat_left)
	var seat_top := left_bounds.end.y
	var body := actor_scene.get_node("Body") as MeshInstance3D
	var body_bounds := mesh_world_aabb(body)
	var back := sofa_scene.get_node("Back") as MeshInstance3D
	var back_front := mesh_world_aabb(back).position.z
	check(absf(body_bounds.position.y - seat_top) < 0.02, "Seated clone sits on the cushion: body %.3f seat %.3f" % [body_bounds.position.y, seat_top])
	check(absf((back_front - body_bounds.end.z) - 0.03) < 0.015, "Clone back stays 3 cm from the sofa backrest: gap %.3f" % [back_front - body_bounds.end.z])
	for leg_name in ["LeftLeg", "RightLeg"]:
		var leg := actor_scene.get_node(leg_name) as Node3D
		check(leg.visible, leg_name + " uses the scene leg")
		check(absf(leg.rotation.x - PI * 0.5) < 0.02, leg_name + " points straight forward")
		var shoe := mesh_world_aabb(leg.get_node("Shoe") as MeshInstance3D)
		check(shoe.position.z < body_bounds.position.z - 0.2, leg_name + " sticks straight out in front of the torso")

	kitchen.free()
	sofa_scene.free()
	actor_scene.free()
	print("PASS: food contact origins and sofa clone seating align with authored surfaces" if failures == 0 else "FAILED: %d surface alignment checks" % failures)
	quit(1 if failures > 0 else 0)
