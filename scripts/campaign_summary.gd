extends RefCounted
## Immutable campaign totals at the moment 5★ is awarded; optional goals use live state.

static func capture(service: Node) -> Dictionary:
	var workers: Array = service.clone_options()
	return {
		"stars":5, "day":int(service.progress.day),
		"guests_served":int(service.served), "order_revenue":int(service.revenue),
		"operating_kitchens":int(service.progress._p5_operating_crew_count(service.stations)),
		"workers":workers.size(), "inspection_served":int(service.progress.banquet_served),
		"inspection_good":int(service.progress.banquet_good)
	}

static func optional_goals(service: Node) -> Array[String]:
	var dishes: Array = service.progress.DISHES + ["meal"] + service.progress.SPECIALTY_DISHES + ["solyanka"]
	var quality_count := 0
	for dish in dishes:
		for station in service.stations:
			if not service.progress._p5_station_has_current_method(station, str(dish)): continue
			if str(station.recipes[dish].quality.grade) in ["A", "S"]:
				quality_count += 1
				break
	var workers: Array = service.clone_options()
	var fast_count := 0
	for worker in workers:
		if float(worker.tempo) >= 1.5: fast_count += 1
	var rest: Dictionary = service.progress.rest_report
	var rest_bonus := float(rest.get("bonus", 0.0))
	return [
		("✓ " if quality_count == dishes.size() else "○ ") + "Все 8 блюд на A или S · %d/8. Считаются способы действующих составов." % quality_count,
		("✓ " if rest_bonus >= 0.2 and int(rest.get("workers", 0)) > 0 else "○ ") + "Отдых с бонусом от 20%% · сейчас %d%%. Проверяется по последнему завершённому отдыху." % roundi(rest_bonus * 100.0),
		("✓ " if fast_count == workers.size() and fast_count > 0 else "○ ") + "Темп каждого работника от 150%% · %d/%d. Проверяется по текущему штату." % [fast_count, workers.size()]
	]
