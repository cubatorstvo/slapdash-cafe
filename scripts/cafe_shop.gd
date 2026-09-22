extends Node3D
const Props = preload("res://scripts/props.gd")
const SceneRuntime=preload("res://scripts/scene_runtime.gd")
const Annex = preload("res://scripts/cafe_annex.gd")
const LabPolicy = preload("res://scripts/laboratory_progression.gd")
const LabLayout = preload("res://scripts/laboratory_layout.gd")
const LoungeProgress = preload("res://scripts/lounge_progression.gd")
const Layout = preload("res://scripts/lounge_layout.gd")
const Expansion = preload("res://scripts/cafe_expansion_layout.gd")
const DeliveryWorker = preload("res://scripts/station_delivery_worker.gd")
const Definition = preload("res://scripts/station_definition.gd")
var ITEMS: Dictionary = preload("res://scripts/cafe_catalogue.gd").ITEMS.duplicate(true)
var game: Node3D
var boxes := {}
var delivery_workers := {}
var delivery_worker_states := {}
var delivery_clock := 0.0
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
	computer = preload("res://scripts/scene_runtime.gd").instantiate("res://scenes/decor/market_computer_desk.tscn") as Node3D
	add_child(computer)
	computer.position = Expansion.MARKET_POSITION
	computer.rotation.y=0.0
	game.development.board.hide()
	for i in range(3):
		var at := lab_position(i)
		var ghost := Props.cylinder(self,0.24,0.07,at-Vector3.UP*0.1,Color("79b8b0"))
		var label := Props.text(self,ITEMS["lab_%d"%i].name+"\nНужна доставка",at+Vector3.UP*0.8,17,Color("d4c99b"))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		guide_nodes.append({"mesh":ghost,"label":label})
	truck = preload("res://scripts/scene_runtime.gd").instantiate("res://scenes/decor/delivery_truck.tscn") as Node3D
	add_child(truck)
	truck.hide()

func refresh_layout() -> void:
	if game==null: return
	computer.position=Expansion.MARKET_POSITION
	for parcel in game.service.progress.deliveries:
		if int(parcel.get("owner",0))!=0 or float(parcel.get("remaining",0.0))<=0.0: continue
		var at:=parcel_drop_position(int(parcel.get("id",0)))
		parcel.position=[at.x,at.y,at.z]


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

func group_purchase_snapshot(group_id: String,type_id: String) -> Dictionary:
	if group_id.is_empty(): return {}
	var group: Dictionary=game.service.table_group_by_id(group_id)
	if group.is_empty() or str(group.type_id)!=type_id: return {}
	return {"id":str(group.id),"name":str(group.name),"type_id":str(group.type_id),"active_dishes":group.active_dishes.duplicate(),"curriculum":group.curriculum.duplicate(true),"plan_revision":int(group.plan_revision)}

func parcel_plan_note(parcel: Dictionary) -> String:
	var group_id:=str(parcel.get("planned_group",""))
	if group_id.is_empty(): return ""
	var snapshot: Dictionary=parcel.get("planned_group_snapshot",{}) if parcel.get("planned_group_snapshot",{}) is Dictionary else {}
	var current: Dictionary=game.service.table_group_by_id(group_id)
	if current.is_empty(): return "Группа из заказа удалена · будет создана отдельная группа по сохранённому плану."
	if snapshot.is_empty(): return ""
	if int(snapshot.get("plan_revision",0))!=int(current.get("plan_revision",0)):
		return "План группы изменился после заказа · при установке применится текущая версия."
	var bought: Dictionary={}
	var now: Dictionary={}
	for item in snapshot.get("curriculum",[]): bought[str(item.get("dish_id",""))]=int(item.get("record_id",0))
	for item in current.get("curriculum",[]): now[str(item.get("dish_id",""))]=int(item.get("record_id",0))
	return "План группы изменился после заказа · при установке применится текущая версия." if bought!=now else ""

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

func parcel_drop_position(id: int) -> Vector3:
	var stage:=Expansion.stage_for_progress(game.service.progress)
	var base:=Expansion.delivery_vehicle_spawn(stage)
	var arrived:=Vector3(base.x-0.8,0.0,base.z)
	var anchor:=Vector3(0.0,0.0,-1.25)
	if is_instance_valid(truck):
		var marker:=truck.get_node_or_null("ParcelDropAnchor") as Node3D
		if marker!=null: anchor=marker.position
	var slot:=posmod(id,9)
	var col:=posmod(slot,3)
	var row:=int(slot/3)
	return arrived+anchor+Vector3((float(col)-1.0)*0.58,0.0,-float(row)*0.5)

func _legacy_drop(parcel: Dictionary) -> bool:
	var at:=Vector3(float(parcel.position[0]),float(parcel.position[1]),float(parcel.position[2]))
	var legacy:=Expansion.delivery_position(Expansion.stage_for_progress(game.service.progress),int(parcel.get("id",0)))
	return Vector2(at.x,at.z).distance_to(Vector2(legacy.x,legacy.z))<0.35

func _delivery_position(id: int) -> Array:
	var at:=parcel_drop_position(id)
	return [at.x,at.y,at.z]

func _new_delivery(item: String,station_id: int,items: Array,delay: float,extra: Dictionary={}) -> Dictionary:
	var p=game.service.progress
	var id: int=p.next_delivery_id
	p.next_delivery_id+=1
	var delivery_position: Array=_delivery_position(id)
	var parcel: Dictionary={"id":id,"item":item,"items":items.duplicate(),"station":station_id,"remaining":delay,"owner":0,"position":delivery_position,"worker_phase":"","worker_role":-1,"worker_position":delivery_position.duplicate(),"worker_age":0.0,"worker_yaw":0.0}
	for key in extra: parcel[key]=extra[key]
	return parcel

func clone_delivery_station(parcel: Dictionary) -> Node3D:
	if parcel.is_empty() or not ITEMS.has(str(parcel.get("item",""))): return null
	if str(ITEMS[str(parcel.item)].kind)!="equipment": return null
	var station: Node3D=game.service.by_id(int(parcel.get("station",0)))
	if station==null or station.manual_station: return null
	return station

func clone_delivery_worker_count(parcel: Dictionary) -> int:
	var station:=clone_delivery_station(parcel)
	if station==null: return 0
	if int(station.staffed)<0: return station.role_count()
	return clampi(int(station.staffed),0,station.role_count())

func clone_delivery_claimed(parcel: Dictionary) -> bool:
	return not parcel.is_empty() and float(parcel.get("remaining",0.0))<=0.0 and int(parcel.get("owner",0))==0 and clone_delivery_worker_count(parcel)>0

func _station_delivery_parcels(station: Node3D) -> Array:
	var result: Array=[]
	for parcel in game.service.progress.deliveries:
		if int(parcel.get("station",0))!=station.station_id or not clone_delivery_claimed(parcel): continue
		result.append(parcel)
	return result

func _worker_position(parcel: Dictionary) -> Vector3:
	var raw: Array=parcel.get("worker_position",parcel.get("position",[0.0,0.0,0.0]))
	return Vector3(float(raw[0]),0.0,float(raw[2])) if raw.size()==3 else Vector3.ZERO

func _store_worker_position(parcel: Dictionary,point: Vector3) -> void:
	parcel.worker_position=[point.x,0.0,point.z]

func _clear_worker_path(parcel: Dictionary) -> void:
	parcel.erase("worker_path")
	parcel.erase("worker_path_index")
	parcel.erase("worker_path_target")
	parcel.erase("worker_path_phase")

func _set_worker_phase(parcel: Dictionary,phase: String) -> void:
	if str(parcel.get("worker_phase",""))==phase: return
	parcel.worker_phase=phase
	parcel.worker_age=0.0
	_clear_worker_path(parcel)
	game.service.progress.revision+=1

func _reset_worker_claim(parcel: Dictionary,keep_position:=true) -> void:
	if keep_position and str(parcel.get("worker_phase","")) in ["carrying","installing"]:
		var at:=_worker_position(parcel)
		parcel.position=[at.x,0.3,at.z]
	parcel.worker_phase=""
	parcel.worker_role=-1
	parcel.worker_age=0.0
	parcel.worker_yaw=0.0
	_clear_worker_path(parcel)

func _worker_start_position(station: Node3D,role: int) -> Vector3:
	return station.to_global(Vector3(station.role_home_x(role),0.0,1.85))

func _worker_install_approach(station: Node3D,role: int) -> Vector3:
	var side:=0.0 if station.role_count()==1 else -0.65+1.30*float(role)/maxf(1.0,float(station.role_count()-1))
	return station.to_global(Vector3(side,0.0,2.55))

func _ensure_worker_path(parcel: Dictionary,target: Vector3) -> bool:
	var signature: Array=[snappedf(target.x,0.05),snappedf(target.z,0.05)]
	if str(parcel.get("worker_path_phase",""))==str(parcel.get("worker_phase","")) and parcel.get("worker_path_target",[])==signature and parcel.get("worker_path",[]) is Array and not parcel.worker_path.is_empty(): return true
	var stage:=Expansion.stage_for_progress(game.service.progress)
	var route: Array=Expansion.cafe_route(_worker_position(parcel),Vector3(target.x,0.0,target.z),stage,true)
	parcel.worker_path=[]
	for point in route: parcel.worker_path.append([point.x,0.0,point.z])
	parcel.worker_path_index=0
	parcel.worker_path_target=signature
	parcel.worker_path_phase=str(parcel.get("worker_phase",""))
	return not parcel.worker_path.is_empty()

func _follow_worker_path(parcel: Dictionary,target: Vector3,delta: float,speed: float) -> bool:
	if not _ensure_worker_path(parcel,target): return false
	var index: int=int(parcel.get("worker_path_index",0))
	var path: Array=parcel.worker_path
	var at: Vector3=_worker_position(parcel)
	while index<path.size():
		var raw: Array=path[index]
		var next:=Vector3(float(raw[0]),0.0,float(raw[2]))
		var offset:=next-at
		if offset.length()<0.055:
			at=next
			index+=1
			continue
		parcel.worker_yaw=atan2(-offset.x,-offset.z)
		at=at.move_toward(next,delta*speed)
		_store_worker_position(parcel,at)
		parcel.worker_path_index=index
		return false
	_store_worker_position(parcel,Vector3(target.x,0.0,target.z))
	parcel.worker_path_index=index
	return true

func _source_worker_tint(station: Node3D,role: int) -> Color:
	if station.type_id=="counter" and is_instance_valid(station.view) and is_instance_valid(station.view.worker): return station.view.worker.tint
	if is_instance_valid(station.view):
		var actors: Variant=station.view.get("actors")
		if actors is Array and role>=0 and role<actors.size() and actors[role] is Node3D: return actors[role].tint
	return [Color("63aa98"),Color("7ba2b0"),Color("c4926e")][role%3]

func _worker_state(parcel: Dictionary,station: Node3D,role: int) -> Dictionary:
	return {"phase":str(parcel.get("worker_phase","approaching_box")),"position":parcel.get("worker_position",[_worker_start_position(station,role).x,0.0,_worker_start_position(station,role).z]),"yaw":float(parcel.get("worker_yaw",0.0)),"age":float(parcel.get("worker_age",0.0)),"variant":(int(parcel.id)+role)%4,"name":str(station.crew[role].get("name","Клон")),"station":station.station_id,"role":role,"parcel":int(parcel.id),"tint":_source_worker_tint(station,role)}

func _cheer_state(station: Node3D,role: int) -> Dictionary:
	var age:=delivery_clock+float(role)*0.71+float(station.station_id)*0.19
	var center:=station.to_global(Vector3(0.0,0.0,2.45))
	var angle:=age*1.65+float(role)*TAU/maxf(1.0,float(station.role_count()))
	var radius:=0.68+0.10*float(role%2)
	var at:=center+Vector3(cos(angle)*radius,0.0,sin(angle)*0.34)
	var toward:=center-at
	return {"phase":"cheering","position":[at.x,0.0,at.z],"yaw":atan2(-toward.x,-toward.z),"age":age,"variant":role+station.station_id,"name":str(station.crew[role].get("name","Клон")),"station":station.station_id,"role":role,"parcel":0,"tint":_source_worker_tint(station,role)}

func _advance_worker_parcel(parcel: Dictionary,station: Node3D,role: int,delta: float) -> void:
	if int(parcel.get("worker_role",-1))!=role:
		parcel.worker_role=role
		parcel.worker_phase="approaching_box"
		var start:=_worker_start_position(station,role)
		_store_worker_position(parcel,start)
		parcel.worker_yaw=station.global_rotation.y+PI
		parcel.worker_age=0.0
		_clear_worker_path(parcel)
	var phase:=str(parcel.get("worker_phase","approaching_box"))
	if phase.is_empty():
		_set_worker_phase(parcel,"approaching_box")
		phase="approaching_box"
	if phase=="approaching_box":
		var raw: Array=parcel.get("position",[0.0,0.0,0.0])
		var box_at:=Vector3(float(raw[0]),0.0,float(raw[2]))
		if _follow_worker_path(parcel,box_at,delta,7.5): _set_worker_phase(parcel,"carrying")
	elif phase=="carrying":
		var target:=_worker_install_approach(station,role)
		if _follow_worker_path(parcel,target,delta,6.2): _set_worker_phase(parcel,"installing")
	elif phase=="installing":
		parcel.worker_age=float(parcel.get("worker_age",0.0))+delta
		if float(parcel.worker_age)>=1.15:
			var name:=parcel_name(parcel)
			var error:=_install_parcel(parcel,true)
			if error.is_empty(): game.service.announce("Работники сами установили: "+name)

func _delivery_assignments(parcels: Array,count: int) -> Dictionary:
	var result: Dictionary={}
	var assigned: Dictionary={}
	for parcel in parcels:
		var role:=int(parcel.get("worker_role",-1))
		if role<0 or role>=count or result.has(role): continue
		result[role]=parcel
		assigned[int(parcel.id)]=true
	for parcel in parcels:
		if assigned.has(int(parcel.id)): continue
		for role in range(count):
			if result.has(role): continue
			result[role]=parcel
			assigned[int(parcel.id)]=true
			break
	return result

func _advance_clone_deliveries(delta: float) -> void:
	delivery_clock+=delta
	delivery_worker_states.clear()
	for station in game.service.stations: station.delivery_celebration_active=false
	for parcel in game.service.progress.deliveries:
		if not clone_delivery_claimed(parcel) and not str(parcel.get("worker_phase","" )).is_empty(): _reset_worker_claim(parcel)
	for station in game.service.stations:
		if station.manual_station: continue
		var count: int=station.role_count() if int(station.staffed)<0 else clampi(int(station.staffed),0,station.role_count())
		if count<=0: continue
		var parcels:=_station_delivery_parcels(station)
		if parcels.is_empty(): continue
		var assignments:=_delivery_assignments(parcels,count)
		station.delivery_celebration_active=true
		for role in range(count):
			var key:="%d:%d"%[station.station_id,role]
			if assignments.has(role):
				var parcel: Dictionary=assignments[role]
				_advance_worker_parcel(parcel,station,role,delta)
				if not parcel.is_empty() and parcel in game.service.progress.deliveries: delivery_worker_states[key]=_worker_state(parcel,station,role)
			else: delivery_worker_states[key]=_cheer_state(station,role)

func equipment_allowed(type_id: String,item: String) -> bool:
	return Definition.equipment_allowed(type_id,item)

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
	p.deliveries.append(_new_delivery(item,station_id,[item],8.0))
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
			var at_raw: Array=parcel.get("worker_position",parcel.position) if clone_delivery_claimed(parcel) and str(parcel.get("worker_phase","")) in ["carrying","installing"] else parcel.position
			var at := Vector3(float(at_raw[0]),float(at_raw[1]),float(at_raw[2]))
			if near_ray(camera,at,0.75):
				if clone_delivery_claimed(parcel): return {"action":"worker_owned_parcel","id":parcel.id,"hint":"Работники уже бегут за этой коробкой"}
				return {"action":"take_parcel","id":parcel.id,"hint":"(E) Взять: "+parcel_name(parcel)}
	var p = game.service.progress
	if p.garland_owned:
		for index in range(p.garland_points.size()):
			var raw: Array = p.garland_points[index]
			if near_ray(camera,Vector3(raw[0],raw[1],raw[2]),0.24): return {"action":"garland_remove","index":index,"hint":"(E) Снять"}
	if p.garland_builder == peer:
		for z in [Annex.CAFE_BACK_Z]:
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
	if action_name=="worker_owned_parcel": return "Не отбирай у ребят праздник — они сами хотят распаковать и установить обновку."
	if action_name == "take_parcel":
		if clone_delivery_claimed(parcel): return "Не отбирай у ребят праздник — они сами хотят распаковать и установить обновку."
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
		var back: float=Layout.back_z(p.lounge_tier)-0.8 if position.x>Annex.DIVIDER_X else LabLayout.back(p.lab_tier)-0.8 if position.x>LabLayout.left(p.lab_tier) else Annex.CAFE_BACK_Z-0.4
		var front:=Expansion.entrance_z(Expansion.stage_for_progress(p))-1.0
		parcel.position=[clampf(position.x,Expansion.HALL_X_MIN+0.8,Expansion.HALL_X_MAX-0.8),0.3,clampf(position.z,front,back)]
	elif action_name == "install_parcel":
		if parcel.owner!=peer or position.distance_to(installation_position(parcel))>4.5: return "Поднеси коробку к отмеченному месту."
		var install_error: String=_install_parcel(parcel)
		if not install_error.is_empty(): return install_error
	else: return "Действие не найдено."
	p.revision+=1
	log_event(action_name,{"item":parcel.item,"station":parcel.station})
	return ""

func _install_parcel(parcel: Dictionary,by_workers:=false) -> String:
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
		if station==null or (not by_workers and station.state not in ["idle","waiting"]): return "Дождись свободной станции."
		for item in parcel.get("items",[parcel.item]):
			if item=="sauce_ramp":
				if item not in station.upgrades: station.upgrades.append(item)
			elif ITEMS.has(item) and ITEMS[item].kind=="equipment" and item not in station.equipment: station.equipment.append(item)
		station.apply_equipment(); station.apply_upgrades()
		game.service.request_auto_training_reconcile()
	elif spec.kind=="station":
		if game.service.by_id(int(parcel.station))!=null: return "Место пока занято."
		var station=game.service.add_station(str(parcel.item),int(parcel.station)-1,false,true)
		if station.type_id=="counter" and "rag" not in station.equipment: station.equipment.append("rag")
		for item in parcel.get("items",[parcel.item]):
			if item==parcel.item or not ITEMS.has(item): continue
			if item=="sauce_ramp":
				if item not in station.upgrades: station.upgrades.append(item)
			elif ITEMS[item].kind=="equipment" and item not in station.equipment: station.equipment.append(item)
		station.apply_equipment(); station.apply_upgrades()
		var planned_group: String=str(parcel.get("planned_group",""))
		var purchase_snapshot: Dictionary=parcel.get("planned_group_snapshot",{}) if parcel.get("planned_group_snapshot",{}) is Dictionary else {}
		var legacy_plan: Dictionary=parcel.get("method_plan",{}) if parcel.get("method_plan",{}) is Dictionary else {}
		var group_error: String=game.service.attach_purchased_station_to_group(station,planned_group,purchase_snapshot,legacy_plan)
		if not group_error.is_empty(): return group_error
		game.service.assign_clones()
		game.service.request_auto_training_reconcile()
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
	var installed_by: String="workers" if by_workers else "player"
	p.delivery_history.push_front({"id":int(parcel.id),"item":str(parcel.item),"items":parcel.get("items",[parcel.item]).duplicate(),"station":int(parcel.station),"installed_by":installed_by,"day":int(p.day)})
	while p.delivery_history.size()>12: p.delivery_history.pop_back()
	p.deliveries.erase(parcel)
	p.revision+=1
	log_event("delivery_installed",{"item":parcel.item,"station":parcel.station,"installed_by":installed_by})
	if by_workers: game.service.feed_system("worker_delivery",{"stations":[int(parcel.station)]},1)
	return ""

func advance(delta: float) -> void:
	for parcel in game.service.progress.deliveries.duplicate():
		if parcel.remaining>0:
			parcel.remaining=maxf(0,parcel.remaining-delta)
			if parcel.remaining==0:
				var dropped:=parcel_drop_position(int(parcel.id))
				parcel.position=[dropped.x,dropped.y,dropped.z]
				truck_age=5
				game.service.progress.revision+=1
				game.service.announce("Доставка у входа: "+parcel_name(parcel))
				log_event("delivery_arrived",{"item":parcel.item})
	_advance_clone_deliveries(delta)

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
			var box := preload("res://scripts/scene_runtime.gd").instantiate("res://scenes/decor/delivery_parcel_box.tscn") as Node3D; add_child(box)
			var label := Props.text(box,parcel_name(parcel),Vector3(0,0.4,0),16,Color("f3dfb0")); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			boxes[parcel.id]=box
		var node: Node3D = boxes[parcel.id]
		var worker_phase: String=str(parcel.get("worker_phase",""))
		node.visible=parcel.remaining<=0 and worker_phase not in ["carrying","installing"]
		if parcel.owner==0 and parcel.remaining<=0 and _legacy_drop(parcel):
			var dropped:=parcel_drop_position(int(parcel.id))
			parcel.position=[dropped.x,dropped.y,dropped.z]
		if parcel.owner==0: node.global_position=Vector3(parcel.position[0],parcel.position[1],parcel.position[2])
		elif parcel.owner==game.session.local_id(): node.global_transform=game.camera.global_transform; node.position+=-game.camera.global_basis.z*0.85-game.camera.global_basis.y*0.28
		else:
			var pose: Dictionary = game.session.player_poses.get(parcel.owner,{})
			if pose.has("position"): node.global_position=Vector3(pose.position[0],pose.position[1]+1.15,pose.position[2])+Vector3(0,0,-0.7).rotated(Vector3.UP,float(pose.get("yaw",0)))
	for id in boxes.keys():
		if id not in ids: boxes[id].queue_free(); boxes.erase(id)
	var worker_ids: Array=[]
	for key in delivery_worker_states:
		worker_ids.append(key)
		var state: Dictionary=delivery_worker_states[key]
		if not delivery_workers.has(key):
			var worker_instance: Node3D=SceneRuntime.instantiate("res://scenes/actors/station_delivery_worker.tscn",DeliveryWorker) as Node3D
			var worker_actor: Node3D=worker_instance.get_node("Actor") as Node3D
			worker_actor.set_script(preload("res://scripts/cook_avatar.gd"))
			worker_actor.tint=state.get("tint",Color("63aa98"))
			add_child(worker_instance)
			worker_instance.setup(str(state.get("name","Клон")),state.get("tint",Color("63aa98")))
			delivery_workers[key]=worker_instance
		delivery_workers[key].apply(state,delta)
	for key in delivery_workers.keys():
		if key not in worker_ids: delivery_workers[key].queue_free(); delivery_workers.erase(key)
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
			var reel:=SceneRuntime.instantiate("res://scenes/decor/garland_reel.tscn") as Node3D
			add_child(reel); garland_reels[p.garland_builder]=reel
		var reel: Node3D = garland_reels[p.garland_builder]
		if p.garland_builder==game.session.local_id(): reel.global_transform=game.camera.global_transform; reel.position+=game.camera.global_basis.x*0.35-game.camera.global_basis.z*0.65-game.camera.global_basis.y*0.3
		else:
			var pose: Dictionary = game.session.player_poses.get(p.garland_builder,{})
			if pose.has("position"): reel.position=Vector3(pose.position[0]+0.3,pose.position[1]+1.2,pose.position[2])
	for id in garland_reels.keys():
		if id!=p.garland_builder: garland_reels[id].queue_free(); garland_reels.erase(id)
	truck_age=maxf(0,truck_age-delta)
	truck.visible=truck_age>0
	var truck_base:=Expansion.delivery_vehicle_spawn(Expansion.stage_for_progress(p))
	truck.position=Vector3(truck_base.x-0.8,0,truck_base.z-(5-truck_age)*0.8)

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
		if not equipment_allowed(station.type_id,item) or p.stars<int(spec.get("star",0)): return "Этот предмет недоступен станции."
		unique.append(item); total+=int(spec.price)
	if p.cash<total: return "Не хватает денег на комплект."
	var error := order(unique[0],station_id)
	if not error.is_empty(): return error
	p.cash-=total-int(ITEMS[unique[0]].price)
	p.deliveries.back().items=unique
	log_event("bundle_ordered",{"station":station_id,"items":unique,"price":total})
	return ""

func order_station_batch(type_id: String,station_ids: Array,equipment: Array,group_id: String) -> String:
	var p=game.service.progress
	if p.busy(): return "Сначала заверши проверку."
	if not type_available(type_id): return "Этот тип кухни ещё не открыт."
	if station_ids.is_empty(): return "Выбери хотя бы одно подготовленное место."
	var unique_ids: Array=[]
	for raw_id in station_ids:
		var station_id: int=int(raw_id)
		if station_id<=Expansion.BASE_SLOT_COUNT or station_id>Expansion.SLOT_COUNT or station_id in unique_ids or not Expansion.slot_available(station_id-1,Expansion.stage_for_progress(p)): return "Проверь выбранные места."
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
	var group_snapshot:=group_purchase_snapshot(group_id,type_id)
	var unit_price: int=int(ITEMS[type_id].price)+equipment_cost
	var total: int=unit_price*unique_ids.size()
	if p.cash<total: return "Не хватает денег на выбранные комплекты."
	p.cash-=total
	for index in range(unique_ids.size()):
		var station_id: int=int(unique_ids[index])
		var contents: Array=[type_id]
		contents.append_array(chosen_equipment)
		p.deliveries.append(_new_delivery(type_id,station_id,contents,8.0+index*0.35,{"method_plan":plan.duplicate(true),"planned_group":group_id,"planned_group_snapshot":group_snapshot.duplicate(true),"unit_price":unit_price}))
	p.revision+=1
	log_event("station_batch_ordered",{"type":type_id,"stations":unique_ids,"equipment":chosen_equipment,"group":group_id,"price":total})
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
