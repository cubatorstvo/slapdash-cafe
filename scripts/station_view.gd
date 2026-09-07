extends Node3D

const Props = preload("res://scripts/props.gd")
const TABLE_HEIGHT := 1.32
const WINE_COLOR := Color("ba4058")

var jug: Node3D
var jug_body: Node3D
var cup: Node3D
var rag: Node3D
var cup_liquid: MeshInstance3D
var rag_surface: MeshInstance3D
var jug_liquid: MeshInstance3D
var stream: MeshInstance3D
var target_ring: MeshInstance3D
var spill_meshes: Array[MeshInstance3D] = []
var fill_label: Label3D
var worker: Node3D
var left_hand: MeshInstance3D
var right_hand: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var is_production := false

func build(production: bool) -> void:
	is_production = production
	var accent := Color("72c1b0") if production else Color("efb65b")
	Props.box(self, Vector3(4.3, 0.18, 2.25), Vector3(0, 1.2, 0), Color("a76f4e"))
	Props.box(self, Vector3(4.16, 0.07, 2.10), Vector3(0, 1.325, 0), Color("eddbb6"))
	for x in [-1.85, 1.85]:
		for z in [-0.85, 0.85]:
			Props.box(self, Vector3(0.13, 1.15, 0.13), Vector3(x, 0.575, z), Color("244047"))
	Props.box(self, Vector3(4.3, 0.25, 0.08), Vector3(0, 1.10, 1.14), accent)
	Props.text(self, "02 / ПРОИЗВОДСТВО" if production else "01 / ПОКАЖИ КАК", Vector3(0, 0.99, 1.20), 25, Color("19353b"))
	# Work boundary markings also make the recording's spatial limits legible.
	for z in [-0.96, 0.96]:
		Props.box(self, Vector3(3.9, 0.007, 0.018), Vector3(0, 1.365, z), accent.darkened(0.25))
	for x in [-1.95, 1.95]:
		Props.box(self, Vector3(0.018, 0.007, 1.94), Vector3(x, 1.365, 0), accent.darkened(0.25))
	_build_jug()
	_build_cup()
	rag = Node3D.new()
	add_child(rag)
	rag_surface = Props.box(rag, Vector3(0.43, 0.055, 0.30), Vector3(0, 0.045, 0), Color("eac26b"))
	for i in range(4):
		Props.box(rag, Vector3(0.025, 0.008, 0.29), Vector3(-0.15 + i * 0.10, 0.076, 0), Color("bc924e"))
	stream = Props.line(self, Vector3.ZERO, Vector3.UP, 0.026, WINE_COLOR)
	stream.visible = false
	var ring := TorusMesh.new()
	ring.inner_radius = 0.14
	ring.outer_radius = 0.18
	target_ring = Props.shape(self, ring, Vector3.ZERO, Color("f3a963"))
	target_ring.visible = false
	fill_label = Props.text(self, "0 / 250 мл", Vector3(0, 2.2, 0), 23, Color("ffffff"))
	fill_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if production:
		_build_worker()

func _build_jug() -> void:
	jug = Node3D.new()
	add_child(jug)
	jug_body = Node3D.new()
	jug.add_child(jug_body)
	jug_body.position.y = 0.48
	Props.cylinder(jug_body, 0.35, 0.68, Vector3(0, -0.06, 0), Color("c77751"), 0.30)
	Props.cylinder(jug_body, 0.305, 0.08, Vector3(0, 0.31, 0), Color("f0c587"))
	jug_liquid = Props.cylinder(jug_body, 0.264, 0.013, Vector3(0, 0.36, 0), WINE_COLOR)
	Props.box(jug_body, Vector3(0.19, 0.12, 0.19), Vector3(0.32, 0.30, 0), Color("c77751"))
	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = 0.15
	handle_mesh.outer_radius = 0.23
	var handle := Props.shape(jug_body, handle_mesh, Vector3(-0.40, 0.03, 0), Color("f0c587"))
	handle.rotation.x = PI * 0.5
	Props.text(jug_body, "1 L", Vector3(0, -0.04, 0.36), 20, Color("fff0c9"))

func _build_cup() -> void:
	cup = Node3D.new()
	add_child(cup)
	Props.cylinder(cup, 0.26, 0.05, Vector3(0, 0.03, 0), Color("73acae"))
	# Thin glass ribs keep the volume visible in the Compatibility renderer.
	for index in range(12):
		var angle := index * TAU / 12.0
		Props.cylinder(cup, 0.012, 0.44, Vector3(cos(angle) * 0.235, 0.27, sin(angle) * 0.235), Color("b9e1dc"))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.224
	rim.outer_radius = 0.25
	Props.shape(cup, rim, Vector3(0, 0.50, 0), Color("d7efdf"))
	cup_liquid = Props.cylinder(cup, 0.218, 1.0, Vector3.ZERO, WINE_COLOR)
	# Target fill mark.
	var mark := TorusMesh.new()
	mark.inner_radius = 0.24
	mark.outer_radius = 0.255
	Props.shape(cup, mark, Vector3(0, 0.446, 0), Color("efb65b"))

func _build_worker() -> void:
	worker = Node3D.new()
	add_child(worker)
	worker.position = Vector3(0, 0, -1.38)
	for x in [-0.16, 0.16]:
		Props.box(worker, Vector3(0.19, 0.66, 0.21), Vector3(x, 0.43, 0), Color("243940"))
		Props.box(worker, Vector3(0.23, 0.15, 0.38), Vector3(x, 0.10, 0.09), Color("172c32"))
	Props.box(worker, Vector3(0.66, 0.65, 0.38), Vector3(0, 1.03, 0), Color("63aa98"))
	Props.box(worker, Vector3(0.43, 0.56, 0.045), Vector3(0, 0.94, 0.22), Color("f4dcad"))
	Props.ball(worker, 0.25, Vector3(0, 1.64, 0), Color("edb68b"))
	Props.cylinder(worker, 0.28, 0.22, Vector3(0, 1.89, 0), Color("f8eacd"))
	for x in [-0.085, 0.085]:
		Props.ball(worker, 0.031, Vector3(x, 1.69, 0.225), Color("25363d"))
	Props.box(worker, Vector3(0.10, 0.02, 0.02), Vector3(0, 1.55, 0.24), Color("794f41"))
	left_hand = Props.ball(self, 0.09, Vector3.ZERO, Color("edb68b"))
	right_hand = Props.ball(self, 0.09, Vector3.ZERO, Color("edb68b"))
	left_arm = Props.line(self, Vector3.ZERO, Vector3.UP, 0.065, Color("63aa98"))
	right_arm = Props.line(self, Vector3.ZERO, Vector3.UP, 0.065, Color("63aa98"))

func update_view(model, animation_time := 0.0, resting := false) -> void:
	jug.position = item_point(model.jug)
	jug_body.rotation.z = -deg_to_rad(model.tilt)
	cup.position = item_point(model.cup)
	rag.position = item_point(model.rag)
	if model.held == "jug": jug.position.y += 0.70
	if model.held == "rag" and model.squeezing: rag.position.y += 0.72
	jug_liquid.visible = model.wine > 0.1
	var height: float = maxf(0.003, model.filled / 250.0 * 0.43)
	cup_liquid.visible = model.filled > 0.1
	cup_liquid.scale.y = height
	cup_liquid.position.y = 0.052 + height * 0.5
	rag_surface.material_override.albedo_color = Color("eac26b").lerp(WINE_COLOR, model.soaked / 300.0)
	rag.scale = Vector3(0.7, 1.2, 0.8) if model.squeezing else Vector3.ONE
	fill_label.position = cup.position + Vector3(0, 0.83, 0)
	fill_label.text = "%d / 250 мл" % roundi(model.filled)
	fill_label.modulate = Color("8bf1b9") if model.success() else Color("ffffff")
	for mesh in spill_meshes:
		mesh.visible = false
	for index in range(model.puddles.size()):
		if index == spill_meshes.size():
			spill_meshes.append(Props.cylinder(self, 1.0, 0.008, Vector3.ZERO, WINE_COLOR.darkened(0.12)))
		var data: Array = model.puddles[index]
		var mesh := spill_meshes[index]
		mesh.visible = true
		mesh.position = Vector3(data[0], TABLE_HEIGHT + 0.055, data[1])
		var radius := clampf(sqrt(float(data[2])) * 0.026, 0.025, 0.34)
		mesh.scale = Vector3(radius, 1.0, radius * 0.8)
	target_ring.visible = not is_production and model.held == "jug"
	var aim: Vector2 = model.spout_target()
	target_ring.position = item_point(aim) + Vector3(0, 0.063, 0)
	target_ring.material_override.albedo_color = Color("6fd7ae") if aim.distance_to(model.cup) <= 0.24 else Color("e9a164")
	stream.visible = model.flowing or model.squeezing
	if stream.visible:
		var start := jug.position + jug_body.position + jug_body.basis * Vector3(0.40, 0.30, 0)
		if model.squeezing: start = rag.position + Vector3(0, 0.02, 0)
		var end: Vector3 = item_point(model.landing) + Vector3(0, 0.07, 0)
		if model.landing.distance_to(model.cup) <= 0.24: end.y += 0.43
		Props.align_line(stream, start, end)
	if is_production:
		_update_worker(model, animation_time, resting)

func _update_worker(model, time: float, resting: bool) -> void:
	var target := Vector3(0.0, 1.35, -0.45)
	match model.held:
		"jug": target = jug.position + Vector3(0, 0.35, 0)
		"cup": target = cup.position + Vector3(0, 0.22, 0)
		"rag": target = rag.position + Vector3(0, 0.06, 0)
	worker.position.x = clampf(target.x, -1.4, 1.4)
	if resting:
		target = worker.position + Vector3(0.0, 1.2 + sin(time * 2.0) * 0.03, 0.32)
	left_hand.position = target + Vector3(-0.16, 0, 0)
	right_hand.position = target + Vector3(0.16, 0, 0)
	Props.align_line(left_arm, worker.position + Vector3(-0.32, 1.24, 0), left_hand.position)
	Props.align_line(right_arm, worker.position + Vector3(0.32, 1.24, 0), right_hand.position)

func item_point(point: Vector2) -> Vector3:
	return Vector3(point.x, TABLE_HEIGHT + 0.05, point.y)

func pick_item(camera: Camera3D, mouse: Vector2) -> String:
	var selected := ""
	var nearest := 65.0
	for entry in [["jug", jug, 0.40], ["cup", cup, 0.25], ["rag", rag, 0.04]]:
		var node: Node3D = entry[1]
		var point := camera.unproject_position(node.global_position + Vector3(0, entry[2], 0))
		var distance := point.distance_to(mouse)
		if distance < nearest:
			nearest = distance
			selected = entry[0]
	return selected
