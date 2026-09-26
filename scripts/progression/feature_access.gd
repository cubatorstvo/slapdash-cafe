extends "res://scripts/progression/feature_access_core.gd"

var _retired_generations: Dictionary = {}

func _milestone_hint(milestone_id: String) -> String:
	var hints := {
		"first_sausage_served":"Обслужить первый заказ сосиски",
		"first_potato_served":"Обслужить первый заказ картофеля",
		"first_star_earned":"Получить первую звезду",
		"repeat_manual_clone_growth_completed":"Завершить два ручных выращивания",
		"first_video_trained_auto_served":"Получить автоподачу от обученного по видео состава",
		"first_group_training_completed":"Обучить минимум два стола одним просмотром",
		"first_group_trained_auto_served":"Получить автоподачу после группового просмотра",
		"first_recalibration_completed":"Реально повысить темп работника рекалибровкой",
		"first_pair_kitchen_auto_served":"Получить автоподачу парной кухни",
		"first_specialty_kitchen_auto_served":"Получить автоподачу бургерной",
		"first_solyanka_auto_served":"Получить автоподачу солянки",
	}
	return str(hints[milestone_id]) if hints.has(milestone_id) else super(milestone_id)

func setup(owner_service: Node, director = null) -> void:
	_retired_generations.clear()
	super(owner_service, director)

func _sync_from_progress_snapshot() -> void:
	if service == null or service.get("progress") == null or progression_director == null: return
	var progress = service.progress
	var raw: Variant = progress.get("feature_progress")
	if not raw is Dictionary or raw.is_empty(): return
	var epoch := str(progress.get("world_epoch"))
	var incoming_cafe := str(raw.get("cafe_id", ""))
	var incoming_revision := int(raw.get("revision", 0))
	var incoming_generation := _generation_key(epoch, incoming_cafe)
	var current_generation := _generation_key(_world_epoch_seen, _cafe_id_seen)
	if incoming_generation != current_generation:
		if _retired_generations.has(incoming_generation): return
		if not current_generation.is_empty(): _retired_generations[current_generation] = true
		progression_director.restore(raw, true)
		_capture_sync_stamp()
	elif incoming_revision > _revision_seen:
		progression_director.restore(raw, true)
		_capture_sync_stamp()

func _generation_key(epoch: String, cafe: String) -> String:
	return "" if epoch.is_empty() and cafe.is_empty() else epoch + "|" + cafe
