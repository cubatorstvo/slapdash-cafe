extends "res://scripts/progression/progression_director_core.gd"

func restore(data: Variant, authoritative_snapshot := false) -> void:
	if not authoritative_snapshot:
		super(data)
		return
	if not data is Dictionary: return
	var source: Dictionary = data
	cafe_id = str(source.get("cafe_id", ""))
	if cafe_id.is_empty(): cafe_id = _new_cafe_id()
	revision = maxi(0, int(source.get("revision", 0)))
	milestones.clear()
	unlocked_features.clear()
	announced_features.clear()
	var saved_milestones: Variant = source.get("milestones", {})
	if saved_milestones is Dictionary:
		for key in saved_milestones:
			var value: Variant = saved_milestones[key]
			if value is Dictionary: milestones[str(key)] = value.duplicate(true)
			elif bool(value): milestones[str(key)] = {}
	var saved_unlocks: Variant = source.get("unlocked_features", [])
	if saved_unlocks is Array:
		for raw_id in saved_unlocks: unlocked_features[str(raw_id)] = true
	var saved_announced: Variant = source.get("announced_features", [])
	if saved_announced is Array:
		for raw_id in saved_announced: announced_features[str(raw_id)] = true
	_publish_to_progress()
