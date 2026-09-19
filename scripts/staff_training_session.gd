extends Node3D
## One shared television lesson. Selected crews finish current work, gather, watch once, then return.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Annex=preload("res://scripts/cafe_annex.gd")
const LoungeLayout=preload("res://scripts/lounge_layout.gd")
var service: Node3D
var active:=false
var phase:=""
var dish:=""
var record_id:=0
var record: Dictionary={}
var station_ids: Array=[]
var actors: Dictionary={}
var actor_paths: Dictionary={}
var actor_meta: Dictionary={}
var revision:=0

func setup(owner_service: Node3D)->void:
	service=owner_service
	name="StaffTrainingSession"

func is_active()->bool: return active

func phase_label()->String:
	return {"assigned":"назначено","gathering":"собираются","walking":"собираются","watching":"смотрят","returning":"возвращаются"}.get(phase,"")

func targets_station(station_id: int, target_dish := "")->bool:
	return active and station_id in station_ids and (target_dish.is_empty() or target_dish==dish)

func pending_source(station_id: int,target_dish: String)->Dictionary:
	if not targets_station(station_id,target_dish): return {}
	return {"id":record_id,"name":str(record.get("name","Запись")),"pending":true}

func start(value: Dictionary, ids: Array)->void:
	reset()
	active=true
	phase="assigned"
	dish=str(value.get("dish",""))
	record_id=int(value.get("id",0))
	record=value.duplicate(true)
	station_ids=ids.duplicate()
	for id in station_ids:
		var station=service.by_id(int(id))
		if station!=null: station.group_training_state="assigned"
	revision+=1

func reset()->void:
	for id in station_ids:
		var station=service.by_id(int(id)) if is_instance_valid(service) else null
		if station!=null: station.group_training_state=""
	for actor in actors.values():
		if is_instance_valid(actor): actor.queue_free()
	actors.clear()
	actor_paths.clear()
	actor_meta.clear()
	active=false
	phase=""
	dish=""
	record_id=0
	record={}
	station_ids.clear()

func _viewer_spot(index: int)->Vector3:
	var row:=int(index/4)
	var col:=index%4
	return Vector3(4.75+col*1.10,0,13.15+row*0.72)

func _route(home_world: Vector3,target_world: Vector3)->Array:
	var home:=service.to_local(home_world)
	var door_cafe:=service.to_local(Annex.REST_DOOR_CAFE)
	var door_room:=service.to_local(Annex.REST_DOOR_ROOM)
	var target:=service.to_local(target_world)
	var route: Array=[home,Vector3(home.x,0,8.9),door_cafe,door_room]
	var p=service.progress
	var inside: Array=LoungeLayout.path_between(Annex.REST_DOOR_ROOM,target_world,int(p.lounge_tier),p.lounge_items)
	for point in inside:
		var local:=service.to_local(point)
		if Vector3(route.back()).distance_to(local)>0.03: route.append(local)
	return route

func _ready_to_leave()->bool:
	for id in station_ids:
		var station=service.by_id(int(id))
		if station==null or station.state!="idle" or station.customer_id>=0 or station.training.active() or station.pending_teacher>0: return false
	return true

func _spawn_actors()->void:
	var viewer_index:=0
	for id in station_ids:
		var station=service.by_id(int(id))
		if station==null: continue
		station.group_training_state="walking"
		var roles: int=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
		for role in range(roles):
			var key: String="%d:%d"%[station.station_id,role]
			var actor:=Avatar.new()
			add_child(actor)
			var member: Dictionary=station.crew[role]
			actor.caption.text=str(member.get("name","Клон"))+" · на обучение"
			actor.notebook.show()
			var home_world: Vector3=station.to_global(Vector3(station.role_home_x(role),0,1.85))
			var target_world: Vector3=_viewer_spot(viewer_index)
			actor.position=service.to_local(home_world)
			actors[key]=actor
			actor_meta[key]={"station":station.station_id,"role":role,"home":home_world,"target":target_world,"name":str(member.get("name","Клон"))}
			var path: Array=_route(home_world,target_world)
			if not path.is_empty(): path.pop_front()
			actor_paths[key]=path
			viewer_index+=1

func _advance_paths(delta: float)->bool:
	var finished:=true
	for key in actors:
		var path: Array=actor_paths.get(key,[])
		if path.is_empty(): continue
		finished=false
		var actor: Node3D=actors[key]
		if actor.walk_to(path[0],delta*1.8):
			path.pop_front()
			actor_paths[key]=path
	for key in actor_paths:
		if not actor_paths[key].is_empty(): return false
	return finished or not actor_paths.is_empty()

func _begin_return()->void:
	phase="returning"
	var keys: Array=actors.keys()
	for index in range(keys.size()):
		var key: String=keys[index]
		var meta: Dictionary=actor_meta[key]
		var route: Array=_route(meta.home,meta.target)
		route.reverse()
		if not route.is_empty(): route.pop_front()
		actor_paths[key]=route
		var station=service.by_id(int(meta.station))
		if station!=null: station.group_training_state="returning"
		actors[key].caption.text=str(meta.name)+" · возвращается"

func _complete()->void:
	for id in station_ids:
		var station=service.by_id(int(id))
		if station==null: continue
		station.recipes[dish]={"tracks":record.get("tracks",[]).duplicate(true),"duration":float(record.get("duration",0.0)),"quality":record.get("quality",{}).duplicate(true)}
		station.method_sources[dish]={"id":record_id,"name":str(record.get("name","Запись"))}
		station.method_plan.erase(dish)
		station.drafts.erase(dish)
		station.group_training_state=""
	service.trace("group_training_complete",{"dish":dish,"record":record_id,"stations":station_ids.duplicate()})
	service.feed_system("training",{"dish":dish,"record":record_id,"name":str(record.get("name","Запись")),"stations":station_ids.duplicate()},station_ids.size())
	service.progress.revision+=1
	var game=service.game
	reset()
	if game!=null: game.save_cafe()

func advance(delta: float)->void:
	if not active: return
	match phase:
		"assigned":
			phase="gathering"
			for id in station_ids:
				var station=service.by_id(int(id))
				if station!=null: station.group_training_state="gathering"
			revision+=1
		"gathering":
			if _ready_to_leave():
				_spawn_actors()
				phase="walking"
				revision+=1
		"walking":
			if _advance_paths(delta):
				phase="watching"
				for id in station_ids:
					var station=service.by_id(int(id))
					if station!=null: station.group_training_state="watching"
				service.start_training_movie(record)
				revision+=1
		"watching":
			var tv:=service.to_local(Vector3(6.5,1.55,11.3))
			var keys: Array=actors.keys()
			for index in range(keys.size()):
				var actor=actors[keys[index]]
				actor.caption.text=str(actor_meta[keys[index]].name)+" · конспектирует"
				actor.observe(tv,tv+Vector3(0.4 if index%2==0 else -0.4,0,0),delta,index)
			if not bool(service.movie_state.get("playing",false)): _begin_return()
		"returning":
			if _advance_paths(delta): _complete()

func snapshot()->Dictionary:
	if not active: return {"active":false,"revision":revision}
	var people: Array=[]
	for key in actors:
		var actor: Node3D=actors[key]
		people.append({"key":key,"name":str(actor_meta[key].name),"position":actor.position,"yaw":actor.rotation.y,"watching":phase=="watching"})
	return {"active":true,"revision":revision,"phase":phase,"dish":dish,"record_id":record_id,"record_name":str(record.get("name","Запись")),"stations":station_ids.duplicate(),"actors":people}

func apply_snapshot(data: Dictionary)->void:
	if not data.get("active",false):
		reset()
		revision=int(data.get("revision",revision))
		return
	active=true
	phase=str(data.get("phase",""))
	dish=str(data.get("dish",""))
	record_id=int(data.get("record_id",0))
	record={"id":record_id,"name":str(data.get("record_name","Запись")),"dish":dish}
	station_ids=data.get("stations",[]).duplicate()
	revision=int(data.get("revision",revision))
	for station in service.stations:
		if station.station_id in station_ids: station.group_training_state=phase
		elif not station.manual_station: station.group_training_state=""
	var keep: Array=[]
	for index in range(data.get("actors",[]).size()):
		var entry: Dictionary=data.actors[index]
		var key: String=str(entry.key)
		keep.append(key)
		if not actors.has(key):
			var actor:=Avatar.new()
			add_child(actor)
			actors[key]=actor
		actor_meta[key]={"name":str(entry.get("name","Клон"))}
		var actor: Node3D=actors[key]
		actor.position=entry.position
		actor.rotation.y=float(entry.get("yaw",0.0))
		actor.caption.text=str(entry.get("name","Клон"))+(" · конспектирует" if entry.get("watching",false) else " · на обучение")
		actor.notebook.show()
		if entry.get("watching",false):
			var tv:=service.to_local(Vector3(6.5,1.55,11.3))
			actor.observe(tv,tv+Vector3(0.35,0,0),0.016,index)
	for key in actors.keys():
		if key not in keep:
			if is_instance_valid(actors[key]): actors[key].queue_free()
			actors.erase(key)
