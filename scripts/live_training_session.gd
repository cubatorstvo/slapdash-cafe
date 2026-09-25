extends Node3D
const Avatar=preload("res://scripts/cook_avatar.gd")
const Definition=preload("res://scripts/station_definition.gd")
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
const SceneRuntime=preload("res://scripts/scene_runtime.gd")
var service: Node3D
var active:=false
var session_id:=0
var revision:=0
var phase:=""
var dish:=""
var teacher_peer:=0
var clone_id:=0
var source_station_id:=0
var source_role:=0
var source_assignment: Dictionary={}
var actor: Node3D
var path: Array=[]
var attendance_valid:=false
var candidate_method_id:=0
var accepted_grade:=""
var return_after_commit:=false

func setup(owner_service: Node3D)->void:
	service=owner_service
	name="LiveTrainingSession"

func is_active()->bool: return active
func reserves_clone(id: int)->bool: return active and clone_id==id
func source_station(): return service.by_id(source_station_id) if is_instance_valid(service) else null
func chef_station(): return service.by_id(1) if is_instance_valid(service) else null

func _clone_assignment(id: int)->Dictionary:
	for station in service.stations:
		if station.manual_station or station.masterclass_station: continue
		var roles: int=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
		for role in range(roles):
			if int(station.crew[role].get("clone_id",0))==id: return {"station":station.station_id,"role":role,"type":station.type_id}
	return {}

func can_start(id: int,target_dish: String,peer: int)->String:
	if active: return "Личный урок уже готовится или идёт."
	if service.progress.stars<1: return "Личный урок откроется после первой звезды."
	if service.progress.busy(): return "Сначала заверши текущую проверку."
	if service.progress.shift not in ["morning","open"]: return "Личный урок проводится в рабочее время."
	if target_dish not in ["wine","potato","sausage"]: return "Первый личный урок рассчитан на одноролевое блюдо."
	if service.masterclass_locked(): return "Шеф-стойка занята съёмкой."
	var chef: Node3D=chef_station()
	if chef==null or not chef.manual_station or chef.training.active(): return "Шеф-стойка сейчас занята."
	var assignment:=_clone_assignment(id)
	if assignment.is_empty(): return "Выбранный клон сейчас не назначен на рабочее место."
	var station: Node3D=service.by_id(int(assignment.station))
	if station==null or station.role_count()!=1 or station.type_id!="counter": return "Для первого личного урока выбери клона с одноролевой стойки."
	if service.game!=null and is_instance_valid(service.game.laboratory) and service.game.laboratory.presenting_clone(id): return "Этот клон сейчас занят в лаборатории."
	if station.delivery_celebration_active or not station.group_training_state.is_empty(): return "Этот клон сейчас занят другой активностью."
	return ""

func start(id: int,target_dish: String,peer: int)->String:
	var error:=can_start(id,target_dish,peer)
	if not error.is_empty(): return error
	active=true; phase="draining"; dish=target_dish; teacher_peer=peer; clone_id=id
	source_assignment=_clone_assignment(id); source_station_id=int(source_assignment.station); source_role=int(source_assignment.role)
	session_id=service.learning_state.next_live_session_id; service.learning_state.next_live_session_id+=1
	attendance_valid=false; candidate_method_id=0; accepted_grade=""; return_after_commit=false
	var station: Node3D=source_station(); var chef: Node3D=chef_station()
	if station!=null: station.pending_teacher=clone_id
	if chef!=null: chef.pending_teacher=clone_id
	service.progress.revision+=1; revision+=1
	service.trace("live_lesson_requested",{"session":session_id,"clone":clone_id,"dish":dish,"station":source_station_id})
	return ""

func _viewer_target()->Vector3:
	var chef: Node3D=chef_station()
	if chef==null: return Vector3.ZERO
	var anchors:=SceneRuntime.instantiate("res://scenes/presentation/presentation_accessory_anchors.tscn") as Node3D
	var local:=Vector3(0,0,-3.25)
	if anchors!=null and anchors.has_node("LiveStudent"): local=(anchors.get_node("LiveStudent") as Marker3D).position
	anchors.free()
	return chef.to_global(local)

func _home_world()->Vector3:
	var station: Node3D=source_station()
	return station.to_global(Vector3(station.role_home_x(source_role),0,1.85)) if station!=null else service.global_position

func _route(from_world: Vector3,to_world: Vector3)->Array:
	var result: Array=[]
	for point in Expansion.cafe_route(from_world,to_world,Expansion.stage_for_progress(service.progress),true): result.append(service.to_local(point))
	return result

func _spawn_actor()->void:
	if is_instance_valid(actor): actor.queue_free()
	actor=Avatar.new(); add_child(actor)
	var member: Dictionary=service.clone_data(clone_id)
	actor.caption.text=str(member.get("name","Клон"))+" · идёт на личный урок"
	actor.notebook.show(); actor.position=service.to_local(_home_world())
	path=_route(_home_world(),_viewer_target())
	if not path.is_empty(): path.pop_front()

func _assignment_still_valid()->bool:
	var now:=_clone_assignment(clone_id)
	return not now.is_empty() and int(now.station)==source_station_id and int(now.role)==source_role

func _release_reservations()->void:
	var station: Node3D=source_station(); var chef: Node3D=chef_station()
	if station!=null and int(station.pending_teacher)==clone_id: station.pending_teacher=0
	if chef!=null and int(chef.pending_teacher)==clone_id: chef.pending_teacher=0

func cancel(reason := "Урок отменён.")->void:
	if not active: return
	var chef: Node3D=chef_station()
	if chef!=null and chef.training.active() and chef.training.purpose=="live_lesson": chef.training.close()
	attendance_valid=false
	if is_instance_valid(actor):
		phase="returning"
		path=_route(actor.global_position,_home_world())
		if not path.is_empty(): path.pop_front()
		actor.caption.text=str(service.clone_data(clone_id).get("name","Клон"))+" · возвращается"
	else:
		_release_reservations(); active=false; phase=""; clone_id=0
	service.progress.revision+=1; revision+=1
	service.trace("live_lesson_cancelled",{"session":session_id,"reason":reason})

func begin_demo()->String:
	if not active or phase!="ready" or not attendance_valid or not _assignment_still_valid(): return "Ученик ещё не готов к показу."
	var chef: Node3D=chef_station()
	if chef==null or chef.training.active() or chef.state!="idle" or chef.customer_id>=0: return "Шеф-стойка ещё занята."
	chef.training.open(dish,teacher_peer,"live_lesson")
	if not chef.training.start_pass([teacher_peer]):
		chef.training.close()
		return "Не удалось начать показ."
	phase="demonstrating"
	revision+=1
	service.progress.revision+=1
	return ""

func accept_from_run(stage: Node3D,tracks: Array)->Dictionary:
	if not active or phase!="demonstrating" or stage!=chef_station() or not attendance_valid or not _assignment_still_valid(): return {"ok":false,"reason":"attendance_interrupted"}
	var quality: Dictionary=stage.model.quality()
	if not bool(quality.get("present",false)): return {"ok":false,"reason":"result_not_served"}
	var required: Array=Definition.DISH_EQUIPMENT.get(dish,[]).duplicate()
	var method_id: int=service.learning_state.register_method(dish,stage.type_id,tracks,quality,required,{"equipment":stage.equipment.duplicate(),"upgrades":stage.upgrades.duplicate()})
	if method_id<=0: return {"ok":false,"reason":"method_invalid"}
	var role_id: String=str(Definition.role_ids(stage.type_id)[0])
	var acquisition:="live:%d:%d:%d:%s"%[session_id,revision,clone_id,role_id]
	var result: Dictionary=service.learning_state.grant_skill(clone_id,stage.type_id,dish,role_id,method_id,{"kind":"live","record_id":0,"record_name":"","teacher_peer":teacher_peer,"session_id":session_id,"station_id":source_station_id},acquisition,service.progress.day)
	if not bool(result.get("ok",false)): return result
	candidate_method_id=method_id; accepted_grade=str(quality.get("grade","D")); return_after_commit=true
	service.rebuild_station_binding(source_station_id,dish)
	service.progression_director.observe("live_lesson_accepted",{"clone_id":clone_id,"dish":dish,"grade":accepted_grade})
	service._refresh_progression()
	service.trace("live_lesson_accepted",{"session":session_id,"clone":clone_id,"dish":dish,"grade":accepted_grade,"method_id":method_id})
	phase="returning"
	if is_instance_valid(actor):
		path=_route(actor.global_position,_home_world())
		if not path.is_empty(): path.pop_front()
		actor.caption.text=str(service.clone_data(clone_id).get("name","Клон"))+" · научился · возвращается"
	revision+=1; service.progress.revision+=1
	return {"ok":true,"method_id":method_id,"grade":accepted_grade,"clone_id":clone_id}

func result_text()->String:
	var name:=str(service.clone_data(clone_id).get("name","Клон"))
	return "%s научился: %s · %s"%[name,Definition.DISHES.get(dish,dish),accepted_grade]

func advance(delta: float)->void:
	if not active: return
	if phase not in ["returning"] and (not _assignment_still_valid() or (source_station()!=null and source_station().delivery_celebration_active)):
		cancel("Ученик покинул назначение."); return
	match phase:
		"draining":
			var station: Node3D=source_station(); var chef: Node3D=chef_station()
			if station!=null and station.state=="idle" and station.customer_id<0 and chef!=null and chef.state=="idle" and chef.customer_id<0 and service.chef_queue().is_empty():
				_spawn_actor(); phase="walking"; revision+=1
		"walking":
			if not is_instance_valid(actor): cancel("Ученик исчез."); return
			if path.is_empty() or actor.walk_to(path[0],delta*1.8):
				if not path.is_empty(): path.pop_front()
				if path.is_empty():
					phase="ready"; attendance_valid=true; actor.caption.text=str(service.clone_data(clone_id).get("name","Клон"))+" · ждёт показа"; revision+=1
		"ready","demonstrating":
			if is_instance_valid(actor): actor.observe(chef_station().to_global(Vector3(0,1.55,0.7)),chef_station().to_global(Vector3(0,1.0,0.1)),delta,0)
		"returning":
			if not is_instance_valid(actor) or path.is_empty() or actor.walk_to(path[0],delta*1.8):
				if is_instance_valid(actor) and not path.is_empty(): path.pop_front()
				if not is_instance_valid(actor) or path.is_empty():
					if is_instance_valid(actor): actor.queue_free()
					var taught_clone:=clone_id
					_release_reservations()
					active=false
					phase=""
					clone_id=0
					revision+=1
					service.progress.revision+=1
					service.trace("live_lesson_returned",{"clone":taught_clone})

func snapshot()->Dictionary:
	var result: Dictionary={"active":active,"session_id":session_id,"revision":revision,"phase":phase,"dish":dish,"teacher_peer":teacher_peer,"clone_id":clone_id,"source_station_id":source_station_id,"source_role":source_role,"attendance_valid":attendance_valid,"candidate_method_id":candidate_method_id,"accepted_grade":accepted_grade}
	if is_instance_valid(actor): result.actor={"position":actor.position,"yaw":actor.rotation.y,"name":str(actor.caption.text)}
	return result

func apply_snapshot(data: Dictionary)->void:
	if not bool(data.get("active",false)):
		if is_instance_valid(actor): actor.queue_free()
		actor=null
		active=false
		phase=""
		clone_id=0
		revision=int(data.get("revision",revision))
		return
	active=true
	session_id=int(data.get("session_id",0))
	revision=int(data.get("revision",revision))
	phase=str(data.get("phase",""))
	dish=str(data.get("dish",""))
	teacher_peer=int(data.get("teacher_peer",0))
	clone_id=int(data.get("clone_id",0))
	source_station_id=int(data.get("source_station_id",0))
	source_role=int(data.get("source_role",0))
	attendance_valid=bool(data.get("attendance_valid",false))
	candidate_method_id=int(data.get("candidate_method_id",0))
	accepted_grade=str(data.get("accepted_grade",""))
	var actor_data: Variant=data.get("actor",{})
	if actor_data is Dictionary and not actor_data.is_empty():
		if not is_instance_valid(actor):
			actor=Avatar.new()
			add_child(actor)
			actor.notebook.show()
		actor.position=actor_data.get("position",actor.position)
		actor.rotation.y=float(actor_data.get("yaw",actor.rotation.y))
		actor.caption.text=str(actor_data.get("name","Клон · личный урок"))
	elif is_instance_valid(actor):
		actor.queue_free()
		actor=null

func reset()->void:
	if is_instance_valid(actor): actor.queue_free()
	_release_reservations(); active=false; phase=""; clone_id=0; path.clear(); attendance_valid=false; candidate_method_id=0; accepted_grade=""; revision+=1
