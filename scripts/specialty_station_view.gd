extends Node3D
const M=preload("res://scripts/specialty_cooking_model.gd")
const P=preload("res://scripts/props.gd")
const Avatar=preload("res://scripts/cook_avatar.gd")
var equipment_nodes:={"grill_kit":[],"assembly_kit":[]}
var items:={}
var actors:Array=[]
var marks:={}
var patty:MeshInstance3D
var bun_top:MeshInstance3D
var status:Label3D
var station_label:Label3D
var bounds:Array=[]
var griddle:MeshInstance3D
var assembly_plate:Node3D

func build(production:=false) -> void:
	var runtime = preload("res://scripts/scene_runtime.gd")
	runtime.ensure_children(self,"res://scenes/stations/burger_station.tscn")
	griddle=get_node("Griddle/Plate") as MeshInstance3D
	assembly_plate=get_node("AssemblyPlate") as Node3D
	equipment_nodes.grill_kit=[get_node("Griddle")]
	equipment_nodes.assembly_kit=[assembly_plate]
	var item_scenes:={
		"patty":"res://scenes/props/patty.tscn",
		"patty_spatula":"res://scenes/props/patty_spatula.tscn",
		"seasoning":"res://scenes/props/burger_seasoning.tscn",
		"bun":"res://scenes/props/burger_bun.tscn",
		"cheese":"res://scenes/props/cheese.tscn",
		"sauce_bottle":"res://scenes/props/sauce_bottle.tscn",
		"chili_bottle":"res://scenes/props/chili_sauce_bottle.tscn"
	}
	for item in M.ITEMS:
		var node:=runtime.instantiate(str(item_scenes[item])) as Node3D
		add_child(node); items[item]=node
		var ring:=P.cylinder(self,0.12,0.005,Vector3.ZERO,Color("92d5d4")); ring.hide(); marks[item]=ring
	patty=items.patty.get_node("Body") as MeshInstance3D
	bun_top=items.bun.get_node("Top") as MeshInstance3D
	for role in range(2):
		var actor:=Avatar.new(); actor.tint=Color("7ba2b0") if role==0 else Color("c4926e"); add_child(actor); actors.append(actor); actor.visible=production
	station_label=get_node("StationLabel") as Label3D
	station_label.text="БУРГЕРНАЯ БРИГАДА" if production else "ПОКАЖИ ВДВОЁМ"
	station_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	status=P.text(self,"",Vector3(0,1.88,-1.15),18); status.pixel_size=0.004; status.billboard=BaseMaterial3D.BILLBOARD_ENABLED

func update_view(model,_time:=0.0,_resting:=false) -> void:
	for kit in equipment_nodes:
		for node in equipment_nodes[kit]: node.visible=kit in model.equipment
	for item in M.ITEMS:
		var point:Vector2=model.positions[item]; var node:Node3D=items[item]; node.visible=model.item_available(item); node.position=Vector3(point.x,M.BASE_Y+float(model.heights[item]),point.y); node.rotation=Vector3.ZERO
		marks[item].position=Vector3(point.x,M.BASE_Y+0.004,point.y); marks[item].visible=int(model.owners[item])>=0
		var owner:=int(model.owners[item])
		if owner>=0 and model.using[owner]:
			if item=="patty_spatula": node.rotation.y=sin(model.elapsed*8.0)*0.7
			elif item in ["seasoning","sauce_bottle","chili_bottle"]: node.rotation.z=PI+sin(model.elapsed*22.0)*0.22
	patty.material_override.albedo_color=Color("b75f4c").lerp(Color("694939"),(float(model.patty_sides[0])+float(model.patty_sides[1]))*0.5)
	if model.flip_time>0: items.patty.rotation.z=(model.flip_time/0.35)*PI
	bun_top.material_override.albedo_color=Color("e0ae62").lerp(Color("95643a"),model.bun_toast)
	griddle.material_override.albedo_color=Color("714b42") if model.griddle_conflict else Color("2f3437")
	for role in range(2):
		var item:String=model.hands[role]; var target: Vector3 = Vector3.ZERO if item.is_empty() else items[item].position+Vector3(0,0.12,0); actors[role].perform(model.poses[role],target,not item.is_empty())
		var appearance:Dictionary=model.poses[role].get("presentation",{}) if model.poses[role].get("presentation",{}) is Dictionary else {}; actors[role].book.set_live(model if appearance.get("book",false) and str(appearance.get("page",""))==model.dish else null)
	status.text="ОБЩАЯ ПЛИТА: %s\nКОТЛЕТА %d%% / %d%% · приправа %s\nБУЛКА %d%% · соус %s%s"%["КОНФЛИКТ — ОБА ЖДУТ" if model.griddle_conflict else "одна поверхность",roundi(model.patty_sides[0]*100),roundi(model.patty_sides[1]*100),"✓" if model.patty_season>=1 else "—",roundi(model.bun_toast*100),"✓" if model.sauce_amount>=1 else "—",(" · сыр "+("✓" if model.cheese_applied else "—")) if model.dish=="cheeseburger" else (" · острый "+("✓" if model.chili_amount>=1 else "—")) if model.dish=="spicy_burger" else ""]

func pick_item(camera:Camera3D) -> String:
	var origin:=to_local(camera.global_position); var ray:=global_basis.inverse()*-camera.global_basis.z; var best:=""; var distance:=100.0
	for item in M.ITEMS:
		if not items[item].visible: continue
		var center:Vector3=items[item].position+Vector3(0,0.15,0); var reach:float=(center-origin).dot(ray); var radius:=0.20 if item in ["seasoning","sauce_bottle","chili_bottle"] else 0.34
		if reach>0 and reach<distance and (origin+ray*reach).distance_to(center)<radius: distance=reach; best=item
	return best
