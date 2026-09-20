extends RefCounted
## Station types describe the kit; purchased instances own crews and recordings.
const TYPES := {
	"counter": {"title": "Тяп-ляп стойка", "roles": ["Повар"], "dishes": ["wine", "potato", "sausage"], "width": 5.5},
	"kitchen": {"title": "Мясо и макароны", "roles": ["Мясо", "Макароны"], "dishes": ["meal"], "width": 6.1},
	"grill_kitchen": {"title": "Общая жарочная", "roles": ["Гриль", "Сборка"], "dishes": ["burger", "cheeseburger", "spicy_burger"], "width": 6.1},
	"solyanka_kitchen": {"title": "Солянка", "roles": ["Огонь", "Мешалка", "Соль"], "dishes": ["solyanka"], "width": 6.1}
}
const DISHES := {"wine": "Бокал вина", "potato": "Жареный картофель", "sausage": "Сосиска в соусе", "meal": "Стейк с макаронами", "burger":"Бургер", "cheeseburger":"Чизбургер", "spicy_burger":"Острый бургер", "solyanka":"Солянка"}
const DISH_ORDER := ["wine","potato","sausage","meal","burger","cheeseburger","spicy_burger","solyanka"]
const EQUIPMENT_BY_TYPE := {
	"counter":["sauce","plates","cup","pan","jug","rag","sauce_ramp"],
	"kitchen":["meat_kit","pasta_kit"],
	"grill_kitchen":["grill_kit","assembly_kit"],
	"solyanka_kitchen":["fire_kit","stir_kit","salt_kit"]
}
const DISH_EQUIPMENT := {
	"wine":["jug","cup"],
	"potato":["pan","plates"],
	"sausage":["sauce","plates"],
	"meal":["meat_kit","pasta_kit"],
	"burger":["grill_kit","assembly_kit"],
	"cheeseburger":["grill_kit","assembly_kit"],
	"spicy_burger":["grill_kit","assembly_kit"],
	"solyanka":["fire_kit","stir_kit","salt_kit"]
}
const REQUIREMENTS := {
	"wine": "Вино: 200–250 мл, кружка 300 мл, бережливость ≤5 мл вне посуды и подноса.",
	"potato": "Картофель: 6 сторон, порция на подносе; тарелка улучшает оценку.",
	"sausage": "Сосиска: покрытие ≥90%, порция на подносе; тарелка улучшает оценку.",
	"meal": "Стейк: 2 стороны 100%, соль ≥1 г. Макароны: сварить, соль ≥1 г, перемешать, порция 100 г. Вода ≥500 мл — условие варки.",
	"burger": "Котлета: две стороны 100% и приправа. Булка: поджарить. Соус. Котлета и булка делят одну жарочную поверхность.",
	"cheeseburger": "Как бургер, плюс сыр при сборке. Общая жарочная поверхность остаётся единственным узким местом.",
	"spicy_burger": "Как бургер, плюс острый соус при сборке. Общая жарочная поверхность остаётся единственным узким местом.",
	"solyanka": "Солянка: качество растёт, если разжечь котёл, посолить, перемешать и набросать внутрь минимум 13 ингредиентов или предметов. Нарушение рецепта снижает оценку, но не блокирует подачу."
}

static func crew(type_id: String, station_id: int) -> Array:
	var result: Array = []
	var names := ["Боря", "Жора", "Лёва", "Сёма", "Кеша", "Веня", "Федя", "Толя"]
	for role in range(TYPES[type_id].roles.size()):
		result.append({"name": "%s №%d.%d" % [names[(station_id + role - 1) % names.size()], station_id, role + 1]})
	return result

static func type_for_dish(dish: String) -> String:
	for type_id in TYPES:
		if dish in TYPES[type_id].dishes: return type_id
	return ""

static func equipment_for_type(type_id: String) -> Array:
	return EQUIPMENT_BY_TYPE.get(type_id,[]).duplicate()

static func equipment_allowed(type_id: String,item: String) -> bool:
	return item in EQUIPMENT_BY_TYPE.get(type_id,[])

static func missing_items(required: Array,equipment: Array,upgrades: Array=[]) -> Array:
	var result: Array=[]
	for item in required:
		if item not in equipment and item not in upgrades: result.append(item)
	return result

static func missing_equipment(dish: String,equipment: Array,upgrades: Array=[]) -> Array:
	return missing_items(DISH_EQUIPMENT.get(dish,[]),equipment,upgrades)
