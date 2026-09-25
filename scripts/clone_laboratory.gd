extends "res://scripts/clone_laboratory_core.gd"

func action(peer: int, data: Dictionary) -> String:
	var action_id := str(data.get("action", ""))
	if not action_id.is_empty() and game != null and is_instance_valid(game.get("service")) and game.service.has_method("check_feature_action"):
		var state: Dictionary = game.service.check_feature_action(action_id, {"actor_id":peer})
		if not bool(state.get("allowed", false)):
			var reason: String = str(game.service.feature_reason(state)) if game.service.has_method("feature_reason") else ""
			return reason if not reason.is_empty() else "Эта возможность сейчас недоступна."
	return super(peer, data)
