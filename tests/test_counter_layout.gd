extends SceneTree
const Model = preload("res://scripts/cooking_model.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var m = Model.new()
	m.reset("sausage")
	var expected_shelf_center: Vector2 = m.Layout.SHELF_HOME + m.Layout.shelf_forward() * (m.Layout.SHELF_HALF.y * 0.5)
	assert(m.Layout.shelf_center().distance_to(expected_shelf_center) < 0.0001, "product shelf should be pulled forward by one quarter depth")
	assert(is_equal_approx(m.Layout.SHELF_YAW, PI / 4.0), "product shelf should face the cook at 45 degrees")
	for point in [m.jug, m.tomato, m.potatoes[0].potato, m.potatoes[1].potato, m.potatoes[2].potato, m.sausages[0].sausage, m.sausages[1].sausage, m.sausages[2].sausage]:
		assert(m.Layout.shelf_contains(point), "initial stock should remain on the rotated shelf")
	m.pick_up("plate_2")
	m.move_item("plate_2", Vector2.ZERO)
	m.put_down()
	m.pick_up("sausage_0")
	m.move_item("sausage", Vector2.ZERO)
	m.put_down()
	assert(m.sausage_state == "plate_2", "food should attach to moved plate")
	m.pick_up("plate_2")
	m.move_item("plate_2", m.Layout.TRAY)
	m.put_down()
	assert(m.served_index("sausage") == 0)
	assert(m.served_in_dish("sausage"))
	var copy = Model.new()
	copy.restore(m.snapshot())
	assert(copy.served_in_dish("sausage"))
	m.reset("wine")
	m._deliver(m.Layout.TRAY, 225, 2.0)
	assert(m.served_wine() == 225)
	assert(m.quality().grade == "A")
	assert(m.spilled() == 0)
	m.reset("wine")
	m.pick_up("cup")
	m.move_item("cup", m.Layout.TRAY)
	m.put_down()
	m.filled = 225
	assert(m.quality().grade == "S")
	m._deliver(m.cup, 100, 2.0)
	assert(m.filled == 300 and m.tray_wine == 25)
	assert(m.spilled() == 0, "cup overflow on tray is served, not lost")
	m.reset("sausage")
	m.pick_up("plate_2")
	m.move_item("plate_2", Vector2.ZERO)
	m.put_down()
	m.pick_up("sausage_0")
	m.move_item("sausage", Vector2(0.1, 0.0))
	m.put_down()
	m.pick_up("plate_2")
	m.move_item("plate_2", Vector2(0.5, 0.0))
	m.lift_held(0.2)
	m.step(0.1, false, true, false)
	assert(m.sausage.distance_to(Vector2(0.6, 0)) < 0.001)
	assert(m.sausage_slip == 0)
	for i in range(10): m.step(0.1, true, false, false)
	assert(not m.sausage_state.begins_with("plate_"), "tilting plate releases food")
	var game = load("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.service.open_for_business = false
	for i in range(5): await process_frame
	var station = game.service.by_id(1)
	var zone_size: Vector2 = station.training_zone_max() - station.training_zone_min()
	assert(is_equal_approx(zone_size.x, station.Definition.TYPES.counter.width * 1.1), "training zone width should be 1.1x")
	assert(is_equal_approx(zone_size.y, 5.2 * 1.1), "training zone depth should be 1.1x")
	assert(station.model.BOUNDS == Vector2(3.35, 2.65), "counter object movement bounds should remain unchanged")
	var shelf = station.view.get_node("ProductShelf")
	assert(is_equal_approx(shelf.rotation.y, PI / 4.0), "visible product shelf should use the 45 degree rotation")
	for edge_name in ["ZoneEdgeFront", "ZoneEdgeBack", "ZoneEdgeLeft", "ZoneEdgeRight"]:
		assert(station.get_node_or_null(edge_name) != null, "training zone should show a visible floor outline on every side")
	assert(is_equal_approx(station.get_node("ZoneEdgeLeft").position.x, station.training_zone_min().x), "left outline should match the logical station boundary")
	assert(is_equal_approx(station.get_node("ZoneEdgeRight").position.x, station.training_zone_max().x), "right outline should match the logical station boundary")
	for index in range(game.service.stations.size() - 1):
		var left = game.service.stations[index]
		var right = game.service.stations[index + 1]
		var left_width: float = game.service.Definition.TYPES[left.type_id].width
		var right_width: float = game.service.Definition.TYPES[right.type_id].width
		var previous_physical_gap: float = (left_width + right_width) / 2.0 * (left.TRAINING_ZONE_SCALE - 1.0)
		var left_edge: float = left.position.x + left.training_zone_max().x
		var right_edge: float = right.position.x + right.training_zone_min().x
		assert(is_equal_approx(right_edge - left_edge, previous_physical_gap), "adjacent station zones should have a visible floor gap")
		var center_distance: float = right.position.x - left.position.x
		var physical_gap: float = center_distance - (left_width + right_width) / 2.0
		assert(is_equal_approx(physical_gap, previous_physical_gap * 2.0), "physical table spacing should be doubled")
	var legacy_save: Dictionary = game.service.save_data()
	legacy_save.version = 2
	legacy_save.served = 17
	for entry in legacy_save.stations: entry.position = [0.0, 0.0, -1.4]
	assert(game.service.load_data(legacy_save), "legacy v2 starter save should migrate")
	assert(game.service.served == 17, "layout migration should preserve cafe progress")
	var migrated_positions: Array = game.service.starter_layout_positions()
	for index in range(game.service.stations.size()):
		assert(game.service.stations[index].position.distance_to(migrated_positions[game.service.stations[index].station_id - 1]) < 0.0001, "legacy starter stations should move to current layout")
	assert(game.service.save_data().version == 3, "migrated saves should write the current layout version")
	print("PASS: movable plates, tray wine, grades, snapshot and scene")
	game._shutdown_tree(game)
	game.free()
	await process_frame
	quit()
