extends Node3D

const TILE := 2.0
const WALL_HEIGHT := 3.2
const WALL_THICKNESS := 0.28
const PLAYER_SPAWN := Vector3(0.0, 1.0, 13.5)

const STAGE_COLORS := {
	1: Color("ef2b2d"),
	2: Color("1428e8"),
	3: Color("1fab54"),
	4: Color("f0df00"),
}

const FLOOR_COLORS := {
	1: Color("694044"),
	2: Color("3c4a79"),
	3: Color("3c674d"),
	4: Color("77713a"),
}

const WALL_COLOR := Color("d8d1c2")
const WALL_TRIM_COLOR := Color("46585d")
const OUTSIDE_COLOR := Color("56615d")
const AISLE_COLOR := Color("81969c")

var stage_roots: Array[Node3D] = []
var stage_cells: Array[Dictionary] = []
var unlock_stage_by_cell: Dictionary = {}
var stage_buttons: Array[Button] = []
var stage_label: Label
var player: CharacterBody3D
var current_stage := 1

func _ready() -> void:
	player = $DebugPlayer
	_build_unlock_map()
	_build_environment()
	_build_stage_snapshots()
	_build_ui()
	set_stage(1)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		set_stage(int(event.keycode - KEY_0))
	elif event.keycode == KEY_R:
		_reset_player()

func _build_unlock_map() -> void:
	# Stage 1: central hall, open rear spine, chef zone, first third of the lab.
	_mark_rect(Rect2i(-3, -6, 6, 15), 1)
	_mark_rect(Rect2i(-5, -7, 8, 2), 1)
	_mark_rect(Rect2i(-5, -12, 3, 5), 1)

	# Stage 2: first five-slot kitchen, first third of lounge and right rear-spine extension.
	_mark_rect(Rect2i(3, -5, 1, 6), 2)
	_mark_rect(Rect2i(4, -5, 7, 6), 2)
	_mark_rect(Rect2i(2, -12, 3, 5), 2)
	_mark_rect(Rect2i(3, -7, 2, 2), 2)

	# Stage 3: second kitchen plus the middle thirds of lab and lounge.
	_mark_rect(Rect2i(-11, -5, 7, 6), 3)
	_mark_rect(Rect2i(-4, -5, 1, 6), 3)
	_mark_rect(Rect2i(-8, -12, 3, 5), 3)
	_mark_rect(Rect2i(5, -12, 3, 5), 3)
	_mark_rect(Rect2i(-8, -7, 3, 2), 3)
	_mark_rect(Rect2i(5, -7, 3, 2), 3)

	# Stage 4: remaining lab/lounge thirds, front production sectors and full rear spine.
	_mark_rect(Rect2i(-11, 1, 7, 6), 4)
	_mark_rect(Rect2i(-4, 1, 1, 6), 4)
	_mark_rect(Rect2i(3, 1, 1, 6), 4)
	_mark_rect(Rect2i(4, 1, 7, 6), 4)
	_mark_rect(Rect2i(-11, -12, 3, 5), 4)
	_mark_rect(Rect2i(8, -12, 3, 5), 4)
	_mark_rect(Rect2i(-11, -7, 3, 2), 4)
	_mark_rect(Rect2i(8, -7, 3, 2), 4)

func _mark_rect(rect: Rect2i, unlock_stage: int) -> void:
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, z)
			if not unlock_stage_by_cell.has(cell):
				unlock_stage_by_cell[cell] = unlock_stage

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("aebfc4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -32.0, 0.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)

	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	_add_box(exterior, "Ground", Vector3(0.0, -0.28, -3.0), Vector3(70.0, 0.4, 70.0), OUTSIDE_COLOR)
	_add_box(exterior, "EntrancePath", Vector3(0.0, -0.055, 22.0), Vector3(5.5, 0.05, 8.0), Color("777d7c"), false)
	_add_floor_label(exterior, "ВХОД", Vector3(0.0, 0.02, 19.7), Color("e6ecec"), 34)

func _build_stage_snapshots() -> void:
	for stage in range(1, 5):
		var root := Node3D.new()
		root.name = "Stage%dSnapshot" % stage
		add_child(root)
		stage_roots.append(root)
		var cells := _cells_for_stage(stage)
		stage_cells.append(cells)
		_build_snapshot(root, cells, stage)
		root.visible = false
		_set_collisions_enabled(root, false)

func _cells_for_stage(stage: int) -> Dictionary:
	var cells: Dictionary = {}
	for cell in unlock_stage_by_cell:
		if int(unlock_stage_by_cell[cell]) <= stage:
			cells[cell] = true
	return cells

func _build_snapshot(root: Node3D, cells: Dictionary, stage: int) -> void:
	_build_floor(root, cells)
	_build_perimeter(root, cells)
	_build_circulation_markings(root, cells, stage)
	_build_chef(root)
	_build_stage_content(root, stage)

func _build_floor(root: Node3D, cells: Dictionary) -> void:
	var floor_root := Node3D.new()
	floor_root.name = "ContinuousFloor"
	root.add_child(floor_root)
	for cell in cells:
		var cell_pos: Vector2i = cell
		var unlock_stage := int(unlock_stage_by_cell[cell_pos])
		var center := _cell_center(cell_pos)
		_add_box(floor_root, "Floor_%d_%d" % [cell_pos.x, cell_pos.y], Vector3(center.x, -0.045, center.z), Vector3(TILE, 0.07, TILE), FLOOR_COLORS[unlock_stage], false)

func _build_perimeter(root: Node3D, cells: Dictionary) -> void:
	var walls := Node3D.new()
	walls.name = "PerimeterWalls"
	root.add_child(walls)
	for cell in cells:
		var cell_pos: Vector2i = cell
		var center := _cell_center(cell_pos)
		var x: int = cell_pos.x
		var z: int = cell_pos.y
		if not cells.has(Vector2i(x - 1, z)):
			_add_wall_segment(walls, "W_%d_%d" % [x, z], Vector3(center.x - TILE * 0.5, WALL_HEIGHT * 0.5, center.z), Vector3(WALL_THICKNESS, WALL_HEIGHT, TILE))
		if not cells.has(Vector2i(x + 1, z)):
			_add_wall_segment(walls, "E_%d_%d" % [x, z], Vector3(center.x + TILE * 0.5, WALL_HEIGHT * 0.5, center.z), Vector3(WALL_THICKNESS, WALL_HEIGHT, TILE))
		if not cells.has(Vector2i(x, z - 1)):
			_add_wall_segment(walls, "N_%d_%d" % [x, z], Vector3(center.x, WALL_HEIGHT * 0.5, center.z - TILE * 0.5), Vector3(TILE, WALL_HEIGHT, WALL_THICKNESS))
		if not cells.has(Vector2i(x, z + 1)) and not _is_entrance_opening(cell_pos):
			_add_wall_segment(walls, "S_%d_%d" % [x, z], Vector3(center.x, WALL_HEIGHT * 0.5, center.z + TILE * 0.5), Vector3(TILE, WALL_HEIGHT, WALL_THICKNESS))

func _is_entrance_opening(cell: Vector2i) -> bool:
	return cell.y == 8 and (cell.x == -1 or cell.x == 0)

func _add_wall_segment(parent: Node3D, node_name: String, center: Vector3, size: Vector3) -> void:
	_add_box(parent, node_name, center, size, WALL_COLOR)
	var trim_size := size
	trim_size.y = 0.14
	var trim_center := center
	trim_center.y = WALL_HEIGHT - 0.08
	_add_box(parent, node_name + "Trim", trim_center, trim_size, WALL_TRIM_COLOR, false)

func _build_circulation_markings(root: Node3D, cells: Dictionary, stage: int) -> void:
	var markings := Node3D.new()
	markings.name = "CirculationMarkings"
	root.add_child(markings)
	_add_box(markings, "MainAisle", Vector3(0.0, 0.005, 4.0), Vector3(3.2, 0.025, 26.0), AISLE_COLOR, false)
	var rear_min_x := -10.0 if stage == 1 else (-10.0 if stage == 2 else (-16.0 if stage == 3 else -22.0))
	var rear_max_x := 6.0 if stage == 1 else (10.0 if stage == 2 else (16.0 if stage == 3 else 22.0))
	_add_box(markings, "RearSpine", Vector3((rear_min_x + rear_max_x) * 0.5, 0.006, -14.0), Vector3(rear_max_x - rear_min_x, 0.027, 2.8), AISLE_COLOR.darkened(0.08), false)
	_add_floor_label(markings, "ГЛАВНЫЙ ПРОХОД", Vector3(0.0, 0.04, 8.0), Color("dce6e8"), 26)
	_add_floor_label(markings, "ЗАДНЯЯ МАГИСТРАЛЬ", Vector3((rear_min_x + rear_max_x) * 0.5, 0.04, -14.0), Color("dce6e8"), 23)

func _build_chef(root: Node3D) -> void:
	var chef := Node3D.new()
	chef.name = "ChefStation"
	root.add_child(chef)
	_add_box(chef, "MainCounter", Vector3(0.0, 0.55, -5.1), Vector3(5.6, 1.1, 1.55), Color("bd853b"))
	_add_box(chef, "CounterTop", Vector3(0.0, 1.15, -5.1), Vector3(5.9, 0.12, 1.75), Color("e2c18b"), false)
	_add_box(chef, "LeftPrep", Vector3(-3.8, 0.45, -5.9), Vector3(1.4, 0.9, 2.4), Color("7c8687"))
	_add_box(chef, "RightPrep", Vector3(3.8, 0.45, -5.9), Vector3(1.4, 0.9, 2.4), Color("7c8687"))
	_add_floating_label(chef, "ШЕФ", Vector3(0.0, 2.25, -5.1), STAGE_COLORS[1], 42)
	_add_floating_label(chef, "за спиной — открытая задняя магистраль", Vector3(0.0, 1.75, -8.0), Color("dbe4e4"), 18)

func _build_stage_content(root: Node3D, stage: int) -> void:
	_add_floor_label(root, "ЛАБОРАТОРИЯ · 1/3", Vector3(-8.0, 0.04, -20.0), STAGE_COLORS[1].lightened(0.22), 28)
	_add_lab_props(root, 1)
	if stage >= 2:
		_add_floor_label(root, "КУХНЯ 1 · 5 МЕСТ", Vector3(15.0, 0.04, -3.8), STAGE_COLORS[2].lightened(0.2), 28)
		_add_kitchen_stations(root, Vector3(15.0, 0.0, -3.8), 5, false)
		_add_floor_label(root, "КОМНАТА ОТДЫХА · 1/3", Vector3(7.0, 0.04, -20.0), STAGE_COLORS[2].lightened(0.2), 25)
		_add_rest_props(root, 1)
	if stage >= 3:
		_add_floor_label(root, "КУХНЯ 2 · МИДГЕЙМ", Vector3(-15.0, 0.04, -3.8), STAGE_COLORS[3].lightened(0.2), 28)
		_add_kitchen_stations(root, Vector3(-15.0, 0.0, -3.8), 7, true)
		_add_floor_label(root, "ЛАБА · 2/3", Vector3(-13.0, 0.04, -20.0), STAGE_COLORS[3].lightened(0.2), 23)
		_add_floor_label(root, "ОТДЫХ · 2/3", Vector3(13.0, 0.04, -20.0), STAGE_COLORS[3].lightened(0.2), 23)
		_add_lab_props(root, 2)
		_add_rest_props(root, 2)
	if stage >= 4:
		_add_floor_label(root, "ЛЕЙТГЕЙМ-СЕКТОР", Vector3(-15.0, 0.04, 8.0), STAGE_COLORS[4].lightened(0.12), 27)
		_add_floor_label(root, "ЛЕЙТГЕЙМ-СЕКТОР", Vector3(15.0, 0.04, 8.0), STAGE_COLORS[4].lightened(0.12), 27)
		_add_kitchen_stations(root, Vector3(-15.0, 0.0, 8.0), 8, true)
		_add_kitchen_stations(root, Vector3(15.0, 0.0, 8.0), 8, false)
		_add_floor_label(root, "ЛАБА · 3/3", Vector3(-19.0, 0.04, -20.0), STAGE_COLORS[4].lightened(0.12), 23)
		_add_floor_label(root, "ОТДЫХ · 3/3", Vector3(19.0, 0.04, -20.0), STAGE_COLORS[4].lightened(0.12), 23)
		_add_lab_props(root, 3)
		_add_rest_props(root, 3)

func _add_kitchen_stations(parent: Node3D, center: Vector3, count: int, face_center: bool) -> void:
	var props := Node3D.new()
	props.name = "KitchenProps_%s" % str(center)
	parent.add_child(props)
	var columns := 4
	for i in range(count):
		var col := i % columns
		var row := i / columns
		var local_x := (float(col) - 1.5) * 2.6
		var local_z := (float(row) - 0.5) * 3.4
		_add_box(props, "Station_%d" % i, center + Vector3(local_x, 0.5, local_z), Vector3(2.0, 1.0, 1.15), Color("8f989a"))
		var edge := center + Vector3(local_x, 1.12, local_z + (-0.72 if face_center else 0.72))
		_add_box(props, "StationEdge_%d" % i, edge, Vector3(2.0, 0.09, 0.12), Color("d8b15b"), false)

func _add_lab_props(parent: Node3D, tier: int) -> void:
	var x := -8.0 - float(tier - 1) * 6.0
	_add_box(parent, "LabBench_%d" % tier, Vector3(x, 0.48, -22.0), Vector3(4.5, 0.96, 1.2), Color("768b88"))
	_add_box(parent, "LabMachine_%d" % tier, Vector3(x, 0.8, -18.0), Vector3(1.5, 1.6, 1.5), Color("87989d"))

func _add_rest_props(parent: Node3D, tier: int) -> void:
	var x := 7.0 + float(tier - 1) * 6.0
	_add_box(parent, "Sofa_%d" % tier, Vector3(x, 0.45, -21.0), Vector3(3.8, 0.9, 1.4), Color("7c6d63"))
	_add_box(parent, "RestTable_%d" % tier, Vector3(x, 0.35, -17.8), Vector3(1.6, 0.7, 1.6), Color("8d7657"))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugUI"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "DEBUG: планировка кафе · цельный blockout"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	column.add_child(buttons)
	var names := ["1 · Красный", "2 · Синий", "3 · Зелёный", "4 · Жёлтый"]
	for i in range(4):
		var button := Button.new()
		button.text = names[i]
		button.tooltip_text = "Переключить состояние кафе"
		button.pressed.connect(set_stage.bind(i + 1))
		buttons.add_child(button)
		stage_buttons.append(button)
	stage_label = Label.new()
	stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(stage_label)
	var controls := Label.new()
	controls.text = "WASD — ходить · Shift — бег · Space — прыжок · мышь — обзор\nTab — курсор/UI · 1–4 — этап · R — вернуть игрока ко входу"
	controls.modulate = Color(0.82, 0.88, 0.9)
	column.add_child(controls)

func set_stage(stage: int) -> void:
	stage = clampi(stage, 1, 4)
	current_stage = stage
	for i in range(stage_roots.size()):
		var active := i == stage - 1
		stage_roots[i].visible = active
		_set_collisions_enabled(stage_roots[i], active)
	for i in range(stage_buttons.size()):
		stage_buttons[i].disabled = i == stage - 1
	if not _player_is_inside_stage(stage):
		_reset_player()
	if stage_label:
		var descriptions := {
			1: "КРАСНЫЙ · цельное стартовое помещение: Шеф, открытая зона за его столом, задняя магистраль и 1/3 лаборатории.",
			2: "СИНИЙ · добавлены первая кухня на 5 мест и 1/3 комнаты отдыха. Наружный периметр физически расширился вправо.",
			3: "ЗЕЛЁНЫЙ · добавлены второй кухонный сектор, средние части лаборатории/отдыха и более длинная задняя магистраль.",
			4: "ЖЁЛТЫЙ · полный поздний контур: четыре производственных сектора, полная лаборатория и комната отдыха. Максимальный размах ≈ 44 × 42 м.",
		}
		stage_label.text = descriptions[stage]

func _player_is_inside_stage(stage: int) -> bool:
	if not is_instance_valid(player):
		return true
	var cell := Vector2i(floori(player.global_position.x / TILE), floori(player.global_position.z / TILE))
	return stage_cells[stage - 1].has(cell)

func _reset_player() -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("reset_pose"):
		player.call("reset_pose", PLAYER_SPAWN)
	else:
		player.global_position = PLAYER_SPAWN
		player.velocity = Vector3.ZERO

func _set_collisions_enabled(root: Node, enabled: bool) -> void:
	for child in _all_descendants(root):
		if child is CollisionShape3D:
			child.set_deferred("disabled", not enabled)

func _all_descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			result.append(child)
			stack.append(child)
	return result

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * TILE, 0.0, (float(cell.y) + 0.5) * TILE)

func _add_floor_label(parent: Node3D, text_value: String, position: Vector3, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.font_size = font_size
	label.outline_size = 6
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.06, 0.07, 0.9)
	parent.add_child(label)

func _add_floating_label(parent: Node3D, text_value: String, position: Vector3, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position
	label.font_size = font_size
	label.outline_size = 7
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.06, 0.07, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color, collision := true) -> Node3D:
	var holder: Node3D
	if collision:
		holder = StaticBody3D.new()
	else:
		holder = Node3D.new()
	holder.name = node_name
	holder.position = center
	parent.add_child(holder)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh_instance.material_override = material
	holder.add_child(mesh_instance)
	if collision:
		var collision_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision_shape.shape = shape
		holder.add_child(collision_shape)
	return holder
