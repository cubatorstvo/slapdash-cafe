extends RefCounted
## Station types describe the kit; purchased instances own crews and recordings.
const TYPES := {
	"counter": {"title": "Тяп-ляп стойка", "roles": ["Повар"], "dishes": ["wine", "potato", "sausage"], "width": 5.5},
	"kitchen": {"title": "Мясо и макароны", "roles": ["Мясо", "Макароны"], "dishes": ["meal"], "width": 6.1},
	"grill_kitchen": {"title": "Общая жарочная", "roles": ["Гриль", "Сборка"], "dishes": ["burger", "cheeseburger", "spicy_burger"], "width": 6.1},
	"solyanka_kitchen": {"title": "Солянка", "roles": ["Огонь", "Мешалка", "Соль"], "dishes": ["solyanka"], "width": 6.1}
}
const DISHES := {"wine": "Бокал вина", "potato": "Жареный картофель", "sausage": "Сосиска в соусе", "meal": "Стейк с макаронами", "burger":"Бургер", "cheeseburger":"Чизбургер", "spicy_burger":"Острый бургер", "solyanka":"Солянка"}
const REQUIREMENTS := {
	"wine": "Вино: 200–250 мл, кружка 300 мл, бережливость ≤5 мл вне посуды и подноса.",
	"potato": "Картофель: 6 сторон, порция на подносе; тарелка улучшает оценку.",
	"sausage": "Сосиска: покрытие ≥90%, порция на подносе; тарелка улучшает оценку.",
	"meal": "Стейк: 2 стороны 100%, соль ≥1 г. Макароны: сварить, соль ≥1 г, перемешать, порция 100 г. Вода ≥500 мл — условие варки.",
	"burger": "Котлета: две стороны 100% и приправа. Булка: поджарить. Соус. Котлета и булка делят одну жарочную поверхность.",
	"cheeseburger": "Как бургер, плюс сыр при сборке. Общая жарочная поверхность остаётся единственным узким местом.",
	"spicy_burger": "Как бургер, плюс острый соус при сборке. Общая жарочная поверхность остаётся единственным узким местом.",
	"solyanka": "Солянка: разжечь котёл, посолить, перемешать и набросать внутрь минимум 13 ингредиентов или предметов."
}

static func crew(type_id: String, station_id: int) -> Array:
	var result: Array = []
	var names := ["Боря", "Жора", "Лёва", "Сёма", "Кеша", "Веня", "Федя", "Толя"]
	for role in range(TYPES[type_id].roles.size()):
		result.append({"name": "%s №%d.%d" % [names[(station_id + role - 1) % names.size()], station_id, role + 1]})
	return result
