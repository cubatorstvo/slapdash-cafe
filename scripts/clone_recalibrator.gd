extends Node3D
## A distinct rhythm instrument plus a persistent, gradual automatic queue.
const Policy=preload("res://scripts/laboratory_progression.gd")
const Layout=preload("res://scripts/laboratory_layout.gd")
const P=preload("res://scripts/props.gd")
const Avatar=preload("res://scripts/cook_avatar.gd")
const BEATS := [1.2,2.2,3.0,4.4,5.3,6.4]
const ROUND_SECONDS := 7.2
var game: Node3D
var laboratory: Node3D
var root: Node3D
var actor: Node3D
var caption: Label3D
var lamps: Array=[]
var stamp := ""
var state: Dictionary:
	get: return game.service.progress.lab_calibration

func setup(owner_game: Node3D, owner_lab: Node3D) -> void:
	game=owner_game; laboratory=owner_lab
	actor=Avatar.new(); add_child(actor); actor.add_to_group("automatic_door_actor")
	rebuild()

func manual_owner() -> int:
	return int(state.get("owner",0)) if state.phase in ["walking","manual"] else 0

func busy() -> bool: return state.phase!="idle"
func clone_id() -> int: return int(state.get("clone_id",0)) if busy() else 0
func reserves_station(id: int) -> bool: return busy() and int(state.station)==id and id>0
func scale_time() -> float: return 1.3 if bool(state.get("slow",false)) else 1.0

func reset() -> void:
	var revision:=int(state.get("revision",0))+1
	var selected:=int(state.get("selected",0))
	game.service.progress.lab_calibration=Policy.blank_calibration()
	state.revision=revision; state.selected=selected

func selected() -> Dictionary:
	var options: Array=game.service.clone_options()
	for option in options:
		if int(option.id)==int(state.get("selected",0)): return option
	return options[0] if not options.is_empty() else {}

func available(option: Dictionary) -> bool:
	if laboratory.nursery.presenting(int(option.id)): return false
	if int(option.station)==0: return true
	var station=game.service.by_id(int(option.station))
	return station!=null and station.state=="idle" and not station.training.active() and station.pending_teacher<=0 and station.customer_id<0

func target(camera: Camera3D, peer: int) -> Dictionary:
	if "lab_chair" not in game.service.progress.lab_upgrades: return {}
	for direction in [-1,1]:
		if game.shop.near_ray(camera,Layout.CHAIR+Vector3(direction*0.57,1.02,-0.60),0.18):
			return {"action":"lab_cal_select","direction":direction,"revision":state.revision,"hint":"(E) Выбрать сотрудника"}
	if game.shop.near_ray(camera,Layout.CHAIR+Vector3(0,1.1,-0.5),0.55):
		if busy(): return {"hint":"Рекалибровка · "+str(state.get("notice","Кресло занято"))}
		var option:=selected()
		return {"action":"lab_cal_start","revision":state.revision,"hint":"(E) Рекалибровка · 10 · "+str(option.get("name","Нет клонов"))}
	return {}

func action(peer: int, data: Dictionary) -> String:
	var p=game.service.progress
	if data.action=="lab_cal_auto":
		if peer!=1 or not laboratory.near_controls(peer): return "Настройка доступна хозяину у компьютера или кресла."
		if "lab_cal_auto" not in p.lab_upgrades: return "Сначала установи автоматику кресла."
		p.lab_auto_calibration=data.get("enabled",false)==true
		p.revision+=1
		if not p.lab_auto_calibration and busy() and int(state.owner)==0: begin_return("Автоматика выключена")
		return ""
	if data.action=="lab_cal_cancel":
		if manual_owner()==peer: begin_return("Попытка прервана")
		return ""
	if data.action=="lab_cal_hit":
		return hit(peer,int(data.get("revision",-1)),float(data.get("observed_age",-1.0)))
	if "lab_chair" not in p.lab_upgrades: return "Сначала установи кресло."
	if laboratory.peer_position(peer).distance_to(Layout.CHAIR)>3.5: return "Подойди к креслу."
	if laboratory.hands_busy(peer) or laboratory.researching(peer) or game.service.training_for(peer)!=null: return "Сначала освободи руки."
	if busy(): return "Кресло занято."
	if int(data.get("revision",-1))!=int(state.revision): return ""
	if data.action=="lab_cal_select":
		var options: Array=game.service.clone_options()
		if options.is_empty(): return "Пока нет клонов."
		var ids: Array=[]
		for option in options: ids.append(int(option.id))
		state.selected=ids[posmod(ids.find(int(selected().get("id",0)))+int(data.get("direction",1)),ids.size())]
		state.revision=int(state.revision)+1
		return ""
	var option:=selected()
	if option.is_empty(): return "Пока нет клонов."
	return start(option,peer)

func start(option: Dictionary, owner: int) -> String:
	var p=game.service.progress
	if busy() or not available(option): return "Дождись, когда сотрудник завершит заказ или показ."
	if p.lab_formula_version<=0: return "Сначала исследуй формулу в микроскопе."
	if float(option.tempo)>=p.lab_formula_tempo-0.00001: return "Темп этого клона уже не ниже изученной формулы."
	var reserve: int=int(p.lab_production.reserve) if owner==0 else 0
	if p.cash-Policy.RECALIBRATION_PRICE<reserve: return "Не хватает денег с учётом резерва."
	p.cash-=Policy.RECALIBRATION_PRICE
	state.phase="walking"; state.clone_id=int(option.id); state.station=int(option.station); state.owner=owner
	state.target=p.lab_formula_tempo; state.start=float(option.tempo)
	state.hits=[-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]; state.misses=0
	state.focus="lab_cal_focus" in p.lab_upgrades; state.slow="lab_cal_slow" in p.lab_upgrades
	state.route=laboratory.route_to_chair(int(option.id))
	state.age=0.0; state.notice="Идёт к креслу"; state.revision=int(state.revision)+1
	p.revision+=1
	game.save_cafe()
	return ""

func hit(peer: int, revision: int, observed_age: float) -> String:
	if state.phase!="manual" or int(state.owner)!=peer or revision!=int(state.revision): return ""
	var age:=float(state.age)
	if peer!=1 and is_finite(observed_age) and observed_age>=age-0.35 and observed_age<=age: age=observed_age
	age/=scale_time()
	var nearest_index: int=-1
	var distance:=INF
	for i in range(BEATS.size()):
		var error:=absf(age-float(BEATS[i]))
		if float(state.hits[i])<0 and error<distance: nearest_index=i; distance=error
	if nearest_index<0 or distance>0.40:
		state.misses=int(state.misses)+1
	else:
		var perfect:=0.11 if bool(state.focus) else 0.065
		state.hits[nearest_index]=clampf(1.0-maxf(0,distance-perfect)/0.25,0,1)
	state.revision=int(state.revision)+1
	return ""

func score() -> float:
	var result:=0.0
	for value in state.hits: result+=maxf(0,float(value))
	result=clampf((result-float(state.misses)*0.15)/6.0,0,1)
	return 1.0 if result>=0.90 else result

func begin_return(message: String) -> void:
	if not busy(): return
	state.phase="returning"; state.owner=0; state.age=0.0; state.notice=message
	var route: Array=state.get("route",[Layout.CHAIR]).duplicate()
	route.reverse(); state.route=route
	state.revision=int(state.revision)+1
	game.service.progress.revision+=1
	game.save_cafe()

func finish_manual() -> void:
	var worker: Dictionary=game.service.clone_data(clone_id())
	if worker.is_empty(): reset(); return
	var attempt:=snappedf(float(state.target)*score(),0.01)
	var before:=float(worker.tempo)
	worker.tempo=maxf(before,attempt)
	var message: String="Темп %d%% → %d%% · результат %d%%"%[roundi(before*100),roundi(float(worker.tempo)*100),roundi(attempt*100)]
	game.session.lab_result(int(state.owner),{"kind":"calibration_result","tempo":worker.tempo,"attempt":attempt,"before":before,"best":state.target})
	game.service.trace("clone_recalibrated",{"clone":clone_id(),"attempt":attempt,"retained":worker.tempo})
	begin_return(message)

func route_duration(route: Array) -> float:
	var length:=0.0
	for i in range(1,route.size()): length+=Vector3(route[i]).distance_to(route[i-1])
	return length/3.2

func advance(delta: float) -> void:
	var p=game.service.progress
	if not busy():
		if p.lab_auto_calibration and "lab_cal_auto" in p.lab_upgrades and not p.busy() and p.shift in ["morning","open"]:
			var options: Array=game.service.clone_options()
			options.sort_custom(func(a,b): return float(a.tempo)<float(b.tempo) if not is_equal_approx(float(a.tempo),float(b.tempo)) else int(a.id)<int(b.id))
			for option in options:
				if float(option.tempo)>=p.lab_formula_tempo: continue
				if available(option): start(option,0); break
		return
	var worker: Dictionary=game.service.clone_data(clone_id())
	if worker.is_empty(): reset(); return
	var owner:=manual_owner()
	if owner>0 and (laboratory.peer_position(owner).distance_to(Layout.CHAIR)>4.5 or game.service.training_for(owner)!=null):
		begin_return("Оператор ушёл · прежний темп сохранён"); return
	state.age=float(state.age)+delta
	match str(state.phase):
		"walking":
			if float(state.age)>=route_duration(state.route):
				state.phase="manual" if int(state.owner)>0 else "auto"
				state.age=0.0; state.revision=int(state.revision)+1
				state.notice="Лови ритм импульсов" if state.phase=="manual" else "Постепенно повышает темп"
		"manual":
			if float(state.age)>=ROUND_SECONDS*scale_time(): finish_manual()
		"auto":
			var rate:=0.012 if "lab_cal_speed" in p.lab_upgrades else 0.006
			worker.tempo=minf(float(state.target),float(worker.tempo)+delta*rate)
			state.remaining=maxf(0,(float(state.target)-float(worker.tempo))/rate)
			if float(worker.tempo)>=float(state.target)-0.00001: begin_return("Достигнут темп %d%%"%roundi(float(worker.tempo)*100))
		"returning":
			if float(state.age)>=route_duration(state.route):
				reset(); game.service.assign_clones(); p.revision+=1; game.save_cafe()

func prepare_sleep() -> void:
	# Auto progress is already in the worker. Everyone can join the shared sleep scene.
	if busy() and manual_owner()==0: reset()

func rebuild() -> void:
	if is_instance_valid(root): root.free()
	root=Node3D.new(); add_child(root); root.position=Layout.CHAIR
	var upgrades: Array=game.service.progress.lab_upgrades
	stamp=str(upgrades)
	root.visible="lab_chair" in upgrades
	lamps.clear()
	P.solid_box(root,Vector3(0.95,0.16,0.86),Vector3(0,0.6,0),Color("78a99b"))
	P.box(root,Vector3(0.95,1.0,0.16),Vector3(0,1.13,0.35),Color("8bbca7"))
	for side in [-1,1]:
		P.box(root,Vector3(0.11,0.5,0.7),Vector3(side*0.49,0.77,0),Color("b5a078"))
		P.box(root,Vector3(0.12,0.65,0.12),Vector3(side*0.38,0.30,0.25),Color("4f7169"))
	P.line(root,Vector3(0,0,0.52),Vector3(0,2.25,0.52),0.06,Color("5b7e70"))
	P.cylinder(root,0.35,0.22,Vector3(0,2.05,0),Color("c9b788"))
	for i in range(3):
		var lamp:=P.ball(root,0.075,Vector3(-0.22+i*0.22,2.10,-0.28),[Color("df997b"),Color("e0ce88"),Color("85c8ac")][i])
		lamps.append(lamp)
	P.box(root,Vector3(0.48,0.20,0.32),Vector3(0,0.92,-0.60),Color("42655c"))
	for side in [-1,1]: P.box(root,Vector3(0.18,0.08,0.18),Vector3(side*0.57,1.02,-0.60),Color("d3b27b"))
	for id in ["lab_cal_focus","lab_cal_slow","lab_cal_auto","lab_cal_speed"]:
		if id not in upgrades: continue
		var at:=Layout.fixture(id)-Layout.CHAIR
		P.box(root,Vector3(0.3,0.25,0.24),at,Color("a7b685"))
		for i in range(3): P.ball(root,0.024,at+Vector3(-0.08+i*0.08,0.04,-0.13),Color("e0d595"))
	caption=P.text(root,"",Vector3(0,2.7,0),20,Color("efdcb3"))
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED; caption.pixel_size=0.0038

func _process(delta: float) -> void:
	if game==null: return
	if stamp!=str(game.service.progress.lab_upgrades): rebuild()
	actor.visible=busy()
	var selected_option:=selected()
	caption.text="РЕКАЛИБРАТОР · до %d%%\n%s"%[roundi(game.service.progress.lab_formula_tempo*100),str(selected_option.get("name","Нет клонов"))]
	if busy():
		caption.text="Клон №%d · %s"%[clone_id(),str(state.notice)]
		if state.phase in ["walking","returning"]:
			var distance:=float(state.age)*3.2
			var route: Array=state.route
			var point: Vector3=route[0]
			var direction:=Vector3.FORWARD
			for i in range(1,route.size()):
				var segment: Vector3=route[i]-route[i-1]
				if distance<segment.length(): point=Vector3(route[i-1])+segment.normalized()*distance; direction=segment; break
				distance-=segment.length(); point=route[i]
			actor.reset_lounge_accessories(); actor.position=point
			actor.rotation=Vector3(0,atan2(-direction.x,-direction.z),0)
			actor.celebrate(float(state.age),1,false)
		else:
			actor.lounge_pose({"position":Layout.CHAIR+Vector3(0,0.05,0),"yaw":0.0,"pose":"watch"},float(state.age),clone_id())
			actor.head.rotation.x=sin(float(state.age)*5.5)*0.05
		actor.caption.hide(); actor.hat.hide()
	for i in range(lamps.size()):
		var glow:=0.35
		if state.phase=="manual":
			for j in range(BEATS.size()):
				if j%3==i: glow=maxf(glow,1.0-clampf(absf(float(state.age)/scale_time()-float(BEATS[j]))/0.25,0,1))
		elif state.phase=="auto": glow=0.65+sin(float(state.age)*4+i)*0.35
		lamps[i].scale=Vector3.ONE*(0.7+glow*0.5)
