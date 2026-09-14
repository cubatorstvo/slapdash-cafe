extends Node3D
const Props = preload("res://scripts/props.gd")
const Annex = preload("res://scripts/cafe_annex.gd")
const LoungeProgress = preload("res://scripts/lounge_progression.gd")
const Layout = preload("res://scripts/lounge_layout.gd")
var ITEMS := {
	"lab_power": {"name":"Усилитель · темп 100–150%","price":180,"kind":"lab_upgrade","star":2},
	"lab_power_2": {"name":"Турбоблок · темп 140–200%","price":320,"kind":"lab_upgrade","star":2},
	"lab_valve": {"name":"Клапан · плавнее менять уровень","price":90,"kind":"lab_upgrade","star":1},
	"lab_damper": {"name":"Демпфер · замедлить стрелку","price":120,"kind":"lab_upgrade","star":1},
	"meat_kit": {"name":"Гриль, тарелка и приборы для мяса","price":120,"kind":"equipment","star":2},
	"pasta_kit": {"name":"Плита, кастрюля и приборы для макарон","price":120,"kind":"equipment","star":2},
	"sauce": {"name":"Миска соуса","price":24,"kind":"equipment"},
	"plates": {"name":"Три тарелки","price":30,"kind":"equipment"},
	"cup": {"name":"Бокал 300 мл","price":30,"kind":"equipment"},
	"pan": {"name":"Дырявая сковорода с горелкой","price":54,"kind":"equipment"},
	"jug": {"name":"Кувшин для вина","price":54,"kind":"equipment"},
	"sauce_ramp": {"name":"Соусный трамплин","price":75,"kind":"equipment","star":1},
	"counter": {"name":"Стол и шкафчик","price":120,"kind":"station","star":1},
	"kitchen": {"name":"Парная кухня","price":250,"kind":"station","star":2},
	"lab_0": {"name":"Лабораторная колба","price":40,"kind":"lab"},
	"lab_1": {"name":"Блок питания лаборатории","price":60,"kind":"lab"},
	"lab_2": {"name":"Стабилизатор клонирования","price":80,"kind":"lab"},
	"sign": {"name":"Вывеска «Мы почти умеем»","price":45,"kind":"decor","star":1},
	"plants": {"name":"Зелёный уголок","price":110,"kind":"decor","star":1},
	"lights": {"name":"Гирлянда на честном слове","price":40,"kind":"garland","star":1}
}
var game: Node3D
var boxes := {}
var local_ghost: MeshInstance3D
var garland_reels := {}
var guide_nodes: Array = []
var computer: Node3D
var truck: Node3D
var truck_age := 0.0
var saved_status := ""

func setup(owner_game: Node3D) -> void:
	game = owner_game
	ITEMS.merge(LoungeProgress.shop_items())
	local_ghost = Props.box(self,Vector3(0.55,0.2,0.45),Vector3.ZERO,Color("83ceab"))
	local_ghost.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	local_ghost.material_override.albedo_color.a = 0.35
	local_ghost.hide()
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

func order(item: String, station_id: int) -> String:
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
		if station == null or ((item in ["meat_kit","pasta_kit"]) != (station.type_id == "kitchen")): return "Выбери тяп-ляп стойку."
		if item in station.equipment or item in station.upgrades: return "Уже установлено."
	elif spec.kind == "station":
		if item == "kitchen":
			if not p.expanded: return "Сначала расширь зал."
			station_id = 4
		else:
			station_id = 0
			for id in [2,3]:
				if game.service.by_id(id) == null and not pending("counter",id): station_id = id; break
		if station_id == 0 or game.service.by_id(station_id) != null: return "Свободных мест нет."
	elif spec.kind == "lab_upgrade":
		station_id=0
		if p.lab_stage<3: return "Сначала собери лабораторию."
		if item in p.lab_upgrades: return "Прибор уже установлен."
		if item=="lab_power_2" and "lab_power" not in p.lab_upgrades: return "Сначала установи усилитель."
	elif spec.kind == "lab":
		station_id = 0
		if int(item.get_slice("_",1)) < p.lab_stage: return "Деталь уже установлена."
	elif spec.kind == "decor":
		station_id = 0
		if item in p.decorations: return "Уже установлено."
	elif spec.kind == "garland":
		station_id = 0
		if p.garland_owned: return "Катушка уже куплена. Возьми её на верстаке."
	if pending(item,station_id): return "Доставка уже заказана."
	if p.cash < spec.price: return "Не хватает денег."
	p.cash -= spec.price
	var id: int = p.next_delivery_id
	p.next_delivery_id += 1
	p.deliveries.append({"id":id,"item":item,"station":station_id,"remaining":8.0,"owner":0,"position":[-10.1+(id%3)*0.65,0.3,4.8+floorf(float(id%9)/3)*0.65]})
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

func lab_position(index: int) -> Vector3: return Annex.lab_world(Vector3(-0.85+index*0.85,1.05,8.6))
func garland_reel_position() -> Vector3: return Annex.lab_world(Vector3(1.48,1.1,8.15))

func installation_position(parcel: Dictionary) -> Vector3:
	var spec: Dictionary = ITEMS[parcel.item]
	if spec.kind == "lounge":
		return Layout.item_position(str(spec.lounge_id),game.service.progress.lounge_tier)+Vector3.UP*0.8
	if spec.kind == "station": return game.service.slot_position(parcel.station-1)+Vector3.UP
	if spec.kind == "equipment":
		var station = game.service.by_id(parcel.station)
		if station == null: return Vector3.INF
		var places := {"meat_kit":Vector3(-1.4,1.1,-0.15),"pasta_kit":Vector3(1.4,1.1,-0.15),"pan":Vector3(-1.05,1.2,-0.1),"sauce":Vector3(0.3,1.09,-0.7),"plates":Vector3(1.3,0.55,1.38),"cup":Vector3(1.93,0.7,1.38),"rag":Vector3(1.88,1.05,0.86),"jug":Vector3(-2.6,1.65,1.1),"sauce_ramp":Vector3(2.65,1.2,0)}
		return station.to_global(places[parcel.item])
	if spec.kind == "lab_upgrade": return game.laboratory.upgrade_position(parcel.item)
	if spec.kind == "lab": return lab_position(int(str(parcel.item).get_slice("_",1)))
	if spec.kind == "garland": return garland_reel_position()
	return Vector3(-9.2,1.7,-7.1) if parcel.item == "sign" else Vector3(-7.5,0.7,8.8)

func near_ray(camera: Camera3D, point: Vector3, radius: float) -> bool:
	var direction := -camera.global_basis.z
	var offset := point-camera.global_position
	return offset.length() < 4.2 and offset.dot(direction) > 0 and (camera.global_position+direction*offset.dot(direction)).distance_to(point)<radius

func target(camera: Camera3D, peer: int) -> Dictionary:
	var id := carried(peer)
	if id >= 0:
		var parcel := parcel_by_id(id)
		var point := installation_position(parcel)
		if near_ray(camera,point,0.85): return {"action":"install_parcel","id":id,"hint":"(E) Установить: "+parcel_name(parcel)}
		return {"action":"drop_parcel","id":id,"hint":"В руках: "+parcel_name(parcel)+" · (E) Поставить коробку"}
	if is_instance_valid(game.laboratory):
		var lab_target: Dictionary = game.laboratory.target(camera, peer)
		if not lab_target.is_empty(): return lab_target
	for parcel in game.service.progress.deliveries:
		if parcel.remaining <= 0 and parcel.owner == 0:
			var at := Vector3(parcel.position[0],parcel.position[1],parcel.position[2])
			if near_ray(camera,at,0.4): return {"action":"take_parcel","id":parcel.id,"hint":"(E) Взять: "+parcel_name(parcel)}
	var p = game.service.progress
	if p.garland_owned:
		for index in range(p.garland_points.size()):
			var raw: Array = p.garland_points[index]
			if near_ray(camera,Vector3(raw[0],raw[1],raw[2]),0.16): return {"action":"garland_remove","index":index,"hint":"(E) Снять гирлянду и перевесить"}
		if near_ray(camera,garland_reel_position(),0.3): return {"action":"garland_put" if p.garland_builder==peer else "garland_take","hint":"(E) Положить катушку" if p.garland_builder==peer else "(E) Взять гирлянду"}
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
	if action_name.begins_with("garland_"):
		if not p.garland_owned: return "Сначала закажи и распакуй гирлянду."
		if carried(peer)>=0: return "Освободи руки."
		if p.garland_builder>0 and p.garland_builder!=peer and game.session.members.has(p.garland_builder): return "Катушка у напарника."
		if action_name == "garland_put":
			if p.garland_builder!=peer or position.distance_to(Vector3(1.48,1.1,8.15))>4.5: return "Подойди к верстаку."
			p.garland_builder=0; p.revision+=1
			return ""
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
		else:
			var at := Vector3(1.48,1.1,8.15)
			if action_name == "garland_remove":
				var i := int(data.get("index",-1))
				if i<0 or i>=p.garland_points.size(): return "Крепление не найдено."
				var raw: Array = p.garland_points[i]; at=Vector3(raw[0],raw[1],raw[2])
			if position.distance_to(at)>4.5: return "Подойди к гирлянде."
			if p.garland_complete: p.popularity=maxi(0,p.popularity-15); p.decorations.erase("lights")
			if action_name == "garland_remove" or p.garland_complete: p.garland_points.clear()
			p.garland_complete=false; p.garland_builder=peer
		p.revision+=1
		log_event(action_name)
		return ""
	var parcel := parcel_by_id(int(data.get("id",-1)))
	if parcel.is_empty(): return "Коробка уже разобрана."
	if action_name == "take_parcel":
		if parcel.remaining>0 or parcel.owner!=0 or carried(peer)>=0 or p.garland_builder==peer: return "Освободи руки или дождись доставки."
		var at := Vector3(parcel.position[0],parcel.position[1],parcel.position[2])
		if position.distance_to(at)>4.5: return "Подойди к коробке."
		parcel.owner=peer
	elif action_name == "drop_parcel":
		if parcel.owner!=peer: return "Коробка не у тебя."
		parcel.owner=0
		var back: float=Layout.back_z(p.lounge_tier)-0.8 if position.x>Annex.DIVIDER_X else Annex.LAB_BACK_Z-0.8 if position.x>Annex.LAB_X_MIN else 9.7
		parcel.position=[clampf(position.x,-11.1,17.1),0.3,clampf(position.z,-6.8,back)]
	elif action_name == "install_parcel":
		if parcel.owner!=peer or position.distance_to(installation_position(parcel))>4.5: return "Поднеси коробку к отмеченному месту."
		var spec: Dictionary = ITEMS[parcel.item]
		if spec.kind == "lounge":
			if not game.session.sleeping_peers.is_empty(): return "Сначала все должны встать с кровати."
			var error:=LoungeProgress.item_error(p,spec)
			if not error.is_empty(): return error
			if bool(spec.upgrade): p.lounge_upgrades.append(spec.lounge_id)
			else: p.lounge_items.append(spec.lounge_id)
		elif spec.kind == "equipment":
			var station = game.service.by_id(parcel.station)
			if station.state not in ["idle","waiting"]: return "Дождись свободной станции."
			for item in parcel.get("items",[parcel.item]):
				if item=="sauce_ramp": station.upgrades.append(item)
				elif item not in station.equipment: station.equipment.append(item)
			station.apply_equipment(); station.apply_upgrades()
		elif spec.kind == "station": game.service.add_station(parcel.item,parcel.station-1,false,true)
		elif spec.kind == "lab_upgrade":
			if game.laboratory.state.phase!="idle": return "Сначала заверши цикл лаборатории."
			if parcel.item not in p.lab_upgrades: p.lab_upgrades.append(parcel.item)
		elif spec.kind == "lab":
			var index := int(str(parcel.item).get_slice("_",1))
			if index!=p.lab_stage: return "Сначала установи предыдущую деталь лаборатории."
			p.lab_stage+=1
		elif spec.kind == "garland": p.garland_owned=true; p.garland_builder=peer
		elif spec.kind == "decor": p.decorations.append(parcel.item); p.popularity+=game.service.Progression.DECOR[parcel.item].popularity
		p.deliveries.erase(parcel)
	else: return "Действие не найдено."
	p.revision+=1
	log_event(action_name,{"item":parcel.item,"station":parcel.station})
	return ""

func advance(delta: float) -> void:
	for parcel in game.service.progress.deliveries:
		if parcel.remaining>0:
			parcel.remaining=maxf(0,parcel.remaining-delta)
			if parcel.remaining==0:
				truck_age=5
				game.service.progress.revision+=1
				game.service.announce("Доставка у входа: "+parcel_name(parcel))
				log_event("delivery_arrived",{"item":parcel.item})

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
		node.visible=parcel.remaining<=0
		if parcel.owner==0: node.global_position=Vector3(parcel.position[0],parcel.position[1],parcel.position[2])
		elif parcel.owner==game.session.local_id(): node.global_transform=game.camera.global_transform; node.position+=-game.camera.global_basis.z*0.85-game.camera.global_basis.y*0.28
		else:
			var pose: Dictionary = game.session.player_poses.get(parcel.owner,{})
			if pose.has("position"): node.global_position=Vector3(pose.position[0],pose.position[1]+1.15,pose.position[2])+Vector3(0,0,-0.7).rotated(Vector3.UP,float(pose.get("yaw",0)))
	for id in boxes.keys():
		if id not in ids: boxes[id].queue_free(); boxes.erase(id)
	local_ghost.hide()
	var held := carried(game.session.local_id())
	if held>=0:
		local_ghost.show(); local_ghost.global_position=installation_position(parcel_by_id(held))
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

func order_bundle(items: Array, station_id: int) -> String:
	var p=game.service.progress
	var station=game.service.by_id(station_id)
	if p.stars<1 or station==null or items.is_empty(): return "Комплекты доступны с первой звезды."
	var unique: Array=[]
	var total := 0
	for item in items:
		if not item is String or item in unique or not ITEMS.has(item): return "Проверь состав заказа."
		var spec: Dictionary=ITEMS[item]
		if spec.kind!="equipment" or item in station.equipment or item in station.upgrades or pending(item,station_id): return "Предмет уже куплен или заказан."
		if ((item in ["meat_kit","pasta_kit"]) != (station.type_id=="kitchen")) or p.stars<int(spec.get("star",0)): return "Этот предмет недоступен станции."
		unique.append(item); total+=int(spec.price)
	if p.cash<total: return "Не хватает денег на комплект."
	var error := order(unique[0],station_id)
	if not error.is_empty(): return error
	p.cash-=total-int(ITEMS[unique[0]].price)
	p.deliveries.back().items=unique
	log_event("bundle_ordered",{"station":station_id,"items":unique,"price":total})
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
