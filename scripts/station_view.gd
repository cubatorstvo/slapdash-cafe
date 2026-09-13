extends Node3D

const Props = preload("res://scripts/props.gd")
const Model = preload("res://scripts/cooking_model.gd")
const TABLE_HEIGHT := Model.Layout.TABLE_Y
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
	_build_countertop_structure(Color("eddbb6"), Color("a76f4e"), Color("79513f"))
	for x in [-1.85, 1.85]:
		for z in [-0.85, 0.85]:
			var leg_height: float = Model.Layout.table_height(Vector2(x, z)) - 0.18
			Props.box(self, Vector3(0.13, leg_height, 0.13), Vector3(x, leg_height * 0.5, z), Color("244047"))
	# Rear stretcher and side rails connect the legs to the sloped tabletop.
	Props.box(self, Vector3(3.83, 0.12, 0.09), Vector3(0, TABLE_HEIGHT - 0.23, -0.85), Color("244047"))
	for x in [-1.85, 1.85]:
		var a := Vector3(x, Model.Layout.table_height(Vector2(x, -0.85)) - 0.23, -0.85)
		var b := Vector3(x, Model.Layout.table_height(Vector2(x, 0.85)) - 0.23, 0.85)
		Props.line(self, a, b, 0.055, Color("244047"))
	_build_front_accent(accent)
	station_label = Props.text(self, "КЛОН" if production else "ПОКАЖИ КАК", Vector3(0, 0.76, 1.20), 25, Color("19353b"))
	# Markings follow the actual surface, including the broken corner.
	for z in [-0.96, 0.96]:
		_surface_marker(Vector2(-1.95, z), Vector2(1.95, z), accent.darkened(0.25))
	for x in [-1.95, 1.95]:
		_surface_marker(Vector2(x, -0.96), Vector2(x, 0.96), accent.darkened(0.25))
	tomato = Node3D.new()
	add_child(tomato)
	Props.ball(tomato, 0.12, Vector3(0, 0.12, 0), Color("d9483b"))
	Props.box(tomato, Vector3(0.12, 0.02, 0.04), Vector3(0, 0.24, 0), Color("6a9c56"))
	_build_jug()
	_build_cup()
	_build_storage_and_tray()
	rag = Node3D.new()
	add_child(rag)
	rag_surface = Props.box(rag, Vector3(0.43, 0.045, 0.30), Vector3(0, 0.025, 0), Color("eac26b"))
	for i in range(4):
		Props.box(rag, Vector3(0.025, 0.008, 0.29), Vector3(-0.15 + i * 0.10, 0.052, 0), Color("bc924e"))
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


func _emit_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot front faces use clockwise winding; the perimeter below is counterclockwise.
	st.set_smooth_group(-1)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)

func _collision_prism(top_points: Array) -> void:
	var points := PackedVector3Array()
	for point in top_points:
		points.append(point)
		points.append(Vector3(point.x, 0.0, point.z))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	add_child(body)
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collider.shape = shape
	body.add_child(collider)

func _build_countertop_structure(top_color: Color, side_color: Color, seam_color: Color) -> void:
	var layout = Model.Layout
	var far_left := Vector3(layout.TABLE_FAR_LEFT.x, TABLE_HEIGHT, layout.TABLE_FAR_LEFT.y)
	var near_left := Vector3(layout.TABLE_NEAR_LEFT.x, TABLE_HEIGHT - layout.TABLE_BREAK_DROP, layout.TABLE_NEAR_LEFT.y)
	var break_near := Vector3(layout.TABLE_BREAK_NEAR.x, TABLE_HEIGHT, layout.TABLE_BREAK_NEAR.y)
	var near_right := Vector3(layout.TABLE_NEAR_RIGHT.x, TABLE_HEIGHT, layout.TABLE_NEAR_RIGHT.y)
	var far_right := Vector3(layout.TABLE_FAR_RIGHT.x, TABLE_HEIGHT, layout.TABLE_FAR_RIGHT.y)
	var top_st := SurfaceTool.new()
	top_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_emit_triangle(top_st, far_left, near_left, break_near)
	_emit_triangle(top_st, far_left, break_near, near_right)
	_emit_triangle(top_st, far_left, near_right, far_right)
	top_st.generate_normals()
	var mesh := ArrayMesh.new()
	top_st.commit(mesh)
	var thickness := 0.18
	var perimeter := [far_left, near_left, break_near, near_right, far_right]
	var bottom: Array = []
	for point in perimeter:
		bottom.append(point - Vector3.UP * thickness)
	var side_st := SurfaceTool.new()
	side_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_emit_triangle(side_st, bottom[0], bottom[2], bottom[1])
	_emit_triangle(side_st, bottom[0], bottom[3], bottom[2])
	_emit_triangle(side_st, bottom[0], bottom[4], bottom[3])
	for index in range(perimeter.size()):
		var next := (index + 1) % perimeter.size()
		_emit_triangle(side_st, perimeter[index], bottom[index], bottom[next])
		_emit_triangle(side_st, perimeter[index], bottom[next], perimeter[next])
	side_st.generate_normals()
	side_st.commit(mesh)
	var countertop := MeshInstance3D.new()
	countertop.name = "Countertop"
	countertop.mesh = mesh
	add_child(countertop)
	countertop.set_surface_override_material(0, Props.material(top_color))
	countertop.set_surface_override_material(1, Props.material(side_color))
	_collision_prism([far_left, break_near, near_right, far_right])
	_collision_prism([far_left, near_left, break_near])
	Props.line(self, far_left + Vector3.UP * 0.012, break_near + Vector3.UP * 0.012, 0.016, seam_color)

func _build_front_accent(color: Color) -> void:
	var layout = Model.Layout
	var main_left: float = layout.TABLE_BREAK_NEAR.x
	var main_right: float = layout.TABLE_NEAR_RIGHT.x
	Props.box(self, Vector3(main_right - main_left, 0.22, 0.08), Vector3((main_left + main_right) * 0.5, 0.78, 1.14), color)
	var low := Vector3(layout.TABLE_NEAR_LEFT.x, 0.78 - layout.TABLE_BREAK_DROP, 1.14)
	var high := Vector3(layout.TABLE_BREAK_NEAR.x, 0.78, 1.14)
	var bar := Props.box(self, Vector3(low.distance_to(high), 0.22, 0.08), (low + high) * 0.5, color)
	bar.rotation.z = atan2(high.y - low.y, high.x - low.x)

func _surface_marker(start: Vector2, end: Vector2, color: Color) -> void:
	var layout = Model.Layout
	const SEGMENTS := 16
	for index in range(SEGMENTS):
		var a2 := start.lerp(end, float(index) / SEGMENTS)
		var b2 := start.lerp(end, float(index + 1) / SEGMENTS)
		var a := Vector3(a2.x, layout.table_height(a2) + 0.008, a2.y)
		var b := Vector3(b2.x, layout.table_height(b2) + 0.008, b2.y)
		Props.line(self, a, b, 0.009, color)

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
	var support: float = model.support_at(point, Model.BASE_Y + float(model.elevations[model.held]))
	grip_marker.position = Vector3(point.x, support + 0.012, point.y)
	var radius_scale := 1.0 if model.held == "jug" else 0.85
	grip_marker.scale = Vector3(radius_scale, 1, radius_scale)
	var lift: float = Model.BASE_Y + float(model.elevations[model.held]) - support
	for index in range(height_dashes.size()):
		var bottom := 0.025 + index * 0.09
		var top := minf(bottom + 0.045, lift)
		if top <= bottom: break
		var dash := height_dashes[index]
		dash.visible = true
		Props.align_line(dash, Vector3(point.x, support + bottom, point.y), Vector3(point.x, support + top, point.y))

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

var catch_marker: Node3D

func update_view(model, animation_time := 0.0, resting := false) -> void:
	if catch_marker==null:
		catch_marker=Node3D.new(); add_child(catch_marker)
		for angle in [-PI/4,PI/4]:
			var bar = preload("res://scripts/props.gd").box(catch_marker,Vector3(0.42,0.014,0.035),Vector3.ZERO,Color("f4ce69"))
			bar.rotation.y=angle
	catch_marker.visible=model.sauce_ramp and (model.sausage_state=="ramp" or model.sausage_launched)
	if catch_marker.visible:
		var landing: Vector2=model.ramp_landing()
		catch_marker.position=Vector3(landing.x,model.BASE_Y+0.02,landing.y)

	dish = model.dish
	for i in range(plates.size()):
		plates[i].visible = model.item_available("plate_%d" % i)
		plates[i].position = item_point(model.plates[i].point) + Vector3.UP * float(model.elevations["plate_%d" % i])
		plates[i].rotation.z = -float(model.plates[i].tilt)
	tray_liquid.visible = model.tray_wine > 0.01
	tray_liquid.scale = Vector3(clampf(sqrt(model.tray_wine / 225.0), 0.08, 1.0), 1, clampf(sqrt(model.tray_wine / 225.0), 0.08, 1.0))
	tomato.position = item_point(model.tomato) + Vector3.UP * model.elevations.tomato
	tomato.visible = not model.tomato_hit and model.item_available("tomato")
	kitchen.update_view(model)
	jug.visible = model.item_available("jug")
	cup.visible = model.item_available("cup")
	rag.visible = model.item_available("rag")
	fill_label.visible = cup.visible
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
		if model.guest_pour: end = model.GUEST_MOUTH
		stream.mesh.top_radius = 0.015 + (model.vessels[model.source].rate() / 1050.0) * 0.045
		stream.mesh.bottom_radius = stream.mesh.top_radius
		Props.align_line(stream, start, end)
	if is_production:
		_update_worker(model, animation_time, resting)

func _update_worker(model, time: float, resting: bool) -> void:
	worker.position = model.actor_position
	worker.rotation.y = model.actor_yaw + PI
	head.rotation.x = -model.actor_pitch
	book.pose_for_gaze(head.rotation.x, false, head.position.y)
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
	var product_shelf := Node3D.new()
	product_shelf.name = "ProductShelf"
	add_child(product_shelf)
	var shelf_center: Vector2 = layout.shelf_center()
	product_shelf.position = Vector3(shelf_center.x, 0, shelf_center.y)
	product_shelf.rotation.y = layout.SHELF_YAW
	var shelf_width: float = layout.SHELF_HALF.x * 2.0
	var shelf_depth: float = layout.SHELF_HALF.y * 2.0
	for height in layout.LEVELS:
		Props.box(product_shelf, Vector3(shelf_width, 0.06, shelf_depth), Vector3(0, height - 0.03, 0), wood)
		Props.collision_box(product_shelf, Vector3(shelf_width, 0.06, shelf_depth), Vector3(0, height - 0.03, 0))
	var leg_x: float = layout.SHELF_HALF.x - 0.04
	var leg_z: float = layout.SHELF_HALF.y - 0.04
	for x in [-leg_x, leg_x]:
		for z in [-leg_z, leg_z]:
			Props.solid_box(product_shelf, Vector3(0.07, 1.45, 0.07), Vector3(x, 0.725, z), metal)
	# Shallow lips keep the stock visible from the cook's side.
	for level in [0, 1]:
		Props.box(product_shelf, Vector3(shelf_width - 0.08, 0.09, 0.025), Vector3(0, layout.LEVELS[level] + 0.045, layout.SHELF_HALF.y - 0.05), wood.lightened(0.1))
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
	# A small open drip holder gives the cloth a dedicated visible home.
	var rag_home := Vector3(layout.RAG_HOME.x, layout.RAG_Y, layout.RAG_HOME.y)
	Props.box(self, Vector3(0.50, 0.025, 0.38), rag_home - Vector3.UP * 0.0125, Color("638f92"))
	for side in [-1, 1]:
		Props.box(self, Vector3(0.02, 0.025, 0.38), rag_home + Vector3(side * 0.25, 0.0125, 0), Color("abc3ba"))
	Props.box(self, Vector3(0.50, 0.025, 0.02), rag_home + Vector3(0, 0.0125, -0.19), Color("abc3ba"))
	var center := Vector3(layout.TRAY.x, layout.TRAY_Y, layout.TRAY.y)
	Props.box(self, Vector3(layout.TRAY_HALF.x * 2, 0.03, layout.TRAY_HALF.y * 2), center - Vector3.UP * 0.015, Color("778e91"))
	for side in [-1, 1]:
		Props.box(self, Vector3(0.025, 0.065, layout.TRAY_HALF.y * 2), center + Vector3(side * layout.TRAY_HALF.x, 0.015, 0), Color("abc3ba"))
		Props.box(self, Vector3(layout.TRAY_HALF.x * 2, 0.065, 0.025), center + Vector3(0, 0.015, side * layout.TRAY_HALF.y), Color("abc3ba"))
	tray_liquid = Props.box(self, Vector3(layout.TRAY_HALF.x * 1.85, 0.008, layout.TRAY_HALF.y * 1.85), center + Vector3.UP * 0.008, WINE_COLOR)
	var label := Props.text(self, "ПОДАЧА", center + Vector3(0, 0.012, layout.TRAY_HALF.y + 0.16), 16, Color("25464a"))
	label.rotation.x = -PI / 2
