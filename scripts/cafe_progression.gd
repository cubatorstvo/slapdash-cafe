extends RefCounted
## Cafe progression is owned by the host; records remain owned by each station.
const DISHES := ["wine", "potato", "sausage"]
const DECOR := {
	"sign": {"name": "Вывеска «Мы почти умеем»", "price": 45, "popularity": 10, "description": "Заметная вывеска у входа."},
	"lights": {"name": "Гирлянда на честном слове", "price": 40, "popularity": 15, "description": "Четыре крепления на стене: развесь ночью."},
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
const SHIFT_SECONDS := 480.0
const LAB_PRICES := [40, 60, 80]
var free_clones := 0
var free_workers: Array = []
var next_clone_id := 1
var lab_upgrades: Array = []
var starter_reward := false
var deliveries: Array = []
var next_delivery_id := 1
var garland_owned := false
var day := 1
var shift := "morning"
var shift_elapsed := 0.0
var manual_served := 0
var lab_stage := 0
var lab_step := -1
var tasting_done: Array = []
var tutorial_served: Array = []
var garland_points: Array = []
var garland_builder := 0
var garland_complete := false
var cash := 20
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

func busy() -> bool: return phase in ["preparing", "showcase", "service", "tasting"]
func arrival_interval() -> float: return maxf(8.0, 18.0 - popularity * 0.20)
func available_dishes() -> Array: return DISHES + (["meal"] if stars >= 2 else [])
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
	if stars == 0:
		return [{"text": "Лаборатория: %d / 3" % lab_stage, "done": lab_stage >= 3}, {"text": "Лично обслужено: %d / 15" % manual_served, "done": manual_served >= 15}]
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
		{"text": "Две бригады: %d / 2" % mini(stations.filter(func(s): return not s.manual_station and s.ready_crew()).size(), 2), "done": stations.filter(func(s): return not s.manual_station and s.ready_crew()).size() >= 2},
		{"text": "Три блюда с записью B или лучше: %d / 3" % ready.size(), "done": ready.size() == 3}
	]

func can_attempt(stations: Array, served: int) -> bool:
	if stars >= 2 or busy() or shift not in ["morning", "open"]: return false
	for requirement in star_requirements(stations, served):
		if not requirement.done: return false
	return true

func objective(stations: Array, served: int, opened: bool) -> String:
	if phase == "tasting": return "Дегустатор · блюдо %d/3 на B или лучше" % (tasting_done.size() + 1)
	if shift == "night": return "Ночь · лаборатория %d/3 · следующий день у двери отдыха" % lab_stage if stars == 0 else "Ночь · обустрой кафе или отдохни до утра"
	if shift == "closing": return "Заканчиваем последние заказы · затем ночной перерыв"
	if stars == 0:
		if not starter_reward: return "Первый гость → соус в подарок · открой кафе у компьютера"
		if can_attempt(stations, served): return "Всё готово · пригласи дегустатора у компьютера"
		return "Открой кафе · покупки у компьютера" if not opened else "Гости %d/15 · лаборатория %d/3 · оборудование в компьютере" % [manual_served, lab_stage]

	if phase == "preparing": return "Банкет · завершаем обычные заказы"
	if phase == "showcase": return "Инспектор · приготовь картофель на B или лучше"
	if phase == "service": return "Банкет · %d/%d гостей · %d/%d довольны" % [banquet_served, BANQUET_SERVED, banquet_good, BANQUET_GOOD]
	if stars >= 2: return "Две звезды · парная кухня и усилители лаборатории доступны в магазине"
	var known := 0
	for station in stations: known += station.recipes.size()
	if stations.size() == 1: return "Первая звезда · купи стойку с клонами за 120"
	if known == 0: return "Первый показ · выбери блюдо и обучи бригаду"
	if not opened: return "Кафе закрыто · открой двери в меню кафе"
	if stations.size() < 2: return "Следующая цель · вторая стойка с бригадой — 120"
	if popularity < STAR_POPULARITY: return "Укрась кафе · популярность %d/%d для второй звезды" % [popularity, STAR_POPULARITY]
	if can_attempt(stations, served): return "Всё готово · пригласи инспектора второй звезды"
	return "Подготовь три блюда на B и обслужи 12 гостей"

func snapshot() -> Dictionary:
	var data := {}
	for key in ["free_workers", "next_clone_id", "lab_upgrades", "free_clones", "starter_reward", "deliveries", "next_delivery_id", "garland_owned", "day", "shift", "shift_elapsed", "manual_served", "lab_stage", "lab_step", "tasting_done", "tutorial_served", "garland_points", "garland_builder", "garland_complete", "cash", "popularity", "stars", "decorations", "expanded", "demand", "phase", "remaining", "banquet_spawned", "banquet_finished", "banquet_served", "banquet_good", "showcase_grade", "orders", "result", "return_open", "event_peer", "revision"]: data[key] = get(key)
	return data.duplicate(true)

func restore(data: Dictionary, resume_event := false) -> void:
	for key in snapshot():
		if data.has(key): set(key, data[key])
	if busy() and not resume_event:
		phase = "none"
		remaining = 0
		result = "Проверка прервана при выходе. Можно пригласить инспектора снова бесплатно."

func recover_deliveries() -> void:
	for parcel in deliveries:
		parcel.owner = 0
	if garland_complete: garland_owned = true
	garland_builder = 0
