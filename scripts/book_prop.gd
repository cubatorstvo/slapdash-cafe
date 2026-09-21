extends Node3D
const P = preload("res://scripts/props.gd")
const Data = preload("res://scripts/cookbook_data.gd")
const Page = preload("res://scripts/recipe_page.gd")
const SceneRuntime = preload("res://scripts/scene_runtime.gd")
const PAGE := Vector2(0.54, 0.76)
const VIEW := Vector2i(640, 900)
const SIZE_MULTIPLIER := 1.2
const FIRST_PERSON_SCALE := 0.82 * SIZE_MULTIPLIER
const THIRD_PERSON_SCALE := SIZE_MULTIPLIER
const FIRST_PERSON_DISTANCE := 0.74
const THIRD_PERSON_DISTANCE := 0.68
const READER_EYE_HEIGHT := 1.55
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
var last_side := -1
var pointer_down := false

func _ready() -> void:
	SceneRuntime.ensure_children(self, "res://scenes/presentation/physical_cookbook.tscn")
	var authored_collision:=get_node_or_null("CollisionShape3D") as CollisionShape3D
	if authored_collision!=null: authored_collision.disabled=true
	var authored_surfaces: Array[MeshInstance3D] = [get_node("LeftPageSurface") as MeshInstance3D, get_node("RightPageSurface") as MeshInstance3D]
	hands = [get_node("HandLeft") as Node3D, get_node("HandRight") as Node3D]
	for index in range(2):
		var side := -1 if index == 0 else 1
		var view := SubViewport.new()
		add_child(view)
		view.size = VIEW
		view.disable_3d = true
		view.transparent_bg = false
		view.handle_input_locally = true
		view.gui_disable_input = false
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var sheet := SceneRuntime.instantiate("res://scenes/ui/cookbook_ui.tscn", Page) as Control
		view.add_child(sheet)
		sheet.name = "L" if side < 0 else "R"
		sheet.anchor_right = 1
		sheet.anchor_bottom = 1
		sheet.chosen.connect(func(page): chosen.emit(page))
		sheet.closed.connect(func(): chosen.emit("close"))
		var mesh := authored_surfaces[index]
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
	page_mesh = get_node("RightPageSurface")
	page_sound = AudioStreamPlayer3D.new()
	add_child(page_sound)
	page_sound.stream = preload("res://assets/audio/page.wav")
	page_sound.max_distance = 6
	page_sound.unit_size = 2
	page_sound.volume_db = -12
	hide()

func pose_in_hands(first_person_held: bool, look_negative_z := true) -> void:
	first_person = first_person_held
	pose_for_gaze(0.0, look_negative_z)
	for i in range(hands.size()):
		var side := -1.0 if i == 0 else 1.0
		if first_person:
			hands[i].position = Vector3(side * 0.58, 0.04, 0.06)
			hands[i].rotation = Vector3(-0.15, -side * 0.45, side * 0.12)
		else:
			hands[i].position = Vector3(side * 0.64, 0.03, 0.38)
			hands[i].rotation = Vector3(0.2, -side * 0.15, 0)
		hands[i].visible = true

func pose_for_gaze(pitch: float, look_negative_z := true, eye_height := READER_EYE_HEIGHT) -> void:
	# Pages face the reader and the spread is centered directly on the gaze ray.
	# First-person pitch/yaw already live on the Camera3D parent, while avatars
	# pass their recorded local head pitch here.
	var forward_zero := Vector3.FORWARD if look_negative_z else Vector3.BACK
	var gaze_basis := Basis(Vector3.RIGHT, pitch)
	var forward := (gaze_basis * forward_zero).normalized()
	var reader_up := (gaze_basis * Vector3.UP).normalized()
	var page_normal := -forward
	var page_z := -reader_up
	var page_x := page_normal.cross(page_z).normalized()
	var origin := Vector3.ZERO if first_person else Vector3(0, eye_height, 0)
	var distance := FIRST_PERSON_DISTANCE if first_person else THIRD_PERSON_DISTANCE
	position = origin + forward * distance
	basis = Basis(page_x, page_normal, page_z)
	var held_scale := FIRST_PERSON_SCALE if first_person else THIRD_PERSON_SCALE
	scale = Vector3.ONE * held_scale

func page_normal() -> Vector3:
	return global_transform.basis.y.normalized()

func page_top() -> Vector3:
	return (-global_transform.basis.z).normalized()

func cover_grip(side: float) -> Vector3:
	return (get_node("LeftGripAnchor") if side < 0 else get_node("RightGripAnchor")).global_position

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
	if not open:
		_leave_side(last_side)
		if page_sound: page_sound.stop()
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

func uv_from_local(local: Vector3) -> Vector2:
	return Vector2(local.x / PAGE.x + 0.5, local.z / PAGE.y + 0.5)

func local_from_uv(uv: Vector2) -> Vector3:
	return Vector3((uv.x - 0.5) * PAGE.x, 0, (uv.y - 0.5) * PAGE.y)

func page_to_world(side: int, uv: Vector2) -> Vector3:
	return surfaces[side].to_global(local_from_uv(uv))

func page_to_screen(camera: Camera3D, side: int, uv: Vector2) -> Vector2:
	return camera.unproject_position(page_to_world(side, uv))

func control_uv(side: int, control: Control) -> Vector2:
	return control.get_global_rect().get_center() / Vector2(VIEW)

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
		var uv := uv_from_local(local)
		if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0: continue
		nearest = t
		best = {"side": i, "uv": uv, "viewport": Vector2(uv.x * VIEW.x, uv.y * VIEW.y)}
	return best

func _leave_side(side: int) -> void:
	if side < 0 or side >= views.size():
		last_side = -1
		pointer_down = false
		return
	var leave := InputEventMouseMotion.new()
	leave.position = Vector2(-64, -1)
	views[side].push_input(leave, true)
	if pointer_down:
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = Vector2(-64, -1)
		up.global_position = up.position
		views[side].push_input(up, true)
	last_side = -1
	pointer_down = false
	last_pointer = Vector2(-1, -1)

func feed_pointer(event: InputEvent, hit: Dictionary) -> void:
	var side := int(hit.get("side", -1)) if not hit.is_empty() else -1
	if last_side >= 0 and side != last_side:
		_leave_side(last_side)
	if hit.is_empty():
		return
	var local := event.duplicate()
	if local is InputEventMouse:
		local.position = hit.viewport
		if local is InputEventMouseButton:
			local.global_position = local.position
			pointer_down = local.pressed and local.button_index == MOUSE_BUTTON_LEFT
	views[hit.side].push_input(local, true)
	last_pointer = hit.viewport
	last_side = hit.side

func _process(delta: float) -> void:
	turn = maxf(0, turn - delta)
	page_mesh.visible = turn > 0 and visible
	page_mesh.rotation.z = sin((1 - turn / 0.22) * PI) * 2.4

func shutdown() -> void:
	_leave_side(last_side)
	is_open = false
	if page_sound and is_instance_valid(page_sound):
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
