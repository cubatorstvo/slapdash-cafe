extends Node3D
## Evening leisure preview: one stable activity per worker and day, neutral rest multiplier.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Props=preload("res://scripts/props.gd")
const Annex=preload("res://scripts/cafe_annex.gd")
const Lounge=preload("res://scripts/lounge_layout.gd")
var game: Node3D
var performers := {}
var plan_stamp := ""
var cached_plan: Array = []

func setup(owner_game: Node3D) -> void:
	game=owner_game

func workers() -> Array:
	var result: Array=[]
	for station in game.service.stations:
		if station.manual_station: continue
		for role in range(station.role_count() if station.staffed<0 else station.staffed):
			var member: Dictionary=station.crew[role]
			var id:=int(member.get("clone_id",0))
			if id<=0: continue
			var home: Vector3=station.to_global(Vector3((-1.35 if role==0 else 1.35) if station.role_count()==2 else 0,0,1.85))
			result.append({"id":id,"name":str(member.name),"home":home,"station":station,"from_lab":false})
	for worker in game.service.progress.free_workers:
		var id:=int(worker.get("id",0))
		if id>0:
			var home:=Annex.lab_world(Vector3(0.98,0,7.98))
			result.append({"id":id,"name":"Свободный клон №%d"%id,"home":home,"station":null,"from_lab":true})
	result.sort_custom(func(a,b): return int(a.id)<int(b.id))
	return result

func rest_spot(index: int) -> Dictionary:
	return Annex.rest_spot(index)

func plan() -> Array:
	var entries:=workers()
	var stamp: String=str(game.service.progress.day)
	for worker in entries: stamp+=":%d:%s"%[worker.id,str(worker.home)]
	if stamp==plan_stamp: return cached_plan
	plan_stamp=stamp
	cached_plan=[]
	var slots:=Lounge.activity_slots()
	for index in range(entries.size()):
		var slot_index:=posmod(index+game.service.progress.day*7,slots.size())
		var spot: Dictionary=slots[slot_index].duplicate(true) if index<slots.size() else Lounge.overflow_slot(index-slots.size())
		var worker: Dictionary=entries[index]
		var route:=route_for(worker,spot.approach)
		cached_plan.append({"worker":worker,"spot":spot,"route":route})
	return cached_plan

func apply_rest() -> void:
	var summary: Array=[]
	for assignment in plan():
		var worker: Dictionary=game.service.clone_data(int(assignment.worker.id))
		if worker.is_empty(): continue
		worker.rest=1.0
		summary.append({"id":assignment.worker.id,"rest":worker.rest})
	game.service.progress.revision+=1
	game.service.trace("rest_applied",{"day":game.service.progress.day+1,"workers":summary})

func settle(actor: Node3D, spot: Dictionary, identity: int) -> void:
	actor.lounge_pose(spot,float(game.service.progress.night_elapsed),identity)

func route_for(info: Dictionary, target: Vector3) -> Array:
	var home: Vector3=info.home
	var route: Array
	if bool(info.get("from_lab",false)):
		route=[home,Annex.LAB_DOOR_ROOM,Annex.LAB_DOOR_CAFE,Vector3(Annex.LAB_DOOR_X,0,8.1),Vector3(Annex.REST_DOOR_X,0,8.1),Annex.REST_DOOR_CAFE,Annex.REST_DOOR_ROOM]
	else:
		route=[home,Vector3(home.x,0,7.8),Vector3(Annex.REST_DOOR_X,0,7.8),Annex.REST_DOOR_CAFE,Annex.REST_DOOR_ROOM]
	var inside_route:=Lounge.approach_path(target)
	for point in inside_route:
		if Vector3(route.back()).distance_to(point)>0.01: route.append(point)
	return route

func _process(_delta: float) -> void:
	if game==null: return
	if game.service.progress.shift!="night":
		for entry in performers.values(): entry.actor.queue_free(); entry.hat.queue_free()
		performers.clear()
		plan_stamp=""
		cached_plan.clear()
		return
	var assignments:=plan()
	var current_ids: Array=[]
	for index in range(assignments.size()):
		var info: Dictionary=assignments[index].worker
		var spot: Dictionary=assignments[index].spot
		var id:=int(info.id)
		current_ids.append(id)
		if not performers.has(id):
			var actor:=Avatar.new(); add_child(actor)
			actor.add_to_group("automatic_door_actor")
			var hat:=Node3D.new(); add_child(hat)
			Props.cylinder(hat,0.26,0.22,Vector3.ZERO,Color("fff0cb"))
			Props.cylinder(hat,0.29,0.04,Vector3(0,-0.09,0),Color("eee0b6"))
			performers[id]={"actor":actor,"hat":hat}
		var entry: Dictionary=performers[id]
		var actor: Node3D=entry.actor
		var hat: Node3D=entry.hat
		var t:=maxf(0,game.service.progress.night_elapsed-index*0.18)
		var variant:=id%3
		var home: Vector3=info.home
		var route: Array=assignments[index].route
		var speed: float=[3.6,4.6,2.9][variant]
		var distance:=maxf(0,t-0.85)*speed
		var point:=home
		var direction:=Vector3.BACK
		var done:=false
		for i in range(1,route.size()):
			var segment: Vector3=route[i]-route[i-1]
			if distance<=segment.length(): point=route[i-1]+segment.normalized()*distance; direction=segment; break
			distance-=segment.length(); point=route[i]
			if i==route.size()-1: done=true
		var station=info.station
		var training: bool = station!=null and station.training.active()
		entry.settled=done and not training
		entry.item=str(spot.item)
		actor.visible=not training
		if done:
			settle(actor,spot,id)
			actor.caption.text=str(info.name)+"\n"+str(spot.activity)
			actor.caption.pixel_size=0.0038
			actor.caption.visible=game.camera.global_position.distance_squared_to(actor.global_position)<25.0
		else:
			actor.position=point
			actor.rotation.y=atan2(-direction.x,-direction.z)
			actor.caption.text=str(info.name)+" · смена закончилась!"
			actor.caption.visible=true
			actor.celebrate(t,variant,t<0.85)
		actor.hat.visible=not done and t<0.42
		hat.visible=t>=0.42 and not training
		var ht:=clampf(t-0.42,0,1.25)
		hat.position=home+Vector3(sin(id*2.7)*ht*1.6,maxf(0.12,1.8+2.2*ht-3.0*ht*ht),cos(id*2.7)*ht*1.5)
		hat.rotation=Vector3(ht*5,ht*3,ht*4)
		if t>1.67: hat.position.y=0.12
	for id in performers.keys():
		if id not in current_ids:
			performers[id].actor.queue_free(); performers[id].hat.queue_free(); performers.erase(id)
