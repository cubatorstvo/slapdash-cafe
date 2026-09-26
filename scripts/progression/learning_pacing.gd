extends Node

const Core = preload("res://scripts/progression/learning_pacing_core.gd")
const UiMode = preload("res://scripts/cafe_ui_mode.gd")
const CafeStyle = preload("res://scripts/cafe_theme.gd")
const STORE_PATH := "user://p5_learning_pacing.cfg"

var _game: Node
var _cafe_id := ""
var _player_key := ""
var _seen: Dictionary = {}
var _known_sets: Dictionary = {"features":{},"milestones":{}}
var _queued_ids: Dictionary = {}
var _pending: Array[Dictionary] = []
var _current: Dictionary = {}
var _store := ConfigFile.new()
var _layer: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _body: Label

func _ready() -> void:
	process_priority = 100
	_load_identity()
	_build_overlay()

func _process(_delta: float) -> void:
	if not is_instance_valid(_game): _bind_current_scene()
	if not is_instance_valid(_game): _panel.hide(); return
	var snapshot := _feature_snapshot()
	var cafe_id := str(snapshot.get("cafe_id", ""))
	if cafe_id.is_empty(): _panel.hide(); return
	if cafe_id != _cafe_id: _bind_cafe(cafe_id, snapshot)
	_collect_new(snapshot)
	if _current.is_empty() and not _pending.is_empty():
		_current = _pending.pop_front()
		_queued_ids.erase(str(_current.get("id", "")))
		_save_local_state()
	if _current.is_empty(): _panel.hide(); return
	if not Core.can_present(_presentation_state()): _panel.hide(); return
	_show_current()

func _unhandled_input(event: InputEvent) -> void:
	if _current.is_empty() or not _panel.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		mark_current_seen()
		get_viewport().set_input_as_handled()

func current_task() -> Dictionary:
	if not is_instance_valid(_game): return {}
	var service: Variant = _game.get("service")
	if not is_instance_valid(service): return {}
	return preload("res://scripts/cafe_journey.gd").current(service.get("progress"), service.get("stations"), int(service.get("served")), bool(service.get("open_for_business")), service)

func mark_current_seen() -> void:
	if _current.is_empty(): return
	var explanation_id := str(_current.get("id", ""))
	if not explanation_id.is_empty(): _seen[explanation_id] = true
	_current.clear()
	_panel.hide()
	_save_local_state()

func _bind_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null or not _has_property(scene, "service") or not _has_property(scene, "hud"): return
	_game = scene

func _feature_snapshot() -> Dictionary:
	if not is_instance_valid(_game): return {}
	var service: Variant = _game.get("service")
	if not is_instance_valid(service): return {}
	var progress: Variant = service.get("progress")
	if progress == null: return {}
	var snapshot: Variant = progress.get("feature_progress")
	return snapshot if snapshot is Dictionary else {}

func _bind_cafe(cafe_id: String, snapshot: Dictionary) -> void:
	if not _cafe_id.is_empty(): _save_local_state()
	_cafe_id = cafe_id
	_pending.clear(); _queued_ids.clear(); _current.clear(); _panel.hide()
	_store = ConfigFile.new()
	_store.load(STORE_PATH)
	var section := _section()
	var returning := _store.has_section(section)
	_seen.clear()
	for raw_id in _store.get_value(section, "seen", []): _seen[str(raw_id)] = true
	_known_sets = Core.snapshot_sets(snapshot)
	if returning:
		for raw_id in _store.get_value(section, "pending", []):
			var definition := Core.explanation_by_id(str(raw_id))
			if not definition.is_empty(): _enqueue(definition, false)
	else:
		var catchup := Core.collapse_catchup(snapshot, _seen)
		for explanation_id in catchup.get("skip_ids", []): _seen[str(explanation_id)] = true
		var current: Variant = catchup.get("current", {})
		if current is Dictionary and not current.is_empty(): _enqueue(current, false)
	_save_local_state()

func _collect_new(snapshot: Dictionary) -> void:
	var added := false
	for definition in Core.collect_new(snapshot, _known_sets, _seen, _queued_ids):
		_enqueue(definition, false)
		added = true
	_known_sets = Core.snapshot_sets(snapshot)
	if added: _save_local_state()

func _enqueue(definition: Dictionary, save_now := true) -> void:
	var explanation_id := str(definition.get("id", ""))
	if explanation_id.is_empty() or _seen.has(explanation_id) or _queued_ids.has(explanation_id): return
	if not _current.is_empty() and str(_current.get("id", "")) == explanation_id: return
	_queued_ids[explanation_id] = true
	_pending.append(definition.duplicate(true))
	if save_now: _save_local_state()

func _presentation_state() -> Dictionary:
	var station: Variant = _game.call("local_station") if _game.has_method("local_station") else null
	var training_active := false
	var lesson_active := false
	if is_instance_valid(station):
		var training: Variant = station.get("training")
		if training != null and training.has_method("active"):
			training_active = bool(training.call("active"))
			lesson_active = training_active and str(training.get("purpose")) == "lesson"
	var session: Variant = _game.get("session")
	var sleeping := is_instance_valid(session) and ((session.has_method("local_sleeping") and bool(session.call("local_sleeping"))) or (session.has_method("sleep_scene_active") and bool(session.call("sleep_scene_active"))))
	var service: Variant = _game.get("service")
	var inspection := false
	if is_instance_valid(service):
		var progress: Variant = service.get("progress")
		if progress != null:
			var visit: Variant = progress.get("visit")
			inspection = visit is Dictionary and str(visit.get("phase", "")) == "active"
	var hud: Variant = _game.get("hud")
	var notice: Variant = hud.get("notice") if is_instance_valid(hud) else null
	var urgent_notice := is_instance_valid(notice) and not str(notice.get("text")).strip_edges().is_empty()
	return {
		"ui_mode":"world" if UiMode.resolve(_game) == UiMode.WORLD else "busy",
		"input_blocked":bool(_game.call("input_blocked")) if _game.has_method("input_blocked") else false,
		"holding_item":not str(_game.get("anchored_item")).is_empty() if _has_property(_game, "anchored_item") else false,
		"cooking":training_active and not lesson_active,
		"teaching":lesson_active,
		"confirming":bool(_game.call("awaiting_serving_confirmation")) if _game.has_method("awaiting_serving_confirmation") else false,
		"inspection":inspection,
		"sleep":sleeping,
		"urgent_notice":urgent_notice
	}

func _show_current() -> void:
	_title.text = str(_current.get("title", "Новая возможность"))
	_body.text = str(_current.get("text", "")) + "\nF1 — понятно"
	_panel.show()

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-390, 96)
	_panel.custom_minimum_size = Vector2(360, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.theme = CafeStyle.make()
	_layer.add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", CafeStyle.GOLD)
	column.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 330
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body)
	_panel.hide()

func _load_identity() -> void:
	_store.load(STORE_PATH)
	_player_key = str(_store.get_value("identity", "player_key", ""))
	if _player_key.is_empty():
		_player_key = Crypto.new().generate_random_bytes(16).hex_encode()
		_store.set_value("identity", "player_key", _player_key)
		_store.save(STORE_PATH)

func _save_local_state() -> void:
	if _cafe_id.is_empty(): return
	_store.set_value(_section(), "seen", _sorted_true_keys(_seen))
	var pending_ids: Array[String] = []
	if not _current.is_empty(): pending_ids.append(str(_current.get("id", "")))
	for definition in _pending: pending_ids.append(str(definition.get("id", "")))
	_store.set_value(_section(), "pending", pending_ids)
	_store.save(STORE_PATH)

func _section() -> String: return "cafe:%s:player:%s" % [_cafe_id, _player_key]

func _sorted_true_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in source:
		if bool(source[key]): result.append(str(key))
	result.sort()
	return result

func _has_property(target: Object, property_name: String) -> bool:
	if target == null: return false
	for property in target.get_property_list():
		if str(property.get("name", "")) == property_name: return true
	return false
