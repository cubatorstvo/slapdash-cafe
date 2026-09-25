extends "res://scripts/cafe_progression_core.gd"

const STARTER_SEQUENCE := ["sausage", "potato", "wine"]

func available_dishes() -> Array:
	if stars != 0: return super()
	var result: Array = ["sausage"]
	if "sausage" in tutorial_served: result.append("potato")
	if "potato" in tutorial_served: result.append("wine")
	return result

func _p5_structural_crew_ready(station) -> bool:
	if station == null or station.manual_station or station.masterclass_station: return false
	var roles := int(station.role_count())
	if roles <= 0 or station.crew.size() < roles: return false
	for role in range(roles):
		if role >= station.crew.size() or not station.crew[role] is Dictionary or int(station.crew[role].get("clone_id", 0)) <= 0: return false
	return true

func _p5_station_has_current_method(station, dish: String, require_b_plus := true) -> bool:
	if not _p5_structural_crew_ready(station): return false
	if not station.recipes.has(dish) or not station.missing_recipe_equipment(dish).is_empty(): return false
	var source: Dictionary = station.method_sources.get(dish, {}) if station.method_sources.get(dish, {}) is Dictionary else {}
	var clone_ids: Variant = source.get("clone_ids", [])
	if not clone_ids is Array or clone_ids.size() != station.role_count(): return false
	for role in range(station.role_count()):
		if role >= station.crew.size() or int(station.crew[role].get("clone_id", 0)) <= 0 or int(clone_ids[role]) != int(station.crew[role].get("clone_id", 0)): return false
	var report: Dictionary = station.recipes.get(dish, {}).get("quality", {})
	if not bool(report.get("present", false)): return false
	return not require_b_plus or str(report.get("grade", "D")) in ["B", "A", "S"]

func _p5_ready_dish_count_for(stations: Array, dishes: Array) -> int:
	var count := 0
	for dish in dishes:
		if stations.any(func(station): return _p5_station_has_current_method(station, str(dish), true)): count += 1
	return count

func _p5_ready_dish_count(stations: Array) -> int:
	return _p5_ready_dish_count_for(stations, STARTER_SEQUENCE)

func _p5_operating_crew_count(stations: Array) -> int:
	var count := 0
	for station in stations:
		if not _p5_structural_crew_ready(station): continue
		if station.dishes().any(func(dish): return _p5_station_has_current_method(station, str(dish), false)): count += 1
	return count

func _p5_type_crew_count(stations: Array, type_id: String) -> int:
	var count := 0
	for station in stations:
		if station != null and str(station.type_id) == type_id and _p5_structural_crew_ready(station): count += 1
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
	if stars == 2:
		var all_ready := _p5_ready_dish_count_for(stations, STARTER_SEQUENCE + ["meal"])
		var production := _p5_operating_crew_count(stations)
		return [
			{"text":"Три работающие станции: %d / 3" % mini(production, 3), "done":production >= 3},
			{"text":"Четыре освоенных способа B или лучше: %d / 4" % all_ready, "done":all_ready == 4},
			{"text":"Автоподачи после второй звезды: %d / %d" % [mini(third_star_auto_served, THIRD_STAR_AUTO_SERVED), THIRD_STAR_AUTO_SERVED], "done":third_star_auto_served >= THIRD_STAR_AUTO_SERVED},
			{"text":"Парная кухня обслужила: %d / %d" % [mini(journey_meals_served, THIRD_STAR_MEALS), THIRD_STAR_MEALS], "done":journey_meals_served >= THIRD_STAR_MEALS},
			{"text":"Популярность: %d / %d" % [popularity, THIRD_STAR_POPULARITY], "done":popularity >= THIRD_STAR_POPULARITY}
		]
	if stars == 3:
		var specialty_ready := _p5_ready_dish_count_for(stations, SPECIALTY_DISHES)
		var grill_crews := _p5_type_crew_count(stations, "grill_kitchen")
		return [
			{"text":"Специализированная кухня работает: %d / 1" % mini(grill_crews, 1), "done":grill_crews >= 1},
			{"text":"Три освоенных бургера B или лучше: %d / 3" % specialty_ready, "done":specialty_ready == 3},
			{"text":"Бургерная обслужила: %d / %d" % [mini(fourth_star_specialty_served, FOURTH_STAR_SPECIALTY_SERVED), FOURTH_STAR_SPECIALTY_SERVED], "done":fourth_star_specialty_served >= FOURTH_STAR_SPECIALTY_SERVED},
			{"text":"Автоподачи после третьей звезды: %d / %d" % [mini(fourth_star_auto_served, FOURTH_STAR_AUTO_SERVED), FOURTH_STAR_AUTO_SERVED], "done":fourth_star_auto_served >= FOURTH_STAR_AUTO_SERVED},
			{"text":"Популярность: %d / %d" % [popularity, FOURTH_STAR_POPULARITY], "done":popularity >= FOURTH_STAR_POPULARITY}
		]
	if stars == 4:
		var solyanka_ready := _p5_ready_dish_count_for(stations, ORCHESTRATION_DISHES)
		var solyanka_crews := _p5_type_crew_count(stations, "solyanka_kitchen")
		return [
			{"text":"Трёхролевая кухня работает: %d / 1" % mini(solyanka_crews, 1), "done":solyanka_crews >= 1},
			{"text":"Солянка освоена на B или лучше: %d / 1" % solyanka_ready, "done":solyanka_ready == 1},
			{"text":"Солянка обслужила: %d / %d" % [mini(fifth_star_solyanka_served, FIFTH_STAR_SOLYANKA_SERVED), FIFTH_STAR_SOLYANKA_SERVED], "done":fifth_star_solyanka_served >= FIFTH_STAR_SOLYANKA_SERVED},
			{"text":"Автоподачи после четвёртой звезды: %d / %d" % [mini(fifth_star_auto_served, FIFTH_STAR_AUTO_SERVED), FIFTH_STAR_AUTO_SERVED], "done":fifth_star_auto_served >= FIFTH_STAR_AUTO_SERVED}
		]
	return super(stations, served)

func objective(stations: Array, served: int, opened: bool) -> String:
	return str(preload("res://scripts/cafe_journey_access.gd").current(self, stations, served, opened).title)
