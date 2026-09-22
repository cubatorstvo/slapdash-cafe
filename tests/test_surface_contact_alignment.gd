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
	root.add_child(sofa_scene)
	var seat := sofa_scene.get_node("SeatLeft") as Marker3D
	var seat_top := seat.position.y
	var actor_scene := preload("res://scenes/actors/cook_avatar.tscn").instantiate() as Node3D
	root.add_child(actor_scene)
	var body := actor_scene.get_node("Body") as MeshInstance3D
	var body_box := body.get_aabb()
	var body_bottom := body.position.y + body_box.position.y * body.scale.y
	var sofa_spot := LoungeLayout.rest_spot(0, 0, ["sofa"])
	check(absf(float(sofa_spot.position.y)) < 0.001, "Sofa clone root stays on floor datum")
	check(absf(body_bottom + float(sofa_spot.position.y) - seat_top) < 0.04, "Seated clone torso starts at sofa seat surface: body %.3f seat %.3f" % [body_bottom + float(sofa_spot.position.y), seat_top])

	kitchen.free()
	sofa_scene.free()
	actor_scene.free()
	print("PASS: food contact origins and sofa clone seating align with authored surfaces" if failures == 0 else "FAILED: %d surface alignment checks" % failures)
	quit(1 if failures > 0 else 0)
