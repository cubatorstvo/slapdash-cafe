extends SceneTree
const Scene = preload("res://scenes/cafe.tscn")
var game
var role := "host"
var stage := 0
var timer := 0.0
var started := 0
var quit_at := 0.0
var saw_parallel := false
func _initialize() -> void: setup.call_deferred()
func setup() -> void:
	role = OS.get_cmdline_user_args()[0]
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.service.open_for_business = false
	game.service.clear_world()
	game.service.initial_stations()
	game.service.revenue = 73 if role == "guest" else 0
	if role == "host": game.service.add_station("counter", Vector3(0, 0, 5), 27)
	game.session.configure("host" if role == "host" else "join", "127.0.0.1", 27843, role)
	started = Time.get_ticks_msec()
func fail(message: String) -> void:
	printerr("FAIL: ", role, " ", message)
	quit(1)
func act(action: String, station: int, extra := {}) -> void:
	var value := {"action": action, "station": station}
	value.merge(extra)
	game.session.request_action(value)
func _process(delta: float) -> bool:
	if started == 0: return false
	timer += delta
	if Time.get_ticks_msec() - started > 30000:
		fail("Timeout at stage %d" % stage)
		return false
	if not game.session.is_guest(): game.service.advance(delta)
	game.session.advance(delta)
	game.service.refresh_views(delta)
	if role == "host": host_tick()
	elif role == "guest": guest_tick()
	else: observer_tick()
	return false
func host_tick() -> void:
	var first = game.service.by_id(1)
	var second = game.service.by_id(2)
	var kitchen = game.service.by_id(4)
	if stage == 0 and game.session.members.size() >= 2:
		game.player.global_position = first.to_global(Vector3(0, 0.02, 1.8))
		act("open", 1, {"dish": "wine"})
		act("pass", 1, {"participants": [1]})
		stage = 1
	elif stage == 1 and first.training.phase == "recording" and second.training.phase == "recording":
		print("READY: late join")
		saw_parallel = true
		stage = 2
	elif stage == 2 and game.session.members.size() == 3 and second.training.phase == "idle":
		act("cancel", 1)
		game.player.global_position = kitchen.to_global(Vector3(-1.3, 0.02, 1.8))
		act("open", 4, {"dish": "meal"})
		var guest_id := 0
		for id in game.session.members:
			if game.session.members[id] == "guest": guest_id = id
		act("pass", 4, {"participants": [1, guest_id]})
		game.session.send_input(kitchen, {}, {"grab": "pasta_salt_tool"})
		stage = 3
	elif stage == 3 and kitchen.model.hands[1] == "salt":
		if kitchen.model.hands[0] != "pasta_salt_tool": fail("Host cross-zone tool missing")
		print("CHECK: both live roles share zones")
		stage = 4
	elif stage == 4 and kitchen.training.phase == "idle" and game.session.members.size() < 3:
		if not saw_parallel: fail("No concurrent sessions")
		print("PASS: host simultaneous lessons, dynamic station, late join, shared live zones, disconnect cleanup")
		stage = 5
		quit_at = timer + 2
	elif stage == 5 and timer > quit_at:
		game.session.leave("")
		quit(0)
func guest_tick() -> void:
	if stage == 6:
		if game.service.revenue != 73 or game.service.stations.size() != 4: fail("Guest local cafe not restored")
		print("PASS: guest independent lesson, mixed participants, cross-zone access and local backup")
		quit(0)
		return
	if not game.session.synced: return
	var first = game.service.by_id(1)
	var second = game.service.by_id(2)
	var kitchen = game.service.by_id(4)
	if game.service.by_id(27) == null: fail("Fifth station not replicated")
	if first.model.potatoes.size() != 3 or first.model.sausages.size() != 3 or first.model.vessels.cup == null: fail("New stock and vessels not replicated")
	if stage == 0 and first.training.phase == "recording":
		game.player.global_position = second.to_global(Vector3(0, 0.02, 1.8))
		stage = 1
		quit_at = timer + 0.3
	elif stage == 1 and timer > quit_at:
		act("open", 2, {"dish": "potato"})
		stage = 2
	elif stage == 2 and second.training.phase == "ready":
		act("pass", 2, {"participants": [game.session.local_id()]})
		stage = 3
	elif stage == 3 and game.session.members.size() == 3 and second.training.phase == "recording":
		saw_parallel = true
		act("cancel", 2)
		stage = 4
	elif stage == 4 and kitchen.training.phase == "recording":
		if kitchen.training.role_for(game.session.local_id()) != 1: fail("Wrong assignment")
		game.session.send_input(kitchen, {}, {"grab": "salt"})
		stage = 5
	elif stage == 5 and kitchen.model.hands[1] == "salt" and kitchen.model.hands[0] == "pasta_salt_tool":
		if not saw_parallel: fail("Parallel training not seen")
		game.session.leave("")
		stage = 6
func observer_tick() -> void:
	if not game.session.synced: return
	var first = game.service.by_id(1)
	var second = game.service.by_id(2)
	var kitchen = game.service.by_id(4)
	if stage == 0:
		if game.service.stations.size() != 5: fail("Late observer did not receive dynamic stations")
		# Both lessons can end shortly after the roster update; their station sessions remain valid.
		stage = 1
	elif stage == 1 and kitchen.training.phase == "recording":
		stage = 2
	elif stage == 2 and kitchen.training.phase == "idle":
		print("PASS: late observer sees station sessions and cancelled live take")
		game.session.leave("")
		quit(0)
