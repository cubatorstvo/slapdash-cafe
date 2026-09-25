extends RefCounted
const Legacy = preload("res://scripts/cafe_journey.gd")

static func current(p, stations: Array, served: int, opened: bool, service=null) -> Dictionary:
	if p.stars >= 1 and p.journey_auto_served < 1:
		var production: Array = []
		for station in stations:
			if not station.manual_station and not station.masterclass_station: production.append(station)
		if Legacy.worker_count(p, stations) == 0:
			var grow_step: Dictionary = Legacy.grow(p, stations)
			grow_step.chapter = "ПЕРВЫЙ ДОХОД КЛОНА"
			return grow_step
		if production.is_empty():
			var slot := 2
			while stations.any(func(station): return int(station.station_id) == slot): slot += 1
			var table_step: Dictionary = Legacy.buy(p, "counter", slot, "Подготовь первый производственный стол для созданного клона. После этого позови его к Шефу на личный урок.")
			table_step.chapter = "ПЕРВЫЙ ДОХОД КЛОНА"
			return table_step
		if production.all(func(station): return Legacy.crew_count(station) <= 0):
			var assign_step: Dictionary = Legacy.grow(p, stations)
			assign_step.chapter = "ПЕРВЫЙ ДОХОД КЛОНА"
			return assign_step
	return Legacy.current(p, stations, served, opened, service)
