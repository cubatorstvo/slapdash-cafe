extends Node3D

const TABLE_SKEWS: Array[float] = [-0.09, 0.07, -0.04, 0.11, -0.06]

const TILE := 2.0
const WALL_HEIGHT := 3.2
const WALL_THICKNESS := 0.28
const EARLY_ENTRANCE_Z: float = 2.0
const FINAL_ENTRANCE_Z: float = 16.0

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
const WALL_CAP_COLOR := Color("46585d")
const TEMP_PANEL_COLOR := Color("9b815d")
const TEMP_FRAME_COLOR := Color("3f4747")
const TEMP_WARNING_COLOR := Color("e3bd36")
const OUTSIDE_COLOR := Color("56615d")

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
	# Fixed Chef plaza, narrower public approach, compact six-metre-deep back rooms.
	_mark_rect(Rect2i(-3, -7, 6, 6), 1)
	_mark_rect(Rect2i(-2, -1, 4, 2), 1)
	_mark_rect(Rect2i(-2, 1, 4, 7), 4)
	_mark_rect(Rect2i(-3, -10, 3, 3), 1)
	_mark_rect(Rect2i(3, -5, 7, 6), 2)
	_mark_rect(Rect2i(2, -1, 1, 2), 2)
	_mark_rect(Rect2i(0, -10, 3, 3), 2)
	_mark_rect(Rect2i(-10, -5, 7, 6), 3)
	_mark_rect(Rect2i(-3, -1, 1, 2), 3)
	_mark_rect(Rect2i(-6, -10, 3, 3), 3)
	_mark_rect(Rect2i(3, -10, 3, 3), 3)
	_mark_rect(Rect2i(-6, -7, 3, 2), 3)
	_mark_rect(Rect2i(3, -7, 3, 2), 3)
	_mark_rect(Rect2i(-10, 1, 8, 6), 4)
	_mark_rect(Rect2i(2, 1, 8, 6), 4)
	_mark_rect(Rect2i(-9, -10, 3, 3), 4)
	_mark_rect(Rect2i(6, -10, 3, 3), 4)
	_mark_rect(Rect2i(-9, -7, 3, 2), 4)
	_mark_rect(Rect2i(6, -7, 3, 2), 4)

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
	_add_box(exterior, "GroundVisual", Vector3(0.0, -0.14, -3.0), Vector3(70.0, 0.24, 70.0), OUTSIDE_COLOR, false)
	_add_invisible_floor_collider(exterior)

func _add_invisible_floor_collider(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "FloorCollider"
	body.position = Vector3(0.0, -0.1, -3.0)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(120.0, 0.2, 120.0)
	collision.shape = shape
	body.add_child(collision)

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
	_build_perimeter(root, cells, stage)
	_build_entrance(root, stage)
	_build_back_block_divider(root, stage)
	_build_wayfinding(root, stage)
	_build_chef(root)
	_build_stage_content(root, stage)

func _build_floor(root: Node3D, cells: Dictionary) -> void:
	var floor_root := Node3D.new()
	floor_root.name = "ContinuousFloor"
	root.add_child(floor_root)
	var materials: Dictionary = {}
	for stage in range(1, 5):
		var material := StandardMaterial3D.new()
		material.albedo_color = FLOOR_COLORS[stage]
		material.roughness = 0.94
		materials[stage] = material
	for cell in cells:
		var cell_pos: Vector2i = cell
		var unlock_stage := int(unlock_stage_by_cell[cell_pos])
		var center := _cell_center(cell_pos)
		var tile := MeshInstance3D.new()
		tile.name = "Floor_%d_%d" % [cell_pos.x, cell_pos.y]
		tile.position = Vector3(center.x, 0.002, center.z)
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(TILE, TILE)
		tile.mesh = mesh
		tile.material_override = materials[unlock_stage]
		floor_root.add_child(tile)

func _build_perimeter(root: Node3D, cells: Dictionary, stage: int) -> void:
	var walls := Node3D.new()
	walls.name = "PerimeterWalls"
	root.add_child(walls)
	var final_cells := _cells_for_stage(4)
	var groups: Dictionary = {}
	for cell in cells:
		var c: Vector2i = cell
		_collect_boundary(groups, cells, final_cells, c, "W", Vector2i(c.x - 1, c.y), c.x, c.y)
		_collect_boundary(groups, cells, final_cells, c, "E", Vector2i(c.x + 1, c.y), c.x + 1, c.y)
		_collect_boundary(groups, cells, final_cells, c, "N", Vector2i(c.x, c.y - 1), c.y, c.x)
		if not _is_entrance_opening(c, stage):
			_collect_boundary(groups, cells, final_cells, c, "S", Vector2i(c.x, c.y + 1), c.y + 1, c.x)
	for key in groups:
		var group: Dictionary = groups[key]
		var positions: Array = group.positions
		positions.sort()
		if positions.is_empty():
			continue
		var run_start := int(positions[0])
		var previous := run_start
		for i in range(1, positions.size()):
			var current := int(positions[i])
			if current != previous + 1:
				_build_wall_run(walls, str(group.side), int(group.line), run_start, previous, bool(group.temporary))
				run_start = current
			previous = current
		_build_wall_run(walls, str(group.side), int(group.line), run_start, previous, bool(group.temporary))

func _collect_boundary(groups: Dictionary, cells: Dictionary, final_cells: Dictionary, cell: Vector2i, side: String, neighbor: Vector2i, line: int, position: int) -> void:
	if cells.has(neighbor):
		return
	var temporary := final_cells.has(neighbor)
	var key := "%s|%d|%d" % [side, line, 1 if temporary else 0]
	if not groups.has(key):
		groups[key] = {"side": side, "line": line, "temporary": temporary, "positions": []}
	groups[key].positions.append(position)

func _build_wall_run(parent: Node3D, side: String, line: int, start: int, finish: int, temporary: bool) -> void:
	var count := finish - start + 1
	var length := float(count) * TILE
	var center: Vector3
	var size: Vector3
	var inward := Vector3.ZERO
	if side == "W" or side == "E":
		center = Vector3(float(line) * TILE, WALL_HEIGHT * 0.5, (float(start) + float(count) * 0.5) * TILE)
		size = Vector3(WALL_THICKNESS, WALL_HEIGHT, length)
		inward = Vector3.RIGHT if side == "W" else Vector3.LEFT
	else:
		center = Vector3((float(start) + float(count) * 0.5) * TILE, WALL_HEIGHT * 0.5, float(line) * TILE)
		size = Vector3(length, WALL_HEIGHT, WALL_THICKNESS)
		inward = Vector3.BACK if side == "N" else Vector3.FORWARD
	var node_name := "%s_%d_%d_%d" % [side, line, start, finish]
	if temporary:
		_add_temporary_wall(parent, node_name, center, size, inward, side, length)
	else:
		_add_final_wall(parent, node_name, center, size)

func _add_final_wall(parent: Node3D, node_name: String, center: Vector3, size: Vector3) -> void:
	_add_box(parent, node_name, center, size, WALL_COLOR)
	var cap_size := size
	cap_size.y = 0.12
	if size.x < size.z:
		cap_size.x += 0.08
	else:
		cap_size.z += 0.08
	var cap_center := center
	cap_center.y = WALL_HEIGHT + 0.06
	_add_box(parent, node_name + "Cap", cap_center, cap_size, WALL_CAP_COLOR, false)

func _add_temporary_wall(parent: Node3D, node_name: String, center: Vector3, size: Vector3, inward: Vector3, side: String, length: float) -> void:
	var partition := Node3D.new()
	partition.name = node_name + "_ExpansionPartition"
	parent.add_child(partition)
	_add_box(partition, "Panel", center, size, TEMP_PANEL_COLOR)

	var frame_depth := 0.09
	var frame_offset := inward * (WALL_THICKNESS * 0.5 + frame_depth * 0.5)
	var is_vertical := side == "W" or side == "E"
	var rail_size := Vector3(frame_depth, 0.12, length) if is_vertical else Vector3(length, 0.12, frame_depth)
	_add_box(partition, "TopRail", center + frame_offset + Vector3(0.0, WALL_HEIGHT * 0.5 - 0.16, 0.0), rail_size, TEMP_FRAME_COLOR, false)
	_add_box(partition, "BottomRail", center + frame_offset + Vector3(0.0, -WALL_HEIGHT * 0.5 + 0.16, 0.0), rail_size, TEMP_FRAME_COLOR, false)

	var stud_count := maxi(2, int(ceil(length / 2.0)) + 1)
	for i in range(stud_count):
		var t := 0.0 if stud_count == 1 else float(i) / float(stud_count - 1)
		var offset_along := lerpf(-length * 0.5 + 0.08, length * 0.5 - 0.08, t)
		var stud_center := center + frame_offset
		var stud_size: Vector3
		if is_vertical:
			stud_center.z += offset_along
			stud_size = Vector3(frame_depth, WALL_HEIGHT - 0.24, 0.10)
		else:
			stud_center.x += offset_along
			stud_size = Vector3(0.10, WALL_HEIGHT - 0.24, frame_depth)
		_add_box(partition, "Stud_%d" % i, stud_center, stud_size, TEMP_FRAME_COLOR, false)

	var band_depth := 0.07
	var band_center := center + inward * (WALL_THICKNESS * 0.5 + band_depth * 0.5 + 0.01)
	band_center.y = 0.62
	var band_size := Vector3(band_depth, 0.24, maxf(0.4, length - 0.20)) if is_vertical else Vector3(maxf(0.4, length - 0.20), 0.24, band_depth)
	_add_box(partition, "WarningBand", band_center, band_size, TEMP_WARNING_COLOR, false)

	var sign_position := center + inward * 0.22
	sign_position.y = 1.85
	_add_zone_sign(partition, "РАСШИРЕНИЕ", sign_position, Color("fff2b0"), 26)

func _build_back_block_divider(root: Node3D, stage: int) -> void:
	if stage < 2:
		return
	var divider := Node3D.new()
	divider.name = "LabRestSharedWall"
	root.add_child(divider)
	_add_final_wall(divider, "SharedWall", Vector3(0.0, WALL_HEIGHT * 0.5, -17.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, 6.0))

func _entrance_z(stage: int) -> float:
	return FINAL_ENTRANCE_Z if stage == 4 else EARLY_ENTRANCE_Z

func _is_entrance_opening(cell: Vector2i, stage: int) -> bool:
	var entrance_row: int = int(_entrance_z(stage) / TILE) - 1
	return cell.y == entrance_row and (cell.x == -1 or cell.x == 0)

func _build_entrance(root: Node3D, stage: int) -> void:
	var entrance_z: float = _entrance_z(stage)
	_add_box(root, "EntrancePath", Vector3(0.0, -0.055, entrance_z + 4.0), Vector3(5.5, 0.10, 8.0), Color("777d7c"), false)
	_add_zone_sign(root, "ВХОД", Vector3(0.0, 2.2, entrance_z + 1.7), Color("e6ecec"), 34)

func _build_wayfinding(root: Node3D, stage: int) -> void:
	_add_zone_sign(root, "ГЛАВНЫЙ ПРОХОД", Vector3(0.0, 2.65, 8.0 if stage == 4 else 0.0), Color("dce6e8"), 24)
	_add_zone_sign(root, "ЗАДНЯЯ МАГИСТРАЛЬ", Vector3(0.0, 2.65, -12.0), Color("dce6e8"), 22)

func _build_chef(root: Node3D) -> void:
	var chef := Node3D.new()
	chef.name = "ChefStation"
	root.add_child(chef)
	_add_box(chef, "MainCounter", Vector3(0.0, 0.55, -5.1), Vector3(5.6, 1.1, 1.55), Color("bd853b"))
	_add_box(chef, "CounterTop", Vector3(0.0, 1.18, -5.1), Vector3(5.9, 0.14, 1.75), Color("e2c18b"), false)
	_add_box(chef, "LeftPrep", Vector3(-3.8, 0.45, -5.9), Vector3(1.4, 0.9, 2.4), Color("7c8687"))
	_add_box(chef, "RightPrep", Vector3(3.8, 0.45, -5.9), Vector3(1.4, 0.9, 2.4), Color("7c8687"))
	_add_zone_sign(chef, "ШЕФ", Vector3(0.0, 2.3, -5.1), STAGE_COLORS[1], 42)
	_add_zone_sign(chef, "за спиной — открытая задняя магистраль", Vector3(0.0, 2.05, -8.0), Color("dbe4e4"), 18)

func _build_stage_content(root: Node3D, stage: int) -> void:
	_add_zone_sign(root, "ЛАБОРАТОРИЯ", Vector3(-3.0, 2.35, -19.0), STAGE_COLORS[1], 25)
	_add_lab_props(root, 1)
	if stage >= 2:
		_add_rest_props(root, 1)
		_add_zone_sign(root, "ОТДЫХ", Vector3(3.0, 2.35, -19.0), STAGE_COLORS[2], 25)
		# A: crooked five-table horseshoe, entrance towards the Chef on the left.
		_build_court(root, "Zone A · 5", Vector3(13, 0, -4), [
			Vector3(-1.6, 0, -3.6), Vector3(2.0, 0, -3.4), Vector3(4.1, 0, 0.1),
			Vector3(2.1, 0, 3.6), Vector3(-1.6, 0, 3.5)], Vector3.ZERO, 2)
	if stage >= 3:
		_add_lab_props(root, 2)
		_add_rest_props(root, 2)
		# B: elongated, asymmetric oval with an open right-hand mouth.
		_build_court(root, "Zone B · 7", Vector3(-13, 0, -4), [
			Vector3(2.4, 0, -3.6), Vector3(-0.8, 0, -3.8), Vector3(-3.7, 0, -2.6),
			Vector3(-4.4, 0, 0.5), Vector3(-3.0, 0, 3.4), Vector3(0.2, 0, 3.9),
			Vector3(3.4, 0, 3.0)], Vector3.ZERO, 3)
	if stage >= 4:
		_add_lab_props(root, 3)
		_add_rest_props(root, 3)
		# C: irregular public square; the upper-right corner is the entrance.
		_build_court(root, "Zone C · 8", Vector3(-13, 0, 8), [
			Vector3(-3.5, 0, -3.7), Vector3(-0.2, 0, -4.0), Vector3(-4.4, 0, -0.6),
			Vector3(-4.0, 0, 2.8), Vector3(-1.4, 0, 4.0), Vector3(1.9, 0, 3.8),
			Vector3(4.3, 0, 1.4), Vector3(4.1, 0, -1.8)], Vector3.ZERO, 4)
		# D: two connected public pockets, with two back-to-back central counters.
		_build_court(root, "Zone D · 10", Vector3(13, 0, 8), [
			Vector3(-2.5, 0, -3.8), Vector3(0.6, 0, -4.0), Vector3(3.7, 0, -3.2),
			Vector3(4.5, 0, -0.1), Vector3(4.0, 0, 3.2), Vector3(0.8, 0, 4.0),
			Vector3(-2.5, 0, 3.7), Vector3(-4.3, 0, 1.0)], Vector3(0, 0, -1), 4)
		_add_debug_table(root, "D_CenterNorth", Vector3(12.0, 0, 7.0), Vector3(12.0, 0, 3.0), 0.06)
		_add_debug_table(root, "D_CenterSouth", Vector3(14.0, 0, 9.2), Vector3(14.0, 0, 13.0), -0.08)

func _build_court(parent: Node3D, title: String, center: Vector3, offsets: Array[Vector3], focus_offset: Vector3, stage: int) -> void:
	var court := Node3D.new()
	court.name = title.split(" · ")[0].replace(" ", "")
	parent.add_child(court)
	_add_zone_sign(court, title, center + Vector3(0, 2.8, 0), STAGE_COLORS[stage].lightened(0.2), 30)
	_add_zone_sign(court, "ПОСЕТИТЕЛИ", center + Vector3(0, 0.3, 0.6), Color("dce6e8"), 19)
	for i in range(offsets.size()):
		var offset: Vector3 = offsets[i]
		var skew: float = TABLE_SKEWS[i % TABLE_SKEWS.size()]
		_add_debug_table(court, "Slot_%02d" % (i + 1), center + offset, center + focus_offset, skew)

func _add_debug_table(parent: Node3D, title: String, position: Vector3, customer_focus: Vector3, skew: float) -> void:
	var station := Node3D.new()
	station.name = title
	station.position = position
	# Local +Z is the customer edge, local -Z the cook's standing position.
	var inward := customer_focus - position
	station.rotation.y = atan2(inward.x, inward.z) + skew
	parent.add_child(station)
	_add_box(station, "Table", Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 1.1), Color("8f989a"))
	_add_box(station, "CustomerEdge", Vector3(0, 1.04, 0.5), Vector3(2.0, 0.08, 0.12), Color("d8b15b"), false)
	_add_box(station, "CookPosition", Vector3(0, 0.025, -1.1), Vector3(0.85, 0.04, 0.85), Color("748ca6"), false)
	_add_zone_sign(station, "ПОВАР", Vector3(0, 0.3, -1.1), Color("b7cbe0"), 16)

func _add_lab_props(parent: Node3D, tier: int) -> void:
	var x := -3.0 - float(tier - 1) * 6.0
	_add_box(parent, "LabBench_%d" % tier, Vector3(x, 0.48, -19.0), Vector3(4.5, 0.96, 1.2), Color("768b88"))
	_add_box(parent, "LabMachine_%d" % tier, Vector3(x, 0.8, -16.0), Vector3(1.5, 1.6, 1.5), Color("87989d"))

func _add_rest_props(parent: Node3D, tier: int) -> void:
	var x := 3.0 + float(tier - 1) * 6.0
	_add_box(parent, "Sofa_%d" % tier, Vector3(x, 0.45, -18.6), Vector3(3.8, 0.9, 1.4), Color("7c6d63"))
	_add_box(parent, "RestTable_%d" % tier, Vector3(x, 0.35, -15.5), Vector3(1.6, 0.7, 1.6), Color("8d7657"))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugUI"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(590.0, 0.0)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "DEBUG: Zone A–D · посетители внутри, повара снаружи"
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
	var legend := Label.new()
	legend.text = "Золотой край — подача внутрь · голубое место — повар снаружи. Перегородки — будущие расширения."
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.modulate = Color(0.95, 0.88, 0.67)
	column.add_child(legend)
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
			1: "КРАСНЫЙ · Шеф + 1/3 лаборатории. Закрытые будущие проходы обозначены глухими строительными перегородками.",
			2: "СИНИЙ · + Zone A на 5 мест + 1/3 комнаты отдыха. Временные перегородки переезжают на новый край доступного помещения.",
			3: "ЗЕЛЁНЫЙ · + Zone B на 7 мест + средние части лаборатории и отдыха.",
			4: "ЖЁЛТЫЙ · + Zone C (8) и Zone D (10). Полный поздний контур. Временных перегородок больше нет; остаётся только постоянный наружный периметр.",
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
	var spawn_position: Vector3 = Vector3(0.0, 1.0, _entrance_z(current_stage) - 2.5)
	if player.has_method("reset_pose"):
		player.call("reset_pose", spawn_position)
	else:
		player.global_position = spawn_position
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

func _add_zone_sign(parent: Node3D, text_value: String, position: Vector3, color: Color, font_size: int) -> void:
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

