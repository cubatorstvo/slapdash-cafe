extends "res://scripts/cafe_service_feature_core.gd"

const STARTER_DISH_SEQUENCE := ["sausage", "potato", "wine"]
const STANDARD_FORMULA_TEMPO := 1.0

func _ready() -> void:
	super()
	if progress.shift == "morning":
		progress.shift = "open"
		open_for_business = true
		spawn_clock = 2.0

func _ensure_standard_formula() -> void:
	if progress.stars < 1 or progress.lab_stage < 3 or progress.lab_formula_version > 0: return
	progress.lab_formula_tempo = STANDARD_FORMULA_TEMPO
	progress.lab_formula_version = 1
	progress.revision += 1
	progression_director.observe("standard_formula_available", {"tempo":STANDARD_FORMULA_TEMPO,"version":progress.lab_formula_version})

func _refresh_progression() -> void:
	_ensure_standard_formula()
	super()

func start_highlights(id: int, peer: int) -> String:
	var error := _action_command_error("masterclass_watch", {"actor_id":peer})
	if not error.is_empty(): return error
	return super(id, peer)

func create_clone(tempo := 1.0, prepaid := false) -> String:
	var clone_id := int(progress.next_clone_id)
	var manual_growth := progress.stars == 1 and "lab_production" not in progress.lab_upgrades
	var result: String = super(tempo, prepaid)
	if result.is_empty() and manual_growth:
		progression_director.observe("manual_clone_growth_completed", {"clone_id":clone_id,"ordinal":clone_id,"tempo":tempo})
		_refresh_progression()
	return result

func _starter_equipped(station: Node3D, dish: String) -> bool:
	return Definition.missing_equipment(dish, station.equipment, station.upgrades).is_empty()

func chef_order_recipe() -> String:
	if progress.stars != 0: return super()
	var personal: Node3D = by_id(1)
	if personal == null or not personal.manual_station: return ""
	for dish in STARTER_DISH_SEQUENCE:
		if dish in progress.tutorial_served: continue
		if _starter_equipped(personal, dish): return dish
		break
	var fallback: Array = []
	for dish in STARTER_DISH_SEQUENCE:
		if dish in progress.tutorial_served and _starter_equipped(personal, dish): fallback.append(dish)
	return "" if fallback.is_empty() else str(fallback[rng.randi_range(0, fallback.size() - 1)])

func _count_completed_customer(customer: Dictionary, station: Node3D) -> void:
	super(customer, station)
	if not station.manual_station: return
	progression_director.observe("manual_served", {"dish":str(customer.get("dish", "")), "station_id":station.station_id})
	if str(customer.get("dish", "")) in STARTER_DISH_SEQUENCE:
		progression_director.observe("starter_dish_served", {"dish":str(customer.dish), "station_id":station.station_id})
	_refresh_progression()

func load_data(data: Dictionary) -> bool:
	if not super(data): return false
	if progress.shift == "morning":
		progress.shift = "open"
		open_for_business = true
		spawn_clock = 2.0
	if int(data.get("version", 0)) == SAVE_VERSION and data.get("progression", {}) is Dictionary and data.progression.get("feature_progress", {}) is Dictionary:
		progress.feature_progress = data.progression.feature_progress.duplicate(true)
		progression_director.restore(progress.feature_progress, true)
		feature_access.setup(self, progression_director)
	return true
