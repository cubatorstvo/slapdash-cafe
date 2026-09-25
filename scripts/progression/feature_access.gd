extends "res://scripts/progression/feature_access_core.gd"

var _retired_generations: Dictionary = {}

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
