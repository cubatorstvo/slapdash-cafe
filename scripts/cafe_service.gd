extends "res://scripts/cafe_service_feature_core.gd"

const STARTER_DISH_SEQUENCE := ["sausage", "potato", "wine"]

func start_highlights(id: int, peer: int) -> String:
	var error := _action_command_error("masterclass_watch", {"actor_id":peer})
	if not error.is_empty(): return error
	return super(id, peer)

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
	if int(data.get("version", 0)) == SAVE_VERSION and data.get("progression", {}) is Dictionary and data.progression.get("feature_progress", {}) is Dictionary:
		progress.feature_progress = data.progression.feature_progress.duplicate(true)
		progression_director.restore(progress.feature_progress, true)
		feature_access.setup(self, progression_director)
	return true
