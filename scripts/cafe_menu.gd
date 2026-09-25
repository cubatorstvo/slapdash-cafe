extends "res://scripts/cafe_menu_core.gd"

func _feature_visible(feature_id: String) -> bool:
	if game == null or not is_instance_valid(game.service) or game.service.get("feature_access") == null: return false
	return bool(game.service.feature_access.access(feature_id).get("visible", false))

func show_station(station: Node3D) -> void:
	super(station)
	_apply_feature_visibility()

func _apply_feature_visibility() -> void:
	if not is_instance_valid(training_box): return
	var recording := _feature_visible("video_recording")
	var training := _feature_visible("video_training")
	for node in training_box.find_children("*", "Control", true, false):
		var text := ""
		if node is Button: text = (node as Button).text
		elif node is Label: text = (node as Label).text
		if text.is_empty(): continue
		var lowered := text.to_lower()
		if not recording and ("мастер-класс" in lowered or "мастер-классы" in lowered):
			node.hide()
			continue
		if not training and (text == "Обучение и группа" or "обучение бригад" in lowered): node.hide()
