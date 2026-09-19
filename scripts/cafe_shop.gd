extends Node3D
const Props = preload("res://scripts/props.gd")
const Annex = preload("res://scripts/cafe_annex.gd")
const LabPolicy = preload("res://scripts/laboratory_progression.gd")
const LabLayout = preload("res://scripts/laboratory_layout.gd")
const LoungeProgress = preload("res://scripts/lounge_progression.gd")
const Layout = preload("res://scripts/lounge_layout.gd")
const Expansion = preload("res://scripts/cafe_expansion_layout.gd")
const Installer = preload("res://scripts/delivery_installer.gd")
var ITEMS: Dictionary = preload("res://scripts/cafe_catalogue.gd").ITEMS.duplicate(true)
var game: Node3D
var boxes := {}
var installers := {}
var local_ghost: MeshInstance3D
var placement_beacon: MeshInstance3D
var placement_label: Label3D
var placement_clock := 0.0
var garland_reels := {}
var guide_nodes: Array = []
var computer: Node3D
var truck: Node3D
var truck_age := 0.0
var saved_status := ""

func setup(owner_game: Node3D) -> void:
	game = owner_game
	ITEMS.merge(LoungeProgress.shop_items())
	ITEMS.merge(LabPolicy.catalogue(),true)
	local_ghost = Props.box(self,Vector3(1.15,0.08,1.15),Vector3.ZERO,Color("72efb3"))
	local_ghost.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	local_ghost.material_override.albedo_color.a = 0.42
	local_ghost.material_override.emission_enabled = true
	local_ghost.material_override.emission = Color("72efb3")
	local_ghost.material_override.emission_energy_multiplier = 1.6
	local_ghost.hide()
	placement_beacon = Props.cylinder(self,0.075,5.2,Vector3.ZERO,Color("72efb3"))
	placement_beacon.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	placement_beacon.material_override.albedo_color.a = 0.24
	placement_beacon.material_override.emission_enabled = true
	placement_beacon.material_override.emission = Color("72efb3")
	placement_beacon.material_override.emission_energy_multiplier = 2.0
	placement_beacon.hide()
	placement_label = Props.text(self,"▼  УСТАНОВИТЬ СЮДА",Vector3.ZERO,30,Color("e8ffd1"))
	placement_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	placement_label.pixel_size = 0.0045
	placement_label.outline_size = 10
	placement_label.hide()
	# A visible computer replaces the abstract cafe board.
	computer = Node3D.new()
	add_child(computer)
	computer.position = Vector3(-10.7,0,-4.6)
	computer.rotation.y=PI/2
	Props.solid_box(computer,Vector3(1.65,0.12,0.9),Vector3(0,0.86,0),Color("99765b"))
	for x in [-0.65,0.65]: Props.solid_box(computer,Vector3(0.1,0.85,0.6),Vector3(x,0.425,0),Color("405b58"))
	Props.box(computer,Vector3(0.95,0.65,0.2),Vector3(0,1.3,-0.15),Color("d8c9a3"))
	Props.box(computer,Vector3(0.82,0.51,0.025),Vector3(0,1.3,-0.035),Color("213b40"))
	Props.text(computer,"ТЯП-ЛЯП МАРКЕТ\n[E] Компьютер",Vector3(0,1.33,-0.01),18,Color("d9c18c"))
	Props.box(computer,Vector3(0.75,0.035,0.22),Vector3(0,0.945,0.22),Color("d7cfae"))
	game.development.board.hide()
	for i in range(3):
		var at := lab_position(i)
		var ghost := Props.cylinder(self,0.24,0.07,at-Vector3.UP*0.1,Color("79b8b0"))
		var label := Props.text(self,ITEMS["lab_%d"%i].name+"\nНужна доставка",at+Vector3.UP*0.8,17,Color("d4c99b"))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		guide_nodes.append({"mesh":ghost,"label":label})
	truck = Node3D.new()
	add_child(truck)
	Props.box(truck,Vector3(1.2,1.15,1.65),Vector3(0,0.9,0),Color("dca859"))
	Props.box(truck,Vector3(1.2,0.8,0.7),Vector3(0,0.72,1.0),Color("69a799"))
	for x in [-0.65,0.65]:
		for z in [-0.55,0.9]: Props.ball(truck,0.23,Vector3(x,0.28,z),Color("263536"))
	truck.hide()

func computer_hit(camera: Camera3D) -> bool:
	var ray := camera.project_ray_normal(camera.get_viewport().get_visible_rect().size/2)
	var hit = AABB(Vector3(-0.85,0.8,-0.3),Vector3(1.7,0.9,0.85)).intersects_ray(computer.to_local(camera.global_position),computer.global_basis.inverse()*ray)
	return hit != null and camera.global_position.distance_to(computer.to_global(hit)) < 3.6

func log_event(kind: String, data := {}) -> void:
	if is_instance_valid(game.telemetry): game.telemetry.event(kind,data)

func pending(item: String, station_id: int) -> bool:
	for box in game.service.progress.deliveries:
		if item in box.get("items",[box.item]) and box.station == station_id: return true
	return false

func installer_supported(item: String) -> bool:
	if not ITEMS.has(item): return false
	return str(ITEMS[item].kind) in ["station","equipment","lounge"]

func type_available(type_id: String) -> bool:
	var p=game.service.progress
	if not ITEMS.has(type_id) or ITEMS[type_id].kind!="station" or p.stars<int(ITEMS[type_id].get("star",0)): return false
	if type_id=="kitchen": return p.expanded
	if type_id=="grill_kitchen": return p.specialized_expanded
	if type_id=="solyanka_kitchen": return p.orchestration_expanded
	return type_id=="counter"

func equipment_catalog(type_id: String) -> Array:
	var result: Array=[]
	for item in ITEMS:
		if ITEMS[item].kind=="equipment" and equipment_allowed(type_id,str(item)): result.append(str(item))
	result.sort()
	return result

func group_training_plan(group_id: String,type_id: String) -> Dictionary:
	if group_id.is_empty(): return {}
	var group: Dictionary=game.service.table_group_by_id(group_id)
	if group.is_empty() or str(group.type_id)!=type_id: return {}
	var plan: Dictionary={}
	for item in group.get("curriculum",[]):
		var dish:=str(item.get("dish_id",""))
		var id:=int(item.get("record_id",0))
		var current: Dictionary=game.service.masterclass_by_id(id)
		if id>0: plan[dish]={"id":id,"name":str(current.get("name","Запись #%d"%id)),"revision":int(item.get("revision",1))}
	return plan

func _delivery_position(id: int) -> Array:
	return [-10.1+(id%3)*0.65,0.3,4.8+floorf(float(id%9)/3)*0.65]

func _new_delivery(item: String,station_id: int,items: Array,installer: bool,delay: float,extra: Dictionary={}) -> Dictionary:
	var p=game.service.progress
	var id: int=p.next_delivery_id
	p.next_delivery_id+=1
	var parcel: Dictionary={"id":id,"item":item,"items":items.duplicate(),"station":station_id,"remaining":delay,"owner":0,"position":_delivery_position(id),"installer":installer,"installer_state":"waiting_delivery","installer_position":_delivery_position(id),"installer_age":0.0,"installer_variant":id%4}
	for key in extra: parcel[key]=extra[key]
	return parcel

func equipment_allowed(type_id: String, item: String) -> bool:
	if type_id=="counter": return item in ["sauce","plates","cup","pan","jug","rag","sauce_ramp"]
	if type_id=="kitchen": return item in ["meat_kit","pasta_kit"]
	if type_id=="grill_kitchen": return item in ["grill_kit","assembly_kit"]
	if type_id=="solyanka_kitchen": return item in ["fire_kit","stir_kit","salt_kit"]
	return false

func order(item: String, station_id: int, with_installer := false) -> String:
	var p = game.service.progress
	if not ITEMS.has(item): return "Товар не найден."
	var spec: Dictionary = ITEMS[item]
	if p.stars < int(spec.get("star",0)): return "Откроется после звезды %d." % spec.star
	if p.busy(): return "Сначала заверши проверку."
	var station = game.service.by_id(station_id)
	if spec.kind == "lounge":
		station_id=0
		var error:=LoungeProgress.item_error(p,spec)
		if not error.is_empty(): return error
	elif spec.kind == "equipment":
		if station == null or not equipment_allowed(station.type_id,item): return "Это оборудование не подходит выбранной станции."
		if item in station.equipment or item in station.upgrades: return "Уже установлено."
	elif spec.kind == "station":
		if item == "solyanka_kitchen":
			if not p.orchestration_expanded: return "Сначала открой сектор оркестрации."
			station_id = 6
		elif item == "grill_kitchen":
			if not p.specialized_expanded: return "Сначала открой специализированный сектор."
			station_id = 5
		elif item == "kitchen":
			if not p.expanded: return "Сначала расширь зал."
			station_id = 4
		else:
			station_id = 0
			for id in [2,3]:
				if game.service.by_id(id) == null and not pending("counter",id): station_id = id; break
		if station_id == 0 or game.service.by_id(station_id) != null: return "Свободных мест нет."
	elif spec.kind == "lab_upgrade":
		station_id=0
		var error:=LabPolicy.error(p,item)
		if not error.is_empty(): return error
	elif spec.kind == "lab":
		station_id = 0
		if int(item.get_slice("_",1)) < p.lab_stage: return "Деталь уже установлена."
	elif spec.kind == "decor":
		station_id = 0
		if item in p.decorations: return "Уже установлено."
	elif spec.kind == "garland":
		station_id = 0
		if p.garland_owned: return "Гирлянда уже куплена."
	if pending(item,station_id): return "Доставка уже заказана."
	if p.cash < spec.price: return "Не хватает денег."
	p.cash -= spec.price
	var installer: bool=bool(with_installer) and installer_supported(item)
	p.deliveries.append(_new_delivery(item,station_id,[item],installer,8.0))
	p.revision += 1
	log_event("purchase",{"item":item,"station":station_id,"price":spec.price,"cash":p.cash})
	return ""

func carried(peer: int) -> int:
	for parcel in game.service.progress.deliveries:
		if parcel.owner == peer: return parcel.id
	return -1

func parcel_by_id(id: int) -> Dictionary:
	for parcel in game.service.progress.deliveries:
		if parcel.id == id: return parcel
	return {}

func parcel_has_installer(parcel: Dictionary) -> bool:
	return bool(parcel.get("installer",false))

func station_install_blocked(parcel: Dictionary) -> bool:
	var spec: Dictionary=ITEMS[parcel.item]
	if spec.kind=="station": return game.service.by_id(int(parcel.station))!=null
	if spec.kind=="equipment":
		var station=game.service.by_id(int(parcel.station))
		return station==null or station.state not in ["idle","waiting"] or station.customer_id>=0 or station.training.active() or not station.group_training_state.is_empty()
	if spec.kind=="lounge": return not game.session.sleeping_peers.is_empty()
	return false

func lab_position(index: int) -> Vector3: return Annex.lab_world(Vector3(-0.85+index*0.85,1.05,8.6))
func installation_position(parcel: Dictionary) -> Vector3:
	var spec: Dictionary = ITEMS[parcel.item]
	if spec.kind == "lounge":
		return Layout.item_position(str(spec.lounge_id),game.service.progress.lounge_tier)+Vector3.UP*0.8
	if spec.kind == "station": return game.service.slot_position(parcel.station-1)+Vector3.UP
	if spec.kind == "equipment":
		var station = game.service.by_id(parcel.station)
		if station == null: return Vector3.INF
		var places := {"meat_kit":Vector3(-1.4,1.1,-0.15),"pasta_kit":Vector3(1.4,1.1,-0.15),"grill_kit":Vector3(-1.35,1.1,-0.25),"assembly_kit":Vector3(1.35,1.1,0.45),"fire_kit":Vector3(-2.0,1.1,0.6),"stir_kit":Vector3(0,1.1,1.25),"salt_kit":Vector3(2.0,1.1,0.6),"pan":Vector3(-1.05,1.2,-0.1),"sauce":Vector3(0.3,1.09,-0.7),"plates":Vector3(1.3,0.55,1.38),"cup":Vector3(1.93,0.7,1.38),"rag":Vector3(1.88,1.05,0.86),"jug":Vector3(-2.6,1.65,1.1),"sauce_ramp":Vector3(2.65,1.2,0)}
		return station.to_global(places[parcel.item])
	if spec.kind == "lab_upgrade": return game.laboratory.upgrade_position(parcel.item)
	if spec.kind == "lab": return lab_position(int(str(parcel.item).get_slice("_",1)))
	if spec.kind == "garland": return Vector3.INF
	return Vector3(-9.2,1.7,-7.1) if parcel.item == "sign" else Vector3(-7.5,0.7,8.8)

func near_ray(camera: Camera3D, point: Vector3, radius: float) -> bool:
	var direction := -camera.global_basis.z
	var offset := point-camera.global_position
	return offset.length() < 4.2 and offset.dot(direction) > 0 and (camera.global_position+direction*offset.dot(direction)).distance_to(point)<radius

func target(camera: Camera3D, peer: int) -> Dictionary:
	var id := carried(peer)
	if id >= 0:
		var parcel := parcel_by_id(id)
		if not parcel.is_empty() and ITEMS[parcel.item].kind=="garland": return {"action":"unpack_garland","id":id,"hint":"(E) Достать гирлянду из коробки"}
		var point := installation_position(parcel)
		if near_ray(camera,point,0.85): return {"action":"install_parcel","id":id,"hint":"(E) Установить: "+parcel_name(parcel)}
		return {"action":"drop_parcel","id":id,"hint":"Неси коробку к яркому маяку · "+parcel_name(parcel)+" · (E) поставить здесь"}
	if is_instance_valid(game.laboratory):
		var lab_target: Dictionary = game.laboratory.target(camera, peer)
		if not lab_target.is_empty(): return lab_target
	for parcel in game.service.progress.deliveries:
		if parcel.remaining <= 0 and parcel.owner == 0:
			var at_raw: Array=parcel.get("installer_position",parcel.position) if parcel_has_installer(parcel) else parcel.position
			var at := Vector3(at_raw[0],at_raw[1],at_raw[2])
			if near_ray(camera,at,0.6):
				if parcel_has_installer(parcel): return {"action":"installer_owned_parcel","id":parcel.id,"hint":"Этой доставкой займется сборщик"}
				return {"action":"take_parcel","id":parcel.id,"hint":"(E) Взять: "+parcel_name(parcel)}
	var p = game.service.progress
	if p.garland_owned:
		for index in range(p.garland_points.size()):
			var raw: Array = p.garland_points[index]
			if near_ray(camera,Vector3(raw[0],raw[1],raw[2]),0.24): return {"action":"garland_remove","index":index,"hint":"(E) Снять"}
	if p.garland_builder == peer:
		for z in [-7.35,10.35]:
			var dir := -camera.global_basis.z
			if absf(dir.z)<0.001: continue
			var distance: float = (float(z)-camera.global_position.z)/dir.z
			var point: Vector3 = camera.global_position+dir*distance
			if distance>0 and distance<4.2 and game.service.valid_wall_point(point): return {"action":"garland_anchor","point":[point.x,point.y,point.z],"hint":"(E) Закрепить · %d/4 · катушка в руках"%p.garland_points.size()}
	return {}

func action(peer: int, data: Dictionary) -> String:
	var action_name: String = data.action
	var p = game.service.progress
	var position: Vector3 = game.player.global_position if peer == 1 else Vector3.INF
	if peer != 1:
		var raw: Array = game.session.player_poses.get(peer,{}).get("position",[])
		if raw.size()==3: position=Vector3(raw[0],raw[1],raw[2])
	if game.service.training_for(peer) != null: return "Сначала заверши готовку."
	game.laboratory.nursery.discard_infinite_tool(peer)
	if game.laboratory.nursery.holding(peer) or game.laboratory.nursery.pulling(peer) or game.laboratory.researching(peer) or game.laboratory.calibrator.manual_owner()==peer: return "Сначала освободи руки или заверши текущее действие."
	if action_name.begins_with("garland_"):
		if not p.garland_owned: return "Сначала закажи гирлянду."
		if carried(peer)>=0: return "Сначала освободи руки."
		if p.garland_builder>0 and p.garland_builder!=peer and game.session.members.has(p.garland_builder): return "Гирлянда у напарника."
		if action_name == "garland_anchor":
			var raw = data.get("point",[])
			if not game.service.Station.TeamModel.numbers(raw,3): return "Выбери стену."
			var point := Vector3(raw[0],raw[1],raw[2])
			if p.garland_builder!=peer or not game.service.valid_wall_point(point) or position.distance_to(point)>4.5: return "Подойди к креплению."
			if not p.garland_points.is_empty():
				var last: Array = p.garland_points.back()
				var distance := point.distance_to(Vector3(last[0],last[1],last[2]))
				if distance<0.65 or distance>4: return "Между креплениями нужно 0.65–4 м."
			p.garland_points.append(raw.duplicate())
			if p.garland_points.size()==4: p.garland_complete=true; p.garland_builder=0; p.popularity+=15; p.decorations.append("lights")
		elif action_name == "garland_remove":
			var i := int(data.get("index",-1))
			if i<0 or i>=p.garland_points.size(): return "Крепление не найдено."
			var raw: Array = p.garland_points[i]
			var at:=Vector3(raw[0],raw[1],raw[2])
			if position.distance_to(at)>4.5: return "Подойди к гирлянде."
			if p.garland_complete: p.popularity=maxi(0,p.popularity-15); p.decorations.erase("lights")
			p.garland_points.clear(); p.garland_complete=false; p.garland_builder=peer
		else: return "Действие гирлянды не найдено."
		p.revision+=1
		log_event(action_name)
		return ""
	var parcel := parcel_by_id(int(data.get("id",-1)))
	if parcel.is_empty(): return "Коробка уже разобрана."
	if action_name=="installer_owned_parcel": return "Этой доставкой займется сборщик."
	if action_name == "take_parcel":
		if parcel_has_installer(parcel): return "Этой доставкой займется сборщик."
		if parcel.remaining>0 or parcel.owner!=0 or carried(peer)>=0 or p.garland_builder==peer: return "Освободи руки или дождись доставки."
		var at := Vector3(parcel.position[0],parcel.position[1],parcel.position[2])
		if position.distance_to(at)>4.5: return "Подойди к коробке."
		if ITEMS[parcel.item].kind=="garland":
			p.garland_owned=true; p.garland_builder=peer; p.deliveries.erase(parcel); p.revision+=1
			log_event("garland_unpacked",{"item":parcel.item}); return ""
		parcel.owner=peer
	elif action_name == "unpack_garland":
		if parcel.owner!=peer or ITEMS[parcel.item].kind!="garland": return "Гирлянда не в руках."
		p.garland_owned=true; p.garland_builder=peer; p.deliveries.erase(parcel); p.revision+=1
		log_event("garland_unpacked",{"item":parcel.item}); return ""
	elif action_name == "drop_parcel":
		if parcel.owner!=peer: return "Коробка не у тебя."
		parcel.owner=0
		var back: float=Layout.back_z(p.lounge_tier)-0.8 if position.x>Annex.DIVIDER_X else LabLayout.back(p.lab_tier)-0.8 if position.x>LabLayout.left(p.lab_tier) else 9.7
		parcel.position=[clampf(position.x,-11.1,17.1),0.3,clampf(position.z,-6.8,back)]
	elif action_name == "install_parcel":
		if parcel.owner!=peer or position.distance_to(installation_position(parcel))>4.5: return "Поднеси коробку к отмеченному месту."
		var install_error: String=_install_parcel(parcel)
		if not install_error.is_empty(): return install_error
	else: return "Действие не найдено."
	p.revision+=1
	log_event(action_name,{"item":parcel.item,"station":parcel.station})
	return ""

func _install_parcel(parcel: Dictionary) -> String:
	var p=game.service.progress
	var spec: Dictionary=ITEMS[parcel.item]
	if spec.kind=="lounge":
		if not game.session.sleeping_peers.is_empty(): return "Сначала все должны встать с кровати."
		var error:=LoungeProgress.item_error(p,spec)
		if not error.is_empty(): return error
		if bool(spec.upgrade): p.lounge_upgrades.append(spec.lounge_id)
		else: p.lounge_items.append(spec.lounge_id)
	elif spec.kind=="equipment":
		var station=game.service.by_id(int(parcel.station))
		if station==null or station.state not in ["idle","waiting"]: return "Дождись свободной станции."
		for item in parcel.get("items",[parcel.item]):
			if item=="sauce_ramp":
				if item not in station.upgrades: station.upgrades.append(item)
			elif ITEMS.has(item) and ITEMS[item].kind=="equipment" and item not in station.equipment: station.equipment.append(item)
		station.apply_equipment(); station.apply_upgrades()
	elif spec.kind=="station":
		if game.service.by_id(int(parcel.station))!=null: return "Место пока занято."
		var station=game.service.add_station(str(parcel.item),int(parcel.station)-1,false,true)
		if station.type_id=="counter" and "rag" not in station.equipment: station.equipment.append("rag")
		for item in parcel.get("items",[parcel.item]):
			if item==parcel.item or not ITEMS.has(item): continue
			if item=="sauce_ramp":
				if item not in station.upgrades: station.upgrades.append(item)
			elif ITEMS[item].kind=="equipment" and item not in station.equipment: station.equipment.append(item)
		station.method_plan=parcel.get("method_plan",{}).duplicate(true)
		station.apply_equipment(); station.apply_upgrades()
		var planned_group: String=str(parcel.get("planned_group",""))
		if not planned_group.is_empty() and not game.service.table_group_by_id(planned_group).is_empty(): game.service.add_station_to_group(planned_group,station.station_id)
		game.service.assign_clones()
	elif spec.kind=="lab_upgrade":
		if game.laboratory.blocks_sleep() or game.laboratory.calibrator.busy(): return "Сначала заверши работу с приборами."
		var error:=LabPolicy.error(p,str(parcel.item))
		if not error.is_empty(): return error
		p.lab_upgrades.append(parcel.item)
	elif spec.kind=="lab":
		var index:=int(str(parcel.item).get_slice("_",1))
		if index!=p.lab_stage: return "Сначала установи предыдущую деталь лаборатории."
		p.lab_stage+=1
	elif spec.kind=="garland": p.garland_owned=true
	elif spec.kind=="decor": p.decorations.append(parcel.item); p.popularity+=game.service.Progression.DECOR[parcel.item].popularity
	var completed_by_installer: bool=parcel_has_installer(parcel)
	var completed_station_id: int=int(parcel.station) if spec.kind=="station" else 0
	p.delivery_history.push_front({"id":int(parcel.id),"item":str(parcel.item),"items":parcel.get("items",[parcel.item]).duplicate(),"station":int(parcel.station),"installer":completed_by_installer,"day":int(p.day)})
	while p.delivery_history.size()>12: p.delivery_history.pop_back()
	p.deliveries.erase(parcel)
	p.revision+=1
	log_event("delivery_installed",{"item":parcel.item,"station":parcel.station,"installer":completed_by_installer})
	if completed_by_installer and completed_station_id>0:
		var installed=game.service.by_id(completed_station_id)
		var missing_workers: int=1 if installed!=null and installed.staffed>=0 and installed.staffed<installed.role_count() else 0
		game.service.feed_system("installer",{"stations":[completed_station_id],"workers_missing":missing_workers},1)
	return ""

func _advance_installer(parcel: Dictionary,delta: float) -> void:
	if parcel.remaining>0: return
	var target:=installation_position(parcel)
	if not target.is_finite(): return
	var state:=str(parcel.get("installer_state","waiting_delivery"))
	if state=="waiting_delivery":
		parcel.installer_state="walking"
		parcel.installer_position=parcel.get("position",_delivery_position(int(parcel.id))).duplicate()
		parcel.installer_age=0.0
		game.service.progress.revision+=1
		return
	var raw: Array=parcel.get("installer_position",parcel.position)
	var at:=Vector3(raw[0],raw[1],raw[2])
	var waiting_point:=target+Vector3(0,0,2.15)
	if state=="walking":
		at=at.move_toward(waiting_point,delta*3.2)
		parcel.installer_position=[at.x,at.y,at.z]
		if at.distance_to(waiting_point)<0.06:
			parcel.installer_state="waiting" if station_install_blocked(parcel) else "installing"
			parcel.installer_age=0.0
			game.service.progress.revision+=1
	elif state=="waiting":
		parcel.installer_age=float(parcel.get("installer_age",0.0))+delta
		if not station_install_blocked(parcel):
			parcel.installer_state="installing"
			parcel.installer_age=0.0
			game.service.progress.revision+=1
	elif state=="installing":
		parcel.installer_age=float(parcel.get("installer_age",0.0))+delta
		parcel.installer_position=[waiting_point.x,waiting_point.y,waiting_point.z]
		if float(parcel.installer_age)>=1.8:
			var error:=_install_parcel(parcel)
			if not error.is_empty():
				parcel.installer_state="waiting"
				parcel.installer_age=0.0
			else:
				game.service.announce("Сборщик установил: "+parcel_name(parcel) if parcel in game.service.progress.deliveries else "Сборщик закончил установку.")

func advance(delta: float) -> void:
	for parcel in game.service.progress.deliveries.duplicate():
		if parcel.remaining>0:
			parcel.remaining=maxf(0,parcel.remaining-delta)
			if parcel.remaining==0:
				truck_age=5
				game.service.progress.revision+=1
				game.service.announce(("Сборщик приехал: " if parcel_has_installer(parcel) else "Доставка у входа: ")+parcel_name(parcel))
				log_event("delivery_arrived",{"item":parcel.item,"installer":parcel_has_installer(parcel)})
		if parcel in game.service.progress.deliveries and parcel_has_installer(parcel): _advance_installer(parcel,delta)

func _process(delta: float) -> void:
	if game==null: return
	var p = game.service.progress
	for i in range(guide_nodes.size()):
		guide_nodes[i].mesh.visible=i>=p.lab_stage
		guide_nodes[i].label.visible=i>=p.lab_stage
	var ids: Array = []
	for parcel in p.deliveries:
		ids.append(parcel.id)
		if not boxes.has(parcel.id):
			var box := Node3D.new(); add_child(box)
			Props.box(box,Vector3(0.52,0.5,0.48),Vector3.ZERO,Color("b28a59"))
			Props.box(box,Vector3(0.09,0.51,0.49),Vector3.ZERO,Color("d4be91"))
			var label := Props.text(box,parcel_name(parcel),Vector3(0,0.4,0),16,Color("f3dfb0")); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			boxes[parcel.id]=box
		var node: Node3D = boxes[parcel.id]
		node.visible=parcel.remaining<=0 and not parcel_has_installer(parcel)
		if parcel.owner==0: node.global_position=Vector3(parcel.position[0],parcel.position[1],parcel.position[2])
		elif parcel.owner==game.session.local_id(): node.global_transform=game.camera.global_transform; node.position+=-game.camera.global_basis.z*0.85-game.camera.global_basis.y*0.28
		else:
			var pose: Dictionary = game.session.player_poses.get(parcel.owner,{})
			if pose.has("position"): node.global_position=Vector3(pose.position[0],pose.position[1]+1.15,pose.position[2])+Vector3(0,0,-0.7).rotated(Vector3.UP,float(pose.get("yaw",0)))
	for id in boxes.keys():
		if id not in ids: boxes[id].queue_free(); boxes.erase(id)
	var installer_ids: Array=[]
	for parcel in p.deliveries:
		if not parcel_has_installer(parcel) or parcel.remaining>0: continue
		installer_ids.append(parcel.id)
		if not installers.has(parcel.id):
			var worker:=Installer.new(); add_child(worker); worker.setup(int(parcel.id)); installers[parcel.id]=worker
		var worker: Node3D=installers[parcel.id]
		worker.apply(parcel,installation_position(parcel),delta)
	for id in installers.keys():
		if id not in installer_ids: installers[id].queue_free(); installers.erase(id)
	placement_clock += delta
	local_ghost.hide()
	placement_beacon.hide()
	placement_label.hide()
	var held := carried(game.session.local_id())
	if held>=0:
		var held_parcel:=parcel_by_id(held)
		if not held_parcel.is_empty() and ITEMS[held_parcel.item].kind!="garland":
			var install_target: Vector3=installation_position(held_parcel)
			if install_target.is_finite():
				var pulse: float=0.5+0.5*sin(placement_clock*5.2)
				local_ghost.show(); local_ghost.global_position=install_target
				local_ghost.scale=Vector3.ONE*(0.92+0.13*pulse)
				placement_beacon.show(); placement_beacon.global_position=install_target+Vector3.UP*2.6
				placement_beacon.material_override.albedo_color.a=0.16+0.16*pulse
				placement_label.show(); placement_label.global_position=install_target+Vector3.UP*(5.35+0.13*pulse)
				placement_label.text="▼  УСТАНОВИТЬ СЮДА\n%s\n%d м"%[parcel_name(held_parcel),roundi(game.player.global_position.distance_to(install_target))]
	if p.garland_builder>0:
		if not garland_reels.has(p.garland_builder):
			var reel := Node3D.new(); add_child(reel)
			Props.cylinder(reel,0.16,0.22,Vector3.ZERO,Color("dabb84"))
			for i in range(5): Props.ball(reel,0.045,Vector3(sin(i)*0.18,0.05,cos(i)*0.18),Color("ffe39d"))
			garland_reels[p.garland_builder]=reel
		var reel: Node3D = garland_reels[p.garland_builder]
		if p.garland_builder==game.session.local_id(): reel.global_transform=game.camera.global_transform; reel.position+=game.camera.global_basis.x*0.35-game.camera.global_basis.z*0.65-game.camera.global_basis.y*0.3
		else:
			var pose: Dictionary = game.session.player_poses.get(p.garland_builder,{})
			if pose.has("position"): reel.position=Vector3(pose.position[0]+0.3,pose.position[1]+1.2,pose.position[2])
	for id in garland_reels.keys():
		if id!=p.garland_builder: garland_reels[id].queue_free(); garland_reels.erase(id)
	truck_age=maxf(0,truck_age-delta)
	truck.visible=truck_age>0
	truck.position=Vector3(-10.8,0,2.5+(5-truck_age)*0.8)

func parcel_name(parcel: Dictionary) -> String:
	var names: PackedStringArray=[]
	for item in parcel.get("items",[parcel.item]): names.append(ITEMS[item].name)
	return "Комплект · станция %d · %d предметов"%[parcel.station,names.size()] if names.size()>1 else " + ".join(names)

func order_bundle(items: Array, station_id: int, with_installer := false) -> String:
	var p=game.service.progress
	var station=game.service.by_id(station_id)
	if p.stars<1 or station==null or items.is_empty(): return "Комплекты доступны с первой звезды."
	var unique: Array=[]
	var total := 0
	for item in items:
		if not item is String or item in unique or not ITEMS.has(item): return "Проверь состав заказа."
		var spec: Dictionary=ITEMS[item]
		if spec.kind!="equipment" or item in station.equipment or item in station.upgrades or pending(item,station_id): return "Предмет уже куплен или заказан."
		if not equipment_allowed(station.type_id,item) or p.stars<int(spec.get("star",0)): return "Этот предмет недоступен станции."
		unique.append(item); total+=int(spec.price)
	if p.cash<total: return "Не хватает денег на комплект."
	var error := order(unique[0],station_id,with_installer)
	if not error.is_empty(): return error
	p.cash-=total-int(ITEMS[unique[0]].price)
	p.deliveries.back().items=unique
	log_event("bundle_ordered",{"station":station_id,"items":unique,"price":total,"installer":bool(with_installer)})
	return ""

func order_station_batch(type_id: String,station_ids: Array,equipment: Array,group_id: String,with_installers: bool) -> String:
	var p=game.service.progress
	if p.busy(): return "Сначала заверши проверку."
	if not type_available(type_id): return "Этот тип кухни ещё не открыт."
	if station_ids.is_empty(): return "Выбери хотя бы одно подготовленное место."
	var unique_ids: Array=[]
	for raw_id in station_ids:
		var station_id: int=int(raw_id)
		if station_id<=Expansion.BASE_SLOT_COUNT or station_id>Expansion.SLOT_COUNT or station_id in unique_ids: return "Проверь выбранные места."
		if game.service.by_id(station_id)!=null or pending(type_id,station_id): return "Место %d уже занято или ожидает доставку."%station_id
		unique_ids.append(station_id)
	var chosen_equipment: Array=[]
	var equipment_cost:=0
	for raw_item in equipment:
		var item:=str(raw_item)
		if item in chosen_equipment or not ITEMS.has(item) or ITEMS[item].kind!="equipment" or not equipment_allowed(type_id,item): return "Проверь оснащение комплекта."
		if p.stars<int(ITEMS[item].get("star",0)): return "Часть оснащения ещё не открыта."
		chosen_equipment.append(item)
		equipment_cost+=int(ITEMS[item].price)
	var group: Dictionary={}
	if not group_id.is_empty():
		group=game.service.table_group_by_id(group_id)
		if group.is_empty() or str(group.type)!=type_id: return "Выбранная группа не подходит этой кухне."
	var plan:=group_training_plan(group_id,type_id)
	var unit_price: int=int(ITEMS[type_id].price)+equipment_cost
	var total: int=unit_price*unique_ids.size()
	if p.cash<total: return "Не хватает денег на выбранные комплекты."
	p.cash-=total
	for index in range(unique_ids.size()):
		var station_id: int=int(unique_ids[index])
		var contents: Array=[type_id]
		contents.append_array(chosen_equipment)
		p.deliveries.append(_new_delivery(type_id,station_id,contents,bool(with_installers),8.0+index*0.35,{"method_plan":plan.duplicate(true),"planned_group":group_id,"unit_price":unit_price}))
	p.revision+=1
	log_event("station_batch_ordered",{"type":type_id,"stations":unique_ids,"equipment":chosen_equipment,"group":group_id,"installer":with_installers,"price":total})
	game.service.feed_system("batch",{"stations":unique_ids,"group":group_id},unique_ids.size())
	return ""

func reward_sauce() -> void:
	var p=game.service.progress
	if p.starter_reward: return
	p.starter_reward=true
	var station=game.service.by_id(1)
	if "sauce" in station.equipment or pending("sauce",1): p.cash+=24
	else:
		var id: int=p.next_delivery_id; p.next_delivery_id+=1
		p.deliveries.append({"id":id,"item":"sauce","station":1,"remaining":8.0,"owner":0,"position":[-10.1,0.3,4.8]})
	game.service.announce("Первый гость обслужен! Подарок: соус для твоей стойки. Доставка у входа.")
	p.revision+=1
