extends Node3D
const M = preload("res://scripts/solyanka_cooking_model.gd")
const P = preload("res://scripts/props.gd")
const Avatar = preload("res://scripts/cook_avatar.gd")
var station_label: Label3D
var status: Label3D
var actors: Array = []
var items: Dictionary = {}
var marks: Dictionary = {}
var fire_root: Node3D
var broth: MeshInstance3D
var last_pot_count := 0
var is_production := false

func build(production := false) -> void:
	is_production = production
	var runtime = preload("res://scripts/scene_runtime.gd")
	runtime.ensure_children(self,"res://scenes/stations/solyanka_station.tscn")
	broth=get_node("Cauldron/Broth") as MeshInstance3D
	fire_root=get_node("Cauldron/Fire") as Node3D
	var item_scenes:={
		"lighter":"res://scenes/props/solyanka_lighter.tscn", "potato":"res://scenes/props/solyanka_potato.tscn", "onion":"res://scenes/props/solyanka_onion.tscn",
		"tomato":"res://scenes/props/solyanka_tomato.tscn", "carrot":"res://scenes/props/solyanka_carrot.tscn", "garlic":"res://scenes/props/solyanka_garlic.tscn",
		"boot":"res://scenes/props/solyanka_boot.tscn", "paddle":"res://scenes/props/solyanka_paddle.tscn", "cabbage":"res://scenes/props/solyanka_cabbage.tscn",
		"cucumber":"res://scenes/props/solyanka_cucumber.tscn", "beet":"res://scenes/props/solyanka_beet.tscn", "pepper":"res://scenes/props/solyanka_pepper.tscn",
		"zucchini":"res://scenes/props/solyanka_zucchini.tscn", "mug":"res://scenes/props/solyanka_mug.tscn", "salt":"res://scenes/props/solyanka_salt.tscn",
		"pickle":"res://scenes/props/solyanka_pickle.tscn", "lemon":"res://scenes/props/solyanka_lemon.tscn", "sausage":"res://scenes/props/solyanka_sausage.tscn",
		"mushroom":"res://scenes/props/solyanka_mushroom.tscn", "eggplant":"res://scenes/props/solyanka_eggplant.tscn", "bolt":"res://scenes/props/solyanka_bolt.tscn"
	}
	for item in M.ITEMS:
		var node:=runtime.instantiate(str(item_scenes[item])) as Node3D
		add_child(node); items[item]=node
		var mark:=P.cylinder(self,0.16,0.008,Vector3.ZERO,Color("f3d690")); marks[item]=mark
	for role in range(3):
		var actor:=Avatar.new(); actor.tint=[Color("a56b58"),Color("6e9c83"),Color("8b78a8")][role]; add_child(actor); actors.append(actor); actor.visible=production
	station_label=get_node("StationLabel") as Label3D
	station_label.text="СОЛЯНКА · ТРИ РОЛИ" if production else "ПОКАЖИ ВТРОЁМ"
	station_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	status=P.text(self,"",Vector3(0,-20,0),1,Color(0,0,0,0)); status.hide()

func _build_item(parent: Node3D, item: String) -> void:
	match item:
		"lighter":
			P.box(parent,Vector3(0.14,0.26,0.08),Vector3(0,0.13,0),Color("d85c47")); P.box(parent,Vector3(0.10,0.06,0.07),Vector3(0,0.29,0),Color("c6c0a8"))
		"paddle":
			P.box(parent,Vector3(0.08,0.62,0.08),Vector3(0,0.31,0),Color("bc9360")); P.box(parent,Vector3(0.30,0.07,0.22),Vector3(0,0.64,0),Color("c8a06c"))
		"salt":
			P.cylinder(parent,0.12,0.30,Vector3(0,0.15,0),Color("e7e1ce")); P.cylinder(parent,0.11,0.05,Vector3(0,0.325,0),Color("7d8580"))
		"boot":
			P.box(parent,Vector3(0.26,0.34,0.20),Vector3(0,0.17,0),Color("5b4335")); P.box(parent,Vector3(0.22,0.12,0.38),Vector3(0,0.05,-0.12),Color("4a372d"))
		"mug":
			P.cylinder(parent,0.15,0.25,Vector3(0,0.125,0),Color("91b9b7")); P.box(parent,Vector3(0.10,0.15,0.05),Vector3(0.18,0.14,0),Color("91b9b7"))
		"bolt":
			P.cylinder(parent,0.07,0.32,Vector3(0,0.16,0),Color("8a9290")); P.cylinder(parent,0.13,0.07,Vector3(0,0.34,0),Color("747c7a"))
		"sausage":
			var s := P.cylinder(parent,0.08,0.42,Vector3(0,0.20,0),Color("c77862")); s.rotation.z = PI/2
		"carrot", "cucumber", "pickle", "zucchini":
			var c := P.cylinder(parent,0.09,0.38,Vector3(0,0.18,0),Color("d77f45") if item=="carrot" else Color("6e9f60")); c.rotation.z = PI/2
		"cabbage":
			P.ball(parent,0.20,Vector3(0,0.20,0),Color("8eae6b"))
		"lemon":
			var l := P.ball(parent,0.15,Vector3(0,0.15,0),Color("dfc950")); l.scale = Vector3(1.25,0.85,0.85)
		"mushroom":
			P.cylinder(parent,0.07,0.18,Vector3(0,0.09,0),Color("ded0ad")); P.ball(parent,0.16,Vector3(0,0.24,0),Color("a77b62")).scale.y = 0.55
		"garlic":
			P.ball(parent,0.13,Vector3(0,0.13,0),Color("e6dcc3"))
		"eggplant":
			var e := P.ball(parent,0.16,Vector3(0,0.16,0),Color("76507f")); e.scale = Vector3(0.85,0.95,1.35)
		"onion", "tomato", "potato", "beet", "pepper":
			var colors := {"onion":Color("d6c3a0"),"tomato":Color("d85b49"),"potato":Color("b99157"),"beet":Color("9e4659"),"pepper":Color("d69a43")}
			var f := P.ball(parent,0.16,Vector3(0,0.16,0),colors[item]); f.scale = Vector3(1.0,0.9,1.15)
		_:
			P.ball(parent,0.14,Vector3(0,0.14,0),Color("caa369"))

func update_view(model,_time := 0.0,_resting := false) -> void:
	status.hide()
	fire_root.visible = model.fire_started
	if fire_root.visible:
		fire_root.scale.y = 0.90 + sin(model.elapsed*14.0)*0.12
	broth.material_override.albedo_color = Color("9e4934").lerp(Color("7b5538"),clampf(float(model.pot_count())/M.MIN_CONTENTS,0,1)*0.45)
	for item in M.ITEMS:
		var node: Node3D = items[item]
		node.visible = model.item_available(item)
		if node.visible:
			var point: Vector2 = model.positions[item]
			node.position = Vector3(point.x,M.BASE_Y+float(model.heights[item]),point.y)
			node.rotation = Vector3.ZERO
			var owner := int(model.owners[item])
			if owner >= 0 and model.using[owner]:
				if item == "paddle": node.rotation.y = sin(model.elapsed*11.0)*0.9
				elif item == "salt": node.rotation.z = PI + sin(model.elapsed*20.0)*0.20
				elif item == "lighter": node.rotation.z = -0.35
		var mark: Node3D = marks[item]
		mark.position = Vector3(model.positions[item].x,M.BASE_Y+0.004,model.positions[item].y)
		mark.visible = node.visible and int(model.owners[item]) >= 0
	for role in range(3):
		var item: String = model.hands[role]
		var target: Vector3 = Vector3.ZERO if item.is_empty() else items[item].position+Vector3(0,0.12,0)
		actors[role].perform(model.poses[role],target,not item.is_empty())
		var appearance: Dictionary = model.poses[role].get("presentation",{}) if model.poses[role].get("presentation",{}) is Dictionary else {}
		actors[role].book.set_live(model if appearance.get("book",false) and str(appearance.get("page",""))==model.dish else null)
	var count: int = model.pot_count()
	if count > last_pot_count:
		for n in range(mini(3,count-last_pot_count)): _splash(count+n)
	last_pot_count = count

func _splash(seed: int) -> void:
	for i in range(6):
		var angle := float(seed*3+i)*1.17
		var drop := P.ball(self,0.045,Vector3(M.POT.x+cos(angle)*0.18,1.66,M.POT.y+sin(angle)*0.18),Color("b75d3c"))
		drop.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var end := drop.position+Vector3(cos(angle)*0.38,0.28+0.05*(i%3),sin(angle)*0.38)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(drop,"position",end,0.32)
		tween.tween_property(drop,"scale",Vector3.ZERO,0.32)
		tween.tween_property(drop.material_override,"albedo_color:a",0.0,0.32)
		tween.chain().tween_callback(drop.queue_free)

func pick_item(camera: Camera3D) -> String:
	var origin := to_local(camera.global_position)
	var ray := global_basis.inverse()*-camera.global_basis.z
	var best := ""
	var distance := 100.0
	for item in M.ITEMS:
		if not items[item].visible: continue
		var center: Vector3 = items[item].position+Vector3(0,0.16,0)
		var reach := (center-origin).dot(ray)
		if reach>0 and reach<distance and (origin+ray*reach).distance_to(center)<0.30:
			distance=reach; best=item
	return best
