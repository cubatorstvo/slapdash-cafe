extends SceneTree
## Two real processes, launched by run_network_test.py.
const Scene = preload("res://scenes/cafe.tscn")
var game
var host := false
var started := false
var elapsed := 0.0
var stage := 0
var saw_guest := false
var saw_salt := false
var saw_denied := false
func _initialize() -> void:
	host = "host" in OS.get_cmdline_user_args()
	run.call_deferred()
func run() -> void:
	game = Scene.instantiate()
	game.name = "Cafe"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.session_paused = false
	game.service.open_for_business = false
	while game.service.clones.size() < 2: game.service.create_clone()
	game.session.configure("host" if host else "join", "127.0.0.1", 28767, "Host" if host else "Guest")
	started = true
func _process(delta: float) -> bool:
	if not started: return false
	elapsed += delta
	if elapsed > 18:
		printerr("FAIL: network timeout ", "host" if host else "guest", " stage ", stage)
		quit(1)
		return false
	if host:
		if stage == 0 and game.session.members.size() == 2:
			var peer: int = game.session.members.keys().filter(func(id): return id != 1)[0]
			game.team.start("together", [game.service.clones[0].id, game.service.clones[1].id], peer)
			game.team.model.grab(0, "salt")
			stage = 1
			elapsed = 0
		if stage > 0:
			if elapsed < 1.5:
				if game.team.model.owners.salt == 0: saw_denied = true
			elif stage == 1:
				game.team.model.drop(0)
				stage = 2
			if game.team.model.owners.salt == 1: saw_guest = true
			if game.team.model.meat_salt >= 1: saw_salt = true
			game.team.advance(delta)
			game.lecture.advance(delta)
			if stage == 2 and not game.team.active():
				if saw_guest and saw_salt and saw_denied and game.service.team_recipe.is_empty():
					print("PASS: host received peer commands, shared ownership held, disconnect cancelled safely")
					quit(0)
				else:
					printerr("FAIL: host network assertions ", saw_guest, saw_salt, saw_denied)
					quit(1)
		game.session.advance(delta)
	else:
		if game.team.phase == "together":
			if stage == 0:
				stage = 1
				elapsed = 0
				game.session.send_event({"grab": "salt"})
			if elapsed > 2 and stage == 1:
				game.session.send_event({"grab": "salt"})
				stage = 2
			game.session.send_motion({"pose": {"position": [1.2, 0, 1.8], "yaw": 0, "pitch": -0.2}, "target": [-2.25, 0.45], "height": 0.6, "use": true})
			if stage == 2 and elapsed > 4:
				if game.team.model.owners.salt != 1 or game.team.model.meat_salt < 1:
					printerr("FAIL: guest did not receive authoritative shared cooking")
					quit(1)
				else:
					game.session.leave("Test disconnect")
					if game.service.stations[3].state != "idle" or game.service.stations[3].clone_ids != [-1, -1]:
						printerr("FAIL: guest local cafe was not restored")
						quit(1)
						return false
					print("PASS: guest joined, received shared kitchen and left")
					quit(0)
	return false
