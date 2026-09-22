extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var room := Node3D.new()
	root.add_child(room)
	var avatar: Node3D = load("res://scripts/cook_avatar.gd").new()
	room.add_child(avatar)
	await process_frame
	var failed := false
	avatar.lounge_pose({"pose": "chat", "position": Vector3(5.95, -0.1, 14.45), "yaw": 0.0, "id": "sofa_left"}, 1.2, 3)
	failed = failed or not _arms_stay_on_body(avatar, "chat")
	failed = failed or not _seated_legs_stay_with_the_body(avatar)
	avatar.perform({"position": [0, 0, 0], "yaw": 0.0, "pitch": 0.1}, Vector3(0.2, 0.9, -0.4), true)
	failed = failed or not _arms_stay_on_body(avatar, "work")
	avatar.sleep_pose({"position": Vector3(6, 0.7, 14), "sleep_kind": "back", "sleep_rotation": Vector3.ZERO, "yaw": 0.0}, 0.4, 2)
	failed = failed or not _arms_stay_on_body(avatar, "sleep")
	print("CLONE ARMS: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _arms_stay_on_body(avatar: Node3D, label: String) -> bool:
	var ok := true
	for i in 2:
		var arm: MeshInstance3D = avatar.arms[i]
		var pivot := arm.get_parent() as Node3D
		var hand := pivot.get_node("Hand") as Node3D
		var side := -1.0 if i == 0 else 1.0
		var shoulder: Vector3 = avatar.to_global(Vector3(side * 0.3, 1.2, 0))
		var center_gap: float = arm.global_position.distance_to((shoulder + hand.global_position) * 0.5)
		var reach: float = shoulder.distance_to(hand.global_position)
		print(label, " arm", i, " reach=", snappedf(reach, 0.001), " center_gap=", snappedf(center_gap, 0.001))
		if reach > 1.35 or center_gap > 0.05:
			ok = false
	return ok

func _seated_legs_stay_with_the_body(avatar: Node3D) -> bool:
	var ok := true
	for part in avatar.lounge_legs.get_children():
		var at: Vector3 = (part as Node3D).position
		print("seated leg ", at)
		if at.z < -0.45 or at.y > 0.8:
			ok = false
	return ok
