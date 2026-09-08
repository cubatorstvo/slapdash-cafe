extends Node3D
const Avatar = preload("res://scripts/cook_avatar.gd")
var students: Array = []
var returning := false
var on_return := Callable()
var target: Node3D

func begin(names: Array, starts: Array, desk: Node3D, watching: Node3D, callback: Callable, return_points: Array = []) -> void:
	clear_now()
	target = watching
	on_return = callback
	returning = false
	for i in range(names.size()):
		var actor := Avatar.new()
		add_child(actor)
		actor.position = starts[i]
		actor.caption.text = names[i] + "\nЗаписывает…"
		var seat := desk.to_global(Vector3((i - (names.size() - 1) * 0.5) * 1.15, 0, -1.7))
		var side := desk.to_global(Vector3(-3.4 if i == 0 else 3.4, 0, -1.7))
		var home: Vector3 = return_points[i] if return_points.size() > i else starts[i]
		var home_exit := Vector3(14.85 if home.x > 9 else home.x + 2.55, 0, home.z)
		var start_exit := Vector3(14.85 if starts[i].x > 9 else starts[i].x + 2.55, 0, starts[i].z)
		students.append({"actor": actor, "home": home, "exit": home_exit, "seat": seat, "path": [start_exit, Vector3(start_exit.x, 0, 2.6), Vector3(side.x, 0, 2.6), side, seat], "back": side})

func finish() -> void:
	returning = true
	for entry in students:
		entry.actor.notebook.hide()
		entry.actor.caption.text = entry.actor.caption.text.split("\n")[0] + "\nК заказам"
		entry.path = [entry.back, Vector3(entry.back.x, 0, 2.6), Vector3(entry.exit.x, 0, 2.6), entry.exit, entry.home]

func clear_now() -> void:
	for entry in students: entry.actor.queue_free()
	students.clear()
	if on_return.is_valid(): on_return.call()
	on_return = Callable()
	returning = false

func advance(delta: float) -> void:
	var complete := returning
	for i in range(students.size()):
		var entry: Dictionary = students[i]
		if not entry.path.is_empty():
			if entry.actor.walk_to(entry.path[0], delta): entry.path.pop_front()
			complete = false
		elif not returning:
			entry.actor.rotation.y = PI
			var neighbor: Vector3 = students[(i + 1) % students.size()].actor.position + Vector3(0, 1.5, 0) if students.size() > 1 else target.global_position
			entry.actor.observe(target.global_position + Vector3(0, 1.5, 0), neighbor, delta, i)
	if complete: clear_now()
