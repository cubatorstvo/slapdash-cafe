extends RefCounted
const Quality = preload("res://scripts/dish_quality.gd")

static func standard(dish: String) -> Dictionary:
	return {"dish": dish, "title": "Стандартный рецепт", "faces": 6, "coat_min": 0.9, "coat_max": 1.0, "min_ml": 200.0, "max_ml": 250.0, "portions": 1, "premium": 1.0}

static func choose(dish: String, equipment: Array, serial: int, rng: RandomNumberGenerator) -> Dictionary:
	var order := standard(dish)
	if serial < 3: return order
	order.premium = 1.5
	var variant := rng.randi_range(0, 2)
	match dish:
		"wine":
			order.min_ml = [80.0,150.0,250.0][variant]
			order.max_ml = [120.0,200.0,280.0][variant]
			order.title = ["На пробу", "Полбокала настроения", "Щедрый бокал"][variant]
		"potato":
			order.faces = [2,4,6][variant] if "pan" in equipment else 6
			order.title = ["Подрумянить слегка", "Почти со всех сторон", "Румяный со всех сторон"][variant] if "pan" in equipment else "Картофель как получится"
		"sausage":
			order.title = ["Немного соуса", "Соуса не жалеть", "Двойная порция"][variant]
			if variant == 0 and "sauce" in equipment: order.coat_min = 0.2; order.coat_max = 0.45
			if variant == 2: order.portions = 2; order.premium = 2.0
	return order

static func range_score(value: float, low: float, high: float) -> float:
	if value < low: return clampf(value / maxf(low, 0.001), 0, 1)
	if value <= high: return 1.0
	return clampf(1.0 - (value - high) / maxf(0.05, high * 0.5), 0, 1)

# Only deviations from the cookbook belong on the order slip. Never live progress.
static func special_request(order: Dictionary) -> String:
	if order.is_empty(): return ""
	var dish: String = order.get("dish", "")
	var base := standard(dish)
	var changes: PackedStringArray = []
	match dish:
		"wine":
			if order.get("min_ml",200.0) != base.min_ml or order.get("max_ml",250.0) != base.max_ml:
				changes.append(("только попробовать, " if float(order.min_ml) <= 80 else "") + "%.0f–%.0f мл" % [order.min_ml,order.max_ml])
		"potato":
			if order.get("faces",6) != base.faces: changes.append("%d стороны" % order.faces)
		"sausage":
			if order.get("portions",1) != base.portions: changes.append("двойная порция")
			if order.get("coat_min",0.9) != base.coat_min or order.get("coat_max",1.0) != base.coat_max:
				changes.append("соус %.0f–%.0f%%" % [order.coat_min*100,order.coat_max*100])
	if changes.is_empty(): return ""
	return {"wine":"Вино","potato":"Картошка жареная","sausage":"Сосиска в соусе"}.get(dish,dish) + " (" + ", ".join(changes) + ")"

static func grade_candidate(candidate: Dictionary, dish: String, order: Dictionary, waste: float) -> Dictionary:
	var criteria: Array = []
	match dish:
		"wine":
			criteria = [{"label": "Вино: %.0f / %.0f–%.0f мл" % [candidate.get("ml",0),order.min_ml,order.max_ml], "value": clampf(float(candidate.get("ml",0))/maxf(1,order.min_ml),0,1) if float(candidate.get("ml",0)) <= order.max_ml else clampf(1-(float(candidate.get("ml",0))-order.max_ml)/50.0,0,1)}, {"label": "Бережливость: " + ("✓" if waste <= 5 else "×"), "value": 1.0 if waste <= 5 else 0.0}]
		"potato": criteria = [{"label": "Обжарено сторон: %d / %d" % [candidate.get("faces",0),order.faces], "value": minf(1, float(candidate.get("faces",0))/maxf(1,order.faces))}]
		"sausage": criteria = [{"label": "Соус: %.0f%% / %.0f–%.0f%%" % [candidate.get("coat",0)*100,order.coat_min*100,order.coat_max*100], "value": range_score(candidate.get("coat",0),order.coat_min,order.coat_max)}]
	var report := Quality.result(criteria, candidate.get("present",false), [])
	var utensil: bool = candidate.get("utensil", false)
	report.criteria.append({"label": "Посуда: " + ("✓" if utensil else "×"), "value": 1.0 if utensil else 0.0})
	if report.present and not utensil:
		var grades := ["D","C","B","A","S"]
		report.grade = grades[maxi(0, grades.find(report.grade)-1)]
		report.price_factor = Quality.PRICE_FACTORS[report.grade]
	report.candidate = candidate
	return report

static func evaluate(model) -> Dictionary:
	var order: Dictionary = standard(model.dish) if model.chef_order.is_empty() else model.chef_order
	var candidates: Array = model.serving_candidates(model.dish)
	var waste: float = model.spilled() + model.soaked + model.lost
	var graded: Array = []
	for candidate in candidates: graded.append(grade_candidate(candidate,model.dish,order,waste))
	graded.sort_custom(func(a,b): return a.price_factor > b.price_factor if not is_equal_approx(a.price_factor,b.price_factor) else bool(a.candidate.get("showy",false)) and not bool(b.candidate.get("showy",false)))
	var needed: int = int(order.portions)
	var chosen: Dictionary = grade_candidate({"present":false},model.dish,order,waste) if graded.is_empty() else graded[0].duplicate(true)
	if needed > 1:
		var score := 0.0
		for i in range(mini(needed,graded.size())): score += maxf(0,float(graded[i].score)-(0.25 if not graded[i].candidate.get("utensil",false) else 0))
		var portion := Quality.result([{"label":"Порции: %d/%d" % [mini(needed,graded.size()),needed],"value":score/needed}], not graded.is_empty(), [])
		chosen.grade = portion.grade
		chosen.price_factor = portion.price_factor
		chosen.score = portion.score
		chosen.criteria.append({"label": "Порции: %d/%d" % [mini(needed,graded.size()),needed], "value": minf(1,float(graded.size())/needed)})
	for i in range(mini(needed,graded.size())):
		if graded[i].candidate.get("showy",false): chosen.style_count = 1; chosen.style_multiplier = 1.2; chosen.style_tricks = ["Ловкая подача"]
	var preview: Dictionary = chosen if chosen.present else grade_candidate(model.preview_candidate(model.dish),model.dish,order,waste)
	var lines: Array = []
	for criterion in preview.criteria: lines.append(criterion.label)
	if needed > 1: lines.append("Порции: %d/%d" % [mini(needed,graded.size()),needed])
	var location := str(chosen.candidate.get("location","ещё не подано"))
	lines.append("Выпито гостем: %.0f мл" % model.guest_serving.drunk if model.dish == "wine" else "Лучшая порция: " + location)
	chosen.components = [{"id":model.dish,"name":{"wine":"Вино","potato":"Картофель","sausage":"Сосиска"}[model.dish],"role":0,"served":chosen.present,"location":location,"lines":lines,"details":lines.duplicate()}]
	chosen.order = order.duplicate(true)
	return chosen
