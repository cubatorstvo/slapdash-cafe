extends RefCounted
## Cafe progression is owned by the host; records remain owned by each station.
const DISHES := ["wine", "potato", "sausage"]
const SPECIALTY_DISHES := ["burger", "cheeseburger", "spicy_burger"]
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
const THIRD_STAR_POPULARITY := 40
const THIRD_STAR_AUTO_SERVED := 10
const THIRD_STAR_MEALS := 3
const BIG_LUNCH_SECONDS := 240.0
const BIG_LUNCH_GUESTS := 14
const BIG_LUNCH_SERVED := 11
const BIG_LUNCH_GOOD := 8
const BIG_LUNCH_REWARD := 300
const SPECIALTY_EXPANSION_PRICE := 260
const GRILL_KITCHEN_PRICE := 380
const FOURTH_STAR_POPULARITY := 55
const FOURTH_STAR_AUTO_SERVED := 14
const FOURTH_STAR_SPECIALTY_SERVED := 6
const FOURTH_STAR_SECONDS := 300.0
const FOURTH_STAR_GUESTS := 18
const FOURTH_STAR_SERVED := 15
const FOURTH_STAR_GOOD := 11
const FOURTH_STAR_REWARD := 450
const SHIFT_SECONDS := 480.0
const CHEF_ORDER_INTERVALS := [Vector2(25.0,35.0),Vector2(45.0,60.0),Vector2(75.0,95.0),Vector2(105.0,130.0),Vector2(140.0,175.0),Vector2(180.0,220.0)]
const CHEF_ORDER_PREMIUM := [1.0,1.5,2.2,3.0,3.8,4.8]
const LAB_PRICES := [40, 60, 80]
var journey_auto_served := 0
var journey_meals_served := 0
var third_star_auto_served := 0
var fourth_star_auto_served := 0
var fourth_star_specialty_served := 0
var visit: Dictionary = {}
var visit_serial := 0
var visit_next_day := 0
var visit_next_kind := "critics"
var free_clones := 0
var free_workers: Array = []
var next_clone_id := 1
var lab_upgrades: Array = []
var lab_tier := 0
var lab_formula_tempo := 0.70
var lab_formula_version := 0
var lab_sample := {}
var lab_sample_serial := 0
var lab_pots: Array = []
var lab_production := {"enabled":false,"target":2,"reserve":150}
var lab_calibration := preload("res://scripts/laboratory_progression.gd").blank_calibration()
var lab_auto_calibration := false
var starter_reward := false
var deliveries: Array = []
var next_delivery_id := 1
var garland_owned := false
var lounge_tier := 0
var lounge_items: Array = ["sofa"]
var lounge_upgrades: Array = []
var rest_multiplier := 1.0
var rest_report := {}
var night_elapsed := 0.0
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
var specialized_expanded := false
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
func chef_order_stage() -> int: return clampi(stars,0,5)
func chef_order_delay(rng: RandomNumberGenerator) -> float:
	var window: Vector2=CHEF_ORDER_INTERVALS[chef_order_stage()]
	return rng.randf_range(window.x,window.y)
func chef_order_premium() -> float: return float(CHEF_ORDER_PREMIUM[chef_order_stage()])
func available_dishes() -> Array: return DISHES + (["meal"] if stars >= 2 else []) + (SPECIALTY_DISHES if stars >= 3 else [])
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

func _dish_ready(stations: Array, dish: String) -> bool:
	for station in stations:
		var report: Dictionary = station.recipes.get(dish, {}).get("quality", {})
		if report.get("present", false) and report.get("grade", "D") in ["B", "A", "S"]: return true
	return false

func _ready_dish_count(stations: Array, dishes: Array) -> int:
	var count := 0
	for dish in dishes:
		if _dish_ready(stations, str(dish)): count += 1
	return count

func _ready_automatic_count(stations: Array) -> int:
	return stations.filter(func(s): return not s.manual_station and s.ready_crew()).size()

func star_requirements(stations: Array, served: int) -> Array:
	if stars == 0:
		return [{"text": "Лаборатория: %d / 3" % lab_stage, "done": lab_stage >= 3}, {"text": "Лично обслужено: %d / 15" % manual_served, "done": manual_served >= 15}]
	if stars == 1:
		var ready: int = _ready_dish_count(stations, DISHES)
		var crews: int = _ready_automatic_count(stations)
		return [
			{"text": "Популярность: %d / %d" % [popularity, STAR_POPULARITY], "done": popularity >= STAR_POPULARITY},
			{"text": "Обслужено гостей: %d / %d" % [served, REQUIRED_SERVED], "done": served >= REQUIRED_SERVED},
			{"text": "Две бригады: %d / 2" % [mini(crews, 2)], "done": crews >= 2},
			{"text": "Три блюда с записью B или лучше: %d / 3" % ready, "done": ready == 3}
		]
	if stars == 2:
		var all_ready: int = _ready_dish_count(stations, DISHES + ["meal"])
		var production: int = _ready_automatic_count(stations)
		return [
			{"text": "Три работающие станции: %d / 3" % mini(production, 3), "done": production >= 3},
			{"text": "Четыре блюда с записью B или лучше: %d / 4" % all_ready, "done": all_ready == 4},
			{"text": "Автоподачи после второй звезды: %d / %d" % [mini(third_star_auto_served, THIRD_STAR_AUTO_SERVED), THIRD_STAR_AUTO_SERVED], "done": third_star_auto_served >= THIRD_STAR_AUTO_SERVED},
			{"text": "Парная кухня обслужила: %d / %d" % [mini(journey_meals_served, THIRD_STAR_MEALS), THIRD_STAR_MEALS], "done": journey_meals_served >= THIRD_STAR_MEALS},
			{"text": "Популярность: %d / %d" % [popularity, THIRD_STAR_POPULARITY], "done": popularity >= THIRD_STAR_POPULARITY}
		]
	if stars == 3:
		var specialty_ready: int = _ready_dish_count(stations, SPECIALTY_DISHES)
		var grill_crews: int = stations.filter(func(s): return s.type_id=="grill_kitchen" and not s.manual_station and s.ready_crew()).size()
		return [
			{"text":"Специализированная кухня работает: %d / 1"%mini(grill_crews,1),"done":grill_crews>=1},
			{"text":"Три бургера с записью B или лучше: %d / 3"%specialty_ready,"done":specialty_ready==3},
			{"text":"Бургерная обслужила: %d / %d"%[mini(fourth_star_specialty_served,FOURTH_STAR_SPECIALTY_SERVED),FOURTH_STAR_SPECIALTY_SERVED],"done":fourth_star_specialty_served>=FOURTH_STAR_SPECIALTY_SERVED},
			{"text":"Автоподачи после третьей звезды: %d / %d"%[mini(fourth_star_auto_served,FOURTH_STAR_AUTO_SERVED),FOURTH_STAR_AUTO_SERVED],"done":fourth_star_auto_served>=FOURTH_STAR_AUTO_SERVED},
			{"text":"Популярность: %d / %d"%[popularity,FOURTH_STAR_POPULARITY],"done":popularity>=FOURTH_STAR_POPULARITY}
		]
	return []

func can_attempt(stations: Array, served: int) -> bool:
	if stars >= 4 or busy() or shift not in ["morning", "open"]: return false
	for requirement in star_requirements(stations, served):
		if not requirement.done: return false
	return true

func inspection_orders() -> Array:
	if stars == 3:
		return ["meal","wine","burger","potato","sausage","meal","burger","cheeseburger","spicy_burger","burger","cheeseburger","spicy_burger","meal","potato","cheeseburger","burger","sausage","spicy_burger"]
	if stars == 2:
		return ["meal", "wine", "potato", "sausage", "meal", "wine", "potato", "sausage", "meal", "potato", "wine", "sausage", "meal", "potato"]
	return ["wine", "potato", "sausage", "sausage", "wine", "potato", "potato", "sausage", "wine"]

func inspection_chef_indices() -> Array:
	return [1,13,16] if stars == 3 else [1, 6, 11] if stars == 2 else [0, 3, 6]

func inspection_seconds() -> float:
	return FOURTH_STAR_SECONDS if stars == 3 else BIG_LUNCH_SECONDS if stars == 2 else BANQUET_SECONDS

func inspection_guest_count() -> int:
	return FOURTH_STAR_GUESTS if stars == 3 else BIG_LUNCH_GUESTS if stars == 2 else BANQUET_GUESTS

func inspection_served_target() -> int:
	return FOURTH_STAR_SERVED if stars == 3 else BIG_LUNCH_SERVED if stars == 2 else BANQUET_SERVED

func inspection_good_target() -> int:
	return FOURTH_STAR_GOOD if stars == 3 else BIG_LUNCH_GOOD if stars == 2 else BANQUET_GOOD

func inspection_spawn_interval(next_index := -1) -> float:
	if stars == 3:
		var index: int=banquet_spawned if int(next_index)<0 else int(next_index)
		return 6.0 if index<6 else 3.0 if index<12 else 4.0
	return 4.0 if stars == 2 else 8.0

func inspection_name() -> String:
	return "Три волны" if stars == 3 else "Большой обед" if stars == 2 else "Делегация"

func objective(stations: Array, served: int, opened: bool) -> String:
	return str(preload("res://scripts/cafe_journey.gd").current(self,stations,served,opened).title)

func snapshot() -> Dictionary:
	var data := {}
	for key in ["journey_auto_served", "journey_meals_served", "third_star_auto_served", "fourth_star_auto_served", "fourth_star_specialty_served", "visit", "visit_serial", "visit_next_day", "visit_next_kind", "lab_tier", "lab_formula_tempo", "lab_formula_version", "lab_sample", "lab_sample_serial", "lab_pots", "lab_production", "lab_calibration", "lab_auto_calibration", "lounge_tier", "lounge_items", "lounge_upgrades", "rest_multiplier", "rest_report", "night_elapsed", "free_workers", "next_clone_id", "lab_upgrades", "free_clones", "starter_reward", "deliveries", "next_delivery_id", "garland_owned", "day", "shift", "shift_elapsed", "manual_served", "lab_stage", "lab_step", "tasting_done", "tutorial_served", "garland_points", "garland_builder", "garland_complete", "cash", "popularity", "stars", "decorations", "expanded", "specialized_expanded", "demand", "phase", "remaining", "banquet_spawned", "banquet_finished", "banquet_served", "banquet_good", "showcase_grade", "orders", "result", "return_open", "event_peer", "revision"]: data[key] = get(key)
	return data.duplicate(true)

func restore(data: Dictionary, resume_event := false) -> void:
	for key in snapshot():
		if data.has(key): set(key, data[key])
	lab_tier=clampi(lab_tier,0,2)
	lab_formula_tempo=clampf(lab_formula_tempo,0.70,10.0)
	lounge_tier=clampi(lounge_tier,0,2)
	rest_multiplier=clampf(rest_multiplier,1.0,1.30)
	if busy() and not resume_event:
		phase = "none"
		remaining = 0
		result = "Проверка прервана при выходе. Можно пригласить инспектора снова бесплатно."

func recover_deliveries() -> void:
	for parcel in deliveries:
		parcel.owner = 0
	if garland_complete: garland_owned = true
	garland_builder = 0
