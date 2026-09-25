extends "res://scripts/cafe_office_feature_core.gd"

func _mark_opened_feature_seen() -> void:
	if game == null or not is_instance_valid(game.service) or game.service.get("feature_access") == null: return
	var state: Dictionary = game.service.feature_access.page_access(tab)
	var feature_id := str(state.get("feature_id", ""))
	if bool(state.get("visible", false)) and not feature_id.is_empty(): game.service.feature_access.mark_seen(feature_id)

func open(page := "overview") -> void:
	super(page)
	_mark_opened_feature_seen()

func navigate(page: String) -> void:
	super(page)
	_mark_opened_feature_seen()

func overview_page(host: bool) -> void:
	super(host)
	var service = game.service
	var p = service.progress
	if not service.open_for_business or str(p.shift) != "open": return
	var shift_button := button(content, "Закончить смену досрочно", func(): send({"action":"business"}, true), host and not p.busy(), "Сначала заверши текущее событие." if p.busy() else "")
	content.move_child(shift_button, mini(1, content.get_child_count() - 1))
