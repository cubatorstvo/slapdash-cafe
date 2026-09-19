extends SceneTree
const Scene = preload("res://scenes/cafe.tscn")
const Inputs = preload("res://tests/recipe_inputs.gd")
const DT := 1.0 / 60
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func feed(station: Node3D, role: int, commands: Array) -> void:
	for command in commands:
		var motion: Dictionary = command.duplicate(true)
		var event := {}
		for key in ["grab", "drop"]:
			if motion.has(key):
				event[key] = motion[key]
				motion.erase(key)
		station.training.inputs[role] = motion
		if not event.is_empty(): station.training.queue_event(role, event)
		station.training.advance(DT)

func run() -> void:
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.service.clear_world()
	game.service.initial_stations(true)
	game.service.open_for_business = false
	var service = game.service
	print("[1/7] Station identity, complete kit, attached crew and local training")
	check(service.stations.size() == 4, "Three counters and one team kitchen")
	var first: Node3D = service.stations[0]
	var second: Node3D = service.stations[1]
	var kitchen: Node3D = service.stations[3]
	check(first.crew.size() == 1 and kitchen.crew.size() == 2, "Crew belongs to station")
	service.request_training(first, "wine", 1)
	check(first.training.start_pass([1]), "Start one-role pass")
	first.model.pick_up("pan")
	check(first.model.held == "pan", "Wine goal still permits pan")
	first.model.put_down()
	first.refresh(1, DT)
	check(first.view.kitchen.potato_set.visible and first.view.kitchen.sausage_set.visible and first.view.jug.visible, "All dishes' equipment visible together")
	first.training.close()

	print("[2/7] Full meat role, independent pasta role, forbidden zones")
	service.request_training(kitchen, "meal", 1)
	kitchen.training.start_pass([1, 0])
	check(not kitchen.model.grab(0, "water") and not kitchen.model.grab(0, "pasta_salt_tool"), "Inactive zone cannot be grabbed")
	var meat := Inputs.new()
	meat.meat_role()
	feed(kitchen, 0, meat.commands)
	check(kitchen.model.meat_state == "plate" and kitchen.model.meat_salt >= 1, "Meat prepared through real commands")
	kitchen.training.finish_pass()
	kitchen.training.keep_pass()
	var meat_track: Dictionary = kitchen.training.tracks[0].duplicate(true)
	check(not kitchen.training.can_accept(), "One role cannot serve full meal")
	kitchen.training.start_pass([0, 1])
	check(not kitchen.model.grab(1, "steak"), "Recorded role food protected")
	var pasta := Inputs.new()
	pasta.pasta_role()
	feed(kitchen, 1, pasta.commands)
	check(kitchen.model.success(), "Independent zones produce complete meal")
	check(kitchen.model.zone_snapshot(0) == meat_track.frames.back(), "Finished zone freezes without extra heating")
	kitchen.training.finish_pass()
	kitchen.training.keep_pass()
	check(kitchen.training.tracks[0] == meat_track, "Adding role keeps first track byte-for-byte")
	check(kitchen.training.accept(), "Whole meal accepted")
	var old_record: Dictionary = kitchen.recipes.meal.duplicate(true)

	print("[3/7] Replace whole role, keep old recipe on cancellation, linked cooperative take")
	service.request_training(kitchen, "meal", 1)
	kitchen.training.start_pass([1, 0])
	check(kitchen.training.pending_tracks[1] == old_record.tracks[1], "Independent other role retained")
	feed(kitchen, 0, [{"grab": "steak"}])
	kitchen.training.close()
	check(kitchen.recipes.meal == old_record, "Cancelled replacement keeps production")
	service.request_training(kitchen, "meal", 1)
	kitchen.training.start_pass([1, 22])
	check(kitchen.model.grab(0, "water"), "Simultaneously live roles share both zones")
	kitchen.training.advance(DT)
	kitchen.training.finish_pass(true)
	kitchen.training.keep_pass()
	check(kitchen.training.tracks[1].frames.back().owners.water == -1 and kitchen.training.tracks[0].frames.back().hand == "", "Joint finish releases cross-zone tools before capturing all zones")
	check(kitchen.training.tracks[0].group == kitchen.training.tracks[1].group, "Cross-zone pass records linked roles")
	kitchen.training.start_pass([0, 1])
	check(kitchen.training.pending_tracks[0].is_empty(), "Related old draft cleared explicitly when splitting cooperative take")
	kitchen.training.close()

	print("[4/7] Single recipe is station-owned, exact replay and customer service")
	service.request_training(first, "wine", 1)
	first.training.start_pass([1])
	feed(first, 0, [{"grab": "cup"}])
	for i in range(90): feed(first, 0, [{"target": [first.model.Layout.TRAY.x, first.model.Layout.TRAY.y], "height": 0.15}])
	feed(first, 0, [{"drop": true}, {"grab": "jug"}])
	for i in range(90): feed(first, 0, [{"target": [first.model.cup.x - 0.40, first.model.cup.y], "height": 0.6}])
	for i in range(1800):
		var mouth = first.model.spout_position()
		var offset: float = first.model.spout_target().x - first.model.jug.x
		feed(first, 0, [{"target": [first.model.cup.x - offset, first.model.cup.y], "height": 0.6, "use": first.model.tilt < 44}])
		if first.model.filled >= 215: break
	feed(first, 0, [{"drop": true}])
	check(first.model.success(), "Wine prepared using the same input path")
	first.training.finish_pass()
	first.training.keep_pass()
	check(first.training.accept(), "Wine accepted")
	check(second.recipes.is_empty(), "Same type does not share recipes")
	var first_record: Dictionary = first.recipes.wine.duplicate(true)
	for i in range(first_record.tracks[0].frames.size()):
		first.show_tracks(first_record.tracks, i)
		check(first.model.snapshot() == first_record.tracks[0].frames[i], "Production exactly restores complete kit")
	check(service.spawn_customer("meal"), "Meal guest arrives")
	for i in range(3500): service.advance(DT)
	check(service.served == 1 and service.revenue == 65, "Recorded brigade serves guest")

	print("[5/7] Simultaneous station lessons, pending lesson and real customer")
	service.request_training(first, "wine", 1)
	service.request_training(second, "potato", 22)
	check(first.training.active() and second.training.active(), "Separate stations train concurrently")
	first.training.close()
	second.training.close()
	service.spawn_customer("meal")
	for i in range(1800):
		service.advance(DT)
		if kitchen.state == "cooking": break
	check(kitchen.state == "cooking", "Order started")
	check(service.request_training(kitchen, "meal", 1) and kitchen.pending_teacher == 1, "Teaching waits for current order")
	for i in range(2700): service.advance(DT)
	check(kitchen.training.active() and kitchen.pending_teacher == 0, "Pending lesson starts after order")
	kitchen.training.close()

	print("[6/7] Fixed station slots, save/load drafts and malformed data rejection")
	var saved: Dictionary = bytes_to_var(var_to_bytes(service.save_data()))
	check(saved.version == 21, "Station save uses current persistent-group format")
	for entry in saved.stations:
		check(entry.has("slot") and not entry.has("position") and not entry.has("yaw") and not entry.has("id"), "Slot save omits transforms and runtime IDs")
	check(service.load_data(saved), "Station save loads")
	check(service.stations.size() == 4 and service.by_id(1).recipes.wine == first_record, "Independent recordings survive slot save")
	check(service.by_id(4).drafts.has("meal"), "Confirmed partial role drafts survive save")
	var damaged := saved.duplicate(true)
	damaged.stations[1].slot = damaged.stations[0].slot
	check(not service.load_data(damaged) and service.by_id(1) != null, "Reject duplicate slot without replacing world")
	check(game.save_cafe(), "Queue background save")
	game.save_writer.flush()

	print("[7/7] UI ownership and restart revision")
	first = service.by_id(1)
	game.player.global_position = first.to_global(Vector3(0, 0.02, 1.8))
	game.session.execute_action(1, {"action": "open", "station": 1, "dish": "wine"})
	game.session.execute_action(1, {"action": "pass", "station": 1, "revision": first.training.revision, "participants": [1]})
	game.bind_training()
	check(game.player.station == first and game.player.constrained, "FPS records at real station")
	var revision: int = first.training.revision
	game.session.apply_input(1, {"station": 1, "revision": revision - 1, "event": {"grab": "jug"}})
	check(first.training.events.is_empty(), "Stale take input ignored")
	first.training.close()
	game.queue_free()
	await process_frame
	print("PASS: station ownership, independent roles, recordings, customers, save and UI" if failures == 0 else "FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
