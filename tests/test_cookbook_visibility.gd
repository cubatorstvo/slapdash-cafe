extends SceneTree
const UiMode = preload("res://scripts/cafe_ui_mode.gd")
var failed := false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", message)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	return event

func page_has_text(page: Control, text: String) -> bool:
	for node in page.column.find_children("*", "Label", true, false):
		if str(node.text).contains(text): return true
	return false

func click_control(game, side: int, control: Control) -> void:
	check(control != null, "Clickable cookbook control exists")
	if control == null: return
	var uv: Vector2 = game.cookbook.physical.control_uv(side, control)
	var screen: Vector2 = game.cookbook.physical.page_to_screen(game.camera, side, uv)
	var hit: Dictionary = game.cookbook.physical.hit_from_screen(game.camera, screen)
	check(not hit.is_empty(), "Clickable cookbook control is on a visible physical page")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	game.cookbook._input(down)
	var up := down.duplicate()
	up.pressed = false
	game.cookbook._input(up)

func set_stars(game, stars: int) -> void:
	var p = game.service.progress
	p.stars = stars
	if stars >= 1:
		p.cafe_inaugurated = true
		p.tutorial_served = ["sausage", "potato", "wine"]
		p.lab_stage = 3
		p.next_clone_id = maxi(p.next_clone_id, 2)
	if stars >= 2: p.expanded = true
	if stars >= 3: p.specialized_expanded = true
	if stars >= 4: p.orchestration_expanded = true
	game.service._refresh_progression()

func run() -> void:
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	game.menu.close()
	await process_frame
	game.camera.rotation.x = 0.52
	set_stars(game, 0)
	game.hud.set_event_feed(["Тестовое событие"])
	game.hud.recipe_requested = true
	game.hud.recipe_panel.show()
	game.cookbook.toggle()
	await process_frame
	check(game.hud.presentation_mode == UiMode.COOKBOOK, "Cookbook owns the shared presentation mode")
	check(not game.hud.top.visible and not game.hud.bottom.visible, "Cookbook hides top and bottom world HUD")
	check(not game.hud.crosshair.visible and not game.hud.prompt.visible, "Cookbook hides crosshair and world prompt")
	check(not game.hud.event_feed_panel.visible and not game.hud.recipe_panel.visible, "Cookbook hides event feed and detached recipe card")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Cookbook releases the mouse")
	check(game.cookbook.physical.pages[0].page_side == -1 and game.cookbook.physical.pages[1].page_side == 1, "Page side is explicit before _ready")
	check(game.cookbook.physical.views[0].size == Vector2i(640, 900) and game.cookbook.physical.views[1].size == Vector2i(640, 900), "Both page SubViewports keep the expected size")
	await create_timer(0.05).timeout
	check(game.cookbook.physical.surfaces[0].visible and game.cookbook.physical.surfaces[1].visible, "Both readable surfaces stay visible at 0.05 seconds")
	check(game.cookbook.physical.page_turn_mesh.visible, "Dedicated page-turn leaf animates separately")
	var right = game.cookbook.physical.pages[1]
	check(right.find_button("Сосиска") != null, "Fresh-cafe contents lists the introduced sausage recipe")
	check(right.find_button("вина") == null and right.find_button("картофель") == null, "Potato and wine stay hidden until their starter steps")
	check(right.find_button("Стейк") == null and right.find_button("Бургер") == null and right.find_button("Солянка") == null, "Future recipes are hidden by FeatureAccess")
	game.cookbook.select("solyanka")
	check(game.cookbook.recipe == "index", "Hidden direct recipe request falls back to contents")
	var sausage: Button = right.find_button("Сосиска")
	click_control(game, 1, sausage)
	await process_frame
	check(game.cookbook.recipe == "sausage", "Visible starter recipe remains mouse-clickable")
	await create_timer(0.25).timeout
	check(game.cookbook.physical.surfaces[0].visible and game.cookbook.physical.surfaces[1].visible, "Both readable surfaces stay visible after 0.3 seconds")
	check(not game.cookbook.physical.page_turn_mesh.visible, "Turn leaf hides after its own lifetime")
	await create_timer(0.70).timeout
	check(game.cookbook.physical.surfaces[0].visible and game.cookbook.physical.surfaces[1].visible, "Both readable surfaces stay visible after 1 second")
	check(game.cookbook.physical.surfaces[0].material_override.albedo_texture != null and game.cookbook.physical.surfaces[1].material_override.albedo_texture != null, "Both surfaces retain live viewport textures")
	check(UiMode.handle_key(game, key(KEY_ESCAPE)), "Shared controller handles Esc in cookbook")
	check(not game.cookbook.opened and UiMode.resolve(game) in [UiMode.WORLD, UiMode.STATION], "Esc closes cookbook before pause")
	check(UiMode.handle_key(game, key(KEY_B)) and game.cookbook.opened, "B opens cookbook from gameplay")
	check(UiMode.handle_key(game, key(KEY_B)) and not game.cookbook.opened, "B closes cookbook from cookbook mode")

	set_stars(game, 2)
	game.cookbook.toggle()
	game.cookbook.select("meal")
	await process_frame
	check(page_has_text(game.cookbook.physical.pages[0], "Стейк") and page_has_text(game.cookbook.physical.pages[1], "Макароны"), "Pair-kitchen recipe is split by component across both pages")
	game.cookbook.close()
	set_stars(game, 3)
	game.cookbook.toggle()
	game.cookbook.select("burger")
	await process_frame
	check(page_has_text(game.cookbook.physical.pages[0], "Котлета") and page_has_text(game.cookbook.physical.pages[1], "Сборка"), "Burger recipe uses both pages")
	game.cookbook.close()
	set_stars(game, 4)
	game.cookbook.toggle()
	game.cookbook.select("solyanka")
	await create_timer(0.30).timeout
	var left = game.cookbook.physical.pages[0]
	right = game.cookbook.physical.pages[1]
	check(page_has_text(left, "Огонь") and page_has_text(left, "Мешалка"), "Solyanka first components are on the left page")
	check(page_has_text(right, "Соль") and page_has_text(right, "Общий котёл"), "Solyanka remaining components are on the right page")
	check(left.find_button("Содержание") != null and right.find_button("Содержание") != null, "Long recipe has explicit navigation on both halves")
	game.hud.show_reading_alert("Срочно: тест")
	check(game.hud.reading_alert.visible and game.hud.reading_alert_text.text.contains("Срочно"), "Urgent event uses reserved area outside book text")
	game.hud.show_reading_alert("")
	game.cookbook.close()

	var reader := preload("res://scripts/cook_avatar.gd").new()
	game.add_child(reader)
	await process_frame
	reader.perform({"position":[0.0,0.0,0.0],"yaw":0.0,"pitch":-0.25,"presentation":{"book":true,"page":"solyanka"}}, Vector3.ZERO, false)
	await create_timer(0.30).timeout
	check(reader.book.visible and reader.book.surfaces[0].visible and reader.book.surfaces[1].visible, "Clone reading keeps both physical pages visible")
	reader.free()
	game.queue_free()
	await process_frame
	print("PASS: cookbook visibility and shared UI modes" if not failed else "FAILED")
	quit(1 if failed else 0)
