extends "res://scripts/cafe_progression_core.gd"

const STARTER_SEQUENCE := ["sausage", "potato", "wine"]

func available_dishes() -> Array:
	if stars != 0: return super()
	var result: Array = ["sausage"]
	if "sausage" in tutorial_served: result.append("potato")
	if "potato" in tutorial_served: result.append("wine")
	return result

func star_requirements(stations: Array, served: int) -> Array:
	if stars != 0: return super(stations, served)
	var learned := 0
	for dish in STARTER_SEQUENCE:
		if dish in tutorial_served: learned += 1
	return [
		{"text":"Лично обслужено: %d / 15" % manual_served, "done":manual_served >= 15},
		{"text":"Три стартовых блюда освоены: %d / 3" % learned, "done":learned == 3}
	]

func objective(stations: Array, served: int, opened: bool) -> String:
	return str(preload("res://scripts/cafe_journey_access.gd").current(self, stations, served, opened).title)
