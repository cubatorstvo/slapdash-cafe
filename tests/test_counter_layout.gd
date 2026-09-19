extends SceneTree
const Model = preload("res://scripts/cooking_model.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var m = Model.new()
	m.reset("sausage")
	var shelf_right_near: Vector2 = m.Layout.shelf_point(Vector2(m.Layout.SHELF_HALF.x, m.Layout.SHELF_HALF.y))
	assert(shelf_right_near.distance_to(m.Layout.TABLE_NEAR_LEFT) < 0.0001, "product shelf right-near corner should meet the table left-near corner")
	assert(is_equal_approx(m.Layout.SHELF_YAW, PI / 4.0), "product shelf should meet the table at 45 degrees")
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
	assert(is_equal_approx(zone_size.x, station.SLOT_WIDTH), "every station should use the fixed slot width")
	assert(is_equal_approx(zone_size.y, station.SLOT_DEPTH), "every station should use the fixed slot depth")
	assert(station.model.BOUNDS == Vector2(3.35, 2.65), "counter object movement bounds should remain unchanged")
	var shelf = station.view.get_node("ProductShelf")
	assert(is_equal_approx(shelf.rotation.y, PI / 4.0), "visible product shelf should use the 45 degree rotation")
	assert(m.Layout.broken_corner_contains(Vector2(-1.7, 0.65)), "broken table wedge should include the left-near corner region")
	assert(not m.Layout.broken_corner_contains(Vector2(0.0, 0.0)), "broken table wedge should stay local to the left side")
	assert(is_equal_approx(m.Layout.table_height(m.Layout.TABLE_FAR_LEFT), m.Layout.TABLE_Y), "broken wedge seam should stay flush with the main table")
	assert(is_equal_approx(m.Layout.table_height(m.Layout.TABLE_NEAR_LEFT), m.Layout.TABLE_Y - m.Layout.TABLE_BREAK_DROP), "near-left corner should sink below the rest of the table")
	assert(m.Layout.broken_corner_downhill().dot(Vector2(-1, 1).normalized()) > 0.9, "broken wedge should slope toward the near-left corner")
	for edge_name in ["ZoneEdgeFront", "ZoneEdgeBack", "ZoneEdgeLeft", "ZoneEdgeRight"]:
		assert(station.get_node_or_null(edge_name) != null, "training zone should show a visible floor outline on every side")
	assert(is_equal_approx(station.get_node("ZoneEdgeLeft").position.x, station.training_zone_min().x), "left outline should match the logical station boundary")
	assert(is_equal_approx(station.get_node("ZoneEdgeRight").position.x, station.training_zone_max().x), "right outline should match the logical station boundary")
	for index in range(game.service.stations.size()):
		var current = game.service.stations[index]
		assert(current.slot_index == index, "starter station should occupy its fixed slot")
		assert(current.station_id == index + 1, "runtime station id should be derived from the slot")
		assert(current.position.distance_to(game.service.slot_position(index)) < 0.0001, "station position should be derived from its slot")
		assert(is_equal_approx((current.training_zone_max() - current.training_zone_min()).x, station.SLOT_WIDTH), "all station types should use the same slot width")
	for index in range(game.service.stations.size() - 1):
		var left = game.service.stations[index]
		var right = game.service.stations[index + 1]
		var left_edge: float = left.position.x + left.training_zone_max().x
		var right_edge: float = right.position.x + right.training_zone_min().x
		assert(is_equal_approx(right_edge - left_edge, game.service.SLOT_GAP), "fixed station slots should keep the configured floor gap")
		assert(is_equal_approx(right.position.x - left.position.x, station.SLOT_WIDTH + game.service.SLOT_GAP), "slot centers should be equally spaced")
	var saved: Dictionary = game.service.save_data()
	assert(saved.version == 22, "slot-based saves should use current format v22")
	for index in range(saved.stations.size()):
		var entry: Dictionary = saved.stations[index]
		assert(entry.slot == index, "save should identify station contents by slot")
		assert(not entry.has("position") and not entry.has("yaw") and not entry.has("id"), "save should not persist station transforms or runtime ids")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.version = 3
	legacy.served = 17
	for index in range(legacy.stations.size()):
		legacy.stations[index].id = index + 1
		legacy.stations[index].position = [100.0 + index, 0.0, 100.0]
		legacy.stations[index].yaw = 0.0
		legacy.stations[index].erase("slot")
	assert(game.service.load_data(legacy), "legacy transform-based save should migrate into fixed slots")
	assert(game.service.served == 17, "slot migration should preserve cafe progress")
	for index in range(game.service.stations.size()):
		assert(game.service.stations[index].position.distance_to(game.service.slot_position(index)) < 0.0001, "legacy saved transforms should be ignored")
	assert(game.service.save_data().version == 22, "migrated saves should write current format v22")
	print("PASS: movable plates, tray wine, grades, snapshot and scene")
	game._shutdown_tree(game)
	game.free()
	await process_frame
	quit()
