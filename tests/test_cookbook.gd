extends SceneTree
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; printerr("FAIL: ",message)
func check_reader_book(body: Node3D, book: Node3D, head: Node3D, look_negative_z: bool, who: String) -> void:
	var local_forward := Vector3.FORWARD if look_negative_z else Vector3.BACK
	var gaze: Vector3 = (body.global_basis * (head.basis * local_forward)).normalized()
	var from_head: Vector3 = (book.global_position - head.global_position).normalized()
	check(from_head.dot(gaze) > 0.98, "%s book center stays on the recorded gaze ray" % who)
	check(book.page_normal().dot(-gaze) > 0.98, "%s pages stay perpendicular to and face the gaze ray" % who)
	check(is_equal_approx(book.scale.x, book.THIRD_PERSON_SCALE), "%s uses the 1.2x third-person book scale" % who)
func click_page(game, side: int, uv: Vector2) -> void:
	var screen: Vector2 = game.cookbook.physical.page_to_screen(game.camera, side, uv)
	var hit: Dictionary = game.cookbook.physical.hit_from_screen(game.camera, screen)
	check(not hit.is_empty() and absf(hit.uv.x - uv.x) < 0.08 and absf(hit.uv.y - uv.y) < 0.08, "Screen ray lands on the same page UV")
	var down := InputEventMouseButton.new()
	down.pressed = true
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = screen
	game.cookbook._input(down)
	var up := down.duplicate()
	up.pressed = false
	game.cookbook._input(up)
func click_control(game, side: int, control: Control) -> void:
	check(control != null, "Page control exists to click")
	if control == null: return
	click_page(game, side, game.cookbook.physical.control_uv(side, control))
func check_plane_uv(book: Node3D) -> void:
	var mesh: PlaneMesh = book.surfaces[0].mesh
	var arrays: Array = mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	check(verts.size() > 0 and verts.size() == uvs.size(), "Page mesh exposes vertex UVs")
	var saw_plus := false
	var saw_minus := false
	for i in verts.size():
		check(uvs[i].distance_to(book.uv_from_local(verts[i])) < 0.03, "Hit UV.y follows PlaneMesh local z")
		if verts[i].z > 0.3:
			check(absf(uvs[i].y - 1.0) < 0.05, "local +z is UV.y=1")
			saw_plus = true
		if verts[i].z < -0.3:
			check(absf(uvs[i].y) < 0.05, "local -z is UV.y=0")
			saw_minus = true
	check(saw_plus and saw_minus, "PlaneMesh samples both page poles")
func run() -> void:
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.service.clear_world()
	game.service.initial_stations(true)
	game.camera.rotation.x = 0.52
	var opening_gaze: Vector3 = -game.camera.global_basis.z
	game.cookbook.toggle()
	await process_frame
	await process_frame
	check(game.cookbook.recipe == "index" and game.cookbook.opened and game.cookbook.physical.visible, "Local reader sees the physical book")
	var book_ray: Vector3 = (game.cookbook.physical.global_position - game.camera.global_position).normalized()
	check(book_ray.dot(opening_gaze) > 0.999, "First-person book opens directly on the current gaze ray")
	check(game.cookbook.physical.page_normal().dot(-opening_gaze) > 0.999, "First-person pages are perpendicular to and face the gaze ray")
	check(is_equal_approx(game.cookbook.physical.scale.x, 0.82 * 1.2), "First-person book is exactly 1.2x larger")
	check(game.cookbook.physical.is_open, "Local reading still drives presence")
	check(game.cookbook.physical.hands[0].visible, "3D hands hold the cover edges")
	check_plane_uv(game.cookbook.physical)
	var wine: Button = game.cookbook.physical.pages[1].find_button("вина")
	check(wine != null, "Index lists recipes as one-click links")
	if wine:
		click_control(game, 1, wine)
		await process_frame
		await process_frame
	check(game.cookbook.recipe == "wine", "Upper index entry opens from the visible page UV")
	check(game.cookbook.physical.page_sound.playing, "Page audio plays on the held book")
	var close_recipe: Button = game.cookbook.physical.pages[0].find_button("Закрыть")
	click_control(game, 0, close_recipe)
	await process_frame
	check(not game.cookbook.opened, "Lower close control closes the book")
	game.cookbook.toggle()
	await process_frame
	await process_frame
	wine = game.cookbook.physical.pages[1].find_button("вина")
	click_control(game, 1, wine)
	await process_frame
	await process_frame
	var contents: Button = game.cookbook.physical.pages[0].find_button("Содержание")
	click_control(game, 0, contents)
	await process_frame
	await process_frame
	check(game.cookbook.recipe == "index", "Contents tab returns to the index")
	game.cookbook.select("meal")
	await process_frame
	await process_frame
	var row: Label = null
	for child in game.cookbook.physical.pages[1].column.get_children():
		if child is Label and str(child.text).contains("Обжарить"):
			row = child
			break
	check(row != null, "Recipe body lines are hover targets")
	if row:
		var hover := InputEventMouseMotion.new()
		hover.position = game.cookbook.physical.page_to_screen(game.camera, 1, game.cookbook.physical.control_uv(1, row))
		game.cookbook._input(hover)
		await process_frame
		check(game.cookbook.physical.pages[1].note.text != "", "Hover note appears on the physical page")
		var away := InputEventMouseMotion.new()
		away.position = Vector2(12, 8)
		game.cookbook._input(away)
		await process_frame
		check(game.cookbook.physical.pages[1].note.text == "", "Leaving the page clears the hover note")
	game.cookbook.select("wine")
	check(game.session.capture_player().presentation.page == "wine", "Reading page enters network presence")
	var meal_lines: Array = preload("res://scripts/cookbook_data.gd").components("meal")
	check(meal_lines.size() == 2 and meal_lines[0].lines[0] == "Обжарить с 2 сторон" and meal_lines[1].lines[3] == "Порция — 100 г", "Static recipe labels match the live card")
	check(preload("res://scripts/cookbook_data.gd").RECIPES.sausage.components[0].lines[1].detail.contains("одна сосиска"), "Sausage portion detail is the plated requirement")
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
	check(is_equal_approx(reader.head.rotation.x, -0.25), "Clone keeps the recorded head pitch while reading")
	check_reader_book(reader, reader.book, reader.head, true, "Clone")
	var grip: Vector3 = reader.to_local(reader.book.cover_grip(-1))
	check(grip.z < -0.15 and grip.y > 0.8, "Clone hands reach the lower cover edge")
	reader.free()
	station.view.worker.show()
	station.model.actor_pitch = -0.48
	station.model.presentation.book = true
	station.model.presentation.page = "wine"
	station.view._update_worker(station.model, 0.0, false)
	check_reader_book(station.view.worker, station.view.book, station.view.head, false, "Counter worker")
	check(is_equal_approx(station.view.head.rotation.x, 0.48), "Counter worker keeps the recorded head pitch while reading")
	var worker_grip: Vector3 = station.view.worker.to_local(station.view.book.cover_grip(-1))
	check(worker_grip.y > 0.7, "Worker hands reach the gaze-aligned lower cover edge")
	station.model.presentation.book = false
	station.view._update_worker(station.model, 0.0, false)
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
	kitchen.model.stirred = 0.4
	live_meal = preload("res://scripts/cookbook_data.gd").components("meal", kitchen.model)
	check(live_meal[1].lines[2] == "Перемешать [×]", "Unfinished stirring is a mark, not a percent")
	kitchen.model.stirred = 1.0
	live_meal = preload("res://scripts/cookbook_data.gd").components("meal", kitchen.model)
	check(live_meal[1].lines[2] == "Перемешать [✓]", "Finished stirring uses the check mark")
	kitchen.training.close()
	game.service.request_training(kitchen, "meal", 1)
	kitchen.training.start_pass([1, 2])
	game.bind_training()
	kitchen.model.pasta = 40
	kitchen.model.pasta_salt = 1.2
	kitchen.training.advance(1.0 / 60.0)
	live_meal = preload("res://scripts/cookbook_data.gd").components("meal", kitchen.model)
	check(live_meal[1].lines[3] == "Порция — 100 г [40/100 г]", "Dual-role kitchen keeps pasta mass through a tick")
	check(live_meal[1].lines[1] == "Соль [✓]", "Dual-role kitchen keeps pasta salt through a tick")
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
	game.hush_audio()
	for _i in range(8):
		await process_frame
	game.free()
	game = null
	for _i in range(6):
		await process_frame
	print("PASS: cookbook, recording compatibility, presence and bell" if not failed else "FAILED")
	quit(1 if failed else 0)
