extends Node3D

const Props = preload("res://scripts/props.gd")
const Model = preload("res://scripts/cooking_model.gd")
const TABLE_HEIGHT := Model.SURFACE_Y
const WINE_COLOR := Color("ba4058")

var plates: Array = []
var tray_liquid: MeshInstance3D
var book: Node3D
var tomato: Node3D
var jug: Node3D
var jug_body: Node3D
var cup: Node3D
var rag: Node3D
var cup_liquid: MeshInstance3D
var rag_surface: MeshInstance3D
var jug_liquid: MeshInstance3D
var stream: MeshInstance3D
var target_ring: MeshInstance3D
var grip_marker: Node3D
var height_dashes: Array[MeshInstance3D] = []
var spill_meshes: Array[MeshInstance3D] = []
var fill_label: Label3D
var worker: Node3D
var head: Node3D
var left_hand: MeshInstance3D
var right_hand: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var is_production := false
var dish := "wine"
var name_label: Label3D
var station_label: Label3D
var kitchen: Node3D

func build(production: bool) -> void:
	is_production = production
	var accent := Color("72c1b0") if production else Color("efb65b")
	Props.box(self, Vector3(4.3, 0.18, 2.25), Vector3(0, 0.86, 0), Color("a76f4e"))
	Props.box(self, Vector3(4.16, 0.06, 2.10), Vector3(0, 0.97, 0), Color("eddbb6"))
	Props.collision_box(self, Vector3(4.3, 1.0, 2.25), Vector3(0, 0.5, 0))
	for x in [-1.85, 1.85]:
		for z in [-0.85, 0.85]:
			Props.box(self, Vector3(0.13, 0.83, 0.13), Vector3(x, 0.415, z), Color("244047"))
	Props.box(self, Vector3(4.3, 0.22, 0.08), Vector3(0, 0.78, 1.14), accent)
	station_label = Props.text(self, "КЛОН" if production else "ПОКАЖИ КАК", Vector3(0, 0.76, 1.20), 25, Color("19353b"))
	# Work boundary markings also make the recording's spatial limits legible.
	for z in [-0.96, 0.96]:
		Props.box(self, Vector3(3.9, 0.007, 0.018), Vector3(0, TABLE_HEIGHT + 0.004, z), accent.darkened(0.25))
	for x in [-1.95, 1.95]:
		Props.box(self, Vector3(0.018, 0.007, 1.94), Vector3(x, TABLE_HEIGHT + 0.004, 0), accent.darkened(0.25))
	tomato = Node3D.new()
	add_child(tomato)
	Props.ball(tomato, 0.12, Vector3(0, 0.12, 0), Color("d9483b"))
	Props.box(tomato, Vector3(0.12, 0.02, 0.04), Vector3(0, 0.24, 0), Color("6a9c56"))
	_build_jug()
	_build_cup()
	_build_storage_and_tray()
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
	_build_grip_marker()
	fill_label = Props.text(self, "0 / 300 мл", Vector3(0, 2.2, 0), 20, Color("ffffff"))
	fill_label.pixel_size = 0.004
	fill_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	kitchen = preload("res://scripts/kitchen_props.gd").new()
	add_child(kitchen)
	if production:
		_build_worker()

func _build_grip_marker() -> void:
	grip_marker = Node3D.new()
	add_child(grip_marker)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.31
	ring.outer_radius = 0.335
	var parts: Array[MeshInstance3D] = [Props.shape(grip_marker, ring, Vector3.ZERO, Color("76d7ff"))]
	parts.append(Props.box(grip_marker, Vector3(0.13, 0.006, 0.014), Vector3.ZERO, Color("76d7ff")))
	parts.append(Props.box(grip_marker, Vector3(0.014, 0.006, 0.13), Vector3.ZERO, Color("76d7ff")))
	for index in range(12):
		var dash := Props.line(self, Vector3.ZERO, Vector3.UP, 0.008, Color("76d7ff"))
		height_dashes.append(dash)
		parts.append(dash)
	for part in parts:
		part.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visible = false
	# Children follow the marker; dashes remain station-local at their actual heights.
	for child in grip_marker.get_children(): child.visible = true
	grip_marker.visible = false

func _update_grip_marker(model) -> void:
	grip_marker.visible = not is_production and not model.held.is_empty()
	for dash in height_dashes: dash.visible = false
	if not grip_marker.visible: return
	var point: Vector2 = model.get(model.held)
	grip_marker.position = Vector3(point.x, Model.surface_at(point) + 0.025, point.y)
	var radius_scale := 1.0 if model.held == "jug" else 0.85
	grip_marker.scale = Vector3(radius_scale, 1, radius_scale)
	var lift: float = model.elevations[model.held]
	for index in range(height_dashes.size()):
		var bottom := 0.025 + index * 0.09
		var top := minf(bottom + 0.045, lift)
		if top <= bottom: break
		var dash := height_dashes[index]
		dash.visible = true
		Props.align_line(dash, item_point(point) + Vector3.UP * bottom, item_point(point) + Vector3.UP * top)

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
	for level in [200.0, 250.0]:
		Props.shape(cup, mark, Vector3(0, 0.052 + level / 300.0 * 0.43, 0), Color("efb65b"))

func _build_worker() -> void:
	worker = Node3D.new()
	add_child(worker)
	worker.position = Vector3(0, 0, 1.8)
	worker.rotation.y = PI
	book = preload("res://scripts/book_prop.gd").new()
	worker.add_child(book)
	book.pose_in_hands(false, false)
	name_label = Props.text(worker, "Клон", Vector3(0, 2.25, 0), 22, Color("a6efdb"))
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	for x in [-0.16, 0.16]:
		Props.box(worker, Vector3(0.19, 0.66, 0.21), Vector3(x, 0.43, 0), Color("243940"))
		Props.box(worker, Vector3(0.23, 0.15, 0.38), Vector3(x, 0.10, 0.09), Color("172c32"))
	Props.box(worker, Vector3(0.66, 0.65, 0.38), Vector3(0, 1.03, 0), Color("63aa98"))
	Props.box(worker, Vector3(0.43, 0.56, 0.045), Vector3(0, 0.94, 0.22), Color("f4dcad"))
	head = Node3D.new()
	worker.add_child(head)
	head.position.y = 1.64
	Props.ball(head, 0.25, Vector3.ZERO, Color("edb68b"))
	Props.cylinder(head, 0.28, 0.22, Vector3(0, 0.25, 0), Color("f8eacd"))
	for x in [-0.085, 0.085]:
		Props.ball(head, 0.031, Vector3(x, 0.05, 0.225), Color("25363d"))
	Props.box(head, Vector3(0.10, 0.02, 0.02), Vector3(0, -0.09, 0.24), Color("794f41"))
	left_hand = Props.ball(self, 0.09, Vector3.ZERO, Color("edb68b"))
	right_hand = Props.ball(self, 0.09, Vector3.ZERO, Color("edb68b"))
	left_arm = Props.line(self, Vector3.ZERO, Vector3.UP, 0.065, Color("63aa98"))
	right_arm = Props.line(self, Vector3.ZERO, Vector3.UP, 0.065, Color("63aa98"))

func update_view(model, animation_time := 0.0, resting := false) -> void:
	dish = model.dish
	for i in range(plates.size()):
		plates[i].position = item_point(model.plates[i].point) + Vector3.UP * float(model.elevations["plate_%d" % i])
		plates[i].rotation.z = -float(model.plates[i].tilt)
	tray_liquid.visible = model.tray_wine > 0.01
	tray_liquid.scale = Vector3(clampf(sqrt(model.tray_wine / 225.0), 0.08, 1.0), 1, clampf(sqrt(model.tray_wine / 225.0), 0.08, 1.0))
	tomato.position = item_point(model.tomato) + Vector3.UP * model.elevations.tomato
	tomato.visible = not model.tomato_hit
	kitchen.update_view(model)
	for node in [jug, cup, rag, fill_label]: node.visible = true
	jug.position = item_point(model.jug)
	jug_body.rotation.z = -deg_to_rad(model.tilt)
	cup.position = item_point(model.cup)
	cup.rotation.z = -deg_to_rad(model.vessels.cup.angle)
	rag.position = item_point(model.rag)
	jug.position.y += model.elevations.jug
	cup.position.y += model.elevations.cup
	cup.position += Vector3.UP * 0.25 - cup.basis * Vector3.UP * 0.25
	rag.position.y += model.elevations.rag
	jug_liquid.visible = model.wine > 0.1
	var height: float = maxf(0.003, model.filled / 300.0 * 0.43)
	cup_liquid.visible = model.filled > 0.1
	cup_liquid.scale.y = height
	cup_liquid.position.y = 0.052 + height * 0.5
	rag_surface.material_override.albedo_color = Color("eac26b").lerp(WINE_COLOR, model.soaked / 300.0)
	rag.scale = Vector3(0.7, 1.2, 0.8) if model.squeezing else Vector3.ONE
	fill_label.position = cup.position + Vector3(0, 0.65, 0)
	fill_label.text = "%d / 300 мл" % roundi(model.filled)
	fill_label.modulate = Color("8bf1b9") if model.success() else Color("ffffff")
	_update_grip_marker(model)
	for mesh in spill_meshes:
		mesh.visible = false
	for index in range(model.puddles.size()):
		if index == spill_meshes.size():
			spill_meshes.append(Props.cylinder(self, 1.0, 0.008, Vector3.ZERO, WINE_COLOR.darkened(0.12)))
		var data: Array = model.puddles[index]
		var mesh := spill_meshes[index]
		mesh.visible = true
		mesh.position = Vector3(data[0], Model.surface_at(Vector2(data[0], data[1])) + 0.008, data[1])
		var radius := clampf(sqrt(float(data[2])) * 0.026, 0.025, 0.34)
		mesh.scale = Vector3(radius, 1.0, radius * 0.8)
	target_ring.visible = not is_production and model.held in ["jug", "cup", "rag"]
	var aim: Vector2 = model.rag if model.held == "rag" else model.spout_target()
	var aimed: bool = model.can_fill_at(aim, model.source_height())
	target_ring.position = Vector3(aim.x, Model.surface_at(aim) + 0.01, aim.y)
	var receiver: String = model.receiver_at(aim, model.source_height())
	if not receiver.is_empty(): target_ring.position.y = model.vessel_base(receiver).y + model.vessels[receiver].rim_height
	aimed = not receiver.is_empty()
	target_ring.material_override.albedo_color = Color("6fd7ae") if aimed else Color("e9a164")
	stream.visible = (model.flowing or model.squeezing)
	if stream.visible:
		var start: Vector3 = model.spout_position()
		if model.squeezing: start = rag.position + Vector3(0, 0.04, 0)
		var end := Vector3(model.landing.x, Model.surface_at(model.landing) + 0.01, model.landing.y)
		var receiving: String = model.receiver_at(model.landing, start.y)
		if not receiving.is_empty(): end.y = model.vessel_base(receiving).y + model.vessels[receiving].rim_height
		stream.mesh.top_radius = 0.015 + (model.vessels[model.source].rate() / 1050.0) * 0.045
		stream.mesh.bottom_radius = stream.mesh.top_radius
		Props.align_line(stream, start, end)
	if is_production:
		_update_worker(model, animation_time, resting)

func _update_worker(model, time: float, resting: bool) -> void:
	worker.position = model.actor_position
	worker.rotation.y = model.actor_yaw + PI
	head.rotation.x = -model.actor_pitch
	book.set_reading(model.presentation.book, model.presentation.page)
	book.set_live(model if model.presentation.book and model.presentation.page == model.dish else null)
	var target: Vector3 = worker.position + worker.basis * Vector3(0, 1.05, 0.4)
	match model.held:
		"jug": target = jug.position + Vector3(0, 0.35, 0)
		"plate_0", "plate_1", "plate_2": target = plates[int(model.held.get_slice("_", 1))].position + Vector3(0, 0.05, 0)
		"cup": target = cup.position + Vector3(0, 0.22, 0)
		"tomato": target = tomato.position + Vector3(0, 0.12, 0)
		"rag": target = rag.position + Vector3(0, 0.06, 0)
		"pan": target = kitchen.pan.position + kitchen.pan.basis * Vector3(0, 0.08, 1.0)
		"potato": target = kitchen.potato.position + Vector3(0, 0.14, 0)
		"sausage": target = kitchen.sausage.position + Vector3(0, 0.1, 0)
	if resting and model.held.is_empty(): target.y += sin(time * 2.0) * 0.02
	if book.visible:
		head.rotation.x = minf(head.rotation.x, -0.35)
		left_hand.global_position = book.cover_grip(-1)
		right_hand.global_position = book.cover_grip(1)
	else:
		left_hand.position = target + worker.basis * Vector3(-0.16, 0, 0)
		right_hand.position = target + worker.basis * Vector3(0.16, 0, 0)
	Props.align_line(left_arm, worker.position + worker.basis * Vector3(-0.32, 1.24, 0), left_hand.position)
	Props.align_line(right_arm, worker.position + worker.basis * Vector3(0.32, 1.24, 0), right_hand.position)

func item_point(point: Vector2) -> Vector3:
	return Vector3(point.x, Model.BASE_Y, point.y)

func pick_item(camera: Camera3D) -> String:
	var food_pick: String = kitchen.pick_item(camera, "all")
	var selected := food_pick
	var nearest: float = kitchen.pick_distance if not food_pick.is_empty() else 3.4
	var ray_origin := camera.global_position
	var ray_direction := -camera.global_basis.z
	var entries: Array = [["tomato", tomato, AABB(Vector3(-0.15, 0, -0.15), Vector3(0.3, 0.27, 0.3))], ["jug", jug, AABB(Vector3(-0.66, 0, -0.36), Vector3(1.16, 0.87, 0.72))],
		["cup", cup, AABB(Vector3(-0.27, 0, -0.27), Vector3(0.54, 0.54, 0.54))],
		["rag", rag, AABB(Vector3(-0.25, 0, -0.19), Vector3(0.5, 0.12, 0.38))]]
	for i in range(plates.size()): entries.append(["plate_%d" % i, plates[i], AABB(Vector3(-0.4, -0.01, -0.4), Vector3(0.8, 0.055, 0.8))])
	for entry in entries:
		var node: Node3D = entry[1]
		if not node.visible: continue
		var bounds: AABB = entry[2]
		var hit = bounds.intersects_ray(node.to_local(ray_origin), node.global_basis.inverse() * ray_direction)
		if hit == null: continue
		var distance := ray_origin.distance_to(node.to_global(hit))
		if distance < nearest:
			nearest = distance
			selected = entry[0]
	return selected

func _build_storage_and_tray() -> void:
	var layout = Model.Layout
	var wood := Color("a76f4e")
	var metal := Color("244047")
	for height in layout.LEVELS:
		Props.box(self, Vector3(1.1, 0.06, 1.1), Vector3(layout.SHELF_X, height - 0.03, layout.SHELF_Z), wood)
		Props.collision_box(self, Vector3(1.1, 0.06, 1.1), Vector3(layout.SHELF_X, height - 0.03, layout.SHELF_Z))
	for x in [-0.51, 0.51]:
		for z in [-0.51, 0.51]:
			Props.solid_box(self, Vector3(0.07, 1.45, 0.07), Vector3(layout.SHELF_X + x, 0.725, layout.SHELF_Z + z), metal)
	# Shallow lips keep the stock visible from the cook's side.
	for level in [0, 1]:
		Props.box(self, Vector3(1.02, 0.09, 0.025), Vector3(layout.SHELF_X, layout.LEVELS[level] + 0.045, layout.SHELF_Z + 0.50), wood.lightened(0.1))
	Props.box(self, Vector3(1.3, 0.07, 0.66), Vector3(1.5, layout.CROCKERY_Y - 0.035, layout.CROCKERY_Z - 0.03), wood)
	for i in range(3):
		var plate := Node3D.new()
		add_child(plate)
		Props.cylinder(plate, 0.39, 0.02, Vector3(0, 0.01, 0), Color("e7eee1"))
		var rim := TorusMesh.new()
		rim.inner_radius = 0.35
		rim.outer_radius = 0.39
		Props.shape(plate, rim, Vector3(0, 0.025, 0), Color("83b9ac"))
		plates.append(plate)
	var center := Vector3(layout.TRAY.x, layout.TRAY_Y, layout.TRAY.y)
	Props.box(self, Vector3(layout.TRAY_HALF.x * 2, 0.03, layout.TRAY_HALF.y * 2), center - Vector3.UP * 0.015, Color("778e91"))
	for side in [-1, 1]:
		Props.box(self, Vector3(0.025, 0.065, layout.TRAY_HALF.y * 2), center + Vector3(side * layout.TRAY_HALF.x, 0.015, 0), Color("abc3ba"))
		Props.box(self, Vector3(layout.TRAY_HALF.x * 2, 0.065, 0.025), center + Vector3(0, 0.015, side * layout.TRAY_HALF.y), Color("abc3ba"))
	tray_liquid = Props.box(self, Vector3(layout.TRAY_HALF.x * 1.85, 0.008, layout.TRAY_HALF.y * 1.85), center + Vector3.UP * 0.008, WINE_COLOR)
	var label := Props.text(self, "ПОДАЧА", center + Vector3(0, 0.012, layout.TRAY_HALF.y + 0.16), 16, Color("25464a"))
	label.rotation.x = -PI / 2
