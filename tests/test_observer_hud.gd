extends SceneTree
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; printerr("FAIL: ", message)
func look_at_station(game, station: Node3D) -> void:
	game.player.global_position = station.to_global(Vector3(0, 0.02, 1.8))
	game.player.rotation.y = station.global_rotation.y
	game.camera.rotation.x = -0.12
func record(grade: String, duration: float, dish := "wine") -> Dictionary:
	var components: Array = preload("res://scripts/cookbook_data.gd").components(dish)
	return {"tracks": [], "duration": duration, "quality": {"grade": grade, "components": components, "present": true}}
func apply_guest_world(station: Node3D, entry: Dictionary) -> void:
	station.order_dish = str(entry.get("order_dish", ""))
	station.recipes = {}
	var qualities: Dictionary = entry.get("recipe_quality", {})
	for key in entry.known:
		station.recipes[key] = {"duration": entry.recipe_times[key], "quality": qualities.get(key, {})}
func run() -> void:
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.service.clear_world()
	game.service.initial_stations(true)
	game.service.open_for_business = false
	var station = game.service.by_id(1)
	game.service.request_training(station, "wine", 1)
	station.training.start_pass([1])
	game.bind_training()
	game.menu.close()
	game.cookbook.close()
	game.refresh_hud()
	check(game.local_station() == station, "Local player is in the training context")
	check(not game.hud.recipe_panel.visible, "Local training keeps the recipe panel hidden")
	check(game.hud.recipe_panel_text().is_empty(), "Closed book does not leave a HUD requirement list")
	station.training.close()
	game.bind_training()
	station.recipes["wine"] = record("C", 55.0)
	station.order_dish = "wine"
	station.state = "cooking"
	station.model.filled = 0
	var live_grade: String = str(station.model.quality().grade)
	check(live_grade != "C", "Live clone frame differs from the saved record grade")
	look_at_station(game, station)
	game.refresh_hud()
	check(game.hud.recipe_panel.visible, "Observer looking at a cooking clone sees the recipe panel")
	var text: String = game.hud.recipe_panel_text()
	check(text.contains("Бокал вина") and text.contains("C") and text.contains("55.0"), "Observer panel shows dish, saved grade and duration")
	check(text.contains("Запись клона"), "Observer panel names the saved clone take")
	check(not text.contains(live_grade) or live_grade == "C", "Observer panel does not use the live replay grade")
	check(is_equal_approx(float(station.recipes.wine.duration), 55.0), "Duration in the record matches the panel source")
	station.recipes["wine"] = record("A", 31.4)
	game.refresh_hud()
	text = game.hud.recipe_panel_text()
	check(text.contains("A") and text.contains("31.4 с"), "Replaced record updates observer grade and time")
	check(not text.contains("55.0"), "Old duration leaves the observer panel")
	var entry: Dictionary = station.world_entry()
	check(entry.order_dish == "wine", "World snapshot includes order_dish")
	check(entry.recipe_times.wine == 31.4, "World snapshot includes recipe duration")
	check(str(entry.recipe_quality.wine.grade) == "A", "World snapshot includes saved quality")
	check(game.session.PROTOCOL == "slapdash-cafe-stations-8", "World protocol bumped for quality replication")
	var guest = game.service.by_id(2)
	apply_guest_world(guest, entry)
	check(guest.order_dish == "wine", "Guest restores the cooking dish")
	check(str(guest.recipes.wine.quality.grade) == "A" and is_equal_approx(float(guest.recipes.wine.duration), 31.4), "Guest restores the same observer summary")
	guest.state = "cooking"
	look_at_station(game, guest)
	game.refresh_hud()
	text = game.hud.recipe_panel_text()
	check(text.contains("A") and text.contains("31.4"), "Guest-side observer panel matches the host record")
	game.player.global_position = Vector3(20, 0.02, 20)
	game.refresh_hud()
	check(not game.hud.recipe_panel.visible, "Leaving observer focus hides the recipe panel")
	game.hush_audio()
	for _i in range(6):
		await process_frame
	game.free()
	print("PASS: observer HUD uses saved clone records" if not failed else "FAILED")
	quit(1 if failed else 0)
