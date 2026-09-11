extends SceneTree
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; printerr("FAIL: ",message)
func check_reader_book(body: Node3D, book: Node3D, head: Node3D, who: String) -> void:
	var toward_head: Vector3 = (head.global_position - book.global_position).normalized()
	check(book.page_normal().dot(toward_head) > 0.25, "%s pages face the reader" % who)
	var away := book.global_position - body.global_position
	away.y = 0.0
	check(away.length() > 0.05 and book.page_top().dot(away.normalized()) > 0.2, "%s book top points away from the reader" % who)
func click_page(game, side: int, uv: Vector2) -> void:
	var screen: Vector2 = game.cookbook.physical.page_to_screen(game.camera, side, uv)
	var down := InputEventMouseButton.new()
	down.pressed = true
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = screen
	game.cookbook._input(down)
	var up := down.duplicate()
	up.pressed = false
	game.cookbook._input(up)
func run() -> void:
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cookbook.toggle()
	await process_frame
	await process_frame
	check(game.cookbook.recipe == "index" and game.cookbook.opened and game.cookbook.physical.visible, "Local reader sees the physical book")
	check(game.cookbook.physical.is_open, "Local reading still drives presence")
	check(game.cookbook.physical.hands[0].visible, "3D hands hold the cover edges")
	var wine: Control = null
	for child in game.cookbook.physical.pages[1].column.get_children():
		if child is Button and str(child.text).contains("вина"): wine = child; break
	check(wine != null, "Index lists recipes as one-click links")
	if wine:
		var uv: Vector2 = wine.get_global_rect().get_center() / Vector2(game.cookbook.physical.VIEW)
		click_page(game, 1, uv)
		await process_frame
	check(game.cookbook.recipe == "wine", "Screen-space ray opens a recipe on the page")
	check(game.cookbook.physical.page_sound.playing, "Page audio plays on the held book")
	check(game.session.capture_player().presentation.page == "wine", "Reading page enters network presence")
	var meal_lines: Array = preload("res://scripts/cookbook_data.gd").components("meal")
	check(meal_lines.size() == 2 and meal_lines[0].lines[0] == "Обжарить с 2 сторон" and meal_lines[1].lines[3] == "Порция — 100 г", "Static recipe labels match the live card")
	game.cookbook.close()
	var station = game.service.by_id(1)
	game.service.request_training(station,"potato",1)
	station.training.start_pass([1])
	game.bind_training()
	game.menu.close()
	game.cookbook.toggle()
	check(game.cookbook.recipe == "potato", "Lesson opens current recipe")
	station.training.inputs[0] = game.build_motion(station,1.0/60)
	station.training.advance(1.0/60)
	var frame: Dictionary = station.training.pending_tracks[0].frames[0]
	check(frame.presentation.book and frame.presentation.page == "potato", "Book recorded with cooking")
	var replay = preload("res://scripts/cooking_model.gd").new()
	replay.restore(frame)
	check(replay.presentation.book,"Book restored for clone")
	var old := frame.duplicate(true)
	old.erase("presentation")
	replay.restore(old)
	check(not replay.presentation.book,"Old recording remains valid")
	check(game.service.matches_schema(old, frame), "Save schema accepts frames without presentation")
	game.cookbook.close()
	game.player.global_position = station.global_position + Vector3(0,0,1.8)
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.physical_keycode = KEY_ENTER
	game._unhandled_input(enter)
	check(station.training.phase == "recording", "Enter has no finish action")
	game.session.request_action({"action":"ring","station":1})
	check(station.training.phase == "confirm_finish", "Bell asks before missing serving")
	check(station.training.pending_tracks[0].frames.back().presentation.bell == 1,"Bell stored at the ring")
	station.training.finish_pass(true)
	check(station.training.pending_tracks[0].frames.back().presentation.bell == 1,"Bell stored in final frame")
	var malformed := {"position":[0,0,0],"yaw":0.0,"pitch":0.0,"presentation":42}
	check(not game.session.clean_pose(malformed).presentation.book,"Malformed appearance safely ignored")
	game.cookbook.toggle()
	check(game.cookbook.opened, "Book can open after a take")
	game.menu.show_station(station)
	game._physics_process(1.0/60)
	check(not game.cookbook.opened, "Station menu closes the book")
	var hidden := preload("res://scripts/cook_avatar.gd").new()
	game.add_child(hidden)
	await process_frame
	hidden.hide()
	hidden.book.set_reading(true, "wine")
	check(not hidden.book.shown() and not hidden.book.page_sound.playing, "Hidden avatar does not play page turns")
	hidden.free()
	var reader := preload("res://scripts/cook_avatar.gd").new()
	game.add_child(reader)
	await process_frame
	reader.perform({"position": [0.0, 0.0, 0.0], "yaw": 0.0, "pitch": -0.25, "presentation": {"book": true, "page": "potato"}}, Vector3.ZERO, false)
	check(reader.book.visible, "Remote clone keeps a physical book")
	check_reader_book(reader, reader.book, reader.head, "Clone")
	var grip: Vector3 = reader.to_local(reader.book.cover_grip(-1))
	check(grip.z < -0.15 and grip.y > 0.8, "Clone hands reach the lower cover edge")
	reader.free()
	station.view.worker.show()
	station.view.book.set_reading(true, "wine")
	check_reader_book(station.view.worker, station.view.book, station.view.head, "Counter worker")
	var worker_grip: Vector3 = station.view.worker.to_local(station.view.book.cover_grip(-1))
	check(worker_grip.z > 0.15 and worker_grip.y > 0.8, "Worker hands reach the lower cover edge")
	station.view.book.set_reading(false, "wine")
	game.cookbook.toggle()
	game.session.leave("test")
	check(not game.cookbook.opened, "Disconnect hides the book")
	var kitchen = game.service.by_id(4)
	game.service.request_training(kitchen, "meal", 1)
	kitchen.training.start_pass([1, 0])
	game.bind_training()
	game.menu.close()
	game.feedback.update(0)
	kitchen.model.meat_sides = [1.0, 0.0]
	game.feedback.update(0)
	check(game.feedback.latches[kitchen.station_id].sides == 1, "Steak-side ready uses the cooked-face threshold once")
	kitchen.model.meat_sides = [0.999, 0.2]
	game.feedback.update(0)
	check(game.feedback.latches[kitchen.station_id].sides == 1, "Near-threshold steak sides do not chime again")
	var live_meal: Array = preload("res://scripts/cookbook_data.gd").components("meal", kitchen.model)
	check(live_meal[0].lines[0].contains("100%") and live_meal[0].lines[0].contains("0%"), "Live steak sides use the same labels")
	check(live_meal[1].lines[0].begins_with("Сварить"), "Live pasta cooking keeps the static label")
	kitchen.training.close()
	var wine_station = game.service.by_id(2)
	game.service.request_training(wine_station, "wine", 1)
	wine_station.training.start_pass([1])
	game.bind_training()
	game.menu.close()
	game.feedback.update(0)
	wine_station.model.filled = 220
	game.feedback.update(0)
	check(game.feedback.latches[2].wine, "Wine ready matches the 200–250 ml requirement")
	wine_station.model.filled = 205
	game.feedback.update(0)
	wine_station.model.filled = 245
	game.feedback.update(0)
	check(game.feedback.latches[2].wine, "Threshold chatter does not clear the wine latch")
	wine_station.model.filled = 180
	game.feedback.update(0)
	check(not game.feedback.latches[2].wine, "Leaving the wine window allows a later announcement")
	game.free()
	print("PASS: cookbook, recording compatibility, presence and bell" if not failed else "FAILED")
	quit(1 if failed else 0)
