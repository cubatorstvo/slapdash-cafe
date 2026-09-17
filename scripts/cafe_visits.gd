extends RefCounted
## One optional visit at a time. Settled guest slots survive save/reload.
const PREPARATION := 60.0
const DURATION := 240.0
const KINDS := {
	"critics":{"name":"Четыре критика","dishes":["wine","potato","sausage","wine"],"grade":"A","good":4,"cash":60,"popularity":5},
	"crew":{"name":"Обед для соседней мастерской","dishes":["sausage","wine","potato","sausage","wine","potato"],"grade":"B","good":5,"cash":80,"popularity":3}
}

static func busy(p) -> bool: return p.visit.get("phase","") in ["scheduled","active"]
static func spec(p) -> Dictionary: return KINDS.get(p.visit.get("kind",""),{})
static func eligible(service, kind: String) -> bool:
	var p=service.progress
	if p.stars<1 or p.journey_auto_served<3: return false
	if kind=="critics":
		var personal=service.by_id(1)
		if personal==null: return false
		for item in ["jug","cup","pan","plates","sauce"]:
			if item not in personal.equipment: return false
		return true
	var crews:=0
	for station in service.stations:
		if not station.manual_station and station.ready_crew(): crews+=1
	if crews<2: return false
	for dish in ["wine","potato","sausage"]:
		var known:=false
		for station in service.stations:
			if station.manual_station: continue
			var quality: Dictionary=station.recipes.get(dish,{}).get("quality",{})
			if quality.get("present",false) and quality.get("grade","D") in ["B","A","S"]: known=true
		if not known: return false
	return true

static func action(service, action_name: String, id: int) -> String:
	var p=service.progress
	if int(p.visit.get("id",-1))!=id: return "Предложение уже изменилось."
	if action_name=="visit_cancel":
		if busy(p): finish(service,false,"Визит отменён.")
		return ""
	if p.visit.get("phase","")!="offered": return "Предложение уже обработано."
	if action_name=="visit_decline":
		p.visit.phase="declined"; p.visit_next_day=p.day+2; p.revision+=1
		service.game.save_cafe()
		return ""
	if p.busy(): return "Сначала заверши проверку на звезду."
	if not eligible(service,str(p.visit.kind)): return "Подготовь оборудование и бригады по условиям визита."
	if p.shift not in ["morning","open"]: return "Визит можно назначить утром или в открытую смену."
	p.visit.phase="scheduled"
	p.visit.start_day=p.day if 480.0-p.shift_elapsed>=PREPARATION+DURATION else p.day+1
	p.visit.preparation=PREPARATION; p.visit.remaining=DURATION; p.visit.spawn_clock=0.0
	p.revision+=1
	service.announce("Визит принят: "+str(spec(p).name)+". Подготовка — минута открытой смены." if int(p.visit.start_day)==p.day else "Визит назначен на утро дня %d."%p.visit.start_day)
	service.game.save_cafe()
	return ""

static func chef_reserved(p) -> bool:
	return busy(p) and p.visit.kind=="critics" and int(p.visit.get("start_day",p.day))<=p.day

static func advance(service, delta: float) -> void:
	var p=service.progress
	var phase:=str(p.visit.get("phase",""))
	if not busy(p):
		if phase=="offered" or p.busy() or p.shift not in ["morning","open"] or p.day<p.visit_next_day: return
		var preferred: String="crew" if p.visit_next_kind=="crew" else "critics"
		var kind: String=preferred if eligible(service,preferred) else "critics" if eligible(service,"critics") else ""
		if kind.is_empty(): return
		p.visit_serial+=1
		p.visit={"id":p.visit_serial,"kind":kind,"phase":"offered","settled":[],"paid":0,"good":0,"remaining":DURATION,"preparation":PREPARATION,"spawn_clock":0.0,"result":""}
		p.revision+=1
		service.announce("Добровольное предложение в компьютере: "+str(spec(p).name)+". Принять можно, когда будет удобно.")
		service.game.save_cafe()
		return
	if p.busy() or not service.open_for_business or p.day<int(p.visit.start_day): return
	var elapsed:=delta
	if phase=="scheduled":
		var preparation_left:=float(p.visit.preparation)
		p.visit.preparation=maxf(0,preparation_left-delta)
		if float(p.visit.preparation)>0: return
		elapsed=maxf(0,delta-preparation_left)
		p.visit.phase="active"; p.revision+=1
		service.announce(str(spec(p).name)+": гости идут. Визит длится четыре минуты.")
	p.visit.remaining=maxf(0,float(p.visit.remaining)-elapsed)
	if float(p.visit.remaining)<=0:
		finish(service,false,"Время визита вышло."); return
	p.visit.spawn_clock=maxf(0,float(p.visit.spawn_clock)-elapsed)
	if float(p.visit.spawn_clock)>0: return
	var data:=spec(p)
	for slot in range(data.dishes.size()):
		if slot in p.visit.settled: continue
		var present:=false
		for guest in service.customers:
			if int(guest.get("visit_id",-1))==int(p.visit.id) and int(guest.get("visit_slot",-1))==slot: present=true; break
		if present: continue
		var chef: bool=p.visit.kind=="critics"
		var dish: String=data.dishes[slot]
		var available: bool=service.chef_queue().size()<service.CHEF_QUEUE_LIMIT if chef else false
		if not chef:
			for station in service.stations:
				if not station.manual_station and station.ready_crew() and station.state=="idle" and station.pending_teacher==0 and station.recipes.has(dish): available=true
		if available and service.spawn_customer(dish,false,chef,{"id":p.visit.id,"slot":slot,"kind":p.visit.kind}):
			p.visit.spawn_clock=8.0
		return

static func settled(service, guest: Dictionary, paid: bool, grade: String) -> void:
	var p=service.progress
	if p.visit.get("phase","")!="active" or int(guest.get("visit_id",-1))!=int(p.visit.id): return
	var slot:=int(guest.get("visit_slot",-1))
	var data:=spec(p)
	if slot<0 or slot>=data.dishes.size() or slot in p.visit.settled: return
	p.visit.settled.append(slot)
	if paid and (p.visit.kind=="critics" or guest.get("automatic_serving",false)):
		p.visit.paid=int(p.visit.paid)+1
		if grade in (["A","S"] if p.visit.kind=="critics" else ["B","A","S"]): p.visit.good=int(p.visit.good)+1
	p.revision+=1
	if p.visit.settled.size()>=data.dishes.size():
		finish(service,int(p.visit.paid)==data.dishes.size() and int(p.visit.good)>=int(data.good),"")
	else: service.game.save_cafe()

static func finish(service, won: bool, reason: String) -> void:
	var p=service.progress
	if not busy(p): return
	var data:=spec(p)
	p.visit.phase="won" if won else "lost"
	p.visit_next_day=p.day+2
	p.visit_next_kind="crew" if p.visit.kind=="critics" else "critics"
	if won:
		p.cash+=int(data.cash); p.popularity+=int(data.popularity)
	p.visit.result=("%s · +%d денег, +%d популярности"%[data.name,data.cash,data.popularity]) if won else ("%s Визит завершён: подано %d/%d, нужных оценок %d/%d. Обычная оплата блюд сохранена."%[reason,p.visit.paid,data.dishes.size(),p.visit.good,data.good])
	p.revision+=1
	# Freeze before closing unstarted orders so nested callbacks cannot settle twice.
	for guest in service.customers:
		if int(guest.get("visit_id",-1))==int(p.visit.id) and guest.state in ["queued","walking","waiting"]:
			service.finish_customer(int(guest.id),false)
	service.trace("visit_finished",{"id":p.visit.id,"kind":p.visit.kind,"won":won,"paid":p.visit.paid,"good":p.visit.good})
	service.announce(p.visit.result)
	service.game.save_cafe()

static func close_shift(service) -> void:
	var p=service.progress
	if p.visit.get("phase","")=="active": finish(service,false,"Смена закончена.")
	elif p.visit.get("phase","")=="scheduled":
		p.visit.start_day=maxi(p.day+1,int(p.visit.start_day))
		p.visit.preparation=PREPARATION

static func status(p) -> String:
	var phase:=str(p.visit.get("phase",""))
	if phase.is_empty(): return ""
	var data:=spec(p)
	if data.is_empty(): return ""
	match phase:
		"offered": return "По желанию: "+str(data.name)+" · предложение в компьютере"
		"scheduled":
			return str(data.name)+" · утром дня %d"%p.visit.start_day if int(p.visit.start_day)>p.day else str(data.name)+" · подготовка %d с"%ceili(float(p.visit.preparation))
		"active": return "%s · %d/%d подач · %s: %d/%d · %d:%02d"%[data.name,p.visit.paid,data.dishes.size(),data.grade,p.visit.good,data.good,ceili(float(p.visit.remaining))/60,ceili(float(p.visit.remaining))%60]
		"won","lost": return str(p.visit.result)
	return ""

static func badge(person: Node3D, kind: String) -> void:
	if kind.is_empty(): return
	var label: Label3D=person.get_node_or_null("VisitBadge")
	if label==null:
		label=Label3D.new(); label.name="VisitBadge"; person.add_child(label)
		label.position=Vector3(0,2.65,0); label.pixel_size=0.003; label.font_size=20
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate=Color("f2c477") if kind=="critics" else Color("a3d7c0")
	label.text="КРИТИК · A" if kind=="critics" else "ОБЕД МАСТЕРСКОЙ"
