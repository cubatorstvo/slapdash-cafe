extends RefCounted
## Derive the next useful action from shared cafe facts, including work done ahead of time.
const DISH_NAMES := {"sausage":"сосиска в соусе","potato":"картофель","wine":"вино","meal":"мясо с макаронами"}
const GEAR := {"sausage":["sauce","plates"],"potato":["pan","plates"],"wine":["jug","cup"],"meal":["meat_kit","pasta_kit"]}
const Catalogue=preload("res://scripts/cafe_catalogue.gd")
const GOODS := {"sauce":"миску соуса","plates":"тарелки","pan":"сковороду","jug":"кувшин","cup":"бокал","meat_kit":"комплект для мяса","pasta_kit":"комплект для макарон","lab_0":"лабораторную колбу","lab_1":"блок питания","lab_2":"стабилизатор","counter":"стол и шкафчик","kitchen":"парную кухню"}

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

static func grow(p, stations: Array) -> Dictionary:
	if not p.free_workers.is_empty() and stations.any(func(station):return not station.manual_station and crew_count(station)<station.role_count()):
		return step("worker_return","Работник возвращается к назначению","Свободный клон займёт вакансию после завершения рекалибровки. Можно заняться другими делами.","laboratory")
	if p.lab_formula_version<=0:
		if not p.lab_sample.is_empty():
			return step("microscope","Исследуй каплю в микроскопе","E — возьми образец со стола, затем E у микроскопа. Лучшая формула сохранится для следующих посадок.","sample" if int(p.lab_sample.get("carrier",0))==0 else "microscope")
		return step("formula","Создай первую формулу · 20","E у стола лаборатории. Держи уровень в зелёной области, затем останови стрелку. После первого входа падение ниже зелёной портит жидкость.","laboratory") if p.cash>=20 else step("formula_money","Заработай на эксперимент · %d/20"%p.cash,"Обслужи гостя шефом. Формула нужна для выращивания работников.","station",1)
	var candidate: Dictionary={}
	# A ready sprout/adult takes priority over starting another pot.
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
	# While growth runs, prepare a destination and its first inexpensive recipe.
	var destination
	for station in stations:
		if not station.manual_station and crew_count(station)<station.role_count(): destination=station; break
	if destination==null:
		for slot in [2,3]:
			if not stations.any(func(station):return station.station_id==slot):
				return buy(p,"counter",slot,"Пока клон растёт, подготовь его рабочее место.")
	else:
		var equipment:=equip(p,destination,"meal" if destination.type_id=="kitchen" else "sausage")
		if not equipment.is_empty(): return equipment
	return step("growing","Клон растёт · можно заняться кафе","Пока таймер идёт, обслуживай заказы или занимайся покупками. Готовый этап дождётся тебя без штрафа.","pot",0,id)

static func next_step(p, stations: Array, served: int, opened: bool) -> Dictionary:
	var personal
	var counters: Array=[]
	var kitchen
	for station in stations:
		if station.manual_station: personal=station
		elif station.type_id=="counter": counters.append(station)
		else: kitchen=station
	counters.sort_custom(func(a,b):return a.station_id<b.station_id)
	if p.stars==0:
		if not p.starter_reward:
			return step("first_guest","Обслужи первого гостя","E у личной стойки → приготовить заказ. B — книга; еду на поднос, E у звонка. Соус придёт в подарок.","station",1) if opened else step("open","Открой своё кафе","Подойди к компьютеру, нажми E и выбери «Открыть кафе». Первый гость познакомит с подачей.")
		if personal!=null:
			for dish in ["sausage","potato","wine"]:
				var equipment:=equip(p,personal,dish)
				if not equipment.is_empty(): return equipment
				if dish not in p.tutorial_served:
					return step("try_"+dish,"Освой блюдо: "+str(DISH_NAMES[dish]),"Обслужи настоящий заказ этим блюдом. Требования и управление — в книге B.","station",1)
		if p.lab_stage<3: return buy(p,"lab_%d"%p.lab_stage,0,"Собери три детали лаборатории; после первой звезды здесь появятся твои работники.")
		if p.manual_served<15: return step("practice","Подготовься к дегустации · %d/15 гостей"%p.manual_served,"Закрепи три блюда: дегустатор попросит каждое на B или лучше. Лаборатория уже собрана.","station",1)
		return step("first_star","Пригласи дегустатора","Компьютер → Звёзды. Три стандартных блюда на B. Неудачное блюдо можно повторить бесплатно.")
	if p.journey_auto_served<1:
		if worker_count(p,stations)==0: return grow(p,stations)
		if counters.is_empty(): return buy(p,"counter",2,"Это пустой стол: работник займёт его, а оборудование и запись ты подготовишь сам.")
		var first=counters[0]
		if crew_count(first)==0: return grow(p,stations)
		if not first.recipes.values().any(func(record):return record.get("quality",{}).get("present",false)):
			var dish: String=str(first.recipes.keys()[0]) if not first.recipes.is_empty() else "sausage"
			var equipment:=equip(p,first,dish)
			if not equipment.is_empty(): return equipment
			return teach(first,dish)
		return step("first_income","Дождись первого заработка клона","Открой кафе и заверши обучение. Клон повторит принятую запись, обслужит гостя и принесёт деньги; шеф свободен для других дел.","station",first.station_id)
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
			return teach(selected,dish,true)
		if p.popularity<30: return step("popularity","Подними популярность · %d/30"%p.popularity,"Выбери украшения: вывеска +10, гирлянда +15, зелёный уголок +20. Покупки — в компьютере.")
		if p.can_attempt(stations,served): return step("second_star","Пригласи делегацию второй звезды","Компьютер → Звёзды. За 4 минуты: 8 подач, 6 оценок B; три гостя заказывают лично шефу.")
		return step("ready_crews","Дождись готовности двух бригад","Заверши обучение или рекалибровку. Полный список условий — Компьютер → Звёзды.")
	if p.stars==2:
		if not p.expanded: return step("third_expand","Расширь зал для парной кухни · 180","Компьютер → Интернет-магазин → расширение. Третья звезда проверит уже не сам факт автоматизации, а мощность всего кафе.")
		if kitchen==null: return buy(p,"kitchen",4,"Парная кухня нужна как третья производственная линия перед Большим обедом.")
		if crew_count(kitchen)<kitchen.role_count(): return grow(p,stations)
		var kitchen_equipment:=equip(p,kitchen,"meal")
		if not kitchen_equipment.is_empty(): return kitchen_equipment
		var meal_report: Dictionary=kitchen.recipes.get("meal",{}).get("quality",{})
		if not meal_report.get("present",false) or not meal_report.get("grade","D") in ["B","A","S"]: return teach(kitchen,"meal",true)
		if p.journey_meals_served<1: return step("first_meal","Получи первый доход от парной кухни","Открой кафе: оба клона повторят совместный рецепт на реальном заказе.","station",kitchen.station_id)
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
	return step("complete","Третья звезда получена · этап масштабирования пройден","Кафе выдерживает плотный поток. Следующий крупный этап добавит специализированную кухню с взаимозависимыми ролями.")

static func current(p, stations: Array, served: int, opened: bool) -> Dictionary:
	var result:=next_step(p,stations,served,opened)
	result.chapter="ПЕРВАЯ ЗВЕЗДА" if p.stars==0 else "ПЕРВЫЙ ДОХОД КЛОНА" if p.journey_auto_served<1 else "ВТОРАЯ ЗВЕЗДА" if p.stars==1 else "ТРЕТЬЯ ЗВЕЗДА · МАСШТАБ" if p.stars==2 else "МАСШТАБИРОВАНИЕ ПРОЙДЕНО"
	if p.busy():
		var inspection_title: String
		var inspection_detail: String
		if p.phase=="tasting":
			inspection_title="Дегустация · %d/3"%mini(3,p.tasting_done.size()+1)
			inspection_detail="Приготовь каждое блюдо на B или лучше. Неудачное можно повторить."
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
			result.detail=("Большой обед" if p.stars==2 else "Делегация")+" начнётся после освобождения станций."
	elif p.shift not in ["night","closing"] and result.key in ["first_star","second_star","third_star"] and p.visit.get("phase","") in ["scheduled","active"]:
		result.title="К проверке на звезду всё готово"
		result.detail="Сначала заверши или отмени добровольный визит в компьютере, затем пригласи проверку."
	elif p.shift in ["night","closing"]:
		result.detail="После отдыха: "+result.title+". "+result.detail
		result.title="Смена завершена · всем в Шеф-кровать" if p.shift=="night" else "Завершаем последние заказы"
		result.place="bed" if p.shift=="night" else ""
	elif not opened and result.place=="station" and result.key not in ["first_guest"] and not result.key.begins_with("teach_"):
		result.detail="Сначала открой кафе у компьютера. "+result.detail
		result.place="computer"
	return result
