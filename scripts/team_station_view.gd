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
	P.solid_box(self, Vector3(6.1, 0.16, 2.25), Vector3(0, 0.92, 0), Color("b98a58"))
	for x in [-2.65, 2.65]: P.box(self, Vector3(0.18, 0.87, 1.8), Vector3(x, 0.43, 0), Color("344e53"))
	var before := get_child_count()
	for point in [M.GRILL, M.STOVE]:
		P.box(self, Vector3(1.08, 0.06, 0.9), Vector3(point.x, 1.02, point.y), Color("303d42"))
		P.cylinder(self, 0.37, 0.035, Vector3(point.x, 1.07, point.y), Color("da7846"))
	for n in range(7): P.box(self, Vector3(0.85, 0.035, 0.035), Vector3(M.GRILL.x, 1.1, M.GRILL.y - 0.3 + n * 0.1), Color("384046"))
	for plate in [M.PLATE, M.PASTA_PLATE]: serving_plates.append(P.cylinder(self, 0.44, 0.025, Vector3(plate.x, 1.03, plate.y), Color("fff0d4")))
	var new_nodes := get_children().slice(before)
	equipment_nodes.meat_kit = new_nodes.slice(0,2)+new_nodes.slice(4,11)+[new_nodes[11]]
	equipment_nodes.pasta_kit = new_nodes.slice(2,4)+[new_nodes[12]]
	for item in M.ITEMS:
		var node := Node3D.new()
		add_child(node)
		items[item] = node
		var ring := P.cylinder(self, 0.12, 0.005, Vector3.ZERO, Color("92d5d4"))
		ring.visible = false
		marks[item] = ring
	meat = P.ball(items.steak, 0.28, Vector3(0, 0.1, 0), Color("bc6355"))
	meat.scale = Vector3(1.2, 0.35, 0.8)
	for n in range(4): P.box(items.steak, Vector3(0.4, 0.007, 0.015), Vector3(0, 0.19, -0.13 + n * 0.075), Color("713d2f"))
	P.cylinder(items.pot, 0.36, 0.08, Vector3(0, 0.04, 0), Color("627e87"))
	for n in range(20):
		var a := n * TAU / 20
		P.box(items.pot, Vector3(0.12, 0.3, 0.04), Vector3(sin(a) * 0.34, 0.2, cos(a) * 0.34), Color("78939a")).rotation.y = a
	for side in [-1, 1]: P.box(items.pot, Vector3(0.18, 0.06, 0.13), Vector3(side * 0.43, 0.23, 0), Color("313b42"))
	liquid = P.cylinder(items.pot, 0.31, 0.015, Vector3(0, 0.12, 0), Color("74b9cb"))
	noodles = Node3D.new()
	items.pot.add_child(noodles)
	plated = Node3D.new()
	add_child(plated)
	plated.position = Vector3(M.PASTA_PLATE.x, 1.06, M.PASTA_PLATE.y)
	for group in [noodles, plated]:
		for n in range(18):
			var noodle := P.cylinder(group, 0.017, 0.12, Vector3(sin(n * 2.3) * 0.23, 0.04 + (n % 3) * 0.025, cos(n * 3.1) * 0.2), Color("edcf74"))
			noodle.rotation = Vector3(PI / 2, n * 0.7, 0.3)
	P.cylinder(items.water, 0.19, 0.43, Vector3(0, 0.22, 0), Color("80b5c1"), 0.23)
	P.box(items.water, Vector3(0.12, 0.06, 0.16), Vector3(0.22, 0.42, 0), Color("80b5c1"))
	P.box(items.water, Vector3(0.09, 0.3, 0.13), Vector3(-0.25, 0.23, 0), Color("80b5c1"))
	P.box(items.pasta_bag, Vector3(0.35, 0.48, 0.22), Vector3(0, 0.24, 0), Color("d7b168"))
	P.text(items.pasta_bag, "PASTA", Vector3(0, 0.25, 0.12), 12).pixel_size = 0.003
	for key in ["salt", "pasta_salt_tool"]:
		P.cylinder(items[key], 0.075, 0.17, Vector3(0, 0.085, 0), Color("efe9d6"))
		P.cylinder(items[key], 0.078, 0.035, Vector3(0, 0.18, 0), Color("718188"))
	for key in ["spatula", "pasta_spatula"]:
		P.box(items[key], Vector3(0.10, 0.035, 0.48), Vector3(0, 0.03, 0), Color("96744e"))
		P.box(items[key], Vector3(0.24, 0.025, 0.26), Vector3(0, 0.03, -0.32), Color("a2b4b4"))
	for role in range(2):
		var actor := Avatar.new()
		actor.tint = Color("689fb8") if role == 0 else Color("b58b69")
		add_child(actor)
		actors.append(actor)
		actor.visible = production
		streams.append(P.line(self, Vector3.ZERO, Vector3(0, 0.5, 0), 0.017, Color("a0d5e2")))
	station_label = P.text(self, "СТОЙКА 4 · БРИГАДА" if production else "ПОКАЖИ ВДВОЁМ\n[E] Стейк с макаронами", Vector3(0, 1.28, -1.2), 25, Color("f2cc8a"))
	station_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
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
