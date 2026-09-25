extends "res://scripts/cafe_progression_core.gd"

const STARTER_SEQUENCE := ["sausage", "potato", "wine"]

func available_dishes() -> Array:
	if stars != 0: return super()
	var result: Array = ["sausage"]
	if "sausage" in tutorial_served: result.append("potato")
	if "potato" in tutorial_served: result.append("wine")
	return result

func _p5_station_has_current_method(station, dish: String, require_b_plus := true) -> bool:
	if station == null or station.manual_station or station.masterclass_station or not station.ready_crew(): return false
	if not station.recipes.has(dish) or not station.missing_recipe_equipment(dish).is_empty(): return false
	var source: Dictionary = station.method_sources.get(dish, {}) if station.method_sources.get(dish, {}) is Dictionary else {}
	var clone_ids: Variant = source.get("clone_ids", [])
	if not clone_ids is Array or clone_ids.is_empty(): return false
	var report: Dictionary = station.recipes.get(dish, {}).get("quality", {})
	if not bool(report.get("present", false)): return false
	return not require_b_plus or str(report.get("grade", "D")) in ["B", "A", "S"]

func _p5_ready_dish_count(stations: Array) -> int:
	var count := 0
	for dish in STARTER_SEQUENCE:
		if stations.any(func(station): return _p5_station_has_current_method(station, dish, true)): count += 1
	return count

func _p5_operating_crew_count(stations: Array) -> int:
	var count := 0
	for station in stations:
		if station == null or station.manual_station or station.masterclass_station or not station.ready_crew(): continue
		if station.dishes().any(func(dish): return _p5_station_has_current_method(station, str(dish), false)): count += 1
	return count

func star_requirements(stations: Array, served: int) -> Array:
	if stars == 0:
		var learned := 0
		for dish in STARTER_SEQUENCE:
			if dish in tutorial_served: learned += 1
		return [
			{"text":"Лично обслужено: %d / 15" % manual_served, "done":manual_served >= 15},
			{"text":"Три стартовых блюда освоены: %d / 3" % learned, "done":learned == 3}
		]
	if stars == 1:
		var ready := _p5_ready_dish_count(stations)
		var crews := _p5_operating_crew_count(stations)
		return [
			{"text":"Популярность: %d / %d" % [popularity, STAR_POPULARITY], "done":popularity >= STAR_POPULARITY},
			{"text":"Обслужено гостей: %d / %d" % [served, REQUIRED_SERVED], "done":served >= REQUIRED_SERVED},
			{"text":"Две работающие бригады: %d / 2" % [mini(crews, 2)], "done":crews >= 2},
			{"text":"Три освоенных способа B или лучше: %d / 3" % ready, "done":ready == 3}
		]
	return super(stations, served)

func objective(stations: Array, served: int, opened: bool) -> String:
	return str(preload("res://scripts/cafe_journey_access.gd").current(self, stations, served, opened).title)
