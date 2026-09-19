extends Node3D

const STAGE_COLORS := {
	1: Color("ef2b2d"),
	2: Color("1428e8"),
	3: Color("1fab54"),
	4: Color("f0df00"),
}

const FLOOR_COLORS := {
	1: Color("5c3032"),
	2: Color("26386f"),
	3: Color("28583b"),
	4: Color("686024"),
}

var stage_roots: Array[Node3D] = []
var stage_buttons: Array[Button] = []
var stage_label: Label
var player: CharacterBody3D

func _ready() -> void:
	player = $DebugPlayer
	_build_environment()
	_build_layout()
	_build_ui()
	set_stage(1)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		set_stage(int(event.keycode - KEY_0))

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b8c8ce")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)

	var neutral := Node3D.new()
	neutral.name = "NeutralCirculation"
	add_child(neutral)
	_add_box(neutral, "CentralAisle", Vector3(0.0, -0.15, 5.0), Vector3(10.0, 0.3, 22.0), Color("6c777b"))
	_add_box(neutral, "RearSpine", Vector3(0.0, -0.15, -11.5), Vector3(46.0, 0.3, 3.0), Color("71858a"))
	_add_box(neutral, "EntranceApron", Vector3(0.0, -0.15, 17.0), Vector3(10.0, 0.3, 4.0), Color("626c70"))
	_add_wall(neutral, "EntranceLeft", Vector3(-5.2, 1.5, 16.0), Vector3(0.4, 3.0, 4.0), Color("33494f"))
	_add_wall(neutral, "EntranceRight", Vector3(5.2, 1.5, 16.0), Vector3(0.4, 3.0, 4.0), Color("33494f"))

	for x in range(-5, 6, 5):
		_add_box(neutral, "GridX_%d" % x, Vector3(float(x), 0.012, 5.0), Vector3(0.035, 0.02, 22.0), Color(0.8, 0.9, 0.95, 0.35), false)
	for z in range(-5, 16, 5):
		_add_box(neutral, "GridZ_%d" % z, Vector3(0.0, 0.012, float(z)), Vector3(10.0, 0.02, 0.035), Color(0.8, 0.9, 0.95, 0.35), false)

func _build_layout() -> void:
	for stage in range(1, 5):
		var root := Node3D.new()
		root.name = "Stage%d" % stage
		add_child(root)
		stage_roots.append(root)

	_build_stage_1(stage_roots[0])
	_build_stage_2(stage_roots[1])
	_build_stage_3(stage_roots[2])
	_build_stage_4(stage_roots[3])

func _build_stage_1(root: Node3D) -> void:
	_add_zone_floor(root, "ChefZone", Vector3(0.0, 0.0, -5.8), Vector2(10.0, 8.0), 1, "ШЕФ · стартовая зона\n10 × 8 м")
	_add_box(root, "ChefCounter", Vector3(0.0, 0.65, -6.5), Vector3(5.8, 1.3, 1.8), Color("c58b3c"))
	_add_wall(root, "ChefBackWall", Vector3(0.0, 1.5, -9.8), Vector3(10.0, 3.0, 0.35), Color("5f4d39"))
	_add_zone_floor(root, "LabStart", Vector3(-7.0, 0.0, -18.5), Vector2(6.0, 11.0), 1, "ЛАБА 1/3\n6 × 11 м")
	_add_room_shell(root, "LabStartShell", Rect2(-10.0, -24.0, 6.0, 11.0), "south", Color("42575b"))

func _build_stage_2(root: Node3D) -> void:
	_add_zone_floor(root, "KitchenFirst", Vector3(15.0, 0.0, -3.5), Vector2(14.0, 11.0), 2, "КУХНЯ · 5 слотов\n14 × 11 м")
	_add_room_shell(root, "KitchenFirstShell", Rect2(8.0, -9.0, 14.0, 11.0), "west", Color("3e4d64"))
	for i in range(5):
		var row := i / 3
		var col := i % 3
		_add_box(root, "Station_%d" % i, Vector3(12.0 + col * 3.0, 0.5, -6.0 + row * 4.0), Vector3(2.0, 1.0, 1.2), Color("8b95a3"))
	_add_zone_floor(root, "RestStart", Vector3(7.0, 0.0, -18.5), Vector2(6.0, 11.0), 2, "КОМНАТА ОТДЫХА 1/3\n6 × 11 м")
	_add_room_shell(root, "RestStartShell", Rect2(4.0, -24.0, 6.0, 11.0), "south", Color("42575b"))

func _build_stage_3(root: Node3D) -> void:
	_add_zone_floor(root, "KitchenSecond", Vector3(-15.0, 0.0, -3.5), Vector2(14.0, 11.0), 3, "КУХНЯ · мидгейм\n14 × 11 м")
	_add_room_shell(root, "KitchenSecondShell", Rect2(-22.0, -9.0, 14.0, 11.0), "east", Color("3b5b47"))
	_add_zone_floor(root, "LabMid", Vector3(-13.0, 0.0, -18.5), Vector2(6.0, 11.0), 3, "ЛАБА 2/3")
	_add_room_shell(root, "LabMidShell", Rect2(-16.0, -24.0, 6.0, 11.0), "south", Color("42575b"))
	_add_zone_floor(root, "RestMid", Vector3(13.0, 0.0, -18.5), Vector2(6.0, 11.0), 3, "ОТДЫХ 2/3")
	_add_room_shell(root, "RestMidShell", Rect2(10.0, -24.0, 6.0, 11.0), "south", Color("42575b"))

func _build_stage_4(root: Node3D) -> void:
	_add_zone_floor(root, "KitchenLateLeft", Vector3(-15.0, 0.0, 8.5), Vector2(14.0, 11.0), 4, "ЛЕЙТГЕЙМ-СЕКТОР\n14 × 11 м")
	_add_room_shell(root, "KitchenLateLeftShell", Rect2(-22.0, 3.0, 14.0, 11.0), "east", Color("625d34"))
	_add_zone_floor(root, "KitchenLateRight", Vector3(15.0, 0.0, 8.5), Vector2(14.0, 11.0), 4, "ЛЕЙТГЕЙМ-СЕКТОР\n14 × 11 м")
	_add_room_shell(root, "KitchenLateRightShell", Rect2(8.0, 3.0, 14.0, 11.0), "west", Color("625d34"))
	_add_zone_floor(root, "LabLate", Vector3(-19.0, 0.0, -18.5), Vector2(6.0, 11.0), 4, "ЛАБА 3/3")
	_add_room_shell(root, "LabLateShell", Rect2(-22.0, -24.0, 6.0, 11.0), "south", Color("5d5a37"))
	_add_zone_floor(root, "RestLate", Vector3(19.0, 0.0, -18.5), Vector2(6.0, 11.0), 4, "ОТДЫХ 3/3")
	_add_room_shell(root, "RestLateShell", Rect2(16.0, -24.0, 6.0, 11.0), "south", Color("5d5a37"))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugUI"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(510.0, 0.0)
	layer.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title := Label.new()
	title.text = "DEBUG: планировка кафе"
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
	controls.text = "WASD — ходить · Shift — бег · Space — прыжок · мышь — обзор\nTab — отпустить/захватить курсор · 1–4 — быстро сменить этап"
	controls.modulate = Color(0.82, 0.88, 0.9)
	column.add_child(controls)

func set_stage(stage: int) -> void:
	stage = clampi(stage, 1, 4)
	for i in range(stage_roots.size()):
		_set_stage_root_active(stage_roots[i], i < stage)
	for i in range(stage_buttons.size()):
		stage_buttons[i].disabled = i == stage - 1
	if stage_label:
		var descriptions := {
			1: "КРАСНЫЙ · старт: Шеф + 1/3 лаборатории. Общие проходы оставлены нейтральными для навигации.",
			2: "СИНИЙ · первая автоматизация: + кухня на 5 мест + 1/3 комнаты отдыха.",
			3: "ЗЕЛЁНЫЙ · мидгейм: + второй кухонный сектор + расширение лаборатории и отдыха.",
			4: "ЖЁЛТЫЙ · лейтгейм: открыты все сектора. Полный габарит ≈ 44 × 41 м.",
		}
		stage_label.text = descriptions[stage]

func _set_stage_root_active(root: Node3D, active: bool) -> void:
	root.visible = active
	for child in _all_descendants(root):
		if child is CollisionShape3D:
			child.set_deferred("disabled", not active)

func _all_descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			result.append(child)
			stack.append(child)
	return result

func _add_zone_floor(parent: Node3D, node_name: String, center: Vector3, size_xz: Vector2, stage: int, label_text: String) -> void:
	_add_box(parent, node_name, Vector3(center.x, -0.15, center.z), Vector3(size_xz.x, 0.3, size_xz.y), FLOOR_COLORS[stage])
	var label := Label3D.new()
	label.name = node_name + "Label"
	label.text = label_text
	label.position = Vector3(center.x, 0.08, center.z)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.font_size = 36
	label.outline_size = 6
	label.modulate = STAGE_COLORS[stage].lightened(0.25)
	label.outline_modulate = Color(0.05, 0.06, 0.07, 0.9)
	parent.add_child(label)

func _add_room_shell(parent: Node3D, node_name: String, rect: Rect2, open_side: String, color: Color) -> void:
	var min_x := rect.position.x
	var min_z := rect.position.y
	var max_x := rect.end.x
	var max_z := rect.end.y
	var width := rect.size.x
	var depth := rect.size.y
	var wall_h := 3.0
	var wall_t := 0.35
	if open_side != "north":
		_add_wall(parent, node_name + "North", Vector3((min_x + max_x) * 0.5, wall_h * 0.5, min_z), Vector3(width, wall_h, wall_t), color)
	if open_side != "south":
		_add_wall(parent, node_name + "South", Vector3((min_x + max_x) * 0.5, wall_h * 0.5, max_z), Vector3(width, wall_h, wall_t), color)
	if open_side != "west":
		_add_wall(parent, node_name + "West", Vector3(min_x, wall_h * 0.5, (min_z + max_z) * 0.5), Vector3(wall_t, wall_h, depth), color)
	if open_side != "east":
		_add_wall(parent, node_name + "East", Vector3(max_x, wall_h * 0.5, (min_z + max_z) * 0.5), Vector3(wall_t, wall_h, depth), color)

func _add_wall(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	_add_box(parent, node_name, center, size, color)

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
