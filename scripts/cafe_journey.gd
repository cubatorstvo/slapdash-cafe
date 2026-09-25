extends "res://scripts/cafe_journey_legacy.gd"
## Stage 5.1 owns the zero-star route; stage 5.2 owns the 1★ first-clone chapter.
## Stage 5.3 owns the action-driven 2★–5★ preparation route.
const STARTER_SEQUENCE := ["sausage", "potato", "wine"]

static func _p5_milestone(p, id: String) -> bool:
	var snapshot: Variant = p.get("feature_progress")
	if not snapshot is Dictionary: return false
	var milestones: Variant = snapshot.get("milestones", {})
	return milestones is Dictionary and milestones.has(id)

static func _p5_milestone_data(p, id: String) -> Dictionary:
	var snapshot: Variant = p.get("feature_progress")
	if not snapshot is Dictionary: return {}
	var milestones: Variant = snapshot.get("milestones", {})
	if not milestones is Dictionary: return {}
	var value: Variant = milestones.get(id, {})
	return value if value is Dictionary else {}

static func _p5_has_property(target, property_name: String) -> bool:
	if target == null: return false
	for property in target.get_property_list():
		if str(property.get("name", "")) == property_name: return true
	return false

static func _p5_has_action_snapshot(p) -> bool:
	var snapshot: Variant = p.get("feature_progress")
	if not snapshot is Dictionary: return false
	var milestones: Variant = snapshot.get("milestones", {})
	return milestones is Dictionary and not milestones.is_empty()

static func _p5_counters(stations: Array) -> Array:
	var result: Array=[]
	for station in stations:
		if not station.manual_station and (not _p5_has_property(station,"masterclass_station") or not bool(station.get("masterclass_station"))) and station.type_id=="counter": result.append(station)
	result.sort_custom(func(a,b): return a.station_id < b.station_id)
	return result

static func _p5_station_of_type(stations: Array, type_id: String):
	for station in stations:
		if not station.manual_station and (not _p5_has_property(station,"masterclass_station") or not bool(station.get("masterclass_station"))) and str(station.type_id)==type_id: return station
	return null

static func _p5_current_b_plus(station, dish: String) -> bool:
	if station==null or not station.ready_crew() or not station.recipes.has(dish): return false
	if station.has_method("missing_recipe_equipment") and not station.missing_recipe_equipment(dish).is_empty(): return false
	if _p5_has_property(station,"method_sources") and _p5_has_property(station,"crew"):
		var sources: Variant=station.get("method_sources")
		var crew: Variant=station.get("crew")
		if not sources is Dictionary or not crew is Array: return false
		var source: Variant=sources.get(dish,{})
		if not source is Dictionary: return false
		var clone_ids: Variant=source.get("clone_ids",[])
		if not clone_ids is Array or clone_ids.size()!=station.role_count(): return false
		for role in range(station.role_count()):
			if role>=crew.size() or int(crew[role].get("clone_id",0))<=0 or int(clone_ids[role])!=int(crew[role].get("clone_id",0)): return false
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

static func _p5_video_record(service, stations: Array) -> Dictionary:
	if service==null: return {}
	return _post_star_intro_record(service,stations)

static func _p5_video_station(service, stations: Array):
	if service==null: return null
	for station in stations:
		if station.manual_station or station.masterclass_station: continue
		for dish in station.method_sources:
			var source: Variant=station.method_sources.get(dish,{})
			if source is Dictionary and int(source.get("id",source.get("record_id",0)))>0: return station
	return null

static func _p5_scale_step(p, stations: Array, served: int, service) -> Dictionary:
	var counters:=_p5_counters(stations)
	var kitchen=_p5_station_of_type(stations,"kitchen")
	var specialty=_p5_station_of_type(stations,"grill_kitchen")
	var solyanka=_p5_station_of_type(stations,"solyanka_kitchen")
	if p.stars==2:
		if not _p5_milestone(p,"first_masterclass_saved"):
			return step("scale_first_film","Сними первый мастер-класс","На общей шеф-стойке нажми E → МАСТЕР-КЛАСС, выбери уже знакомое блюдо, приготовь его и явно сохрани принятую запись в видеотеку.","station",1)
		if "television" not in p.lounge_items:
			var tv:=television_step(p)
			tv.key="scale_television"
			return tv
		var record:=_p5_video_record(service,stations)
		if service!=null and record.is_empty():
			return step("scale_matching_film","Сними запись для действующего стола","В видеотеке пока нет фильма, совместимого с установленным производственным столом. Сними мастер-класс его блюда на шеф-стойке.","station",1)
		if not _p5_milestone(p,"first_video_training_completed"):
			var compatible: Array=service.compatible_training_station_ids(int(record.get("id",0))) if service!=null and not record.is_empty() else []
			var target_id:=int(compatible[0]) if not compatible.is_empty() else (int(counters[0].station_id) if not counters.is_empty() else 0)
			var record_name:=str(record.get("name","Запись")) if not record.is_empty() else "сохранённую запись"
			return step("scale_single_video","Назначь фильм одному столу","Компьютер → Столы и обучение → выбери один совместимый стол → добавь «%s» в очередь. Просмотр считается только после реальной выдачи навыка присутствовавшему работнику."%record_name,"computer",target_id)
		if not _p5_milestone(p,"first_video_trained_auto_served"):
			var trained=_p5_video_station(service,stations)
			return step("scale_single_video_work","Дождись автоподачи после просмотра","Пусть работник, реально получивший навык у телевизора, завершит заказ. Сам запуск фильма не закрепляет этап.","station",int(trained.station_id) if trained!=null else 0)
		if not _p5_milestone(p,"two_compatible_stations_seen"):
			if counters.size()<2:
				var slot:=2 if not counters.any(func(station): return station.station_id==2) else 3
				return buy(p,"counter",slot,"Для общего просмотра нужны минимум два совместимых производственных стола.")
			return step("scale_two_compatible","Подготовь два совместимых стола","Массовое назначение появится, когда в кафе реально есть минимум два производственных стола одного типа.","computer")
		if not _p5_milestone(p,"first_group_training_completed"):
			return step("scale_group_video","Обучи минимум два стола одним сеансом","Компьютер → Столы и обучение → выбери минимум два совместимых стола и один фильм. Этап засчитается только после общего просмотра и реальной выдачи навыков, не при заполнении очереди.","computer")
		if not _p5_milestone(p,"first_group_trained_auto_served"):
			var group_data:=_p5_milestone_data(p,"first_group_training_completed")
			var ids: Variant=group_data.get("station_ids",[])
			var station_id:=int(ids[0]) if ids is Array and not ids.is_empty() else 0
			return step("scale_group_work","Закрепи групповое обучение автоподачей","Хотя бы один стол, действительно обученный в общем сеансе, должен завершить реальный автоматический заказ.","station",station_id)
		# Formula improvement is a useful branch introduced here, but the paired kitchen is
		# already unlocked by the completed group cycle and can be bought ahead of this hint.
		if not p.expanded and not _p5_milestone(p,"formula_improvement_relevant"):
			return step("scale_formula","Исследуй улучшенную формулу","Групповое обучение освоено. В лаборатории можно исследовать формулу, которая должна быть быстрее хотя бы одного существующего клона. Парная кухня уже доступна независимо от этого.","laboratory")
		if not p.expanded and _p5_milestone(p,"formula_improvement_relevant") and not _p5_milestone(p,"first_recalibration_completed"):
			if "lab_chair" not in p.lab_upgrades:
				var chair:=step("scale_recalibration_chair","Установи кресло рекалибровки","Полезная формула получена — теперь раздел рекалибровки остаётся известным. Закажи кресло в лабораторном каталоге; парная кухня от этой покупки не зависит.","computer")
				chair.item="lab_chair"
				return chair
			return step("scale_recalibration","Рекалибруй одного клона","Посади подходящего работника в кресло и примени улучшенную формулу. После успешной процедуры факт сохранится навсегда.","laboratory")
		if not p.expanded: return step("third_expand","Расширь зал для парной кухни · 180","Компьютер → Интернет-магазин → расширение. Распространение опыта уже закреплено; теперь добавь двухролевую производственную линию.")
		if kitchen==null: return buy(p,"kitchen",4,"Парная кухня «Мясо и макароны» вводит две согласованные роли одного способа.")
		if crew_count(kitchen)<kitchen.role_count(): return grow(p,stations)
		var kitchen_equipment:=equip(p,kitchen,"meal")
		if not kitchen_equipment.is_empty(): return kitchen_equipment
		if not _p5_current_b_plus(kitchen,"meal"): return masterclass_training_step(p,kitchen,"meal",true,service)
		if not _p5_milestone(p,"first_pair_kitchen_auto_served"): return step("first_meal","Получи первую автоподачу парной кухни","Дождись реального заказа: оба клона должны исполнить роли одного принятого способа «Мясо и макароны».","station",kitchen.station_id)
		if p.journey_meals_served<p.THIRD_STAR_MEALS: return step("meal_capacity","Дай парной кухне поработать · %d/%d"%[p.journey_meals_served,p.THIRD_STAR_MEALS],"Текущие числовые пороги кампании пока сохраняются; пусть двухролевая линия выполнит ещё реальные заказы.","station",kitchen.station_id)
		if p.third_star_auto_served<p.THIRD_STAR_AUTO_SERVED: return step("scale_service","Проверь мощность кафе · %d/%d автоподач"%[p.third_star_auto_served,p.THIRD_STAR_AUTO_SERVED],"Оставь освоенные линии работать вместе. Короткая занятость на доставке не меняет структурную готовность состава.","station",kitchen.station_id)
		if p.popularity<p.THIRD_STAR_POPULARITY: return step("third_popularity","Подними популярность · %d/%d"%[p.popularity,p.THIRD_STAR_POPULARITY],"Используй уже доступные способы развития кафе; новые числовые решения каталогов остаются следующему этапу.")
		if p.can_attempt(stations,served): return step("third_star","Пригласи гостей на Большой обед","Компьютер → Звёзды. Проверка доступна по фактическому текущему составу, знаниям и оснащению.")
		return step("third_ready","Подготовь три производственные линии","Компьютер → Звёзды показывает конкретное недостающее структурное условие.")
	if p.stars==3:
		if not p.specialized_expanded: return step("specialty_expand","Открой специализированный сектор · %d"%p.SPECIALTY_EXPANSION_PRICE,"Компьютер → Интернет-магазин. После 3★ вводится бургерная и её общий физический ресурс.")
		if specialty==null: return buy(p,"grill_kitchen",5,"Бургерная — следующая производственная линия после подтверждённой парной кухни.")
		if crew_count(specialty)<specialty.role_count(): return grow(p,stations)
		var burger_gear:=equip(p,specialty,"burger")
		if not burger_gear.is_empty(): return burger_gear
		for dish in p.SPECIALTY_DISHES:
			if not _p5_current_b_plus(specialty,str(dish)): return masterclass_training_step(p,specialty,str(dish),true,service)
		if not _p5_milestone(p,"first_specialty_kitchen_auto_served"): return step("first_specialty","Получи первую автоподачу бургерной","Дождись реального заказа бургерной после освоения её ролей; только завершённая подача вводит следующий слой.","station",specialty.station_id)
		if p.fourth_star_specialty_served<p.FOURTH_STAR_SPECIALTY_SERVED: return step("specialty_capacity","Дай бургерной поработать · %d/%d"%[p.fourth_star_specialty_served,p.FOURTH_STAR_SPECIALTY_SERVED],"Текущий порог кампании сохранён до отдельной настройки каталогов и баланса.","station",specialty.station_id)
		if p.fourth_star_auto_served<p.FOURTH_STAR_AUTO_SERVED: return step("specialty_scale","Проверь весь зал · %d/%d автоподач"%[p.fourth_star_auto_served,p.FOURTH_STAR_AUTO_SERVED],"Старые и новые линии должны работать с нынешними назначенными сотрудниками и их знаниями.","station",specialty.station_id)
		if p.popularity<p.FOURTH_STAR_POPULARITY: return step("fourth_popularity","Подними популярность · %d/%d"%[p.popularity,p.FOURTH_STAR_POPULARITY],"Подготовь кафе к текущей проверке 4★.")
		if p.can_attempt(stations,served): return step("fourth_star","Начни испытание «Три волны»","Компьютер → Звёзды. После успешной проверки откроется глава координации трёхролевой кухни.")
		return step("fourth_ready","Подготовь специализированную линию","Компьютер → Звёзды показывает конкретное недостающее условие.")
	if p.stars==4:
		if not p.orchestration_expanded: return step("orchestration_expand","Открой сектор оркестрации · %d"%p.ORCHESTRATION_EXPANSION_PRICE,"Компьютер → Интернет-магазин. После 4★ вводится кухня «Солянка» на три согласованные роли.")
		if solyanka==null: return buy(p,"solyanka_kitchen",6,"Солянка завершает последовательность поздних кухонь и требует трёх текущих работников.")
		if crew_count(solyanka)<solyanka.role_count(): return grow(p,stations)
		var solyanka_gear:=equip(p,solyanka,"solyanka")
		if not solyanka_gear.is_empty(): return solyanka_gear
		if not _p5_current_b_plus(solyanka,"solyanka"): return masterclass_training_step(p,solyanka,"solyanka",true,service)
		if not _p5_milestone(p,"first_solyanka_auto_served"): return step("first_solyanka","Получи первую автоподачу солянки","Дождись реального заказа: три роли должны исполнить один согласованный способ и завершить подачу.","station",solyanka.station_id)
		if p.fifth_star_solyanka_served<p.FIFTH_STAR_SOLYANKA_SERVED: return step("solyanka_capacity","Накидай солянку гостям · %d/%d"%[p.fifth_star_solyanka_served,p.FIFTH_STAR_SOLYANKA_SERVED],"Текущий порог кампании сохранён; финальная балансировка будет отдельным этапом.","station",solyanka.station_id)
		if p.fifth_star_auto_served<p.FIFTH_STAR_AUTO_SERVED: return step("orchestration_scale","Дай всему кафе поработать · %d/%d автоподач"%[p.fifth_star_auto_served,p.FIFTH_STAR_AUTO_SERVED],"Подготовка к действующей финальной проверке сочетает освоенные производственные линии.","station",solyanka.station_id)
		if p.can_attempt(stations,served): return step("fifth_star","Кафе готово к действующей финальной проверке","Компьютер → Звёзды. Этап 5.3 доводит путь до возможности заслужить 5★; финальный экран и итоговый баланс остаются следующими этапами.","computer")
		return step("fifth_ready","Подготовь кафе к финальной смене","Компьютер → Звёзды показывает оставшиеся условия действующей проверки.","computer")
	return super.next_step(p,stations,served,true,service)

static func next_step(p, stations: Array, served: int, opened: bool, service=null) -> Dictionary:
	if p.stars==1: return _p5_first_clones_step(p,stations,served,service)
	if p.stars>=2 and p.stars<=4:
		if not _p5_has_action_snapshot(p): return super.next_step(p,stations,served,opened,service)
		return _p5_scale_step(p,stations,served,service)
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

static func _p5_night_wrap(p, result: Dictionary) -> Dictionary:
	if p.shift not in ["night","closing"]: return result
	result.detail="После отдыха: "+str(result.title)+". "+str(result.detail)
	var night_bed := "ляг в спальный мешок за стойкой" if preload("res://scripts/cafe_expansion_layout.gd").stage_for_progress(p)<2 else "всем в Шеф-кровать"
	result.title=("Смена завершена · "+night_bed) if p.shift=="night" else "Завершаем последние заказы"
	result.place="bed" if p.shift=="night" else ""
	return result

static func current(p, stations: Array, served: int, opened: bool, service=null) -> Dictionary:
	if p.stars>=2 and p.stars<=4:
		if not _p5_has_action_snapshot(p): return super.current(p,stations,served,opened,service)
		if p.busy(): return super.current(p,stations,served,opened,service)
		var scale_result:=_p5_scale_step(p,stations,served,service)
		scale_result.chapter="ВИДЕООБУЧЕНИЕ · 2★" if p.stars==2 and not _p5_milestone(p,"first_group_trained_auto_served") else "ТРЕТЬЯ ЗВЕЗДА · МАСШТАБ" if p.stars==2 else "ЧЕТВЁРТАЯ ЗВЕЗДА · СПЕЦИАЛИЗАЦИЯ" if p.stars==3 else "ПЯТАЯ ЗВЕЗДА · ОРКЕСТРАЦИЯ"
		return _p5_night_wrap(p,scale_result)
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
		result=_p5_night_wrap(p,result)
	return result