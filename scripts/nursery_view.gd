extends Node3D
## Procedural greenhouse, tools, sprouts and physical extraction.
const P=preload("res://scripts/props.gd")
const Layout=preload("res://scripts/laboratory_layout.gd")
const Policy=preload("res://scripts/laboratory_progression.gd")
const Avatar=preload("res://scripts/cook_avatar.gd")
const GREEN := Color("6db29a")
const WOOD := Color("ad7759")
const CREAM := Color("efdcb3")
var game: Node3D
var nursery: Node3D
var shell: Node3D
var stamp := ""
var pot_views: Dictionary={}
var tool_views: Dictionary={}
var departing: Dictionary={}
var free_views: Dictionary={}
var arm_views: Dictionary={}
var machine_arms: Dictionary={}
var effect_views: Dictionary={}
var clock := 0.0
var microscope_label: Label3D
var production_label: Label3D

func setup(owner_game: Node3D, owner_nursery: Node3D) -> void:
	game=owner_game; nursery=owner_nursery
	rebuild()

func text_at(parent: Node3D, text: String, point: Vector3, size := 20) -> Label3D:
	var label:=P.text(parent,text,point,size,CREAM)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.pixel_size=0.0035
	return label

func light_at(parent: Node3D, point: Vector3, color: Color, energy := 0.8) -> void:
	var light:=preload("res://scenes/runtime/omni_light.tscn").instantiate() as OmniLight3D
	parent.add_child(light)
	light.position=point; light.light_color=color; light.light_energy=energy; light.omni_range=5.0

func rebuild() -> void:
	if is_instance_valid(shell): shell.free()
	shell=Node3D.new(); shell.name="NurserySceneObjects"; add_child(shell)
	pot_views.clear(); machine_arms.clear()
	var p=game.service.progress
	stamp=Layout.stamp(p)
	var runtime=preload("res://scripts/scene_runtime.gd")
	# The annex owns the room shell. Nursery-specific permanent objects are authored scenes.
	var scope:=runtime.instantiate("res://scenes/lab/microscope.tscn") as Node3D
	shell.add_child(scope); scope.position=Layout.MICROSCOPE
	microscope_label=scope.get_node("Label") as Label3D
	var shelf:=runtime.instantiate("res://scenes/lab/tool_shelf.tscn") as Node3D
	shell.add_child(shelf); shelf.position=Vector3(Layout.SUPPLY_X,0,18.225)
	var tool_scenes: Dictionary={"soil":"res://scenes/lab/soil_scoop.tscn","liquid":"res://scenes/lab/formula_pipette.tscn","sample":"res://scenes/lab/formula_pipette.tscn","water":"res://scenes/lab/watering_tool.tscn","fertilizer":"res://scenes/lab/fertilizer_tool.tscn"}
	for type in nursery.TOOLS:
		var tool:=runtime.instantiate(str(tool_scenes[type])) as Node3D
		shell.add_child(tool); tool.position=Layout.tool_point(type)
	for i in range(Policy.pot_count(p)):
		var root:=runtime.instantiate("res://scenes/lab/clone_pot.tscn") as Node3D
		shell.add_child(root); root.position=Layout.pot_point(i)
		var sprout:=runtime.instantiate("res://scenes/actors/clone_sprout.tscn") as Node3D
		var actor:=sprout.get_node("Actor") as Node3D
		actor.set_script(Avatar)
		root.add_child(sprout)
		var soil:=root.get_node("Soil") as MeshInstance3D
		var mouth:=sprout.get_node("SproutDecor/HungryMouth") as Node3D
		var pellet:=sprout.get_node("FertilizerPellet") as Node3D; pellet.hide()
		var label:=text_at(root,"",Vector3(0,2.1,0),18)
		pot_views[i]={"root":root,"soil":soil,"actor":actor,"mouth":mouth,"label":label,"pellet":pellet}
		if "lab_lamps" in p.lab_upgrades:
			var lamp:=runtime.instantiate("res://scenes/lab/grow_lamp.tscn") as Node3D; root.add_child(lamp)
			light_at(root,Vector3(0,2.7,0),Color("e2b8da"),0.5)
		if "lab_feeder" in p.lab_upgrades:
			root.add_child(runtime.instantiate("res://scenes/lab/auto_feeder.tscn"))
		# Small per-pot pipes/arms remain composed from scene-backed reusable primitives.
		if "lab_irrigation" in p.lab_upgrades:
			P.line(root,Vector3(0.63,0.18,0),Vector3(0.63,1.2,0),0.025,Color("82bdb6")); P.line(root,Vector3(0.63,1.2,0),Vector3(0.3,1.15,0),0.025,Color("82bdb6"))
		if "lab_planter" in p.lab_upgrades:
			P.line(root,Vector3(0.68,0.1,0.45),Vector3(0.68,1.68,0.45),0.035,Color("779b82")); P.box(root,Vector3(0.30,0.25,0.25),Vector3(0.45,1.70,0.15),Color("c6b080")); P.line(root,Vector3(0.45,1.7,0.15),Vector3(-0.35,1.6,0.15),0.026,Color("9dd0b7"))
		if "lab_extractor" in p.lab_upgrades:
			var arm:=Node3D.new(); arm.name="ExtractorArm"; root.add_child(arm); arm.position=Vector3(0,1.75,0.3)
			for side in [-1,1]: P.line(arm,Vector3(side*0.65,0.9,0),Vector3(side*0.38,0,0),0.045,Color("d5b47d")); P.box(arm,Vector3(0.10,0.20,0.2),Vector3(side*0.33,-0.1,-0.1),Color("5b8e81"))
			machine_arms[i]=arm
	for id in p.lab_upgrades:
		if not Policy.ITEMS.has(id) or Policy.ITEMS[id].branch=="formula" or Policy.ITEMS[id].branch=="calibration" or id in ["lab_feeder","lab_lamps","lab_rack","lab_rack_2"]: continue
		build_machine(id)
	for rack_id in ["lab_rack","lab_rack_2"]:
		if rack_id in p.lab_upgrades:
			var path: String="res://scenes/lab/pot_rack.tscn" if rack_id=="lab_rack" else "res://scenes/lab/extra_rack_section.tscn"
			var rack:=runtime.instantiate(path) as Node3D
			shell.add_child(rack); rack.position=Layout.fixture(rack_id)
	production_label=text_at(shell,"",Layout.fixture("lab_production")+Vector3(0,1.8,0),18)
	production_label.visible="lab_production" in p.lab_upgrades

func build_machine(id: String) -> void:
	var paths: Dictionary={
		"lab_irrigation":"res://scenes/lab/irrigation_tank.tscn","lab_nutrients":"res://scenes/lab/nutrient_dispenser.tscn",
		"lab_planter":"res://scenes/lab/planter.tscn","lab_extractor":"res://scenes/lab/extractor.tscn",
		"lab_climate":"res://scenes/lab/climate_unit.tscn","lab_production":"res://scenes/lab/production_controller.tscn"
	}
	if not paths.has(id): return
	var root:=preload("res://scripts/scene_runtime.gd").clone_warm(str(paths[id])) as Node3D
	shell.add_child(root); root.position=Layout.fixture(id)
	text_at(root,str(Policy.ITEMS[id].name).get_slice(" · ",0),Vector3(0,1.95,0),17)

func build_tool(parent: Node3D, type: String) -> void:
	var paths: Dictionary={"soil":"res://scenes/lab/soil_scoop.tscn","liquid":"res://scenes/lab/formula_pipette.tscn","sample":"res://scenes/lab/formula_pipette.tscn","water":"res://scenes/lab/watering_tool.tscn","fertilizer":"res://scenes/lab/fertilizer_tool.tscn"}
	if paths.has(type): parent.add_child(preload("res://scripts/scene_runtime.gd").clone_warm(str(paths[type])))

func _attention_position(peer: int) -> Vector3:
	if peer==game.session.local_id(): return game.player.global_position+Vector3(0,1.2,0)
	var point: Vector3=game.laboratory.peer_position(peer)
	return point+Vector3(0,1.2,0) if point!=Vector3.INF else Vector3.INF

func _begging_target(pot_point: Vector3) -> Dictionary:
	var best_point: Vector3=Vector3.INF
	var best_distance: float=7.0
	for peer in nursery.hands:
		if nursery.tool(int(peer))!="fertilizer": continue
		var point: Vector3=_attention_position(int(peer))
		if point==Vector3.INF: continue
		var distance: float=pot_point.distance_to(point)
		if distance<best_distance:
			best_distance=distance; best_point=point
	if best_point!=Vector3.INF: return {"point":best_point,"distance":best_distance,"fertilizer":true}
	var local_point: Vector3=game.player.global_position+Vector3(0,1.2,0)
	best_distance=pot_point.distance_to(local_point)
	best_point=local_point if best_distance<5.5 else Vector3.INF
	for peer in game.session.members:
		if int(peer)==game.session.local_id(): continue
		var point: Vector3=_attention_position(int(peer))
		if point==Vector3.INF: continue
		var distance: float=pot_point.distance_to(point)
		if distance<best_distance and distance<5.5:
			best_distance=distance; best_point=point
	return {} if best_point==Vector3.INF else {"point":best_point,"distance":best_distance,"fertilizer":false}

func _apply_begging(actor: Node3D, mouth: Node3D, id: int) -> void:
	var attention: Dictionary=_begging_target(Layout.pot_point(id))
	if attention.is_empty():
		mouth.scale.y=0.5
		return
	var point: Vector3=attention.point
	var delta: Vector3=point-actor.global_position
	var distance: float=float(attention.distance)
	var reach: float=7.0 if bool(attention.fertilizer) else 5.5
	var strength: float=clampf(1.0-(distance-0.8)/(reach-0.8),0.0,1.0)
	actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-delta.x,-delta.z),0.38)
	var chirp: float=0.5+0.5*sin(clock*8.5+id*1.7)
	mouth.scale.y=0.5+strength*(1.0+chirp*0.65)
	actor.head.rotation.x=-0.18-strength*(0.08+0.05*sin(clock*10.0+id))
	actor.head.rotation.z+=sin(clock*6.0+id*1.4)*0.12*strength
	actor.position.y+=maxf(0.0,sin(clock*7.0+id))*0.035*strength

func _process(delta: float) -> void:
	if game==null: return
	var paused: bool=game.session_paused and not game.session.online()
	if not paused: clock+=delta
	if stamp!=Layout.stamp(game.service.progress): rebuild()
	var p=game.service.progress
	microscope_label.text="МИКРОСКОП\nФормула: %d%% · версия %d"%[roundi(p.lab_formula_tempo*100),p.lab_formula_version]
	production_label.text="АВТОВЫПУСК: "+("ВКЛ" if p.lab_production.enabled else "ВЫКЛ")+"\n"+nursery.notice
	for value in p.lab_pots:
		var id:=int(value.id)
		if not pot_views.has(id): continue
		var entry: Dictionary=pot_views[id]
		var actor: Node3D=entry.actor
		entry.soil.visible=value.phase!="empty"
		actor.visible=value.phase in ["growing_sprout","feed","growing_clone","ready"]
		entry.pellet.visible=float(value.get("feed_age",10))<0.8
		var seated: Dictionary={"position":Vector3(0,0.18,0),"yaw":0.0,"pose":"watch"}
		actor.lounge_pose(seated,clock,id)
		actor.scale=Vector3.ONE
		if value.phase in ["growing_sprout","feed"]:
			var maturity: float=1.0-float(value.remaining)/nursery.STAGE_SECONDS if value.phase=="growing_sprout" else 1.0
			actor.scale=Vector3.ONE*(0.14+0.24*maturity)
			actor.position.y=0.58
			actor.head.rotation.x=-0.18
		elif value.phase=="growing_clone":
			var growth: float=1.0-float(value.remaining)/float(nursery.STAGE_SECONDS)
			actor.scale=Vector3.ONE*lerpf(0.38,1.0,growth)
			actor.position.y=lerpf(0.58,0.18,growth)
		actor.head.rotation.z=sin(clock*2.0+id)*0.045
		if is_instance_valid(actor.lounge_legs): actor.lounge_legs.rotation.x=sin(clock*3.8+id)*0.09 if value.phase=="ready" else 0.0
		if value.phase=="feed": _apply_begging(actor,entry.mouth,id)
		else: entry.mouth.scale.y=0.5
		if entry.pellet.visible:
			var raw: Array=value.feed_from
			var from:=Vector3(raw[0],raw[1],raw[2])-Layout.pot_point(id)
			var amount:=clampf(float(value.feed_age)/0.8,0,1)
			entry.pellet.position=from.lerp(actor.position+Vector3(0,1.41,-0.22)*actor.scale,amount)+Vector3.UP*sin(amount*PI)*0.3
			actor.head.rotation.x=-0.25
		if nursery.pulls.has(id):
			var pull: Dictionary=nursery.pulls[id]
			var amount:=float(pull.progress)
			var direction:=Vector3(0,0,-1)
			if int(pull.owner)>0:
				direction=(game.laboratory.peer_position(int(pull.owner))-Layout.pot_point(id))*Vector3(1,0,1)
				direction=direction.normalized()
			actor.position+=Vector3.UP*(amount*0.85+sin(amount*PI*7)*0.035)+direction*amount*0.55
			actor.rotation.z=sin(clock*19)*0.055*(1-amount)
			actor.rotation.x=-0.12*amount if pull.grip=="head" else 0.14*amount
			actor.head.position.y=1.51+(0.12*amount if pull.grip=="head" else 0.0)
			if amount>0.35:
				actor.reset_lounge_accessories()
				for i in range(actor.legs.size()): actor.legs[i].rotation.x=sin(clock*16+i*PI)*0.4
			if machine_arms.has(id): machine_arms[id].position.y=1.75+amount*0.85
		else:
			actor.head.position.y=1.51
			if machine_arms.has(id): machine_arms[id].position.y=2.1
		var state_text: String={"empty":"Земля → формула → вода","soil":"Нужна капля формулы","seeded":"Нужен полив","growing_sprout":"Прорастает","feed":"Хочу удобрение!","growing_clone":"Дозревает","ready":"Вытащи меня!"}.get(value.phase,"")
		if value.phase in ["growing_sprout","growing_clone"]: state_text+=" · %d с"%ceili(float(value.remaining)/Policy.growth_speed(p))
		entry.label.text="Горшок %d · %s"%[id+1,state_text]
		if value.phase not in ["empty","soil"]: entry.label.text+="\n%d%% · формула %d"%[roundi(float(value.tempo)*100),value.formula]
		entry.label.visible=game.camera.global_position.distance_to(Layout.pot_point(id))<5.5
	draw_tools()
	draw_effects()
	draw_departures(delta)
	draw_free_workers(delta)

func draw_tools() -> void:
	for peer in tool_views.keys():
		if not nursery.hands.has(peer) or tool_views[peer].type!=str(nursery.hands[peer]):
			tool_views[peer].node.queue_free(); tool_views.erase(peer)
	for peer in nursery.hands:
		if not tool_views.has(peer):
			var root:=Node3D.new(); add_child(root); build_tool(root,str(nursery.hands[peer]))
			tool_views[peer]={"node":root,"type":str(nursery.hands[peer])}
		var root: Node3D=tool_views[peer].node
		if int(peer)==game.session.local_id():
			root.visible=not game.session.sleep_scene_active() and not game.laboratory.ui.opened()
			root.global_transform=game.camera.global_transform
			root.position+=game.camera.global_basis*Vector3(0.35,-0.30,-0.65)
			root.rotation.z+=0.25
		else:
			root.global_position=game.laboratory.peer_position(int(peer))+Vector3(0.32,1.18,-0.2)
	for peer in arm_views.keys():
		if not nursery.pulling(int(peer)):
			for arm in arm_views[peer]: arm.queue_free()
			arm_views.erase(peer)
	for id in nursery.pulls:
		var pull: Dictionary=nursery.pulls[id]
		var peer:=int(pull.owner)
		if peer<=0: continue
		if not arm_views.has(peer): arm_views[peer]=[P.line(self,Vector3.ZERO,Vector3.UP,0.06,GREEN),P.line(self,Vector3.ZERO,Vector3.UP,0.06,GREEN)]
		var growing: Node3D=pot_views[int(id)].actor
		var point: Vector3=growing.head.global_position if pull.grip=="head" else growing.to_global(Vector3(0.29 if pull.grip=="shoulder" else 0,1.20,0))
		for i in range(2):
			var start: Vector3=game.laboratory.peer_position(peer)+Vector3(-0.3 if i==0 else 0.3,1.2,0)
			if peer==game.session.local_id(): start=game.camera.global_position+game.camera.global_basis*Vector3(-0.27 if i==0 else 0.27,-0.30,-0.15)
			P.align_line(arm_views[peer][i],start,point+Vector3(-0.07 if i==0 else 0.07,0,0))

func draw_departures(_delta: float) -> void:
	var ids: Array=[]
	for entry in nursery.departures:
		var id:=int(entry.id); ids.append(id)
		if not departing.has(id):
			var actor:=Avatar.new(); add_child(actor); actor.add_to_group("automatic_door_actor"); departing[id]=actor
		var actor: Node3D=departing[id]
		var distance:=maxf(0,float(entry.age)-0.5)*3.0
		var route: Array=entry.route
		var point: Vector3=route[0]
		var direction:=Vector3.FORWARD
		for i in range(1,route.size()):
			var segment: Vector3=route[i]-route[i-1]
			if distance<segment.length(): point=Vector3(route[i-1])+segment.normalized()*distance; direction=segment; break
			distance-=segment.length(); point=route[i]; direction=segment
		actor.position=point; actor.rotation=Vector3(0,atan2(-direction.x,-direction.z),0)
		actor.celebrate(float(entry.age),1,false); actor.hat.hide()
		actor.caption.text="Клон №%d · вырос!"%id
	for id in departing.keys():
		if id not in ids: departing[id].queue_free(); departing.erase(id)

func draw_free_workers(delta: float) -> void:
	var ids: Array=[]
	var p=game.service.progress
	var index:=0
	for worker in p.free_workers:
		var id:=int(worker.id); ids.append(id)
		if not free_views.has(id):
			var actor:=Avatar.new(); add_child(actor); free_views[id]=actor
		var actor: Node3D=free_views[id]
		actor.visible=not nursery.presenting(id) and game.laboratory.reserved_clone_id()!=id
		var home:=Layout.waiting_point(index)
		actor.position=home
		actor.idle(home,delta,clock,id,0.0)
		actor.caption.text="Свободный №%d · %d%%"%[id,roundi(float(worker.tempo)*100)]
		actor.caption.visible=game.camera.global_position.distance_to(home)<4.5
		index+=1
	for id in free_views.keys():
		if id not in ids: free_views[id].queue_free(); free_views.erase(id)

func draw_effects() -> void:
	var ids: Array=[]
	for effect in nursery.effects:
		var id:=int(effect.id); ids.append(id)
		if not effect_views.has(id):
			var root:=Node3D.new(); add_child(root)
			var color: Color={"soil":Color("796042"),"liquid":Color("91dca8"),"water":Color("9fcad0")}.get(effect.kind,Color.WHITE)
			for i in range(9): P.ball(root,0.035 if effect.kind=="soil" else 0.022,Vector3.ZERO,color)
			effect_views[id]=root
		var root: Node3D=effect_views[id]
		root.visible=float(effect.age)>=0.0
		if not root.visible: continue
		var source: Vector3=effect.from
		if int(effect.peer)==game.session.local_id() and tool_views.has(effect.peer):
			var tool: Node3D=tool_views[effect.peer].node
			source=tool.global_position
			tool.rotation.z-=sin(clampf(float(effect.age)/float(effect.duration),0,1)*PI)*0.7
		var target:=Layout.pot_point(int(effect.pot))+Vector3(0,0.82,0)
		for i in range(root.get_child_count()):
			var amount:=clampf(float(effect.age)/float(effect.duration)*1.5-float(i)*0.055,0,1)
			var scatter:=Vector3(sin(i*2.4),0,cos(i*2.4))*0.15*amount
			root.get_child(i).position=source.lerp(target,amount)+scatter+Vector3.UP*sin(amount*PI)*0.15
	for id in effect_views.keys():
		if id not in ids: effect_views[id].queue_free(); effect_views.erase(id)
