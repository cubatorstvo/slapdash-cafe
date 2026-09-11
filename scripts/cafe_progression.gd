extends RefCounted
## Cafe progression is owned by the host; records remain owned by each station.
const DISHES := ["wine", "potato", "sausage"]
const DECOR := {
	"sign": {"name": "Вывеска «Мы почти умеем»", "price": 45, "popularity": 10, "description": "Заметная вывеска у входа."},
	"lights": {"name": "Гирлянда на честном слове", "price": 85, "popularity": 15, "description": "Тёплый свет над залом."},
	"plants": {"name": "Зелёный уголок", "price": 110, "popularity": 20, "description": "Большие растения и цветные кашпо."}
}
const STAR_POPULARITY := 30
const REQUIRED_SERVED := 12
const COUNTER_PRICE := 120
const UPGRADE_PRICE := 75
const EXPANSION_PRICE := 180
const KITCHEN_PRICE := 250
const SHOWCASE_SECONDS := 120.0
const BANQUET_SECONDS := 240.0
const BANQUET_GUESTS := 9
const BANQUET_SERVED := 8
const BANQUET_GOOD := 6
var cash := 60
var popularity := 0
var stars := 0
var decorations: Array = []
var expanded := false
var demand := {}
var phase := "none"
var remaining := 0.0
var banquet_spawned := 0
var banquet_finished := 0
var banquet_served := 0
var banquet_good := 0
var showcase_grade := ""
var orders: Array = []
var result := ""
var return_open := false
var event_peer := 1
var revision := 0

func busy() -> bool: return phase in ["preparing", "showcase", "service"]
func arrival_interval() -> float: return maxf(8.0, 18.0 - popularity * 0.20)
func available_dishes() -> Array: return DISHES + (["meal"] if stars > 0 else [])
func paid_decoration(id: String) -> String:
	if not DECOR.has(id): return "Украшение не найдено."
	if id in decorations: return "Это украшение уже установлено."
	if cash < DECOR[id].price: return "Не хватает денег."
	cash -= DECOR[id].price
	popularity += DECOR[id].popularity
	decorations.append(id)
	revision += 1
	return ""

func record_demand(dish: String, reason: String) -> void:
	if not demand.has(dish): demand[dish] = {"served": 0, "untrained": 0, "busy": 0}
	demand[dish][reason] = int(demand[dish].get(reason, 0)) + 1
	revision += 1

func star_requirements(stations: Array, served: int) -> Array:
	var ready: Array = []
	for dish in DISHES:
		for station in stations:
			var report: Dictionary = station.recipes.get(dish, {}).get("quality", {})
			if report.get("present", false) and report.get("grade", "D") in ["B", "A", "S"]:
				ready.append(dish)
				break
	return [
		{"text": "Популярность: %d / %d" % [popularity, STAR_POPULARITY], "done": popularity >= STAR_POPULARITY},
		{"text": "Обслужено гостей: %d / %d" % [served, REQUIRED_SERVED], "done": served >= REQUIRED_SERVED},
		{"text": "Две рабочие станции: %d / 2" % mini(stations.size(), 2), "done": stations.size() >= 2},
		{"text": "Три блюда с записью B или лучше: %d / 3" % ready.size(), "done": ready.size() == 3}
	]

func can_attempt(stations: Array, served: int) -> bool:
	if stars > 0 or busy(): return false
	for requirement in star_requirements(stations, served):
		if not requirement.done: return false
	return true

func objective(stations: Array, served: int, opened: bool) -> String:
	if phase == "preparing": return "Банкет · завершаем обычные заказы"
	if phase == "showcase": return "Инспектор · приготовь картофель на B или лучше"
	if phase == "service": return "Банкет · %d/%d гостей · %d/%d довольны" % [banquet_served, BANQUET_SERVED, banquet_good, BANQUET_GOOD]
	if stars > 0: return "Первая звезда! Расширь зал и открой кухню на двоих"
	var known := 0
	for station in stations: known += station.recipes.size()
	if known == 0: return "Первый показ · выбери блюдо и обучи бригаду"
	if not opened: return "Кафе закрыто · открой двери в меню кафе"
	if stations.size() < 2: return "Следующая цель · вторая стойка с бригадой — 120"
	if popularity < STAR_POPULARITY: return "Укрась кафе · популярность %d/%d для первой звезды" % [popularity, STAR_POPULARITY]
	if can_attempt(stations, served): return "Всё готово · пригласи инспектора первой звезды"
	return "Подготовь три блюда на B и обслужи 12 гостей"

func snapshot() -> Dictionary:
	var data := {}
	for key in ["cash", "popularity", "stars", "decorations", "expanded", "demand", "phase", "remaining", "banquet_spawned", "banquet_finished", "banquet_served", "banquet_good", "showcase_grade", "orders", "result", "return_open", "event_peer", "revision"]: data[key] = get(key)
	return data.duplicate(true)

func restore(data: Dictionary, resume_event := false) -> void:
	for key in snapshot():
		if data.has(key): set(key, data[key])
	if busy() and not resume_event:
		phase = "none"
		remaining = 0
		result = "Проверка прервана при выходе. Можно пригласить инспектора снова бесплатно."
