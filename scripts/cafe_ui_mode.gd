extends RefCounted
const WORLD := "world"
const STATION := "station"
const COOKBOOK := "cookbook"
const OFFICE := "office"
const INSTRUMENT := "instrument"
const PAUSE := "pause"
const SLEEP := "sleep"
const GAMEPLAY := WORLD
const MODES := [WORLD, STATION, COOKBOOK, OFFICE, INSTRUMENT, PAUSE, SLEEP]

static func resolve(game: Node) -> String:
	if game == null or not is_instance_valid(game): return WORLD
	var session: Variant = game.get("session")
	if session != null and is_instance_valid(session) and (session.sleep_scene_active() or session.local_sleeping()): return SLEEP
	if bool(game.get("session_paused")): return PAUSE
	var office: Variant = game.get("office")
	if office != null and is_instance_valid(office) and office.opened(): return OFFICE
	var cookbook: Variant = game.get("cookbook")
	if cookbook != null and is_instance_valid(cookbook) and bool(cookbook.opened): return COOKBOOK
	var laboratory: Variant = game.get("laboratory")
	if laboratory != null and is_instance_valid(laboratory) and is_instance_valid(laboratory.ui) and bool(laboratory.ui.opened()): return INSTRUMENT
	if game.has_method("awaiting_serving_confirmation") and bool(game.awaiting_serving_confirmation()): return INSTRUMENT
	var menu: Variant = game.get("menu")
	if menu != null and is_instance_valid(menu) and bool(menu.opened()): return INSTRUMENT
	var steam: Variant = game.get("steam")
	if steam != null and is_instance_valid(steam) and bool(steam.overlay_open): return INSTRUMENT
	if game.has_method("local_station"):
		var station: Variant = game.local_station()
		if station != null and is_instance_valid(station) and (bool(station.training.active()) or str(station.state) == "cooking"): return STATION
	return WORLD

static func current(game: Node) -> String:
	if game == null or not is_instance_valid(game): return WORLD
	return str(game.get_meta("ui_mode", resolve(game)))

static func world_hud(mode: String) -> bool:
	return mode in [WORLD, STATION]

static func apply(game: Node, mode: String) -> void:
	if game == null or not is_instance_valid(game): return
	var normalized := mode if mode in MODES else WORLD
	game.set_meta("ui_mode", normalized)
	var hud: Variant = game.get("hud")
	if hud != null and is_instance_valid(hud):
		if "presentation_mode" in hud: hud.presentation_mode = normalized
		var show_world := world_hud(normalized)
		_set_visible(hud, "Root/Top", show_world)
		_set_visible(hud, "Root/Bottom", show_world)
		_set_visible(hud, "Root/Crosshair", show_world)
		_set_visible(hud, "Root/Prompt", show_world)
		_set_visible(hud, "Root/VisitStatus", show_world)
		_set_visible(hud, "Root/Toast", show_world)
		var notice: CanvasItem = hud.get_node_or_null("Root/Notice")
		if notice != null: notice.visible = show_world and not str(notice.get("text")).is_empty()
		var event_feed: CanvasItem = hud.get_node_or_null("Root/EventFeed")
		if event_feed != null: event_feed.visible = show_world and bool(hud.get("event_feed_requested"))
		var recipe_panel: CanvasItem = hud.get_node_or_null("Root/RecipePanel")
		if recipe_panel != null: recipe_panel.visible = show_world and bool(hud.get("recipe_requested"))
		_set_visible(hud, "Root/PausePanel", normalized == PAUSE)
		var reading_alert: CanvasItem = hud.get_node_or_null("Root/ReadingAlert")
		if reading_alert != null: reading_alert.visible = normalized == COOKBOOK and not str(hud.get("reading_alert_message")).is_empty()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if show_world else Input.MOUSE_MODE_VISIBLE

static func sync(game: Node) -> String:
	var next := resolve(game)
	if current(game) != next: apply(game, next)
	return next

static func handle_key(game: Node, event: InputEvent) -> bool:
	if game == null or not is_instance_valid(game) or not (event is InputEventKey): return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo: return false
	var mode := resolve(game)
	if key_event.physical_keycode == KEY_B:
		var cookbook: Variant = game.get("cookbook")
		if cookbook == null or not is_instance_valid(cookbook): return false
		if mode == COOKBOOK: cookbook.close()
		elif mode in [WORLD, STATION]: cookbook.toggle()
		else: return false
		apply(game, resolve(game))
		return true
	if key_event.physical_keycode != KEY_ESCAPE: return false
	match mode:
		OFFICE:
			game.office.close()
		COOKBOOK:
			game.cookbook.close()
		PAUSE:
			game.toggle_pause()
		INSTRUMENT:
			if is_instance_valid(game.laboratory) and is_instance_valid(game.laboratory.ui) and game.laboratory.ui.opened():
				if not game.laboratory.ui.handle_input(key_event): return false
			elif game.awaiting_serving_confirmation():
				var station = game.local_station()
				if station == null or station.training.lead != game.session.local_id(): return false
				game.menu.close()
				game.session.request_action({"action":"resume","station":station.station_id})
			elif is_instance_valid(game.menu) and game.menu.opened(): game.menu.close()
			else: return false
		WORLD, STATION:
			game.toggle_pause()
		_:
			return false
	apply(game, resolve(game))
	return true

static func _set_visible(hud: Node, path: NodePath, value: bool) -> void:
	var node: CanvasItem = hud.get_node_or_null(path)
	if node != null: node.visible = value
