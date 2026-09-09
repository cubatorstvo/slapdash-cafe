extends SceneTree
## Real peers exercise guest-led teaching, late join, overlay and save isolation.
const Scene = preload("res://scenes/cafe.tscn")
var game
var role := ""
var active := false
var elapsed := 0.0
var saw_three := false
var saw_team := false
var saw_wine := false
var saw_overlay_progress := false
var checked_busy := false
var team_start := 0.0
func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		printerr("FAIL: ", role, ": ", message)
		quit(1)
func wait_for(predicate: Callable) -> void:
	while not predicate.call(): await process_frame
func _process(delta: float) -> bool:
	if not active: return false
	elapsed += delta
	if elapsed > 30:
		printerr("FAIL: timeout ", role)
		quit(1)
	if role != "host": game.session.advance(delta)
	else:
		if game.session.members.size() == 3: saw_three = true
		if game.recording and not checked_busy:
			checked_busy = true
			game._begin_selected_training("potato", game.service.clones[1].id, 1)
			check(game.selected_dish == "wine" and game.recording, "stale host menu cannot replace guest lesson")
		if game.service.clones.size() >= 2 and game.service.clones[0].recipes.has("wine"): saw_wine = true
		if game.team.active():
			if not saw_team:
				saw_team = true
				team_start = game.team.model.elapsed
				game.steam._overlay(true, true, 480)
				print("READY: late join")
			if game.team.model.elapsed > team_start + 0.4: saw_overlay_progress = true
	return false
func run() -> void:
	game = Scene.instantiate()
	game.name = "Cafe"
	root.add_child(game)
	await process_frame
	game.service.open_for_business = false
	game.service.revenue = 42 if role == "host" else 1234
	if role != "host": game.set_physics_process(false)
	game.session.configure("host" if role == "host" else "join", "127.0.0.1", 28768, role)
	active = true
	if role == "host": await host_run()
	elif role == "guest": await guest_run()
	else: await observer_run()
func host_run() -> void:
	await wait_for(func(): return saw_three and saw_team and game.session.members.size() == 1)
	check(not game.team.active(), "disconnect cancels guest-led team")
	check(saw_wine, "guest's successful wine lesson saved on host")
	check(saw_overlay_progress, "overlay must not pause shared simulation")
	check(game.service.clones.size() == 2, "guest can create employees")
	check(game.service.clones[0].recipes.wine.frames[-1].filled >= 225, "recorded goal is complete")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(saved != null, "host writes staff save")
	print("PASS: host authority, guest lessons, overlay, late join and disconnect")
	quit(0)
func guest_run() -> void:
	await wait_for(func(): return game.session.synced)
	check(game.service.revenue == 42, "joined host's cafe")
	game.player.global_position = game.clone_machine.global_position + Vector3(0, 0.02, 2)
	await create_timer(0.2).timeout
	game.session.request_action({"action": "clone"})
	await wait_for(func(): return game.service.clones.size() == 2)
	game.player.global_position = game.training.to_global(Vector3(0, 0.02, 2.1))
	await create_timer(0.2).timeout
	game.session.request_action({"action": "single", "dish": "wine", "clone": game.service.clones[0].id, "slot": 0})
	await wait_for(func(): return game.is_local_teaching())
	check(game.player.constrained, "guest placed inside teaching boundary")
	game.session.send_single_event({"grab": "jug"})
	while not game.live.success():
		var target: Vector2 = game.live.cup - (game.live.spout_target() - game.live.jug)
		game.session.send_single_motion({"pose": {"position": [0, 0.02, 2.1], "yaw": 0, "pitch": -0.3}, "target": [target.x, target.y], "height": 0.9, "use": true})
		await create_timer(1.0 / 30.0).timeout
	game.session.send_single_event({"finish": true})
	await wait_for(func(): return not game.recording)
	check(not game.player.constrained, "successful lesson releases guest")
	check("wine" in game.service.clones[0].known, "guest receives employee knowledge")
	game.player.global_position = game.team.view.to_global(Vector3(0, 0.02, 2.1))
	await create_timer(0.2).timeout
	game.session.request_action({"action": "team", "mode": "together", "ids": [game.service.clones[0].id, game.service.clones[1].id], "partner": 1})
	await wait_for(func(): return game.team.phase == "together")
	check(game.team.local_role == 0, "guest can lead with host in second role")
	game.session.send_event({"grab": "salt"})
	while game.session.members.size() < 3 or game.team.model.meat_salt < 1:
		game.session.send_motion({"pose": {"position": [-1.2, 0, 1.8], "yaw": 0, "pitch": -0.2}, "target": [-2.25, 0.45], "height": 0.6, "use": true})
		await create_timer(1.0 / 30.0).timeout
	check(game.team.model.owners.salt == 0, "guest lead owns shared salt")
	await create_timer(0.4).timeout
	var old_revision: int = game.session.seen_restart
	game.session.send_event({"retake": true})
	await wait_for(func(): return game.session.seen_restart != old_revision)
	game.session._event.rpc_id(1, {"revision": old_revision, "cancel": true})
	await create_timer(0.4).timeout
	check(game.team.active(), "old commands cannot cancel new take")
	game.session.leave("Test done")
	check(game.service.revenue == 1234 and game.service.clones.size() == 1, "guest's original cafe restored")
	check(game.service.clones[0].recipes.is_empty(), "host's recordings not written into guest cafe")
	print("PASS: guest creates staff, teaches wine, leads team, retakes and restores local cafe")
	quit(0)
func observer_run() -> void:
	await wait_for(func(): return game.session.synced and game.team.active())
	check(game.team.local_role == -1 and not game.player.constrained, "late spectator stays free")
	await wait_for(func(): return game.session.remote_students.size() == 2 and game.session.player_avatars.size() == 2)
	check(game.team.view.actors[0].visible and game.team.view.actors[1].visible, "spectator sees both cooks")
	check("wine" in game.service.clones[0].known, "late join receives prior knowledge")
	await wait_for(func(): return not game.team.active())
	game.session.leave("Observer done")
	check(game.service.revenue == 1234, "observer restores local progress")
	print("PASS: late spectator receives players, students, knowledge and cancellation")
	quit(0)
