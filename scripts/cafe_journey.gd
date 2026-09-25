extends RefCounted
## Derive the next useful action from shared cafe facts, including work done ahead of time.
const DISH_NAMES := {"sausage":"сосиска в соусе","potato":"картофель","wine":"вино","meal":"мясо с макаронами","burger":"бургер","cheeseburger":"чизбургер","spicy_burger":"острый бургер","solyanka":"солянка"}
const GEAR := {"sausage":["sauce","plates"],"potato":["pan","plates"],"wine":["jug","cup"],"meal":["meat_kit","pasta_kit"],"burger":["grill_kit","assembly_kit"],"cheeseburger":["grill_kit","assembly_kit"],"spicy_burger":["grill_kit","assembly_kit"],"solyanka":["fire_kit","stir_kit","salt_kit"]}
const Catalogue=preload("res://scripts/cafe_catalogue.gd")
const Lounge=preload("res://scripts/lounge_progression.gd")
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
const GOODS := {"sauce":"миску соуса","plates":"тарелки","pan":"сковороду","jug":"кувшин","cup":"бокал","meat_kit":"комплект для мяса","pasta_kit":"комплект для макарон","lab_0":"лабораторную колбу","lab_1":"блок питания","lab_2":"стабилизатор","counter":"стол и шкафчик","kitchen":"парную кухню","grill_kit":"общую жарочную поверхность","assembly_kit":"комплект сборки","grill_kitchen":"бургерную кухню","fire_kit":"набор огня и овощей","stir_kit":"мешалку и овощи","salt_kit":"соль и овощи","solyanka_kitchen":"кухню «Солянка»"}

static func step(key: String, title: String, detail: String, place := "computer", station := 0, pot := -1) -> Dictionary:
	return {"key":key,"title":title,"detail":detail,"place":place,"station":station,"pot":pot,"item":"","chapter":""}

static func pending(p, item: String, station: int) -> Dictionary:
	for parcel in p.deliveries:
		if int(parcel.station)==station and item in parcel.get("items",[parcel.item]): return parcel
	return {}

static func buy(p, item: String, station: int, reason: String) -> Dictionary:
	var spec: Dictionary=Catalogue.ITEMS[item]
	var title: String=GOODS[item]
	var parcel:=pending(p,item,station)
	var result: Dictionary
	if not parcel.is_empty():
		result=step("delivery_"+item,"Установи "+title,"Доставка в пути; коробка появится у входа." if float(parcel.remaining)>0 else "Забери коробку у входа и поднеси к отмеченному месту. "+reason,"delivery",station)
	elif p.cash<int(spec.price):
		result=step("earn_"+item,"Накопи на "+title+" · %d/%d"%[p.cash,spec.price],"Обслуживай гостей шефом. "+reason,"station",1)
	else:
		result=step("buy_"+item,"Закажи "+title+" · %d"%spec.price,"Компьютер → Интернет-магазин. "+reason,"computer",station)
	result.item=item
	return result

static func crew_count(station) -> int:
	return station.role_count() if station.staffed<0 else station.staffed

static func worker_count(p, stations: Array) -> int:
	var count: int=p.free_workers.size()
	for station in stations:
		if not station.manual_station: count+=crew_count(station)
	return count

static func equipped(station, dish: String) -> bool:
	for item in GEAR[dish]:
		if item not in station.equipment: return false
	return true

static func equip(p, station, dish: String) -> Dictionary:
	for item in GEAR[dish]:
		if item not in station.equipment:
			return buy(p,item,station.station_id,"Это оборудование нужно для блюда на станции %d."%station.station_id)
	return {}

static func teach(station, dish: String, quality := false) -> Dictionary:
	var detail: String="E у станции → выбери блюдо → «Обучить здесь» → назначь себя роли → начни показ."
	var title: String=("Улучши запись до B: " if quality else "Обучи клона: ")+str(DISH_NAMES[dish])
	var run=station.training
	if run.active() and run.purpose=="lesson":
		match str(run.phase):
			"recording","confirm_finish":
				title="Заверши показ блюда"
				detail="Приготовь блюдо по книге B, положи на подачу и нажми E у звонка. Сохраняется весь твой показ."
			"review":
				title="Сохрани удачный показ"
				detail="E у станции → «Сохранить показ». Затем прими всё блюдо, чтобы клон начал выполнять заказы."
			"ready":
				var lengths: Array=station.remote_summary.get("lengths",[]) if not station.remote_summary.is_empty() else run.summary().lengths
				if not lengths.is_empty() and lengths.all(func(length):return int(length)>0):
					title="Прими запись для бригады"
					detail="E у станции → «Обучить бригаду · вернуться к заказам». Сохранённый черновик ещё нужно принять."
	return step("teach_%d_%s"%[station.station_id,dish],title,detail,"station",station.station_id)

static func suitable_masterclass(service, dish: String, quality := false) -> Dictionary:
	if service==null: return {}
	var candidates: Array=[]
	for record in service.masterclasses:
		if str(record.get("dish",""))!=dish: continue
		if bool(record.get("archived",false)): continue
		var report: Dictionary=record.get("quality",{})
		if quality and str(report.get("grade","D")) not in ["B","A","S"]: continue
		candidates.append(record)
	if candidates.is_empty(): return {}
	candidates.sort_custom(func(a,b):return float(a.get("duration",99999.0))<float(b.get("duration",99999.0)))
	return candidates[0]

static func television_step(p) -> Dictionary:
	for parcel in p.deliveries:
		if "rest_television" in parcel.get("items",[parcel.item]):
			return step("delivery_tv","Установи телевизор для обучения","Телевизор уже заказан. Дождись доставки и установи его в комнате отдыха; фильмы мастер-классов показываются именно там.","delivery")
	var price: int=int(Lounge.GOODS.television.price)
	if p.cash<price: return step("earn_tv","Накопи на телевизор · %d/%d"%[p.cash,price],"Телевизор нужен сотрудникам для просмотра хайлайтов мастер-класса. Пока обслуживай гостей шефом.","station",1)
	var result:=step("buy_tv","Установи телевизор для обучения · %d"%price,"Компьютер → Комната отдыха → Телевизор. После доставки установи коробку в существующей комнате отдыха.","computer")
	result.item="rest_television"
	return result

static func live_training_step(p, station, dish: String, quality: bool, service) -> Dictionary:
	if service==null: return teach(station,dish,quality)
	var existing: Dictionary=station.recipes.get(dish,{})
	var report: Dictionary=existing.get("quality",{})
	if report.get("present",false) and (not quality or str(report.get("grade","D")) in ["B","A","S"]): return {}
	if is_instance_valid(service.live_training) and service.live_training.is_active():
		var session=service.live_training
		var phase_text: String={"draining":"заканчивает принятый заказ","walking":"идёт к Шефу","ready":"уже на месте","demonstrating":"смотрит показ","returning":"возвращается"}.get(str(session.phase),str(session.phase))
		return step("live_lesson_wait_"+dish,"Личный урок: "+phase_text,"Ученик физически участвует в уроке. Если он уйдёт до принятия результата, прежний навык сохранится.","station",1)
	var clone_id:=0
	var clone_name:="клона"
	var roles: int=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())
	if roles>0:
		clone_id=int(station.crew[0].get("clone_id",0))
		clone_name=str(station.crew[0].get("name","клона"))
	var quality_text:=" на B или лучше" if quality else ""
	return step("live_lesson_"+dish,"Позови на урок: "+str(DISH_NAMES[dish]),"E у шеф-станции → «Позвать на урок» → %s. Дождись его прихода, покажи блюдо%s и прими результат. Фильм и телевизор для этого не нужны."%[clone_name,quality_text],"station",1)

static func masterclass_training_step(p, station, dish: String, quality: bool, service) -> Dictionary:
	if service==null: return teach(station,dish,quality)
	if p.stars<2: return live_training_step(p,station,dish,quality,service)
	var existing: Dictionary=station.recipes.get(dish,{})
	var report: Dictionary=existing.get("quality",{})
	if report.get("present",false) and (not quality or str(report.get("grade","D")) in ["B","A","S"]): return {}
	if service.masterclass_locked() and service.masterclass_active():
		return step("masterclass_live_"+dish,"Заверши мастер-класс: "+str(DISH_NAMES[dish]),"На шеф-станции идёт мастер-класс. Заверши принятое приготовление и сохрани запись в видеотеку.","station",1)
	var record: Dictionary=suitable_masterclass(service,dish,quality)
	if record.is_empty():
		var quality_text: String=" на B или лучше" if quality else ""
		return step("masterclass_"+dish,"Проведи мастер-класс: "+str(DISH_NAMES[dish]),"E у шеф-станции → МАСТЕР-КЛАСС → выбери блюдо. Приготовь%s и сохрани запись: она появится в общей видеотеке."%quality_text,"station",1)
	if "television" not in p.lounge_items: return television_step(p)
	if is_instance_valid(service.staff_training) and service.staff_training.targets_station(station.station_id,dish):
		return step("training_"+dish,"Дождись окончания обучения","Сотрудники закончат текущий заказ, соберутся у телевизора с блокнотами, посмотрят хайлайты и вернутся к столу.","television",station.station_id)
	var compatible: Array=service.compatible_training_station_ids(int(record.id))
	var mass: bool=compatible.size()>1
	var detail: String="Компьютер → Столы и обучение → выбери стол %d → «Обучение» → добавь «%s» в очередь."%[station.station_id,str(record.get("name","Запись"))]
	if mass: detail+=" Можно выбрать сразу несколько столов одного типа: все они уйдут на один общий просмотр."
	return step("assign_masterclass_"+dish,"Назначь запись столу: "+str(DISH_NAMES[dish]),detail,"computer",station.station_id)

static func _post_star_intro_record(service, stations: Array) -> Dictionary:
	if service==null: return {}
	for record in service.masterclasses:
		var source_type: String=str(record.get("source_type",""))
		var dish: String=str(record.get("dish",""))
		for station in stations:
			if station.manual_station or station.masterclass_station: continue
			if str(station.type_id)==source_type and dish in station.dishes(): return record
	return {}

static func _course_has_targets(course: Dictionary)->bool:
	for assignment in course.get("assignments",[]):
		if assignment is Dictionary and not assignment.get("station_ids",[]).is_empty(): return true
	return false

static func _first_course_target(service)->Dictionary:
	if service==null or not is_instance_valid(service.training_queue): return {}
	for course in service.training_queue.courses:
		if not _course_has_targets(course): continue
		for assignment in course.get("assignments",[]):
			if not assignment is Dictionary: continue
			var record_id: int=int(assignment.get("record_id",0))
			var dish: String=str(assignment.get("dish",""))
			for raw_id in assignment.get("station_ids",[]):
				var station_id: int=int(raw_id)
				var station=service.by_id(station_id)
				if station==null: continue
				return {"course_id":int(course.get("id",0)),"station_id":station_id,"record_id":record_id,"dish":dish,"state":str(course.get("state",""))}
	return {}

static func _course_target_learned(service, target: Dictionary)->bool:
	if service==null or target.is_empty(): return false
	var station=service.by_id(int(target.get("station_id",0)))
	if station==null: return false
	var dish: String=str(target.get("dish",""))
	var record_id: int=int(target.get("record_id",0))
	return station.recipes.has(dish) and int(station.method_sources.get(dish,{}).get("id",0))==record_id

static func _post_star_training_intro(p, stations: Array, service) -> Dictionary:
	if p.stars<2 or service==null: return {}
	if service.masterclasses.is_empty():
		return step("training_intro_masterclass","1/5 · Сними первый мастер-класс","Подойди к шеф-станции → E → МАСТЕР-КЛАСС. Приготовь блюдо и сохрани принятую запись в видеотеку.","station",1)
	if "television" not in p.lounge_items:
		var tv:=television_step(p)
		tv.key="training_intro_tv"
		tv.title="2/5 · "+str(tv.title)
		return tv
	var production: Array=[]
	for station in stations:
		if not station.manual_station and not station.masterclass_station: production.append(station)
	if production.is_empty(): return {}
	var record: Dictionary=_post_star_intro_record(service,stations)
	if record.is_empty():
		return step("training_intro_matching_masterclass","1/5 · Сними мастер-класс для производственного стола","Для установленной кухни пока нет совместимой записи. Подойди к шеф-станции и сохрани мастер-класс блюда этого типа.","station",1)
	var target: Dictionary=_first_course_target(service)
	if target.is_empty():
		var compatible: Array=service.compatible_training_station_ids(int(record.get("id",0)))
		var station_id: int=int(compatible[0]) if not compatible.is_empty() else int(production[0].station_id)
		return step("training_intro_course","3/5 · Добавь первое обучение","Открой компьютер → «Столы и обучение» → выбери столы → «Обучение». Добавь «%s» в очередь."%str(record.get("name","Запись")),"station",station_id)
	if not _course_target_learned(service,target):
		var station_id: int=int(target.get("station_id",0))
		var status: String=service.training_queue.station_status(station_id,str(target.get("dish","")))
		var suffix: String=" Сейчас: "+status+"." if not status.is_empty() else ""
		return step("training_intro_wait","4/5 · Дождись окончания обучения","Блюдо уже в очереди. Выбранные сотрудники закончат принятые заказы, вместе дойдут до телевизора, посмотрят фильм и вернутся к столам."+suffix,"television",station_id)
	if p.journey_auto_served<1:
		return step("training_intro_first_work","4/5 · Увидь обученную бригаду в работе","Дождись реального заказа этого стола. Добавление блюда в очередь само по себе не считается обучением: нужен завершённый просмотр и фактическая работа бригады.","station",int(target.get("station_id",0)))
	if not bool(p.training_intro_mass_seen):
		var type_id: String=str(record.get("source_type",""))
		var compatible_count:=0
		var first_id:=0
		for station in stations:
			if station.manual_station or station.masterclass_station or str(station.type_id)!=type_id: continue
			compatible_count+=1
			if first_id==0: first_id=int(station.station_id)
		if compatible_count>=2:
			return step("training_intro_mass","5/5 · Назначь обучение нескольким столам","В компьютере выбери несколько столов одного типа или целую группу и добавь блюдо в очередь. Все выбранные столы уйдут на один общий просмотр.","station",first_id)
	return {}

static func grow(p, stations: Array) -> Dictionary:
	if not p.free_workers.is_empty() and stations.any(func(station):return not station.manual_station and crew_count(station)<station.role_count()):
		return step("worker_return","Работник возвращается к назначению","Свободный клон займёт вакансию после завершения рекалибровки. Можно заняться другими делами.","laboratory")
	if p.lab_formula_version<=0:
		if not p.lab_sample.is_empty():
			return step("microscope","Исследуй каплю в микроскопе","E — возьми образец со стола, затем E у микроскопа. Лучшая формула сохранится для следующих посадок.","sample" if int(p.lab_sample.get("carrier",0))==0 else "microscope")
		return step("formula","Создай первую формулу · 20","E у стола лаборатории. Держи уровень в зелёной области, затем останови стрелку. После первого входа падение ниже зелёной портит жидкость.","laboratory") if p.cash>=20 else step("formula_money","Заработай на эксперимент · %d/20"%p.cash,"Обслужи гостя шефом. Формула нужна для выращивания работников.","station",1)
	var candidate: Dictionary={}
	for value in p.lab_pots:
		if value.phase in ["feed","ready"]: candidate=value; break
	if candidate.is_empty():
		for value in p.lab_pots:
			if value.phase!="empty": candidate=value; break
	if candidate.is_empty(): return step("soil","Насыпь землю в горшок","Возьми совок с полки инструментов через E и нажми E у пустого горшка.","pot",0,0)
	var id:=int(candidate.id)
	match str(candidate.phase):
		"soil":
			return step("seed","Добавь рабочую формулу · 60","Возьми пипетку с полки и добавь каплю. Посадка запомнит текущую формулу.","pot",0,id) if p.cash>=60 else step("seed_money","Накопи на посадку · %d/60"%p.cash,"Обслуживай гостей. Земля в горшке спокойно подождёт.","station",1)
		"seeded": return step("water","Полей будущего клона","Возьми лейку с полки и полей горшок через E. Начнётся прорастание.","pot",0,id)
		"feed": return step("feed","Покорми проросток","Возьми удобрение с полки. E у горшка — клон поймает его ртом и продолжит расти.","pot",0,id)
		"ready": return step("harvest","Вытащи выросшего клона","Освободи руки, наведи взгляд на голову, плечо или подмышки. Держи E / ЛКМ и тяни назад.","pot",0,id)
	var destination
	for station in stations:
		if not station.manual_station and crew_count(station)<station.role_count(): destination=station; break
	if destination==null:
		for slot in [2,3]:
			if not stations.any(func(station):return station.station_id==slot):
				return buy(p,"counter",slot,"Пока клон растёт, подготовь его рабочее место.")
	else:
		var equipment:=equip(p,destination,"meal" if destination.type_id=="kitchen" else "burger" if destination.type_id=="grill_kitchen" else "solyanka" if destination.type_id=="solyanka_kitchen" else "sausage")
		if not equipment.is_empty(): return equipment
	return step("growing","Клон растёт · можно заняться кафе","Пока таймер идёт, обслуживай заказы или занимайся покупками. Готовый этап дождётся тебя без штрафа.","pot",0,id)

static func next_step(p, stations: Array, served: int, opened: bool, service=null) -> Dictionary:
	var personal
	var counters: Array=[]
	var kitchen
	var specialty
	var solyanka
	for station in stations:
		if station.manual_station: personal=station
		elif station.type_id=="counter": counters.append(station)
		elif station.type_id=="kitchen": kitchen=station
		elif station.type_id=="grill_kitchen": specialty=station
		elif station.type_id=="solyanka_kitchen": solyanka=station
	counters.sort_custom(func(a,b):return a.station_id<b.station_id)
	if p.stars==0:
		if not p.cafe_inaugurated:
			return step("inaugurate","Перережь ленточку и открой кафе","Подойди ко входу и нажми E у ленточки. До открытия можно спокойно осмотреть кафе.","")
		if p.inauguration_first_service_pending or not p.starter_reward:
			return step("first_guest","Обслужи первого гостя","Первый гость идёт к стойке №1. Приготовь картофель: B — книга; готовое положи на поднос и нажми E у звонка. После подачи придёт соус.","station",1)
		if personal!=null:
			for dish in ["sausage","potato","wine"]:
				var equipment:=equip(p,personal,dish)
				if not equipment.is_empty(): return equipment
				if dish not in p.tutorial_served:
					return step("try_"+dish,"Освой блюдо: "+str(DISH_NAMES[dish]),"Обслужи настоящий заказ этим блюдом. Требования и управление — в книге B.","station",1)
		if p.lab_stage<3: return buy(p,"lab_%d"%p.lab_stage,0,"Собери три детали лаборатории; после первой звезды здесь появятся твои работники.")
		if p.manual_served<15: return step("practice","Подготовься к дегустации · %d/15 гостей"%p.manual_served,"Закрепи три блюда: дегустатор попросит каждое на B или лучше. Лаборатория уже собрана.","station",1)
		return step("first_star","Пригласи дегустатора","Компьютер → Звёзды. Три стандартных блюда на B. Неудачное блюдо можно повторить бесплатно.")
	var training_intro: Dictionary=_post_star_training_intro(p,stations,service)
	if not training_intro.is_empty(): return training_intro
	if p.journey_auto_served<1:
		if worker_count(p,stations)==0: return grow(p,stations)
		if counters.is_empty(): return buy(p,"counter",2,"Это пустой стол: работник займёт его, а оборудование и запись ты подготовишь сам.")
		var first=counters[0]
		if crew_count(first)==0: return grow(p,stations)
		if not first.recipes.values().any(func(record):return record.get("quality",{}).get("present",false)):
			var dish: String=str(first.recipes.keys()[0]) if not first.recipes.is_empty() else "sausage"
			var equipment:=equip(p,first,dish)
			if not equipment.is_empty(): return equipment
			return masterclass_training_step(p,first,dish,false,service)
		return step("first_income","Дождись первого заработка клона","Заверши обучение и дождись реального заказа. Клон повторит принятую запись, обслужит гостя и принесёт деньги; шеф свободен для других дел.","station",first.station_id)
	if p.stars==1:
		if counters.size()<2:
			var missing:=2 if not counters.any(func(station):return station.station_id==2) else 3
			return buy(p,"counter",missing,"Для делегации нужны две укомплектованные бригады.")
		for station in counters:
			if crew_count(station)<station.role_count(): return grow(p,stations)
		for dish in ["sausage","potato","wine"]:
			var learned:=false
			for station in counters:
				var report: Dictionary=station.recipes.get(dish,{}).get("quality",{})
				if report.get("present",false) and report.get("grade","D") in ["B","A","S"]: learned=true
			if learned: continue
			var selected=counters[0]
			for station in counters:
				if equipped(station,dish): selected=station; break
				if station.recipes.size()<selected.recipes.size(): selected=station
			var equipment:=equip(p,selected,dish)
			if not equipment.is_empty(): return equipment
			return masterclass_training_step(p,selected,dish,true,service)
		if p.popularity<30: return step("popularity","Подними популярность · %d/30"%p.popularity,"Выбери украшения: вывеска +10, гирлянда +15, зелёный уголок +20. Покупки — в компьютере.")
		if p.can_attempt(stations,served): return step("second_star","Пригласи делегацию второй звезды","Компьютер → Звёзды. За 4 минуты: 8 подач, 6 оценок B; три гостя заказывают лично шефу.")
		return step("ready_crews","Дождись готовности двух бригад","Заверши обучение или рекалибровку. Полный список условий — Компьютер → Звёзды.")
	if p.stars==2:
		if not p.expanded: return step("third_expand","Расширь зал для парной кухни · 180","Компьютер → Интернет-магазин → расширение. Дальше одинаковые столы удобно собирать в группы и покупать комплектами; оснащение уже работающих столов клоны с удовольствием установят сами. Третья звезда проверит мощность всего кафе.")
		if kitchen==null: return buy(p,"kitchen",4,"Парная кухня нужна как третья производственная линия перед Большим обедом.")
		if crew_count(kitchen)<kitchen.role_count(): return grow(p,stations)
		var kitchen_equipment:=equip(p,kitchen,"meal")
		if not kitchen_equipment.is_empty(): return kitchen_equipment
		var meal_report: Dictionary=kitchen.recipes.get("meal",{}).get("quality",{})
		if not meal_report.get("present",false) or not meal_report.get("grade","D") in ["B","A","S"]: return masterclass_training_step(p,kitchen,"meal",true,service)
		if p.journey_meals_served<1: return step("first_meal","Получи первый доход от парной кухни","Дождись реального заказа: оба клона должны повторить совместный рецепт.","station",kitchen.station_id)
		for station in counters:
			if crew_count(station)<station.role_count(): return grow(p,stations)
		for dish in ["sausage","potato","wine"]:
			var ready:=false
			for station in counters:
				var report: Dictionary=station.recipes.get(dish,{}).get("quality",{})
				if report.get("present",false) and report.get("grade","D") in ["B","A","S"]: ready=true
			if not ready:
				var selected=counters[0]
				for station in counters:
					if equipped(station,dish): selected=station; break
				return teach(selected,dish,true)
		if p.journey_meals_served<p.THIRD_STAR_MEALS:
			return step("meal_capacity","Дай парной кухне поработать · %d/%d"%[p.journey_meals_served,p.THIRD_STAR_MEALS],"Пусть новая бригада несколько раз выполнит реальный заказ. Это покажет, что двухролевой процесс стабильно работает.","station",kitchen.station_id)
		if p.third_star_auto_served<p.THIRD_STAR_AUTO_SERVED:
			return step("scale_service","Проверь мощность кафе · %d/%d автоподач"%[p.third_star_auto_served,p.THIRD_STAR_AUTO_SERVED],"Оставь кафе работать и наблюдай за узкими местами. Если поток копится, можно сократить запись, улучшить темп клонов или отдых — конкретный способ не обязателен.","station",kitchen.station_id)
		if p.popularity<p.THIRD_STAR_POPULARITY:
			return step("third_popularity","Подними популярность · %d/%d"%[p.popularity,p.THIRD_STAR_POPULARITY],"Большому обеду нужен заметный поток. Украшения и добровольные визиты повышают популярность; выбери удобный путь.")
		if p.can_attempt(stations,served): return step("third_star","Пригласи гостей на Большой обед","Компьютер → Звёзды. За 4 минуты придут 14 гостей: нужно 11 подач и 8 оценок B или выше. Три заказа остаются за шефом.")
		return step("third_ready","Подготовь три производственные линии","Заверши обучение или рекалибровку. Компьютер → Звёзды показывает, чего не хватает перед Большим обедом.")
	if p.stars==3:
		if not p.specialized_expanded: return step("specialty_expand","Открой специализированный сектор · %d"%p.SPECIALTY_EXPANSION_PRICE,"Компьютер → Интернет-магазин. Новый сектор добавляет пятую станцию в глубине зала и открывает взаимозависимую кухню.")
		if specialty==null: return buy(p,"grill_kitchen",5,"Это первая кухня, где обе роли делят один физический ресурс — жарочную поверхность.")
		if crew_count(specialty)<specialty.role_count(): return grow(p,stations)
		var burger_gear:=equip(p,specialty,"burger")
		if not burger_gear.is_empty(): return burger_gear
		for dish in p.SPECIALTY_DISHES:
			var report:Dictionary=specialty.recipes.get(dish,{}).get("quality",{})
			if not report.get("present",false) or not report.get("grade","D") in ["B","A","S"]: return masterclass_training_step(p,specialty,dish,true,service)
		if p.fourth_star_specialty_served<1: return step("first_specialty","Проверь общую плиту на реальном заказе","Дождись заказа бургерной. Запись должна пережить настоящий заказ: котлета и булка не должны одновременно блокировать общую поверхность.","station",specialty.station_id)
		if p.fourth_star_specialty_served<p.FOURTH_STAR_SPECIALTY_SERVED: return step("specialty_capacity","Дай бургерной поработать · %d/%d"%[p.fourth_star_specialty_served,p.FOURTH_STAR_SPECIALTY_SERVED],"Наблюдай, где запись ждёт общую плиту. При необходимости перезапиши одну роль, сохранив тайминг другой.","station",specialty.station_id)
		if p.fourth_star_auto_served<p.FOURTH_STAR_AUTO_SERVED: return step("specialty_scale","Проверь весь зал · %d/%d автоподач"%[p.fourth_star_auto_served,p.FOURTH_STAR_AUTO_SERVED],"Четвёртая звезда проверяет не одну кухню, а способность старых и новых линий переживать смену профиля спроса.","station",specialty.station_id)
		if p.popularity<p.FOURTH_STAR_POPULARITY: return step("fourth_popularity","Подними популярность · %d/%d"%[p.popularity,p.FOURTH_STAR_POPULARITY],"Для трёх волн нужен более заметный поток. Подойдут обустройство и добровольные визиты.")
		if p.can_attempt(stations,served): return step("fourth_star","Начни испытание «Три волны»","Компьютер → Звёзды. Смешанный поток сменится бургерным пиком, затем придёт общий финал: 18 гостей, 15 подач, 11 B+.")
		return step("fourth_ready","Подготовь специализированную линию","Заверши обучение или рекалибровку. Полный список условий — Компьютер → Звёзды.")
	if p.stars==4:
		if not p.orchestration_expanded: return step("orchestration_expand","Открой сектор оркестрации · %d"%p.ORCHESTRATION_EXPANSION_PRICE,"Компьютер → Интернет-магазин. Здесь появится шестая станция на три роли.")
		if solyanka==null: return buy(p,"solyanka_kitchen",6,"Солянка — первая кухня на три одновременные записи: огонь, мешалка и соль работают вокруг одного котла.")
		if crew_count(solyanka)<solyanka.role_count(): return grow(p,stations)
		var solyanka_gear:=equip(p,solyanka,"solyanka")
		if not solyanka_gear.is_empty(): return solyanka_gear
		var report:Dictionary=solyanka.recipes.get("solyanka",{}).get("quality",{})
		if not report.get("present",false) or not report.get("grade","D") in ["B","A","S"]: return masterclass_training_step(p,solyanka,"solyanka",true,service)
		if p.fifth_star_solyanka_served<p.FIFTH_STAR_SOLYANKA_SERVED: return step("solyanka_capacity","Накидай солянку гостям · %d/%d"%[p.fifth_star_solyanka_served,p.FIFTH_STAR_SOLYANKA_SERVED],"Дождись заказов солянки. Три клона одновременно повторяют свои записи; следи, чтобы котёл получил минимум 13 вещей, огонь, соль и перемешивание.","station",solyanka.station_id)
		if p.fifth_star_auto_served<p.FIFTH_STAR_AUTO_SERVED: return step("orchestration_scale","Дай всему кафе поработать · %d/%d автоподач"%[p.fifth_star_auto_served,p.FIFTH_STAR_AUTO_SERVED],"Подготовка к финалу проверяет, что трёхролевая кухня не вытеснила старые производственные линии.","station",solyanka.station_id)
		if p.can_attempt(stations,served): return step("fifth_star","Начни «День пяти звёзд»","Компьютер → Звёзды. Финальная смена идёт тремя фазами: общий наплыв → критики → общая кульминация. Провал можно повторить бесплатно.","computer")
		return step("fifth_ready","Подготовь кафе к финальной смене","Полный список условий перед Днём пяти звёзд — Компьютер → Звёзды.","computer")
	return step("complete","Пять звёзд получены","Кафе завершило основную кампанию.")

static func current(p, stations: Array, served: int, opened: bool, service=null) -> Dictionary:
	var result:=next_step(p,stations,served,opened,service)
	result.chapter="ВИДЕООБУЧЕНИЕ · 2★" if str(result.get("key","")).begins_with("training_intro_") else "ПЕРВАЯ ЗВЕЗДА" if p.stars==0 else "ПЕРВЫЙ ДОХОД КЛОНА" if p.journey_auto_served<1 else "ВТОРАЯ ЗВЕЗДА" if p.stars==1 else "ТРЕТЬЯ ЗВЕЗДА · МАСШТАБ" if p.stars==2 else "ЧЕТВЁРТАЯ ЗВЕЗДА · СПЕЦИАЛИЗАЦИЯ" if p.stars==3 else "ПЯТАЯ ЗВЕЗДА · ОРКЕСТРАЦИЯ" if p.stars==4 else "КАФЕ · 5★"
	if p.busy():
		var inspection_title: String
		var inspection_detail: String
		if p.phase=="tasting":
			inspection_title="Дегустация · %d/3"%mini(3,p.tasting_done.size()+1)
			inspection_detail="Приготовь каждое блюдо на B или лучше. Неудачное можно повторить."
		elif p.stars==4:
			inspection_title="День пяти звёзд · %s · %d/%d подач · %d/%d B+"%[p.inspection_phase_name(),p.banquet_served,p.inspection_served_target(),p.banquet_good,p.inspection_good_target()]
			inspection_detail=p.inspection_phase_detail()
		elif p.stars==3:
			inspection_title="Три волны · %d/%d подач · %d/%d B+"%[p.banquet_served,p.inspection_served_target(),p.banquet_good,p.inspection_good_target()]
			inspection_detail="Смешанный поток → бургерный пик → общий финал. Следи, чтобы общая жарочная не простаивала в конфликте."
		elif p.stars==2:
			inspection_title="Большой обед · %d/%d подач · %d/%d B+"%[p.banquet_served,p.inspection_served_target(),p.banquet_good,p.inspection_good_target()]
			inspection_detail="Три личных заказа остаются за шефом. Остальной поток должен выдержать автоматизированный зал."
		else:
			inspection_title="Делегация · %d/%d подач · %d/%d довольны"%[p.banquet_served,p.inspection_served_target(),p.banquet_good,p.inspection_good_target()]
			inspection_detail="Шеф обслуживает личные заказы, бригады повторяют записи. Следи за общим временем."
		result=step("inspection",inspection_title,inspection_detail,"station",1)
		result.chapter="ПРОВЕРКА НА ЗВЕЗДУ"
		if p.phase=="preparing":
			result.title="Завершаем заказы перед проверкой"
			result.detail=p.inspection_name()+" начнётся после освобождения станций."
	elif p.shift not in ["night","closing"] and result.key in ["first_star","second_star","third_star","fourth_star","fifth_star"] and p.visit.get("phase","") in ["scheduled","active"]:
		result.title="К проверке на звезду всё готово"
		result.detail="Сначала заверши или отмени добровольный визит в компьютере, затем пригласи проверку."
	elif p.shift in ["night","closing"]:
		result.detail="После отдыха: "+result.title+". "+result.detail
		var night_bed := "ляг в спальный мешок за стойкой" if Expansion.stage_for_progress(p)<2 else "всем в Шеф-кровать"
		result.title=("Смена завершена · "+night_bed) if p.shift=="night" else "Завершаем последние заказы"
		result.place="bed" if p.shift=="night" else ""
	elif not opened and not p.cafe_inaugurated:
		result.detail="Сначала перережь ленточку у входа. "+result.detail
		result.place=""
	return result
