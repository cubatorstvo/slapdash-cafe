extends "res://scripts/cafe_journey_legacy.gd"
## Stage 5.1 narrows only the zero-star route. The inherited implementation owns 1★+ progression.
const STARTER_SEQUENCE := ["sausage", "potato", "wine"]

static func next_step(p, stations: Array, served: int, opened: bool, service=null) -> Dictionary:
	if p.stars != 0:
		return super.next_step(p, stations, served, opened, service)
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
	if p.stars != 0 or p.busy():
		return super.current(p, stations, served, opened, service)
	var result := next_step(p, stations, served, opened, service)
	result.chapter = "ПЕРВАЯ ЗВЕЗДА"
	if p.shift not in ["night", "closing"] and result.key == "first_star" and p.visit.get("phase", "") in ["scheduled", "active"]:
		result.title = "К проверке на звезду всё готово"
		result.detail = "Сначала заверши или отмени добровольный визит в компьютере, затем пригласи проверку."
	elif p.shift in ["night", "closing"]:
		result.detail = "После отдыха: " + result.title + ". " + result.detail
		var stage := preload("res://scripts/cafe_expansion_layout.gd").stage_for_progress(p)
		var night_bed := "ляг в спальный мешок за стойкой" if stage < 2 else "всем в Шеф-кровать"
		result.title = ("Смена завершена · " + night_bed) if p.shift == "night" else "Завершаем последние заказы"
		result.place = "bed" if p.shift == "night" else ""
	elif not opened and not p.cafe_inaugurated:
		result.detail = "Сначала перережь ленточку у входа. " + result.detail
		result.place = ""
	return result
