extends PanelContainer

signal continue_requested

func _ready() -> void:
	$Margin/Column/Continue.pressed.connect(func() -> void: continue_requested.emit())

func present(service: Node) -> void:
	var result: Dictionary = service.progress.campaign_result
	$Margin/Column/Period.text = "Итог на момент получения 5★ · день %d" % int(result.get("day", service.progress.day))
	var values: Array = [5, int(result.get("guests_served", 0)), int(result.get("order_revenue", 0)), int(result.get("operating_kitchens", 0)), int(result.get("workers", 0))]
	for index in range(values.size()):
		var label: Label = get_node("Margin/Column/Metrics/Value%d" % index)
		label.text = "%d / 5" % values[index] if index == 0 else str(values[index])
	$Margin/Column/Inspection.text = "День пяти звёзд: %d подач · %d оценок B или выше" % [int(result.get("inspection_served", 0)), int(result.get("inspection_good", 0))]
	var goals: Array[String] = load("res://scripts/campaign_summary.gd").optional_goals(service)
	$Margin/Column/Goals.text = "\n\n".join(goals)
