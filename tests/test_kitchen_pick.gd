extends SceneTree
const Model = preload("res://scripts/cooking_model.gd")
const Kitchen = preload("res://scripts/kitchen_props.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func aim(camera: Camera3D, target: Vector3) -> void:
	camera.global_position = target + Vector3(0, 0.45, 1.4)
	camera.look_at(target)

func run() -> void:
	var kitchen: Node3D = Kitchen.new()
	root.add_child(kitchen)
	var camera := Camera3D.new()
	root.add_child(camera)
	await process_frame
	var model := Model.new()
	model.reset("sausage")
	model.pick_up("sausage_0")
	# Sit the sausage in front of the pan, beside the handle, where the old
	# oversized pan AABB used to steal the ray.
	model.move_item("sausage", Model.PAN_CENTER + Vector2(0.45, 0.92))
	model.put_down()
	kitchen.update_view(model)
	aim(camera, kitchen.sausage_nodes[0].position + Vector3(0, 0.10, 0))
	check(kitchen.pick_item(camera, "all") == "sausage_0", "Ray aimed at a sausage in front of the pan selects the sausage")
	aim(camera, kitchen.pan.position)
	check(kitchen.pick_item(camera, "all") == "pan", "Ray aimed at the pan body still selects the pan")
	aim(camera, kitchen.pan.to_global(Vector3(0, 0.03, 0.82)))
	check(kitchen.pick_item(camera, "all") == "pan", "Ray aimed at the pan handle still selects the pan")
	print("PASS: pan picking follows body and handle, not nearby food" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
