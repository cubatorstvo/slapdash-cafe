extends Node3D
const M = preload("res://scripts/team_cooking_model.gd")
const P = preload("res://scripts/props.gd")
const Avatar = preload("res://scripts/cook_avatar.gd")
var spill_meshes: Array = []
var equipment_nodes := {"meat_kit":[],"pasta_kit":[]}
var serving_plates: Array = []
var items := {}
var actors: Array = []
var streams: Array = []
var marks := {}
var meat: MeshInstance3D
var liquid: MeshInstance3D
var noodles: Node3D
var plated: Node3D
var status: Label3D
var station_label: Label3D
var bounds: Array = []

func build(production := false) -> void:
	var runtime = preload("res://scripts/scene_runtime.gd")
	runtime.ensure_children(self, "res://scenes/stations/meat_pasta_station.tscn")
	station_label = get_node("StationLabel") as Label3D
	station_label.text = "СТОЙКА 4 · БРИГАДА" if production else "ПОКАЖИ ВДВОЁМ\n[E] Стейк с макаронами"
	station_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	serving_plates = [get_node("SteakPlate"), get_node("PastaPlate")]
	equipment_nodes.meat_kit = [get_node("MeatGrill"), get_node("SteakPlate")]
	equipment_nodes.pasta_kit = [get_node("PastaStove"), get_node("PastaPlate")]
	var item_scenes := {
		"steak":"res://scenes/props/steak.tscn",
		"pot":"res://scenes/props/pasta_pot.tscn",
		"water":"res://scenes/props/water_pitcher.tscn",
		"pasta_bag":"res://scenes/props/pasta_bag.tscn",
		"salt":"res://scenes/props/salt_shaker.tscn",
		"spatula":"res://scenes/props/meat_spatula.tscn",
		"pasta_salt_tool":"res://scenes/props/pasta_salt_tool.tscn",
		"pasta_spatula":"res://scenes/props/pasta_spatula.tscn"
	}
	for item in M.ITEMS:
		var node := runtime.instantiate(str(item_scenes[item])) as Node3D
		add_child(node)
		items[item] = node
		var ring := P.cylinder(self, 0.12, 0.005, Vector3.ZERO, Color("92d5d4"))
		ring.visible = false
		marks[item] = ring
	meat = items.steak.get_node("Body") as MeshInstance3D
	liquid = items.pot.get_node("LiquidPreview") as MeshInstance3D
	noodles = Node3D.new()
	items.pot.add_child(noodles)
	plated = Node3D.new()
	add_child(plated)
	plated.position = Vector3(M.PASTA_PLATE.x, 1.06, M.PASTA_PLATE.y)
	# Noodles change amount/position during cooking and remain runtime food geometry.
	for group in [noodles, plated]:
		for n in range(18):
			var noodle := P.cylinder(group, 0.017, 0.12, Vector3(sin(n * 2.3) * 0.23, 0.04 + (n % 3) * 0.025, cos(n * 3.1) * 0.2), Color("edcf74"))
			noodle.rotation = Vector3(PI / 2, n * 0.7, 0.3)
	for role in range(2):
		var actor := Avatar.new()
		actor.tint = Color("689fb8") if role == 0 else Color("b58b69")
		add_child(actor)
		actors.append(actor)
		actor.visible = production
		streams.append(P.line(self, Vector3.ZERO, Vector3(0, 0.5, 0), 0.017, Color("a0d5e2")))
	status = P.text(self, "", Vector3(0, 1.85, -1.15), 19)
	status.pixel_size = 0.004
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if not production:
		for spec in [[Vector3(0.02, 2.6, 4.8), Vector3(-3.4, 1.3, 0.8)], [Vector3(0.02, 2.6, 4.8), Vector3(3.4, 1.3, 0.8)], [Vector3(6.8, 2.6, 0.02), Vector3(0, 1.3, -1.6)], [Vector3(6.8, 2.6, 0.02), Vector3(0, 1.3, 3.2)]]:
			var mesh := P.box(self, spec[0], spec[1], Color("86d7c2"))
			mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.material_override.albedo_color.a = 0.035
			mesh.hide()
			bounds.append(mesh)

func update_view(model, _time := 0.0, _resting := false) -> void:
	for kit in equipment_nodes:
		for node in equipment_nodes[kit]: node.visible=kit in model.equipment
	for item in M.ITEMS:
		var point: Vector2 = model.positions[item]
		var node: Node3D = items[item]
		node.visible = model.item_available(item)
		node.position = Vector3(point.x, M.BASE_Y + model.heights[item], point.y)
		if item == "steak" and model.meat_state == "grill": node.position.y += 0.10
		if item == "pot" and point.distance_to(M.STOVE) < 0.45: node.position.y += 0.075
		node.rotation = Vector3.ZERO
		marks[item].position = Vector3(point.x, M.BASE_Y + 0.004, point.y)
		marks[item].visible = model.owners[item] >= 0
		var owner: int = model.owners[item]
		if owner >= 0 and model.using[owner]:
			if item == "pasta_bag": node.rotation.x = -0.8
			elif item in ["salt", "pasta_salt_tool"]: node.rotation.z = PI + sin(model.elapsed * 22) * 0.25
			elif item in ["spatula", "pasta_spatula"]: node.rotation.y = sin(model.elapsed * 8) * 0.7
		if item in model.vessels:
			node.rotation.z = -deg_to_rad(model.vessels[item].angle)
			var pivot: float = model.vessels[item].pivot_height
			node.position += Vector3.UP * pivot - node.basis * Vector3.UP * pivot
	meat.material_override.albedo_color = Color("bc6355").lerp(Color("74513a"), model.meat_sides[1 - model.meat_face])
	if model.flip_time > 0: items.steak.rotation.z = (model.flip_time / 0.35) * PI
	liquid.visible = model.water > 0
	liquid.position.y = 0.09 + model.water / 800 * 0.19
	noodles.visible = model.pasta > 0
	noodles.position.y = liquid.position.y
	plated.visible = model.served_pasta > 0
	for role in range(2): serving_plates[role].visible=("meat_kit" if role==0 else "pasta_kit") in model.equipment and "serving_plate" not in model.guest_roles[role].swallowed
	for role in range(2):
		var item: String = model.hands[role]
		var target: Vector3 = Vector3.ZERO if item.is_empty() else items[item].position + Vector3(0, 0.12, 0)
		actors[role].perform(model.poses[role], target, not item.is_empty())
		var appearance: Dictionary = model.poses[role].get("presentation", {}) if model.poses[role].get("presentation", {}) is Dictionary else {}
		actors[role].book.set_live(model if appearance.get("book", false) and str(appearance.get("page", "")) == "meal" else null)
		streams[role].visible = model.pouring[role] and not item.is_empty()
		if streams[role].visible:
			streams[role].material_override.albedo_color = Color("a0d5e2") if item == "water" else (Color("fff5d8") if item in ["salt", "pasta_salt_tool"] else Color("edcf74"))
			if item in model.vessels:
				var end: Vector2 = model.pour_target(item)
				P.align_line(streams[role], model.mouth(item), M.GUEST_MOUTH if model.pours_into_guest(item) else Vector3(end.x, M.surface_at(end) + 0.08, end.y))
			else: P.align_line(streams[role], target, Vector3(target.x, M.BASE_Y + 0.08, target.z))
	for mesh in spill_meshes: mesh.hide()
	for i in range(model.spills.size()):
		if i == spill_meshes.size(): spill_meshes.append(P.cylinder(self, 1, 0.008, Vector3.ZERO, Color("8aa9a0")))
		var entry: Array = model.spills[i]
		spill_meshes[i].show()
		spill_meshes[i].position = Vector3(entry[0], M.surface_at(Vector2(entry[0], entry[1])) + 0.008, entry[1])
		var radius := clampf(sqrt(entry[2]) * 0.025, 0.025, 0.3)
		spill_meshes[i].scale = Vector3(radius, 1, radius)
	status.text = "МЯСО %d%% / %d%% · соль %s\nВОДА %d/500 мл · МАКАРОНЫ %d/100 г\nВарка %d%% · мешать %d%% · соль %s" % [model.meat_sides[0] * 100, model.meat_sides[1] * 100, "✓" if model.meat_salt >= 1 else "—", model.water, model.pasta + model.served_pasta, model.cooked * 100, model.stirred * 100, "✓" if model.pasta_salt >= 1 else "—"]

func pick_item(camera: Camera3D) -> String:
	var origin := to_local(camera.global_position)
	var ray := global_basis.inverse() * -camera.global_basis.z
	var best := ""
	var distance := 100.0
	for item in M.ITEMS:
		if not items[item].visible: continue
		var center: Vector3 = items[item].position + Vector3(0, 0.16, -0.12 if item in ["spatula", "pasta_spatula"] else 0)
		var reach := (center - origin).dot(ray)
		var radius := 0.17 if item in ["salt", "pasta_salt_tool"] else (0.32 if item in ["spatula", "pasta_spatula"] else 0.37)
		if reach > 0 and reach < distance and (origin + ray * reach).distance_to(center) < radius:
			distance = reach
			best = item
	return best
