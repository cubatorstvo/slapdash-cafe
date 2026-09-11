extends Node
const Data = preload("res://scripts/cookbook_data.gd")
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

func _from_page(page: String) -> void:
	if page == "close": close()
	else: select(page)

func toggle() -> void:
	if opened: close(); return
	var station: Node3D = game.local_station()
	if station != null and station.training.phase == "recording":
		recipe = station.training.dish
		game.session.send_input(station, {}, {"drop": true})
	else: recipe = "index"
	opened = true
	game.taught.book = true
	physical.set_reading(true, recipe, _live())
	changed.emit()
	game.sync_mouse_mode()

func close() -> void:
	if not opened: return
	opened = false
	physical.set_reading(false, recipe)
	changed.emit()
	game.sync_mouse_mode()

func select(value: String) -> void:
	recipe = Data.page(value)
	physical.set_reading(true, recipe, _live())
	changed.emit()

func _live():
	var station: Node3D = game.local_station() if game != null else null
	if station == null or recipe != station.training.dish: return null
	if station.training.phase != "recording" and station.state != "cooking": return null
	return station.model

func _process(_delta: float) -> void:
	if opened: physical.set_live(_live())

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
