extends Node
const Data = preload("res://scripts/cookbook_data.gd")
const UiMode = preload("res://scripts/cafe_ui_mode.gd")
signal changed
var opened := false
var recipe := "index"
var physical: Node3D
var game: Node3D

func attach(owner_game: Node3D) -> void:
	game = owner_game
	physical = preload("res://scripts/book_prop.gd").new()
	game.camera.add_child(physical)
	physical.pose_in_hands(true)
	physical.chosen.connect(_from_page)
	_sync_feature_pages()

func _feature_for_recipe(dish: String) -> String:
	if dish == "meal": return "kitchen_pair"
	if dish in ["burger","cheeseburger","spicy_burger"]: return "kitchen_grill"
	if dish == "solyanka": return "kitchen_solyanka"
	return "shop_basic"

func _allowed_recipes() -> Array:
	if game == null or not is_instance_valid(game.service) or game.service.get("feature_access") == null: return Data.ORDER.duplicate()
	var result: Array = []
	for dish in Data.ORDER:
		if bool(game.service.feature_access.access(_feature_for_recipe(str(dish))).visible): result.append(dish)
	return result

func _sync_feature_pages() -> void:
	if not is_instance_valid(physical): return
	var allowed := _allowed_recipes()
	for page in physical.pages:
		if page.has_method("set_allowed_pages"): page.set_allowed_pages(allowed)
	if recipe != "index" and recipe not in allowed: recipe = "index"

func _from_page(page: String) -> void:
	if page == "close": close()
	else: select(page)

func toggle() -> void:
	if opened: close(); return
	_sync_feature_pages()
	var station: Node3D = game.local_station()
	if station != null and station.training.phase == "recording" and station.training.dish in _allowed_recipes():
		recipe = station.training.dish
	else: recipe = "index"
	opened = true
	game.taught.book = true
	physical.set_reading(true, recipe, _live())
	changed.emit()
	game.sync_mouse_mode()
	UiMode.apply(game, UiMode.COOKBOOK)

func close() -> void:
	if not opened: return
	opened = false
	physical.set_reading(false, recipe)
	changed.emit()
	game.sync_mouse_mode()
	UiMode.apply(game, UiMode.resolve(game))

func select(value: String) -> void:
	_sync_feature_pages()
	var requested := Data.page(value)
	recipe = requested if requested == "index" or requested in _allowed_recipes() else "index"
	physical.set_reading(true, recipe, _live())
	changed.emit()

func _live():
	var station: Node3D = game.local_station() if game != null else null
	if station == null or recipe != station.training.dish: return null
	if station.training.phase != "recording" and station.state != "cooking": return null
	return station.model

func _process(_delta: float) -> void:
	if opened:
		_sync_feature_pages()
		physical.set_live(_live())

func _input(event: InputEvent) -> void:
	if not opened or not is_instance_valid(physical): return
	if event is InputEventMouse:
		var hit: Dictionary = physical.hit_from_screen(game.camera, event.position)
		physical.feed_pointer(event, hit)
		if not hit.is_empty() or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()

func shutdown() -> void:
	close()
	if is_instance_valid(physical): physical.shutdown()

func _exit_tree() -> void:
	shutdown()
