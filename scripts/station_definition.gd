extends RefCounted
## Station types describe the kit; purchased instances own crews and recordings.
const TYPES := {
	"counter": {"title": "Тяп-ляп стойка", "roles": ["Повар"], "dishes": ["wine", "potato", "sausage"], "width": 4.3},
	"kitchen": {"title": "Мясо и макароны", "roles": ["Мясо", "Макароны"], "dishes": ["meal"], "width": 6.1}
}
const DISHES := {"wine": "Бокал вина", "potato": "Жареный картофель", "sausage": "Сосиска в соусе", "meal": "Стейк с макаронами"}
const REQUIREMENTS := {"wine": "Вино: не менее 225 мл в стакане.", "potato": "Картофель: 6 обжаренных сторон, подача на тарелке.", "sausage": "Сосиска: не менее 90% покрытия соусом, подача на тарелке.", "meal": "Стейк: обе стороны обжарены, соль ≥1 г. Макароны: вода ≥500 мл при варке, сварены и перемешаны, порция ≥100 г, соль ≥1 г. Две части на своих тарелках."}

static func crew(type_id: String, station_id: int) -> Array:
	var result: Array = []
	var names := ["Боря", "Жора", "Лёва", "Сёма", "Кеша", "Веня", "Федя", "Толя"]
	for role in range(TYPES[type_id].roles.size()):
		result.append({"name": "%s №%d.%d" % [names[(station_id + role - 1) % names.size()], station_id, role + 1]})
	return result
