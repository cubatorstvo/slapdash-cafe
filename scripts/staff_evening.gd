extends Node3D
## One activity per worker and evening; a shared bonus and cosmetic sleep poses.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Props=preload("res://scripts/props.gd")
const Annex=preload("res://scripts/cafe_annex.gd")
const Rest=preload("res://scripts/lounge_progression.gd")
const Lounge=preload("res://scripts/lounge_layout.gd")
var game: Node3D
var performers := {}
var plan_stamp := ""
var cached_plan: Array = []
var lounge_ball: Node3D

func setup(owner_game: Node3D) -> void:
	game=owner_game
	lounge_ball=Props.ball(self,0.105,Vector3.ZERO,Color("e6b45f"))
	lounge_ball.hide()

func workers() -> Array:
	var result: Array=[]
	for station in game.service.stations:
		if station.manual_station: continue
		for role in range(station.role_count() if station.staffed<0 else station.staffed):
			var member: Dictionary=station.crew[role]
			var id:=int(member.get("clone_id",0))
			if id<=0: continue
			var home: Vector3=station.to_global(Vector3(station.role_home_x(role),0,1.85))
			result.append({"id":id,"name":str(member.name),"home":home,"station":station,"from_lab":false})
	result.sort_custom(func(a,b): return int(a.id)<int(b.id))
	return result

func rest_spot(index: int) -> Dictionary:
	return Lounge.rest_spot(index,game.service.progress.lounge_tier,game.service.progress.lounge_items)

func plan() -> Array:
	var entries:=workers()
	var p=game.service.progress
	var stamp: String=str(p.day)+":"+Rest.stamp(p)
	for worker in entries: stamp+=":%d:%s"%[worker.id,str(worker.home)]
	if stamp==plan_stamp: return cached_plan
	plan_stamp=stamp
	cached_plan=[]
	var slots:=Rest.slots(p)
	# Rotate the workers across the best occupied places, never their individual bonus.
	var occupied:=mini(entries.size(),slots.size())
	for index in range(entries.size()):
		var slot_index:=posmod(index+p.day*7,maxi(1,occupied))
		var spot: Dictionary=slots[slot_index].duplicate(true) if index<slots.size() else Lounge.overflow_slot(index-slots.size(),p.lounge_tier,p.lounge_items)
		var worker: Dictionary=entries[index]
		var route:=route_for(worker,spot.approach)
		cached_plan.append({"worker":worker,"spot":spot,"route":route})
	return cached_plan

func apply_rest() -> void:
	var p=game.service.progress
	var forecast:=Rest.report(p,workers().size())
	p.rest_report=forecast.duplicate(true)
	p.rest_multiplier=float(forecast.multiplier)
	var summary: Array=[]
	for assignment in plan():
		var worker: Dictionary=game.service.clone_data(int(assignment.worker.id))
		if worker.is_empty(): continue
		worker.rest=p.rest_multiplier
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
	var inside_route:=Lounge.approach_path(target,game.service.progress.lounge_tier,game.service.progress.lounge_items)
	for point in inside_route:
		if Vector3(route.back()).distance_to(point)>0.01: route.append(point)
	return route

func reroute_from(current: Vector3, target: Vector3) -> Array:
	var p=game.service.progress
	if current.x>Annex.REST_X_MIN and current.x<Annex.REST_X_MAX and current.z>Annex.CAFE_BACK_Z:
		return Lounge.path_between(current,target,p.lounge_tier,p.lounge_items)
	var route: Array=[current,Vector3(current.x,0,7.8),Vector3(Annex.REST_DOOR_X,0,7.8),Annex.REST_DOOR_CAFE,Annex.REST_DOOR_ROOM]
	var inside_route:=Lounge.approach_path(target,p.lounge_tier,p.lounge_items)
	for point in inside_route:
		if Vector3(route.back()).distance_to(point)>0.01: route.append(point)
	return route

func _sample_route(route: Array, distance: float) -> Dictionary:
	var point: Vector3=route[0]
	var direction:=Vector3.BACK
	var done:=route.size()<2
	for i in range(1,route.size()):
		var segment: Vector3=Vector3(route[i])-Vector3(route[i-1])
		if distance<=segment.length():
			point=Vector3(route[i-1])+segment.normalized()*distance
			direction=segment
			return {"position":point,"direction":direction,"done":false}
		distance-=segment.length()
		point=Vector3(route[i])
		direction=segment
		if i==route.size()-1: done=true
	return {"position":point,"direction":direction,"done":done}

func _animate_floor_ball(clock: float) -> void:
	if not is_instance_valid(lounge_ball): return
	var floor_group: Array=[]
	for id in performers:
		var entry: Dictionary=performers[id]
		if entry.get("settled",false) and str(entry.get("item",""))=="floor" and is_instance_valid(entry.actor): floor_group.append({"id":int(id),"actor":entry.actor})
	if floor_group.size()<2:
		lounge_ball.hide()
		return
	floor_group.sort_custom(func(a,b): return int(a.id)<int(b.id))
	var duration: float=2.25
	var turn: int=int(floor(clock/duration))
	var sender: Dictionary=floor_group[turn%floor_group.size()]
	var receiver: Dictionary=floor_group[(turn+1)%floor_group.size()]
	var pass_phase: float=fposmod(clock,duration)/duration
	var from: Vector3=sender.actor.head.global_position+Vector3(0,-0.48,0)
	var to: Vector3=receiver.actor.head.global_position+Vector3(0,-0.48,0)
	lounge_ball.global_position=from.lerp(to,pass_phase)+Vector3.UP*sin(pass_phase*PI)*0.72
	lounge_ball.show()
	sender.actor.lounge_ball_react(to,pass_phase,true)
	receiver.actor.lounge_ball_react(from,pass_phase,false)

func _process(_delta: float) -> void:
	if game==null: return
	var cinematic: bool=game.session.sleep_scene_active()
	var wake_scene: bool=cinematic and game.session.sleep_scene_phase()=="wake"
	if game.service.progress.shift!="night" and not wake_scene:
		for entry in performers.values(): entry.actor.queue_free(); entry.hat.queue_free(); entry.sleepy.queue_free()
		performers.clear()
		plan_stamp=""
		cached_plan.clear()
		if is_instance_valid(lounge_ball): lounge_ball.hide()
		return
	var assignments: Array=cached_plan if wake_scene and not cached_plan.is_empty() else plan()
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
			var sleepy:=Props.text(self,"z Z z",Vector3.ZERO,22,Color("f1d9ae"))
			sleepy.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			sleepy.pixel_size=0.005
			sleepy.hide()
			Props.cylinder(hat,0.26,0.22,Vector3.ZERO,Color("fff0cb"))
			Props.cylinder(hat,0.29,0.04,Vector3(0,-0.09,0),Color("eee0b6"))
			performers[id]={"actor":actor,"hat":hat,"sleepy":sleepy}
		var entry: Dictionary=performers[id]
		var actor: Node3D=entry.actor
		var hat: Node3D=entry.hat
		entry.sleepy.hide()
		var new_spot_id: String=str(spot.id)
		var previous_spot_id: String=str(entry.get("spot_id",""))
		if not previous_spot_id.is_empty() and previous_spot_id!=new_spot_id and not wake_scene and not cinematic:
			entry.reroute_route=reroute_from(actor.global_position,spot.approach)
			entry.reroute_started=float(game.service.progress.night_elapsed)
			entry.reroute_active=entry.reroute_route.size()>1
		entry.spot_id=new_spot_id
		var station=info.station
		var training: bool=station!=null and station.training.active()
		actor.visible=not training

		if wake_scene:
			var age: float=game.session.sleep_scene_age()
			var start_delay: float=0.20+float(index%10)*0.075
			var rise_duration: float=0.82+float(id%3)*0.08
			var sleeping_spot:=Lounge.sleep_spot(spot,id,game.service.progress.lounge_tier)
			entry.settled=false
			entry.item=str(spot.item)
			actor.caption.visible=false
			actor.hat.hide()
			if age<start_delay:
				actor.sleep_pose(sleeping_spot,age,id)
			elif age<start_delay+rise_duration:
				var rise: float=smoothstep(0.0,1.0,clampf((age-start_delay)/rise_duration,0,1))
				var from: Vector3=sleeping_spot.position
				var to: Vector3=spot.approach
				var at:=from.lerp(to,rise)+Vector3.UP*sin(rise*PI)*0.16
				actor.morning_wake_pose(at,float(spot.get("yaw",0)),rise,id)
			else:
				var run_clock: float=age-start_delay-rise_duration
				var reverse_route: Array=assignments[index].route.duplicate()
				reverse_route.reverse()
				var variant: int=id%5
				var speed: float=[4.4,5.15,3.85,4.75,4.15][variant]
				var sample: Dictionary=_sample_route(reverse_route,run_clock*speed)
				actor.position=sample.position
				var direction: Vector3=sample.direction
				actor.rotation.y=atan2(-direction.x,-direction.z)
				if sample.done:
					actor.position=info.home
					actor.rotation.y=station.global_rotation.y if station!=null else 0.0
					actor.celebrate(run_clock,variant%3,false)
				else: actor.morning_run(run_clock,variant)
				hat.visible=not training and not sample.done
			continue

		var clock: float=game.service.progress.night_elapsed
		if cinematic: clock=maxf(clock,float(game.session.sleep_scene.night_start)+game.session.sleep_scene_age()*9.0)
		var t:=maxf(0,clock-index*0.18)
		var variant:=id%3
		var home: Vector3=info.home
		var route: Array=assignments[index].route
		var speed: float=[3.6,4.6,2.9][variant]
		if bool(entry.get("reroute_active",false)):
			var reroute_clock: float=maxf(0.0,clock-float(entry.get("reroute_started",clock)))
			var reroute_sample: Dictionary=_sample_route(entry.reroute_route,reroute_clock*(speed+1.25))
			actor.position=reroute_sample.position
			var reroute_direction: Vector3=reroute_sample.direction
			actor.rotation.y=atan2(-reroute_direction.x,-reroute_direction.z)
			entry.settled=false
			entry.item=str(spot.item)
			if not reroute_sample.done:
				actor.morning_run(reroute_clock,id%5)
				actor.hat.hide()
				actor.caption.text=str(info.name)+" · бежит смотреть новинку!"
				actor.caption.visible=game.camera.global_position.distance_squared_to(actor.global_position)<36.0
				continue
			entry.reroute_active=false
		var sample: Dictionary=_sample_route(route,maxf(0,t-0.85)*speed)
		var point: Vector3=sample.position
		var direction: Vector3=sample.direction
		var done: bool=sample.done
		entry.settled=done and not training
		entry.item=str(spot.item)
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
		if cinematic and done:
			var age: float=game.session.sleep_scene_age()
			var blend:=smoothstep(0.0,1.0,clampf((age-2.1-float(index%10)*0.09)/1.3,0,1))
			if blend>0:
				var from_position: Vector3=actor.position
				var from_rotation: Vector3=actor.rotation
				var sleeping_spot:=Lounge.sleep_spot(spot,id,game.service.progress.lounge_tier)
				actor.sleep_pose(sleeping_spot,age,id)
				actor.position=from_position.lerp(actor.position,blend)
				actor.position.y+=sin(blend*PI)*0.35
				var target_rotation: Vector3=actor.rotation
				actor.rotation=Vector3(lerp_angle(from_rotation.x,target_rotation.x,blend),lerp_angle(from_rotation.y,target_rotation.y,blend),lerp_angle(from_rotation.z,target_rotation.z,blend))
				actor.caption.text=str(info.name)+" · "+str(sleeping_spot.activity)
				actor.caption.visible=false
				entry.settled=false
				entry.sleepy.visible=blend>0.9
				entry.sleepy.position=actor.head.global_position+Vector3(0,0.45+sin(age*1.4+id)*0.08,0)
	for id in performers.keys():
		if id not in current_ids:
			performers[id].actor.queue_free(); performers[id].hat.queue_free(); performers[id].sleepy.queue_free(); performers.erase(id)
	if wake_scene or cinematic:
		if is_instance_valid(lounge_ball): lounge_ball.hide()
	else:
		_animate_floor_ball(game.service.progress.night_elapsed)
