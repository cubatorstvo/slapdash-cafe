extends "res://scripts/cafe_journey_legacy.gd"
## Stage 5.1 owns the zero-star route; stage 5.2 owns the 1★ first-clone chapter.
const STARTER_SEQUENCE := ["sausage", "potato", "wine"]

static func _p5_milestone(p, id: String) -> bool:
	var snapshot: Variant = p.get("feature_progress")
	if not snapshot is Dictionary: return false
	var milestones: Variant = snapshot.get("milestones", {})
	return milestones is Dictionary and milestones.has(id)

static func _p5_counters(stations: Array) -> Array:
	var result: Array=[]
	for station in stations:
		if not station.manual_station and not station.masterclass_station and station.type_id=="counter": result.append(station)
	result.sort_custom(func(a,b): return a.station_id < b.station_id)
	return result

static func _p5_current_b_plus(station, dish: String) -> bool:
	if station==null or not station.ready_crew() or not station.recipes.has(dish) or not station.missing_recipe_equipment(dish).is_empty(): return false
	var source: Dictionary=station.method_sources.get(dish,{}) if station.method_sources.get(dish,{}) is Dictionary else {}
	var clone_ids: Variant=source.get("clone_ids",[])
	if not clone_ids is Array or clone_ids.size()!=station.role_count(): return false
	for role in range(station.role_count()):
		if role>=station.crew.size() or int(station.crew[role].get("clone_id",0))<=0 or int(clone_ids[role])!=int(station.crew[role].get("clone_id",0)): return false
	var report: Dictionary=station.recipes.get(dish,{}).get("quality",{})
	return bool(report.get("present",false)) and str(report.get("grade","D")) in ["B","A","S"]

static func _p5_first_clones_step(p, stations: Array, served: int, service) -> Dictionary:
	if p.lab_stage<3:
		return buy(p,"lab_%d"%p.lab_stage,0,"Собери базовую лабораторию по порядку. Следующая обязательная часть появится после установки этой.")
	if p.lab_formula_version<=0:
		return step("standard_formula","Получи стандартную формулу · 100%","После сборки лаборатории базовая формула выдаётся автоматически. Микроскоп и улучшение формулы понадобятся только позже.","laboratory")
	var counters:=_p5_counters(stations)
	var workers:=worker_count(p,stations)
	if p.journey_auto_served<1:
		if workers==0: return grow(p,stations)
		if counters.is_empty(): return buy(p,"counter",2,"Первый клон уже есть. Подготовь ему один производственный стол; для первой автоподачи достаточно одного блюда.")
		var first=counters[0]
		if crew_count(first)<first.role_count(): return grow(p,stations)
		var first_equipment:=equip(p,first,"sausage")
		if not first_equipment.is_empty(): return first_equipment
		if not first.recipes.has("sausage"):
			return masterclass_training_step(p,first,"sausage",false,service)
		return step("first_income","Дождись первой самостоятельной подачи","Нужен реальный успешно обслуженный заказ производственного стола. Принятый личный урок сам по себе автоподачей не считается.","station",first.station_id)
	if workers<2: return grow(p,stations)
	if counters.size()<2:
		var missing:=2 if not counters.any(func(station): return station.station_id==2) else 3
		return buy(p,"counter",missing,"Первый цикл уже знаком. Подготовь второму клону собственное рабочее место.")
	for station in counters:
		if crew_count(station)<station.role_count(): return grow(p,stations)
	var second=counters[1]
	if second.recipes.is_empty():
		var second_equipment:=equip(p,second,"sausage")
		if not second_equipment.is_empty(): return second_equipment
		return masterclass_training_step(p,second,"sausage",false,service)
	for dish in STARTER_SEQUENCE:
		if counters.any(func(station): return _p5_current_b_plus(station,dish)): continue
		var selected=counters[0]
		for station in counters:
			if equipped(station,dish): selected=station; break
			if station.recipes.size()<selected.recipes.size(): selected=station
		var equipment:=equip(p,selected,dish)
		if not equipment.is_empty(): return equipment
		return masterclass_training_step(p,selected,dish,true,service)
	if p.can_attempt(stations,served):
		return step("second_star","Пригласи делегацию второй звезды","Компьютер → Звёзды. Фильм и телевизор не требуются: проверка смотрит на три B+ способа нынешних работников, две действующие бригады и обычные условия кампании.")
	if p.journey_auto_served<3:
		return step("repeat_work","Закрепи автоматизацию · %d/3 автоподач"%p.journey_auto_served,"Это ориентир знакомства, а не условие звезды: дай двум клонам выполнить ещё реальные заказы. Проверка 2★ остаётся доступна сразу, как только выполнен список во вкладке «Звёзды».","station",second.station_id)
	if p.popularity<p.STAR_POPULARITY:
		var rest_note:=" Базовый диван уже доступен работникам; дополнительная мебель и телевизор не обязательны." if not _p5_milestone(p,"first_staff_rest_completed") else ""
		return step("popularity","Подними популярность · %d/%d"%[p.popularity,p.STAR_POPULARITY],"Выбери доступные украшения: это обычное условие кампании."+rest_note)
	return step("ready_crews","Подготовь две действующие бригады","Компьютер → Звёзды показывает конкретное оставшееся условие. Отдых, телевизор, исследование формулы и случайная мебель не являются скрытыми требованиями 2★.")

static func next_step(p, stations: Array, served: int, opened: bool, service=null) -> Dictionary:
	if p.stars==1: return _p5_first_clones_step(p,stations,served,service)
	if p.stars != 0: return super.next_step(p, stations, served, opened, service)
	var personal
	for station in stations:
		if station.manual_station:
			personal = station
			break
	if not p.cafe_inaugurated:
		return step("inaugurate", "Перережь ленточку и открой кафе", "Подойди ко входу и нажми E у ленточки. До открытия можно спокойно осмотреть кафе.", "")
	if p.inauguration_first_service_pending or "sausage" not in p.tutorial_served:
		return step("first_guest", "Обслужи первого гостя", "Первый гость идёт к стойке №1. Приготовь сосиску в соусе; готовое положи на поднос и нажми E у звонка.", "station", 1)
	if personal != null:
		for dish in ["potato", "wine"]:
			var equipment := equip(p, personal, dish)
			if not equipment.is_empty(): return equipment
			if dish not in p.tutorial_served:
				return step("try_" + dish, "Освой блюдо: " + str(DISH_NAMES[dish]), "Обслужи настоящий заказ этим блюдом. Требования и управление — в книге B.", "station", 1)
	if p.manual_served < 15:
		return step("practice", "Подготовься к дегустации · %d/15 гостей" % p.manual_served, "Закрепи три стартовых блюда. Дегустатор попросит каждое на B или лучше.", "station", 1)
	return step("first_star", "Пригласи дегустатора", "Компьютер → Звёзды. Сосиска, картофель и вино — каждое на B или лучше. Неудачное блюдо можно повторить бесплатно.")

static func current(p, stations: Array, served: int, opened: bool, service=null) -> Dictionary:
	if p.stars!=1:
		if p.stars != 0 or p.busy(): return super.current(p, stations, served, opened, service)
		var zero_result := next_step(p, stations, served, opened, service)
		zero_result.chapter = "ПЕРВАЯ ЗВЕЗДА"
		if p.shift not in ["night", "closing"] and zero_result.key == "first_star" and p.visit.get("phase", "") in ["scheduled", "active"]:
			zero_result.title = "К проверке на звезду всё готово"
			zero_result.detail = "Сначала заверши или отмени добровольный визит в компьютере, затем пригласи проверку."
		elif p.shift in ["night", "closing"]:
			zero_result.detail = "После отдыха: " + zero_result.title + ". " + zero_result.detail
			var zero_stage := preload("res://scripts/cafe_expansion_layout.gd").stage_for_progress(p)
			var zero_bed := "ляг в спальный мешок за стойкой" if zero_stage < 2 else "всем в Шеф-кровать"
			zero_result.title = ("Смена завершена · " + zero_bed) if p.shift == "night" else "Завершаем последние заказы"
			zero_result.place = "bed" if p.shift == "night" else ""
		elif not opened and not p.cafe_inaugurated:
			zero_result.detail = "Сначала перережь ленточку у входа. " + zero_result.detail
			zero_result.place = ""
		return zero_result
	if p.busy(): return super.current(p,stations,served,opened,service)
	var result:=_p5_first_clones_step(p,stations,served,service)
	result.chapter="ПЕРВЫЙ ПОМОЩНИК" if p.journey_auto_served<1 else "ВТОРАЯ ЗВЕЗДА"
	if p.shift not in ["night","closing"] and result.key=="second_star" and p.visit.get("phase","") in ["scheduled","active"]:
		result.title="К проверке на звезду всё готово"
		result.detail="Сначала заверши или отмени добровольный визит в компьютере, затем пригласи проверку."
	elif p.shift in ["night","closing"]:
		result.detail="После отдыха: "+result.title+". "+result.detail
		var night_bed := "ляг в спальный мешок за стойкой" if preload("res://scripts/cafe_expansion_layout.gd").stage_for_progress(p)<2 else "всем в Шеф-кровать"
		result.title=("Смена завершена · "+night_bed) if p.shift=="night" else "Завершаем последние заказы"
		result.place="bed" if p.shift=="night" else ""
	return result
