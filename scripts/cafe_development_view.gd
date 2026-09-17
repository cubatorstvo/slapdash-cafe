extends Node3D
const Props = preload("res://scripts/props.gd")
const P = preload("res://scripts/cafe_progression.gd")
const Annex = preload("res://scripts/cafe_annex.gd")
var game: Node3D
var board: Node3D
var decor := {}
var slots: Array = []
var ribbon: Node3D
var star_label: Label3D

func build(root_game: Node3D) -> void:
	game = root_game
	board = Node3D.new()
	add_child(board)
	board.position = Vector3(-1.8, 0, 6.8)
	Props.solid_box(board, Vector3(1.6, 1.6, 0.12), Vector3(0, 1.2, 0), Color("b5875c"))
	Props.box(board, Vector3(1.42, 1.42, 0.03), Vector3(0, 1.2, 0.08), Color("213b3c"))
	var title := Props.text(board, "МОЁ КАФЕ\n[E] Управление", Vector3(0, 1.55, 0.12), 26, Color("efcf91"))
	title.pixel_size = 0.007
	star_label = Props.text(board, "☆ ☆ ☆ ☆ ☆", Vector3(0, 0.95, 0.12), 30, Color("efcf91"))
	star_label.pixel_size = 0.007
	Props.solid_box(board, Vector3(0.9, 0.12, 0.7), Vector3(0, 0.08, 0), Color("775e43"))
	for i in range(4):
		var marker := Node3D.new()
		add_child(marker)
		marker.position = game.service.slot_position(i)
		Props.box(marker, Vector3(5.5, 0.015, 3.6), Vector3(0, 0.015, 0), Color("61716a"))
		var label := Props.text(marker, "", Vector3(0, 1.3, 0), 27, Color("e7c591"))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.005
		slots.append({"node": marker, "label": label})
	ribbon = Node3D.new()
	add_child(ribbon)
	Props.box(ribbon, Vector3(6.0, 0.11, 0.04), Vector3(13.8, 1.0, 0.65), Color("bfa565"))
	var sign := Node3D.new()
	add_child(sign)
	decor.sign = sign
	Props.box(sign, Vector3(3.2, 1.0, 0.12), Vector3(-9.2, 2.8, -7.35), Color("d4a268"))
	Props.text(sign, "МЫ ПОЧТИ УМЕЕМ", Vector3(-9.2, 2.85, -7.25), 33, Color("243f40"))
	var lights := Node3D.new()
	add_child(lights)
	decor.lights = lights
	for i in range(15):
		var x := -10.0 + i * 1.8
		var y := 3.7 - sin(i * PI / 14) * 0.35
		Props.ball(lights, 0.085, Vector3(x, y, -5.7), Color("ffd78c")).material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if i > 0: Props.line(lights, Vector3(x - 1.8, 3.7 - sin((i-1)*PI/14)*0.35, -5.7), Vector3(x,y,-5.7), 0.018, Color("333e39"))
	var plants := Node3D.new()
	add_child(plants)
	decor.plants = plants
	for x in [-7.5, 8.0, 13.0]:
		Props.cylinder(plants, 0.38, 0.55, Vector3(x, 0.275, 8.8), Color("cd9167"), 0.45)
		for i in range(4):
			var leaf := Props.ball(plants, 0.3, Vector3(x + sin(i*1.7)*0.3, 0.95+i*0.20, 8.8), Color("84ad78"))
			leaf.scale = Vector3(0.7, 1.8, 0.65)
	build_night()
	refresh()

func board_hit(camera: Camera3D) -> bool:
	var origin := board.to_local(camera.global_position)
	var ray := board.global_basis.inverse() * -camera.global_basis.z
	var hit = AABB(Vector3(-0.85, 0.35, -0.1), Vector3(1.7, 1.7, 0.3)).intersects_ray(origin, ray)
	return hit != null and origin.distance_to(hit) < 3.5

func refresh() -> void:
	var progress = game.service.progress
	for id in decor: decor[id].visible = id in progress.decorations
	for i in range(slots.size()):
		slots[i].node.visible = game.service.by_id(i + 1) == null
		if i < 3:
			slots[i].label.text = "МЕСТО ДЛЯ СТОЙКИ\nПервая звезда" if progress.stars == 0 else "МЕСТО ДЛЯ СТОЙКИ\n[E] Компьютер · 120"
		else:
			slots[i].label.text = "РАСШИРЕНИЕ ЗАЛА\nВторая звезда" if not progress.expanded else "КУХНЯ НА ДВОИХ\n[E] Компьютер · 250"
	ribbon.visible = not progress.expanded
	var stars_text := PackedStringArray()
	for i in range(5): stars_text.append("★" if i < progress.stars else "☆")
	star_label.text = " ".join(stars_text)
	decor.lights.hide()
	refresh_night()

var night_controls: Array = []
var lab_parts: Array = []
var lab_root: Node3D
var lab_caption: Label3D
var night_room_light: OmniLight3D
var cable_root: Node3D
var cable_stamp := ""
var cable_preview: MeshInstance3D

func build_night() -> void:
	lab_root = Node3D.new()
	add_child(lab_root)
	Annex.place_lab(lab_root)
	Props.solid_box(lab_root, Vector3(3.6, 0.12, 1.0), Vector3(0, 0.85, 8.3), Color("9b795c"))
	for x in [-1.5, 1.5]: Props.solid_box(lab_root, Vector3(0.12,0.8,0.8), Vector3(x,0.4,8.3), Color("526d65"))
	lab_caption = Props.text(lab_root, "ЛАБОРАТОРИЯ", Vector3(0,2.35,8.3), 27, Color("edd09d"))
	lab_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab_caption.pixel_size = 0.005
	for i in range(3):
		var pos := Vector3(-0.85 + i * 0.85, 1.04, 8.2)
		var switch := Props.box(lab_root, Vector3(0.3,0.16,0.32), pos, [Color("79b8c9"),Color("e6c671"),Color("83bc8e")][i])
		night_controls.append({"node": switch, "action": "lab_switch", "index": i, "hint": "(E) Подключить " + ["колбу", "питание", "стабилизатор"][i]})
		var part := Node3D.new()
		lab_root.add_child(part)
		part.position = Vector3(pos.x,0.94,8.6)
		Props.cylinder(part,0.22,0.13,Vector3.ZERO,Color("516d69"))
		Props.cylinder(part,0.16,0.55,Vector3(0,0.32,0),[Color("93d5d2"),Color("e0cd79"),Color("a2cb87")][i])
		Props.ball(part,0.16,Vector3(0,0.65,0),Color("e9dcaf"))
		lab_parts.append(part)
	var start_button := Props.box(lab_root, Vector3(0.38,0.16,0.38), Vector3(-1.48,1.04,8.1), Color("c68d6d"))
	night_controls.append({"node": start_button, "action": "lab_begin", "hint": "(E) Взять комплект лаборатории"})
	var reel := Props.cylinder(lab_root,0.2,0.15,Vector3(1.48,1.03,8.15),Color("e2c080"))
	night_controls.append({"node": reel, "action": "garland_begin", "hint": "(E) Взять гирлянду · 40"})
	cable_root = Node3D.new()
	add_child(cable_root)
	cable_preview = Props.line(self,Vector3.ZERO,Vector3.UP,0.018,Color("a9ce9d"))
	cable_preview.hide()
	night_room_light = OmniLight3D.new()
	add_child(night_room_light)
	night_room_light.position = Annex.lab_world(Vector3(0,3.5,7.8))
	night_room_light.omni_range = 7
	night_room_light.light_color = Color("ffcf90")
	night_room_light.light_energy = 1.1

func night_target(camera: Camera3D) -> Dictionary:
	if game.service.progress.shift != "night": return {}
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	for entry in night_controls:
		var point: Vector3 = entry.node.global_position
		var box := AABB(point - Vector3(0.25,0.22,0.3),Vector3(0.5,0.44,0.6))
		if entry.action == "next_day": box = AABB(point - Vector3(0.7,1.2,0.2),Vector3(1.4,2.4,0.4))
		var hit = box.intersects_ray(origin,direction)
		if hit != null and origin.distance_to(hit) <= 4.2:
			var result: Dictionary = {"action": entry.action, "hint": entry.hint}
			if entry.has("index"): result.index = entry.index
			if entry.action == "lab_begin" and game.service.progress.lab_stage < 3: result.hint += " · %d" % P.LAB_PRICES[game.service.progress.lab_stage]
			return result
	if game.service.progress.garland_builder == game.session.local_id() and not game.service.progress.garland_complete:
		for z in [-7.35, 10.35]:
			if absf(direction.z) < 0.001: continue
			var distance: float = (z - origin.z) / direction.z
			var point: Vector3 = origin + direction * distance
			if distance > 0 and distance <= 4.2 and game.service.valid_wall_point(point):
				return {"action": "garland_anchor", "point": [point.x,point.y,point.z], "hint": "(E) Закрепить гирлянду · %d/4" % game.service.progress.garland_points.size()}
	return {}

func night_action_position(action: String, data: Dictionary) -> Vector3:
	if action == "garland_anchor":
		var point = data.get("point", [])
		if preload("res://scripts/team_cooking_model.gd").numbers(point, 3): return Vector3(point[0],point[1],point[2])
		return Vector3.INF
	for entry in night_controls:
		if entry.action == action and (action != "lab_switch" or entry.index == int(data.get("index",-1))): return entry.node.global_position
	return Vector3.INF

func refresh_night() -> void:
	var p = game.service.progress
	for i in range(lab_parts.size()): lab_parts[i].visible = i < p.lab_stage and p.lab_stage < 3
	lab_caption.visible = p.lab_stage < 3
	var names := ["Колба", "Питание", "Стабилизатор"]
	var schemes := [[0,1,2],[2,0,1],[1,2,0]]
	lab_caption.text = "ЛАБОРАТОРИЯ ГОТОВА" if p.lab_stage >= 3 else "ЛАБОРАТОРИЯ · %d/3" % p.lab_stage
	if p.lab_step >= 0 and p.lab_stage < 3:
		lab_caption.text += "\nПодключи: " + names[schemes[p.lab_stage][p.lab_step]] + " · %d/3" % p.lab_step
	night_room_light.visible = p.shift == "night"
	for entry in night_controls:
		if entry.action in ["lab_begin","lab_switch"]: entry.node.hide()
	var next := str(p.garland_points)
	if next == cable_stamp: return
	cable_stamp = next
	for child in cable_root.get_children(): child.queue_free()
	var points: Array = p.garland_points
	for i in range(points.size()):
		var end := Vector3(points[i][0],points[i][1],points[i][2])
		Props.ball(cable_root,0.06,end,Color("c69f72"))
		if i == 0: continue
		var start := Vector3(points[i-1][0],points[i-1][1],points[i-1][2])
		var previous := start
		for j in range(1,13):
			var t := float(j)/12.0
			var point := start.lerp(end,t) - Vector3.UP * sin(t*PI)*0.22
			Props.line(cable_root,previous,point,0.013,Color("574c3a"))
			if j % 2 == 0: Props.ball(cable_root,0.065,point,Color("ffcf82")).material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			previous = point

func _process(_delta: float) -> void:
	if game == null or not is_instance_valid(cable_preview): return
	var target: Dictionary = game.shop.target(game.camera,game.session.local_id()) if is_instance_valid(game.shop) else {}
	cable_preview.visible = target.get("action", "") == "garland_anchor" and not game.service.progress.garland_points.is_empty()
	if cable_preview.visible:
		var from: Array = game.service.progress.garland_points.back()
		var to: Array = target.point
		Props.align_line(cable_preview,Vector3(from[0],from[1],from[2]),Vector3(to[0],to[1],to[2]))
