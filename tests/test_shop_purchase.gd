extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; printerr("FAIL: ", text)
func _product_checks(node: Node, into: Array) -> void:
	if node is CheckBox and str(node.tooltip_text).begins_with("Добавить в комплект") and not (node as CheckBox).disabled:
		into.append(node)
	for child in node.get_children(): _product_checks(child, into)
func _press_next(office: Node) -> void:
	var boxes: Array = []
	_product_checks(office.content, boxes)
	for box in boxes:
		if not (box as CheckBox).button_pressed:
			(box as CheckBox).button_pressed = true
			return
func run() -> void:
	if not "--fresh-cafe" in OS.get_cmdline_user_args():
		printerr("FAIL: run with -- --fresh-cafe so the cafe save is not touched")
		quit(1)
		return
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var service = game.service
	var p = service.progress
	p.phase = "none"
	p.stars = 1
	p.cash = 0
	p.deliveries.clear()
	game.player.global_position = Vector3(80, 0, 80)
	game.office.close()
	game.session.execute_action(1, {"action":"buy","kind":"item","item":"plants","station":0})
	check(game.hud.toast.text == "Подойди к компьютеру кафе.", "Closed shop still requires the computer")
	check(p.deliveries.is_empty(), "Rejected buy does not create a parcel")
	game.office.open("stations")
	game.session.execute_action(1, {"action":"buy","kind":"item","item":"plants","station":0})
	check(game.hud.toast.text == "Не хватает денег.", "Open shop reaches the purchase")
	check(p.deliveries.is_empty(), "Unaffordable buy does not create a parcel")
	var chef = service.by_id(1)
	chef.equipment = []
	chef.upgrades = []
	game.office.selections.clear()
	game.office.rebuild()
	var catalog: Array = game.shop.equipment_catalog(chef.type_id)
	var boxes: Array = []
	_product_checks(game.office.content, boxes)
	check(boxes.size() == catalog.size() and catalog.size() > 1, "Every free equipment item has its own checkbox")
	_press_next(game.office)
	_press_next(game.office)
	check(game.office.selections.get(chef.station_id, []) == [catalog[0], catalog[1]], "Checkboxes keep the items that were ticked")
	p.cash = 500
	var error: String = game.shop.order(str(catalog[0]), chef.station_id, false)
	check(error.is_empty() and p.deliveries.size() == 1 and str(p.deliveries[0].item) == str(catalog[0]), "Equipment order creates a parcel")
	game._shutdown_tree(game)
	game.free()
	print("PASS: shop purchase reaches the order and checkboxes keep their items" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
