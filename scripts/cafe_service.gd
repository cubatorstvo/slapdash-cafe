extends "res://scripts/cafe_service_feature_core.gd"

func start_highlights(id: int, peer: int) -> String:
	var error := _action_command_error("masterclass_watch", {"actor_id":peer})
	if not error.is_empty(): return error
	return super(id, peer)
