extends Node3D
## End-of-shift celebration plus deterministic rest spots. Rest affects only the next day.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Props=preload("res://scripts/props.gd")
const REST_SPOTS := [
	{"position":Vector3(6.0,0.62,9.55),"quality":1.10,"pose":"bed"},
	{"position":Vector3(8.7,0.62,9.55),"quality":1.08,"pose":"bed"},
	{"position":Vector3(11.2,0.72,9.45),"quality":1.03,"pose":"bench"},
	{"position":Vector3(13.4,0.80,9.45),"quality":1.00,"pose":"table"},
	{"position":Vector3(7.2,0.06,8.45),"quality":0.96,"pose":"floor"},
	{"position":Vector3(9.7,0.06,8.45),"quality":0.94,"pose":"floor"},
	{"position":Vector3(6.0,0.92,9.55),"quality":0.92,"pose":"stack"},
	{"position":Vector3(14.5,0.0,9.0),"quality":0.90,"pose":"stand"}
]
var game: Node3D
var performers := {}

func setup(owner_game: Node3D) -> void:
	game=owner_game
	# A deliberately undersized rest area: early clones fit, later clones improvise.
	for x in [6.0,8.7]:
		Props.solid_box(self,Vector3(2.15,0.24,0.88),Vector3(x,0.28,9.55),Color("80634f"))
		Props.box(self,Vector3(1.75,0.16,0.72),Vector3(x,0.46,9.55),Color("b9a477"))
		Props.box(self,Vector3(0.48,0.12,0.65),Vector3(x-0.62,0.58,9.55),Color("e5d9b8"))
	Props.solid_box(self,Vector3(2.0,0.42,0.62),Vector3(11.2,0.25,9.45),Color("637b70"))
	Props.solid_box(self,Vector3(1.1,0.78,0.72),Vector3(13.4,0.39,9.45),Color("8d6b50"))

func workers() -> Array:
	var result: Array=[]
	for station in game.service.stations:
		if station.manual_station: continue
		for role in range(station.role_count() if station.staffed<0 else station.staffed):
			var member: Dictionary=station.crew[role]
			var id:=int(member.get("clone_id",0))
			if id<=0: continue
			var home: Vector3=station.to_global(Vector3((-1.35 if role==0 else 1.35) if station.role_count()==2 else 0,0,1.85))
			result.append({"id":id,"name":str(member.name),"home":home,"station":station})
	for worker in game.service.progress.free_workers:
		var id:=int(worker.get("id",0))
		if id>0: result.append({"id":id,"name":"Свободный клон №%d"%id,"home":Vector3(1.0,0,7.95),"station":null})
	result.sort_custom(func(a,b): return int(a.id)<int(b.id))
	return result

func rest_spot(index: int) -> Dictionary:
	if index<REST_SPOTS.size(): return REST_SPOTS[index].duplicate(true)
	var layer:=1+int((index-REST_SPOTS.size())/2)
	var side: float=-1.0 if index%2==0 else 1.0
	return {"position":Vector3(6.0+side*0.18,0.92+layer*0.28,9.55),"quality":0.90,"pose":"stack"}

func plan() -> Array:
	var entries:=workers()
	var result: Array=[]
	if entries.is_empty(): return result
	for spot_index in range(entries.size()):
		var worker_index:=posmod(spot_index+game.service.progress.day,entries.size())
		result.append({"worker":entries[worker_index],"spot":rest_spot(spot_index)})
	return result

func apply_rest() -> void:
	var summary: Array=[]
	for assignment in plan():
		var worker: Dictionary=game.service.clone_data(int(assignment.worker.id))
		if worker.is_empty(): continue
		worker.rest=clampf(float(assignment.spot.quality),0.9,1.1)
		summary.append({"id":assignment.worker.id,"rest":worker.rest})
	game.service.progress.revision+=1
	game.service.trace("rest_applied",{"day":game.service.progress.day+1,"workers":summary})

func settle(actor: Node3D, spot: Dictionary, identity: int) -> void:
	actor.position=spot.position
	actor.book.set_reading(false)
	actor.notebook.hide()
	actor.rotation=Vector3.ZERO
	actor.head.rotation=Vector3.ZERO
	for leg in actor.legs: leg.rotation.x=0
	match str(spot.pose):
		"bed": actor.rotation.z=PI/2; actor.rotation.y=PI if identity%2==0 else 0.0
		"bench": actor.rotation.z=0.35; actor.rotation.y=PI/2
		"table": actor.rotation.z=1.18; actor.rotation.y=-PI/2
		"floor": actor.rotation.z=PI/2; actor.rotation.y=identity*0.7
		"stack": actor.rotation.z=PI/2; actor.rotation.y=PI if identity%2==0 else 0.0
		"stand": actor.rotation.y=PI; actor.head.rotation.x=0.38

func _process(_delta: float) -> void:
	if game==null: return
	if game.service.progress.shift!="night":
		for entry in performers.values(): entry.actor.queue_free(); entry.hat.queue_free()
		performers.clear()
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
		var target:=Vector3(spot.position.x,0,spot.position.z)
		var route: Array=[home,Vector3(home.x,0,4.8),Vector3(5,0,4.8),Vector3(5,0,8.15),target]
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
		actor.visible=not training
		if done:
			settle(actor,spot,id)
			actor.caption.text=str(info.name)+"\nОтдых %d%%"%roundi(float(spot.quality)*100)
		else:
			actor.position=point
			actor.rotation.y=atan2(-direction.x,-direction.z)
			actor.caption.text=str(info.name)+" · смена закончилась!"
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
