extends Node3D
const Props = preload("res://scripts/props.gd")
const P = preload("res://scripts/cafe_progression.gd")
const Annex = preload("res://scripts/cafe_annex.gd")
const Expansion = preload("res://scripts/cafe_expansion_layout.gd")
const SceneRuntime = preload("res://scripts/scene_runtime.gd")
var game: Node3D
var board: Node3D
var decor := {}
var slots: Array = []
var zone_signs: Array = []
var ribbon: Node3D
var specialty_ribbon: Node3D
var orchestration_ribbon: Node3D
var star_label: Label3D

func build(root_game: Node3D) -> void:
	game = root_game
	board=SceneRuntime.instantiate("res://scenes/decor/my_cafe_board.tscn") as Node3D
	add_child(board)
	star_label=board.get_node("Stars") as Label3D
	for i in range(Expansion.SLOT_COUNT):
		var marker := Node3D.new()
		add_child(marker)
		marker.position = game.service.slot_position(i)
		marker.rotation.y=Expansion.rotation_y(i)
		var pad:=Props.box(marker, Vector3(6.4, 0.012, 5.5), Vector3(0, 0.012, 0), Color("61716a"))
		pad.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		pad.material_override.albedo_color.a=0.28
		var label := Props.text(marker, "", Vector3(0, 1.3, 0), 27, Color("e7c591"))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.005
		slots.append({"node": marker, "label": label})
	_bind_authored_world()
	ribbon = Node3D.new()
	add_child(ribbon)
	Props.box(ribbon, Vector3(6.0, 0.11, 0.04), Vector3(13.8, 1.0, 0.65), Color("bfa565"))
	specialty_ribbon=Node3D.new(); add_child(specialty_ribbon)
	Props.box(specialty_ribbon,Vector3(6.2,0.13,0.08),Vector3(10.2,1.0,2.0),Color("c7a65e"))
	var specialty_sign:=Props.text(specialty_ribbon,"СПЕЦИАЛИЗИРОВАННЫЙ СЕКТОР\nТРЕТЬЯ ЗВЕЗДА",Vector3(10.2,1.55,2.0),23,Color("f0d28f")); specialty_sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	orchestration_ribbon=Node3D.new(); add_child(orchestration_ribbon)
	Props.box(orchestration_ribbon,Vector3(6.2,0.13,0.08),Vector3(3.2,1.0,2.0),Color("a97965"))
	var orchestration_sign:=Props.text(orchestration_ribbon,"СЕКТОР ОРКЕСТРАЦИИ\nЧЕТВЁРТАЯ ЗВЕЗДА",Vector3(3.2,1.55,2.0),23,Color("f0d28f")); orchestration_sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	build_night()
	refresh()

func _bind_authored_world() -> void:
	zone_signs.clear(); decor.clear()
	if not is_instance_valid(game.room_shell): return
	for spec in [["ZoneA",2],["ZoneB",3],["ZoneC",4],["ZoneD",4]]:
		var node: Node=game.room_shell.get_node_or_null(str(spec[0])+"/ZoneLabel")
		if node!=null: zone_signs.append({"node":node,"stage":int(spec[1])})
	decor.sign=game.room_shell.get_node_or_null("AlmostReadySign")
	decor.lights=game.room_shell.get_node_or_null("Garland")
	decor.plants=game.room_shell.get_node_or_null("AuthoredPlants")

func board_hit(camera: Camera3D) -> bool:
	var origin := board.to_local(camera.global_position)
	var ray := board.global_basis.inverse() * -camera.global_basis.z
	var hit = AABB(Vector3(-0.85, 0.35, -0.1), Vector3(1.7, 1.7, 0.3)).intersects_ray(origin, ray)
	return hit != null and origin.distance_to(hit) < 3.5

func refresh() -> void:
	_bind_authored_world()
	var progress = game.service.progress
	for sign in zone_signs: sign.node.visible = int(sign.stage)<=Expansion.stage_for_progress(progress)
	for id in decor:
		if is_instance_valid(decor[id]): decor[id].visible = id in progress.decorations
	for i in range(slots.size()):
		slots[i].node.visible = game.service.by_id(i + 1) == null and Expansion.slot_available(i,Expansion.stage_for_progress(progress))
		if i >= Expansion.BASE_SLOT_COUNT:
			slots[i].label.text = Expansion.slot_label(i + 1) + "\n[E] Компьютер · выбрать кухню"
		elif i < 3:
			slots[i].label.text = "МЕСТО ДЛЯ СТОЙКИ\nПервая звезда" if progress.stars == 0 else "МЕСТО ДЛЯ СТОЙКИ\n[E] Компьютер · 120"
		elif i == 3:
			slots[i].label.text = "РАСШИРЕНИЕ ЗАЛА\nВторая звезда" if not progress.expanded else "КУХНЯ НА ДВОИХ\n[E] Компьютер · 250"
		elif i == 4:
			slots[i].label.text = "СПЕЦИАЛИЗАЦИЯ\nТретья звезда" if not progress.specialized_expanded else "ОБЩАЯ ЖАРОЧНАЯ\n[E] Компьютер · 380"
		else:
			slots[i].label.text = "ОРКЕСТРАЦИЯ\nЧетвёртая звезда" if not progress.orchestration_expanded else "СОЛЯНКА · ТРИ РОЛИ\n[E] Компьютер · 520"
	ribbon.visible = false
	specialty_ribbon.visible = false
	orchestration_ribbon.visible = false
	var stars_text := PackedStringArray()
	for i in range(5): stars_text.append("★" if i < progress.stars else "☆")
	star_label.text = " ".join(stars_text)
	if is_instance_valid(decor.get("lights")): decor.lights.hide()
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
	var bench:=SceneRuntime.instantiate("res://scenes/lab/assembly_bench.tscn") as Node3D
	lab_root.add_child(bench); bench.position=Vector3(0,0,8.3)
	lab_caption = Props.text(lab_root, "ЛАБОРАТОРИЯ", Vector3(0,2.35,8.3), 27, Color("edd09d"))
	lab_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lab_caption.pixel_size = 0.005
	var module_paths=["res://scenes/lab/initial_module_1.tscn","res://scenes/lab/initial_module_2.tscn","res://scenes/lab/initial_module_3.tscn"]
	for i in range(3):
		var part:=SceneRuntime.instantiate(module_paths[i]) as Node3D
		lab_root.add_child(part); part.position=Vector3(-0.85+i*0.85,0.78,8.55); lab_parts.append(part)
	var controls:=SceneRuntime.instantiate("res://scenes/lab/initial_controls.tscn") as Node3D
	lab_root.add_child(controls); controls.position=Vector3(0,0.68,8.32); controls.scale.x=2.0
	var switch_nodes=[controls.get_node("Switch1"),controls.get_node("Switch2"),controls.get_node("ReadyLamp")]
	for i in range(3): night_controls.append({"node":switch_nodes[i],"action":"lab_switch","index":i,"hint":"(E) Подключить "+["колбу","питание","стабилизатор"][i]})
	var start_button:=controls.get_node("StartButton")
	night_controls.append({"node":start_button,"action":"lab_begin","hint":"(E) Взять комплект лаборатории"})
	var reel:=SceneRuntime.instantiate("res://scenes/lab/cable_reel.tscn") as Node3D
	lab_root.add_child(reel); reel.position=Vector3(1.48,0.72,8.15)
	night_controls.append({"node":reel,"action":"garland_begin","hint":"(E) Взять гирлянду · 40"})
	cable_root = Node3D.new(); add_child(cable_root)
	cable_preview = Props.line(self,Vector3.ZERO,Vector3.UP,0.018,Color("a9ce9d")); cable_preview.hide()
	night_room_light = SceneRuntime.instantiate("res://scenes/runtime/omni_light.tscn") as OmniLight3D
	add_child(night_room_light)
	night_room_light.position = Annex.lab_world(Vector3(0,3.5,7.8)); night_room_light.omni_range = 7; night_room_light.light_color = Color("ffcf90"); night_room_light.light_energy = 1.1

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
		for z in [Annex.CAFE_BACK_Z]:
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
