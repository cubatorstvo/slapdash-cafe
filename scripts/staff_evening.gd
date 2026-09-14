extends Node3D
## End-of-shift celebration plus deterministic rest spots. Rest affects only the next day.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Props=preload("res://scripts/props.gd")
const REST_SPOTS := [
\t{"position":Vector3(6.0,0.62,9.55),"quality":1.10,"pose":"bed"},
\t{"position":Vector3(8.7,0.62,9.55),"quality":1.08,"pose":"bed"},
\t{"position":Vector3(11.2,0.72,9.45),"quality":1.03,"pose":"bench"},
\t{"position":Vector3(13.4,0.80,9.45),"quality":1.00,"pose":"table"},
\t{"position":Vector3(7.2,0.06,8.45),"quality":0.96,"pose":"floor"},
\t{"position":Vector3(9.7,0.06,8.45),"quality":0.94,"pose":"floor"},
\t{"position":Vector3(6.0,0.92,9.55),"quality":0.92,"pose":"stack"},
\t{"position":Vector3(14.5,0.0,9.0),"quality":0.90,"pose":"stand"}
]
var game: Node3D
var performers := {}

func setup(owner_game: Node3D) -> void:
\tgame=owner_game
\t# A deliberately undersized rest area: early clones fit, later clones improvise.
\tfor x in [6.0,8.7]:
\t\tProps.solid_box(self,Vector3(2.15,0.24,0.88),Vector3(x,0.28,9.55),Color("80634f"))
\t\tProps.box(self,Vector3(1.75,0.16,0.72),Vector3(x,0.46,9.55),Color("b9a477"))
\t\tProps.box(self,Vector3(0.48,0.12,0.65),Vector3(x-0.62,0.58,9.55),Color("e5d9b8"))
\tProps.solid_box(self,Vector3(2.0,0.42,0.62),Vector3(11.2,0.25,9.45),Color("637b70"))
\tProps.solid_box(self,Vector3(1.1,0.78,0.72),Vector3(13.4,0.39,9.45),Color("8d6b50"))

func workers() -> Array:
\tvar result: Array=[]
\tfor station in game.service.stations:
\t\tif station.manual_station: continue
\t\tfor role in range(station.role_count() if station.staffed<0 else station.staffed):
\t\t\tvar member: Dictionary=station.crew[role]
\t\t\tvar id:=int(member.get("clone_id",0))
\t\t\tif id<=0: continue
\t\t\tvar home: Vector3=station.to_global(Vector3((-1.35 if role==0 else 1.35) if station.role_count()==2 else 0,0,1.85))
\t\t\tresult.append({"id":id,"name":str(member.name),"home":home,"station":station})
\tfor worker in game.service.progress.free_workers:
\t\tvar id:=int(worker.get("id",0))
\t\tif id>0: result.append({"id":id,"name":"Свободный клон №%d"%id,"home":Vector3(1.0,0,7.95),"station":null})
\tresult.sort_custom(func(a,b): return int(a.id)<int(b.id))
\treturn result

func rest_spot(index: int) -> Dictionary:
\tif index<REST_SPOTS.size(): return REST_SPOTS[index].duplicate(true)
\tvar layer:=1+int((index-REST_SPOTS.size())/2)
\tvar side: float=-1.0 if index%2==0 else 1.0
\treturn {"position":Vector3(6.0+side*0.18,0.92+layer*0.28,9.55),"quality":0.90,"pose":"stack"}

func plan() -> Array:
\tvar entries:=workers()
\tvar result: Array=[]
\tif entries.is_empty(): return result
\tfor spot_index in range(entries.size()):
\t\tvar worker_index:=posmod(spot_index+game.service.progress.day,entries.size())
\t\tresult.append({"worker":entries[worker_index],"spot":rest_spot(spot_index)})
\treturn result

func apply_rest() -> void:
\tvar summary: Array=[]
\tfor assignment in plan():
\t\tvar worker: Dictionary=game.service.clone_data(int(assignment.worker.id))
\t\tif worker.is_empty(): continue
\t\tworker.rest=clampf(float(assignment.spot.quality),0.9,1.1)
\t\tsummary.append({"id":assignment.worker.id,"rest":worker.rest})
\tgame.service.progress.revision+=1
\tgame.service.trace("rest_applied",{"day":game.service.progress.day+1,"workers":summary})

func settle(actor: Node3D, spot: Dictionary, identity: int) -> void:
\tactor.position=spot.position
\tactor.book.set_reading(false)
\tactor.notebook.hide()
\tactor.rotation=Vector3.ZERO
\tactor.head.rotation=Vector3.ZERO
\tfor leg in actor.legs: leg.rotation.x=0
\tmatch str(spot.pose):
\t\t"bed": actor.rotation.z=PI/2; actor.rotation.y=PI if identity%2==0 else 0.0
\t\t"bench": actor.rotation.z=0.35; actor.rotation.y=PI/2
\t\t"table": actor.rotation.z=1.18; actor.rotation.y=-PI/2
\t\t"floor": actor.rotation.z=PI/2; actor.rotation.y=identity*0.7
\t\t"stack": actor.rotation.z=PI/2; actor.rotation.y=PI if identity%2==0 else 0.0
\t\t"stand": actor.rotation.y=PI; actor.head.rotation.x=0.38

func _process(_delta: float) -> void:
\tif game==null: return
\tif game.service.progress.shift!="night":
\t\tfor entry in performers.values(): entry.actor.queue_free(); entry.hat.queue_free()
\t\tperformers.clear()
\t\treturn
\tvar assignments:=plan()
\tvar current_ids: Array=[]
\tfor index in range(assignments.size()):
\t\tvar info: Dictionary=assignments[index].worker
\t\tvar spot: Dictionary=assignments[index].spot
\t\tvar id:=int(info.id)
\t\tcurrent_ids.append(id)
\t\tif not performers.has(id):
\t\t\tvar actor:=Avatar.new(); add_child(actor)
\t\t\tvar hat:=Node3D.new(); add_child(hat)
\t\t\tProps.cylinder(hat,0.26,0.22,Vector3.ZERO,Color("fff0cb"))
\t\t\tProps.cylinder(hat,0.29,0.04,Vector3(0,-0.09,0),Color("eee0b6"))
\t\t\tperformers[id]={"actor":actor,"hat":hat}
\t\tvar entry: Dictionary=performers[id]
\t\tvar actor: Node3D=entry.actor
\t\tvar hat: Node3D=entry.hat
\t\tvar t:=maxf(0,game.service.progress.night_elapsed-index*0.18)
\t\tvar variant:=id%3
\t\tvar home: Vector3=info.home
\t\tvar target:=Vector3(spot.position.x,0,spot.position.z)
\t\tvar route: Array=[home,Vector3(home.x,0,4.8),Vector3(5,0,4.8),Vector3(5,0,8.15),target]
\t\tvar speed: float=[3.6,4.6,2.9][variant]
\t\tvar distance:=maxf(0,t-0.85)*speed
\t\tvar point:=home
\t\tvar direction:=Vector3.BACK
\t\tvar done:=false
\t\tfor i in range(1,route.size()):
\t\t\tvar segment: Vector3=route[i]-route[i-1]
\t\t\tif distance<=segment.length(): point=route[i-1]+segment.normalized()*distance; direction=segment; break
\t\t\tdistance-=segment.length(); point=route[i]
\t\t\tif i==route.size()-1: done=true
\t\tvar station=info.station
\t\tvar training:=station!=null and station.training.active()
\t\tactor.visible=not training
\t\tif done:
\t\t\tsettle(actor,spot,id)
\t\t\tactor.caption.text=str(info.name)+"\\nОтдых %d%%"%roundi(float(spot.quality)*100)
\t\telse:
\t\t\tactor.position=point
\t\t\tactor.rotation.y=atan2(-direction.x,-direction.z)
\t\t\tactor.caption.text=str(info.name)+" · смена закончилась!"
\t\t\tactor.celebrate(t,variant,t<0.85)
\t\tactor.hat.visible=not done and t<0.42
\t\that.visible=t>=0.42 and not training
\t\tvar ht:=clampf(t-0.42,0,1.25)
\t\that.position=home+Vector3(sin(id*2.7)*ht*1.6,maxf(0.12,1.8+2.2*ht-3.0*ht*ht),cos(id*2.7)*ht*1.5)
\t\that.rotation=Vector3(ht*5,ht*3,ht*4)
\t\tif t>1.67: hat.position.y=0.12
\tfor id in performers.keys():
\t\tif id not in current_ids:
\t\t\tperformers[id].actor.queue_free(); performers[id].hat.queue_free(); performers.erase(id)
