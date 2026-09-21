extends Node3D

const Props = preload("res://scripts/props.gd")
const Model = preload("res://scripts/cooking_model.gd")
const SceneRuntime = preload("res://scripts/scene_runtime.gd")
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
	var runtime = preload("res://scripts/scene_runtime.gd")
	runtime.ensure_children(self, "res://scenes/stations/counter_station.tscn")
	station_label = get_node("StationLabel") as Label3D
	station_label.text = "КЛОН" if production else "ПОКАЖИ КАК"
	# The station shell itself is authored in counter_station.tscn. Replace its
	# embedded storage placeholders with the dedicated authored module.
	for path in ["ProductShelf", "ServingTray", "CrockeryShelf"]:
		var placeholder := get_node_or_null(path) as Node3D
		if placeholder != null:
			placeholder.hide()
	var storage := runtime.instantiate("res://scenes/props/counter_storage.tscn") as Node3D
	add_child(storage)
	var shelf_center: Vector2 = Model.Layout.shelf_center()
	storage.position = Vector3(shelf_center.x, 0, shelf_center.y)
	var embedded_tray := storage.get_node_or_null("ServingTray") as Node3D
	if embedded_tray != null:
		embedded_tray.hide()
	var tray_scene := runtime.instantiate("res://scenes/props/serving_tray.tscn") as Node3D
	add_child(tray_scene)
	tray_scene.position = Vector3(Model.Layout.TRAY.x, Model.Layout.TRAY_Y, Model.Layout.TRAY.y)
	for i in range(3):
		var plate := runtime.instantiate("res://scenes/props/plate.tscn") as Node3D
		add_child(plate)
		plate.position = Vector3(1.30 + i * 0.20, Model.Layout.CROCKERY_Y + 0.02, Model.Layout.CROCKERY_Z - 0.04)
		plates.append(plate)
	tomato = runtime.instantiate("res://scenes/props/tomato.tscn") as Node3D
	add_child(tomato)
	jug = runtime.instantiate("res://scenes/props/wine_jug.tscn") as Node3D
	add_child(jug)
	jug_body = jug
	jug_liquid = jug.get_node("WineSurface") as MeshInstance3D
	cup = runtime.instantiate("res://scenes/props/wine_cup.tscn") as Node3D
	add_child(cup)
	cup_liquid = Props.cylinder(cup, 0.218, 1.0, Vector3.ZERO, WINE_COLOR)
	cup_liquid.name = "RuntimeLiquid"
	rag = runtime.instantiate("res://scenes/props/rag.tscn") as Node3D
	add_child(rag)
	rag_surface = rag.get_node("Cloth") as MeshInstance3D
	# Liquids, aim helpers and grip guides are intentionally runtime visuals.
	tray_liquid = Props.box(self, Vector3(Model.Layout.TRAY_HALF.x * 1.85, 0.008, Model.Layout.TRAY_HALF.y * 1.85), Vector3(Model.Layout.TRAY.x, Model.Layout.TRAY_Y + 0.008, Model.Layout.TRAY.y), WINE_COLOR)
	tray_liquid.name = "RuntimeTrayLiquid"
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

func _build_worker() -> void:
	var runtime = preload("res://scripts/scene_runtime.gd")
	worker = runtime.instantiate("res://scenes/actors/cook_avatar.tscn", preload("res://scripts/cook_avatar.gd")) as Node3D
	worker.tint = Color("63aa98")
	worker.position = Vector3(0, 0, 1.8)
	worker.rotation.y = PI
	add_child(worker)
	book = worker.book
	head = worker.head
	name_label = worker.caption
	name_label.text = "Клон"

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
	tomato.visible = model.item_available("tomato")
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
	var target: Vector3 = model.actor_position + Basis(Vector3.UP, model.actor_yaw + PI) * Vector3(0, 1.05, 0.4)
	match model.held:
		"jug": target = jug.position + Vector3(0, 0.35, 0)
		"plate_0", "plate_1", "plate_2": target = plates[int(model.held.get_slice("_", 1))].position + Vector3(0, 0.05, 0)
		"cup": target = cup.position + Vector3(0, 0.22, 0)
		"tomato": target = tomato.position + Vector3(0, 0.12, 0)
		"rag": target = rag.position + Vector3(0, 0.06, 0)
		"pan": target = kitchen.pan.position + kitchen.pan.basis * Vector3(0, 0.08, 1.0)
		"potato": target = kitchen.potato.position + Vector3(0, 0.14, 0)
		"sausage": target = kitchen.sausage.position + Vector3(0, 0.1, 0)
	if resting and model.held.is_empty():
		target.y += sin(time * 2.0) * 0.02
	var pose := {
		"position": [model.actor_position.x, model.actor_position.y, model.actor_position.z],
		"yaw": model.actor_yaw + PI,
		"pitch": -model.actor_pitch,
		"presentation": model.presentation
	}
	worker.perform(pose, target, not model.held.is_empty())
	worker.caption.text = name_label.text

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
