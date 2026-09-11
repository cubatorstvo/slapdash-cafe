extends Node3D
const P = preload("res://scripts/props.gd")
const Data = preload("res://scripts/cookbook_data.gd")
const Page = preload("res://scripts/recipe_page.gd")
const PAGE := Vector2(0.54, 0.76)
const VIEW := Vector2i(640, 900)
signal chosen(page)
var page_sound: AudioStreamPlayer3D
var pages: Array = []
var views: Array = []
var surfaces: Array = []
var hands: Array = []
var current_page := "index"
var is_open := false
var turn := 0.0
var page_mesh: Node3D
var first_person := false
var live_model = null
var last_pointer := Vector2(-1, -1)

func _ready() -> void:
	for side in [-1, 1]:
		P.box(self, Vector3(0.60, 0.044, 0.84), Vector3(side * 0.31, -0.006, 0), Color("7a3d38"))
		P.box(self, Vector3(0.56, 0.016, 0.78), Vector3(side * 0.305, 0.028, 0), Color("f3e6c8") if side < 0 else Color("f8efd6"))
	P.box(self, Vector3(0.038, 0.07, 0.84), Vector3.ZERO, Color("5e322f"))
	for side in [-1, 1]:
		var view := SubViewport.new()
		add_child(view)
		view.size = VIEW
		view.disable_3d = true
		view.transparent_bg = false
		view.handle_input_locally = true
		view.gui_disable_input = false
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var sheet := Page.new()
		view.add_child(sheet)
		sheet.name = "L" if side < 0 else "R"
		sheet.anchor_right = 1
		sheet.anchor_bottom = 1
		sheet.chosen.connect(func(page): chosen.emit(page))
		sheet.closed.connect(func(): chosen.emit("close"))
		var mesh := MeshInstance3D.new()
		add_child(mesh)
		var plane := PlaneMesh.new()
		plane.size = PAGE
		plane.orientation = PlaneMesh.FACE_Y
		mesh.mesh = plane
		mesh.position = Vector3(side * 0.305, 0.046, 0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = view.get_texture()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		mat.render_priority = 1
		mesh.material_override = mat
		pages.append(sheet)
		views.append(view)
		surfaces.append(mesh)
		var hand := Node3D.new()
		add_child(hand)
		hand.position = Vector3(side * 0.62, 0.04, 0.08)
		hand.rotation = Vector3(-0.2, -side * 0.55, side * 0.18)
		P.box(hand, Vector3(0.11, 0.045, 0.14), Vector3(0, 0, 0), Color("e8b893"))
		for i in range(4):
			P.box(hand, Vector3(0.026, 0.026, 0.08), Vector3(side * (-0.035 + i * 0.028), 0.018, -0.10), Color("e0ad86"))
		hands.append(hand)
	page_mesh = Node3D.new()
	add_child(page_mesh)
	P.box(page_mesh, Vector3(0.52, 0.004, 0.72), Vector3(0.26, 0.08, 0), Color("f7eed8"))
	page_sound = AudioStreamPlayer3D.new()
	add_child(page_sound)
	page_sound.stream = preload("res://assets/audio/page.wav")
	page_sound.max_distance = 6
	page_sound.unit_size = 2
	page_sound.volume_db = -12
	hide()

func pose_in_hands(first_person_held: bool, look_negative_z := true) -> void:
	first_person = first_person_held
	if first_person:
		# Upright toward the camera with a slight reader tilt so the whole spread
		# stays on screen at 1280x800 / 1920x1080 and the grip hands remain in frame.
		position = Vector3(0, -0.10, -0.74)
		rotation = Vector3(1.34, 0, 0)
		scale = Vector3(0.82, 0.82, 0.82)
	elif look_negative_z:
		scale = Vector3.ONE
		position = Vector3(0, 1.18, -0.58)
		rotation = Vector3(0.74, 0, 0)
	else:
		scale = Vector3.ONE
		position = Vector3(0, 1.18, 0.58)
		rotation = Vector3(0.74, PI, 0)
	for i in range(hands.size()):
		var side := -1.0 if i == 0 else 1.0
		if first_person:
			hands[i].position = Vector3(side * 0.58, 0.04, 0.06)
			hands[i].rotation = Vector3(-0.15, -side * 0.45, side * 0.12)
		else:
			hands[i].position = Vector3(side * 0.64, 0.03, 0.38)
			hands[i].rotation = Vector3(0.2, -side * 0.15, 0)
		hands[i].visible = true

func page_normal() -> Vector3:
	return global_transform.basis.y.normalized()

func page_top() -> Vector3:
	return (-global_transform.basis.z).normalized()

func cover_grip(side: float) -> Vector3:
	return to_global(Vector3(side * 0.64, 0.02, 0.40))

func ancestors_shown() -> bool:
	if not is_inside_tree(): return false
	var node: Node = get_parent()
	while node != null:
		if node is CanvasItem and not (node as CanvasItem).visible: return false
		if node is Node3D and not (node as Node3D).visible: return false
		node = node.get_parent()
	return true

func shown() -> bool:
	return visible and ancestors_shown()

func set_live(model) -> void:
	live_model = model
	if is_open: _paint()

func set_reading(open: bool, recipe := "index", model = null) -> void:
	var page := Data.page(recipe) if open else current_page
	var turned: bool = open != is_open or (open and current_page != page)
	is_open = open
	visible = open
	if model != null or not open: live_model = model
	for view in views:
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if open else SubViewport.UPDATE_DISABLED
	if turned and open and ancestors_shown(): page_sound.play()
	if open and turned: turn = 0.22
	if open:
		current_page = page
		_paint()
	for hand in hands: hand.visible = open

func _paint() -> void:
	var model = live_model if current_page != "index" else null
	pages[0].show_page(current_page, model)
	pages[1].show_page(current_page, model)

func page_to_world(side: int, uv: Vector2) -> Vector3:
	var local := Vector3((uv.x - 0.5) * PAGE.x, 0, (0.5 - uv.y) * PAGE.y)
	return surfaces[side].to_global(local)

func page_to_screen(camera: Camera3D, side: int, uv: Vector2) -> Vector2:
	return camera.unproject_position(page_to_world(side, uv))

func hit_from_screen(camera: Camera3D, screen: Vector2) -> Dictionary:
	if not visible: return {}
	var origin := camera.project_ray_origin(screen)
	var ray := camera.project_ray_normal(screen)
	var best := {}
	var nearest := 8.0
	for i in range(surfaces.size()):
		var mesh: MeshInstance3D = surfaces[i]
		var n: Vector3 = mesh.global_transform.basis.y.normalized()
		var denom := n.dot(ray)
		if absf(denom) < 0.02: continue
		var point: Vector3 = mesh.global_position
		var t: float = (point - origin).dot(n) / denom
		if t < 0.04 or t > nearest: continue
		var hit: Vector3 = origin + ray * t
		var local: Vector3 = mesh.global_transform.affine_inverse() * hit
		var uv := Vector2(local.x / PAGE.x + 0.5, 0.5 - local.z / PAGE.y)
		if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0: continue
		nearest = t
		best = {"side": i, "uv": uv, "viewport": Vector2(uv.x * VIEW.x, uv.y * VIEW.y)}
	return best

func feed_pointer(event: InputEvent, hit: Dictionary) -> void:
	if hit.is_empty(): return
	var local := event.duplicate()
	if local is InputEventMouse:
		local.position = hit.viewport
		if local is InputEventMouseButton: local.global_position = local.position
	views[hit.side].push_input(local, true)
	last_pointer = hit.viewport

func _process(delta: float) -> void:
	turn = maxf(0, turn - delta)
	page_mesh.visible = turn > 0 and visible
	page_mesh.rotation.z = sin((1 - turn / 0.22) * PI) * 2.4

func shutdown() -> void:
	if page_sound:
		page_sound.stop()
		page_sound.stream = null
	for i in range(surfaces.size()):
		var mesh: MeshInstance3D = surfaces[i]
		if is_instance_valid(mesh) and mesh.material_override:
			mesh.material_override.albedo_texture = null
	for view in views:
		if not is_instance_valid(view): continue
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		view.size = Vector2i(2, 2)

func _exit_tree() -> void:
	shutdown()
