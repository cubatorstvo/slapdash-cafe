extends Node3D
const Annex=preload("res://scripts/cafe_annex.gd")
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
## Host-owned pots persist through saves. Tools and pulling are session-local.
const Policy=preload("res://scripts/laboratory_progression.gd")
const Layout=preload("res://scripts/laboratory_layout.gd")
const STAGE_SECONDS := 75.0
const TOOLS := {"soil":"Совок с землёй","liquid":"Пипетка с лучшей формулой","water":"Лейка","fertilizer":"Удобрение"}
var game: Node3D
var laboratory: Node3D
var hands: Dictionary={}
var pulls: Dictionary={}
var departures: Array=[]
var view: Node3D
var notice := ""
var effects: Array=[]
var effect_serial := 0

func setup(owner_game: Node3D, owner_lab: Node3D) -> void:
	game=owner_game
	laboratory=owner_lab
	view=preload("res://scripts/nursery_view.gd").new()
	add_child(view)
	view.setup(game,self)
	ensure_pots()

func ensure_pots() -> void:
	var p=game.service.progress
	for id in range(p.lab_pots.size(),Policy.pot_count(p)):
		p.lab_pots.append({"id":id,"phase":"empty","tempo":0.7,"formula":0,"remaining":0.0,"revision":0,"feed_age":10.0,"feed_from":[0,0,0]})

func pot(id: int) -> Dictionary:
	for value in game.service.progress.lab_pots:
		if int(value.id)==id: return value
	return {}

func tool(peer: int) -> String: return str(hands.get(peer,""))
func holding(peer: int) -> bool: return not tool(peer).is_empty()
func discard_infinite_tool(peer: int) -> bool:
	var current: String=tool(peer)
	if current not in TOOLS: return false
	hands.erase(peer)
	return true
func pulling(peer: int) -> bool:
	for pull in pulls.values():
		if int(pull.owner)==peer: return true
	return false

func clear_transient() -> void:
	hands.clear(); pulls.clear(); departures.clear(); effects.clear()

func release_peer(peer: int) -> void:
	hands.erase(peer)
	for id in pulls.keys():
		if int(pulls[id].owner)==peer: pulls.erase(id)
	if int(game.service.progress.lab_sample.get("carrier",0))==peer:
		game.service.progress.lab_sample.carrier=0

func target(camera: Camera3D, peer: int) -> Dictionary:
	if pulling(peer): return {"hint":"Держи E / ЛКМ и тяни назад · отпусти, чтобы перехватить"}
	for type in TOOLS:
		if game.shop.near_ray(camera,Layout.tool_point(type),0.25):
			return {"action":"lab_tool","tool":type,"hint":"(E) "+("Положить инструмент" if tool(peer)==type else str(TOOLS[type]))}
	if game.service.progress.lab_stage<3: return {}
	for value in game.service.progress.lab_pots:
		var point:=Layout.pot_point(int(value.id))
		if value.phase=="ready":
			for grip in ["head","shoulder","armpits"]:
				var at:=grip_point(int(value.id),grip)
				if game.shop.near_ray(camera,at,0.22):
					return {"action":"lab_pull","pot":value.id,"revision":value.revision,"grip":grip,"hint":"(ЛКМ / E) Ухватиться "+{"head":"за голову","shoulder":"за плечо","armpits":"под мышками"}[grip]}
		if game.shop.near_ray(camera,point+Vector3.UP*0.9,0.65):
			var hint: String={"empty":"Насыпь землю совком","soil":"Добавь каплю формулы · 60","seeded":"Полей из лейки","growing_sprout":"Прорастает","feed":"Дай удобрение проростку","growing_clone":"Клон растёт","ready":"Ухватись за голову, плечо или под мышками"}.get(value.phase,"")
			if value.phase=="empty" and "lab_planter" in game.service.progress.lab_upgrades: hint="Посадить клона · 60 · земля, формула и вода автоматически"
			if value.phase in ["growing_sprout","growing_clone"]: hint+=" · %d с"%ceili(float(value.remaining)/Policy.growth_speed(game.service.progress))
			return {"action":"lab_pot","pot":value.id,"revision":value.revision,"hint":"(E) "+hint}
	return {}

func grip_point(id: int, grip: String) -> Vector3:
	return Layout.pot_point(id)+{"head":Vector3(0,1.70,-0.05),"shoulder":Vector3(0.29,1.40,-0.08),"armpits":Vector3(-0.29,1.27,-0.08)}.get(grip,Vector3(0,1.7,0))

func action(peer: int, data: Dictionary) -> String:
	var p=game.service.progress
	var position: Vector3=laboratory.peer_position(peer)
	if game.service.training_for(peer)!=null or game.shop.carried(peer)>=0 or p.garland_builder==peer: return "Сначала освободи руки."
	if laboratory.researching(peer) or laboratory.calibrator.manual_owner()==peer: return "Сначала заверши работу с прибором."
	if data.action=="lab_tool":
		var type:=str(data.get("tool",""))
		if not TOOLS.has(type) or position.distance_to(Layout.tool_point(type))>3.2: return "Подойди к инструменту."
		if tool(peer)=="sample": return "Сначала отнеси образец в микроскоп."
		if pulling(peer): return "Сначала отпусти клона."
		if tool(peer)==type: hands.erase(peer)
		else: hands[peer]=type
		return ""
	if p.lab_stage<3 or p.stars<1: return "Нужны готовая лаборатория и первая звезда."
	var value:=pot(int(data.get("pot",-1)))
	if value.is_empty() or int(data.get("revision",-1))!=int(value.revision): return ""
	var point:=Layout.pot_point(int(value.id))
	if position.distance_to(point)>3.6: return "Подойди к горшку."
	if pulls.has(int(value.id)): return "Клона уже вытаскивают."
	if data.action=="lab_pull":
		if value.phase!="ready" or holding(peer) or pulling(peer): return "Освободи руки для клона."
		var grip:=str(data.get("grip",""))
		if grip not in ["head","shoulder","armpits"]: return ""
		pulls[int(value.id)]={"owner":peer,"progress":0.0,"grip":grip,"distance":Vector2(position.x-point.x,position.z-point.z).length(),"automatic":false,"age":0.0}
		return ""
	var before:=str(value.phase)
	match str(value.phase):
		"empty":
			if "lab_planter" in p.lab_upgrades: return plant(value)
			if tool(peer)!="soil": return "Возьми совок с землёй."
			value.phase="soil"
		"soil":
			if tool(peer)!="liquid": return "Возьми пипетку с формулой."
			var error: String=seed_pot(value)
			if not error.is_empty(): return error
		"seeded":
			if tool(peer)!="water": return "Возьми лейку."
			value.phase="growing_sprout"; value.remaining=STAGE_SECONDS
		"feed":
			if tool(peer)!="fertilizer": return "Возьми удобрение."
			feed(value,position+Vector3(0,1.2,-0.1))
		_: return ""
	if before in ["empty","soil","seeded"]:
		var type: String={"empty":"soil","soil":"liquid","seeded":"water"}[before]
		add_effect(type,int(value.id),position+Vector3(0.32,1.18,-0.2),peer)
	changed(value)
	return ""

func add_effect(type: String, id: int, from: Vector3, peer := 0, delay := 0.0) -> void:
	effect_serial+=1
	effects.append({"id":effect_serial,"kind":type,"pot":id,"from":from,"age":-delay,"duration":0.65,"peer":peer})

func seed_pot(value: Dictionary, reserve := 0) -> String:
	var p=game.service.progress
	if p.lab_formula_version<=0: return "Сначала исследуй каплю в микроскопе."
	if p.cash-Policy.CLONE_PRICE<reserve: return "Не хватает денег с учётом резерва."
	p.cash-=Policy.CLONE_PRICE
	value.tempo=p.lab_formula_tempo
	value.formula=p.lab_formula_version
	value.phase="seeded"
	p.revision+=1
	return ""

func plant(value: Dictionary, reserve := 0) -> String:
	if value.phase!="empty": return "Горшок занят."
	var error: String=seed_pot(value,reserve)
	if not error.is_empty(): return error
	value.phase="growing_sprout"; value.remaining=STAGE_SECONDS
	var point:=Layout.pot_point(int(value.id))
	add_effect("soil",int(value.id),point+Vector3(0.45,1.65,0.15),0)
	add_effect("liquid",int(value.id),point+Vector3(-0.35,1.6,0.15),0,0.25)
	add_effect("water",int(value.id),point+Vector3(0.6,1.2,0),0,0.5)
	changed(value)
	return ""

func feed(value: Dictionary, from: Vector3) -> void:
	value.phase="growing_clone"; value.remaining=STAGE_SECONDS
	value.feed_age=0.0; value.feed_from=[from.x,from.y,from.z]

func changed(value: Dictionary) -> void:
	value.revision=int(value.revision)+1
	game.service.progress.revision+=1

func demand() -> int:
	var p=game.service.progress
	var vacancies:=0
	for station in game.service.stations:
		if not station.manual_station and station.staffed>=0: vacancies+=maxi(0,station.role_count()-station.staffed)
	var growing:=0
	for value in p.lab_pots:
		if value.phase not in ["empty","soil"]: growing+=1
	return maxi(0,vacancies+int(p.lab_production.target)-p.free_workers.size()-growing)

func configure(peer: int, data: Dictionary) -> String:
	var p=game.service.progress
	if peer!=1: return "Общий выпуск настраивает хозяин кафе."
	if "lab_production" not in p.lab_upgrades and "lab_cal_auto" not in p.lab_upgrades: return "Сначала установи автоматизацию."
	if not laboratory.near_controls(peer): return "Подойди к компьютеру или пульту."
	p.lab_production={"enabled":data.get("enabled",false)==true and "lab_production" in p.lab_upgrades,"target":clampi(int(data.get("target",2)),0,20),"reserve":clampi(int(data.get("reserve",150)),0,100000)}
	p.revision+=1
	return ""

func advance(delta: float) -> void:
	ensure_pots()
	var p=game.service.progress
	if p.lab_stage<3: return
	var speed:=Policy.growth_speed(p)
	for value in p.lab_pots:
		value.feed_age=minf(10.0,float(value.get("feed_age",10.0))+delta)
		match str(value.phase):
			"seeded":
				if "lab_irrigation" in p.lab_upgrades:
					value.phase="growing_sprout"; value.remaining=STAGE_SECONDS; changed(value)
					add_effect("water",int(value.id),Layout.pot_point(int(value.id))+Vector3(0.6,1.2,0))
			"growing_sprout","growing_clone":
				value.remaining=maxf(0.0,float(value.remaining)-delta*speed)
				if float(value.remaining)<=0.0:
					value.phase="feed" if value.phase=="growing_sprout" else "ready"
					changed(value)
					game.service.announce("Горшок %d · %s"%[int(value.id)+1,"проросток ждёт удобрение" if value.phase=="feed" else "клон готов"])
			"feed":
				if "lab_feeder" in p.lab_upgrades:
					feed(value,Layout.pot_point(int(value.id))+Vector3(0,2.55,0)); changed(value)
			"ready":
				if "lab_extractor" in p.lab_upgrades and not pulls.has(int(value.id)):
					pulls[int(value.id)]={"owner":0,"progress":0.0,"grip":"armpits","distance":0.0,"automatic":true,"age":0.0}
	notice=""
	if "lab_production" in p.lab_upgrades and bool(p.lab_production.enabled) and demand()>0 and p.stars>=1:
		for value in p.lab_pots:
			if value.phase!="empty" or demand()<=0: continue
			notice=plant(value,int(p.lab_production.reserve))
			if not notice.is_empty(): break
	for id in pulls.keys():
		var pull: Dictionary=pulls[id]
		var value:=pot(int(id))
		var owner:=int(pull.owner)
		pull.age=float(pull.get("age",0.0))+delta
		if value.is_empty() or value.phase!="ready": pulls.erase(id); continue
		var effort:=1.0
		if owner>0:
			var position: Vector3=laboratory.peer_position(owner)
			var point:=Layout.pot_point(int(id))
			if position.distance_to(point)>3.8 or game.service.training_for(owner)!=null:
				pulls.erase(id); continue
			if not laboratory.pull_held(owner):
				if owner>1 and float(pull.age)<0.6: continue
				pulls.erase(id); continue
			var distance:=Vector2(position.x-point.x,position.z-point.z).length()
			effort=0.7+0.3*clampf((distance-float(pull.distance))/0.45,0,1)
		var seconds: float=2.4 if pull.grip=="head" else 2.1 if pull.grip=="shoulder" else 1.8
		pull.progress=minf(1.0,float(pull.progress)+delta*effort/seconds)
		if float(pull.progress)>=1.0: harvest(value)
	for effect in effects: effect.age=float(effect.age)+delta
	effects=effects.filter(func(effect):return float(effect.age)<float(effect.duration))
	for entry in departures: entry.age=float(entry.age)+delta
	departures=departures.filter(func(entry): return float(entry.age)<float(entry.duration))

func harvest(value: Dictionary) -> void:
	if value.phase!="ready": return
	var identity: int=game.service.progress.next_clone_id
	var error: String=game.service.create_clone(float(value.tempo),true)
	if not error.is_empty(): notice=error; pulls.erase(int(value.id)); return
	var pull: Dictionary = pulls.get(int(value.id), {})
	if not pull.is_empty() and not bool(pull.get("automatic", true)):
		game.service.record_manual_clone_growth(identity, float(value.tempo))
	var origin:=Layout.pot_point(int(value.id))+Vector3(0,0,-1.05)
	var route:=exit_route(identity,origin)
	var length:=0.0
	for i in range(1,route.size()): length+=Vector3(route[i-1]).distance_to(route[i])
	departures.append({"id":identity,"route":route,"age":0.0,"duration":0.5+length/3.0})
	pulls.erase(int(value.id))
	value.phase="empty"; value.remaining=0.0; value.feed_age=10.0
	changed(value)
	game.service.trace("clone_harvested",{"clone":identity,"tempo":value.tempo,"formula":value.formula,"pot":value.id})
	game.save_cafe()

func exit_route(identity: int, origin: Vector3) -> Array:
	var route: Array=Layout.path(origin,Layout.ENTRY,game.service.progress)
	for option in game.service.clone_options():
		if int(option.id)!=identity: continue
		if int(option.station)==0:
			for i in range(game.service.progress.free_workers.size()):
				if int(game.service.progress.free_workers[i].id)==identity:
					return Layout.path(origin,Layout.waiting_point(i),game.service.progress)
			return [origin]
		var station=game.service.by_id(int(option.station))
		var role:=0
		for i in range(station.crew.size()):
			if int(station.crew[i].get("clone_id",0))==identity: role=i
		var home: Vector3=station.to_global(Vector3(station.role_home_x(role),0,1.85))
		route.append(Annex.LAB_DOOR_ROOM); route.append(Annex.LAB_DOOR_CAFE)
		for point in Expansion.cafe_route(Annex.LAB_DOOR_CAFE,home,Expansion.stage_for_progress(game.service.progress),true):
			if Vector3(route.back()).distance_to(point)>0.01: route.append(point)
		break
	return route

func presenting(identity: int) -> bool:
	for entry in departures:
		if int(entry.id)==identity: return true
	return false

func snapshot() -> Dictionary:
	return {"effects":effects.duplicate(true),"hands":hands.duplicate(true),"pulls":pulls.duplicate(true),"departures":departures.duplicate(true),"notice":notice}

func restore(value: Dictionary) -> void:
	effects=value.get("effects",[]).duplicate(true)
	hands=value.get("hands",{}).duplicate(true)
	pulls=value.get("pulls",{}).duplicate(true)
	departures=value.get("departures",[]).duplicate(true)
	notice=str(value.get("notice",""))
