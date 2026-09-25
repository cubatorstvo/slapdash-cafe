extends "res://scripts/cafe_progression_core.gd"

func objective(stations: Array, served: int, opened: bool) -> String:
	return str(preload("res://scripts/cafe_journey_access.gd").current(self, stations, served, opened).title)
