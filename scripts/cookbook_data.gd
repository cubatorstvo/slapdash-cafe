extends RefCounted
const Definition = preload("res://scripts/station_definition.gd")
const ICONS := {"wine": preload("res://assets/ui/wine.svg"), "potato": preload("res://assets/ui/potato.svg"), "sausage": preload("res://assets/ui/sausage.svg"), "meal": preload("res://assets/ui/meal.svg")}
const ORDER := ["wine", "potato", "sausage", "meal"]
const RECIPES := {
	"wine": {
		"title": "Бокал вина",
		"components": [
			{
				"id": "wine", "name": "Вино", "role": 0,
				"lines": [
					{"id": "volume", "label": "200–250 мл", "detail": "Кружка вмещает 300 мл. Недолив и перелив снижают качество."},
					{"id": "thrift", "label": "Бережливость", "detail": "Не более 5 мл вне посуды и подноса. Пролитое можно собрать тряпкой и выжать обратно в ёмкость."},
					{"id": "utensil", "label": "В чашке", "detail": "Вино без чашки на подносе принимается, но оценка ниже на одну ступень."}
				]
			}
		]
	},
	"potato": {
		"title": "Жареный картофель",
		"components": [
			{
				"id": "potato", "name": "Картофель", "role": 0,
				"lines": [
					{"id": "faces", "label": "6 сторон", "detail": "Каждая из шести сторон должна полностью подрумяниться."},
					{"id": "portion", "label": "Порция", "detail": "На заказ нужна одна картофелина на подносе. Падение само по себе не снижает качество."},
					{"id": "utensil", "label": "На тарелке", "detail": "Еда прямо на подносе принимается, но оценка ниже на одну ступень."}
				]
			}
		]
	},
	"sausage": {
		"title": "Сосиска в соусе",
		"components": [
			{
				"id": "sausage", "name": "Сосиска", "role": 0,
				"lines": [
					{"id": "coating", "label": "Покрытие ≥90%", "detail": "Покрытие видно по цвету сосиски и в карточке блюда."},
					{"id": "portion", "label": "Порция", "detail": "На заказ нужна одна сосиска на подносе."},
					{"id": "utensil", "label": "На тарелке", "detail": "Еда прямо на подносе принимается, но оценка ниже на одну ступень."}
				]
			}
		]
	},
	"meal": {
		"title": "Стейк с макаронами",
		"components": [
			{
				"id": "steak", "name": "Стейк", "role": 0,
				"lines": [
					{"id": "sides", "label": "Обжарить с 2 сторон", "detail": "Обе стороны должны быть обжарены на 100%."},
					{"id": "meat_salt", "label": "Соль", "detail": "Соль мяса ≥1 г учитывается у стейка отдельно от макарон."}
				]
			},
			{
				"id": "pasta", "name": "Макароны", "role": 1,
				"lines": [
					{"id": "cooked", "label": "Сварить", "detail": "Для варки в кастрюле нужно не менее 500 мл воды. Готовность — 100%."},
					{"id": "pasta_salt", "label": "Соль", "detail": "Соль в поданной порции ≥1 г."},
					{"id": "stirred", "label": "Перемешать", "detail": "Перемешивание готовой порции — 100%."},
					{"id": "portion", "label": "Порция — 100 г", "detail": "Оценивается масса на тарелке, а не оставшаяся в кастрюле."}
				]
			}
		]
	}
}

static func page(value: String) -> String: return value if value in ICONS else "index"

static func presentation(data: Dictionary) -> Dictionary:
	return {"book": data.get("book", false) == true, "page": page(str(data.get("page", "index"))), "bell": int(data.get("bell", 0))}

static func title(dish: String) -> String:
	return RECIPES[dish].title if dish in RECIPES else Definition.DISHES.get(dish, "Рецепт")

static func summary(dish: String) -> String:
	if not dish in RECIPES: return ""
	var parts: Array = []
	for component in RECIPES[dish].components:
		var labels: Array = []
		for line in component.lines: labels.append(line.label)
		parts.append(component.name + ": " + ", ".join(labels))
	return "\n".join(parts)

static func mark(ok: bool) -> String: return "✓" if ok else "×"

static func pct(value: float) -> String: return "%d%%" % roundi(clampf(value, 0, 1) * 100)

static func components(dish: String, model = null) -> Array:
	if model != null: return model.quality().components
	if not dish in RECIPES: return []
	var live: bool = model != null
	var result: Array = []
	for component in RECIPES[dish].components:
		var entry := {"id": component.id, "name": component.name, "role": int(component.role), "served": false, "lines": [], "details": []}
		if live: entry.served = _served(dish, component.id, model)
		for line in component.lines:
			var text: String = line.label
			if live:
				var extra := _live(dish, line.id, model, entry.served)
				if not extra.is_empty(): text = "%s [%s]" % [line.label, extra]
			entry.lines.append(text)
			entry.details.append(line.detail)
		result.append(entry)
	return result

static func _served(dish: String, component_id: String, model) -> bool:
	match dish:
		"wine": return model.served_wine() > 0
		"potato", "sausage": return model.served_index(dish) >= 0
		"meal":
			if component_id == "steak": return model.meat_state == "plate" and model.hands.find("steak") < 0
			return model.served_pasta > 0
	return false

static func _live(dish: String, line_id: String, model, served: bool) -> String:
	if line_id == "utensil": return mark(model.served_in_dish(dish))
	match dish:
		"wine":
			if line_id == "volume": return "%d мл" % roundi(model.served_wine() if served else model.filled)
			if line_id == "thrift": return "%s · %.0f мл" % [mark(model.spilled() + model.soaked + model.lost <= 5), model.spilled() + model.soaked + model.lost]
		"potato":
			if line_id == "faces":
				var faces := 0
				if served:
					for heat in model.potatoes[model.served_index("potato")].potato_heat:
						if heat >= 0.999: faces += 1
				else: faces = model.cooked_faces()
				return "%d/6" % faces
			if line_id == "portion": return mark(served)
		"sausage":
			if line_id == "coating":
				var coat: float = model.sausage_coating
				if served: coat = model.sausages[model.served_index("sausage")].sausage_coating
				return "%d%%" % roundi(coat * 100)
			if line_id == "portion": return mark(served)
		"meal":
			if line_id == "sides":
				return "%s / %s" % [pct(model.meat_sides[0]), pct(model.meat_sides[1])]
			if line_id == "meat_salt": return mark(model.meat_salt >= 1)
			if line_id == "cooked": return pct(model.served_cooked if served else model.cooked)
			if line_id == "pasta_salt": return mark((model.served_salt if served else model.pasta_salt) >= 1)
			if line_id == "stirred": return mark((model.served_stirred if served else model.stirred) >= 0.999)
			if line_id == "portion": return "%d/100 г" % roundi(model.served_pasta if served else model.pasta)
	return ""
