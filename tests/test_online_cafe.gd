extends SceneTree
const Scene = preload("res://scenes/cafe.tscn")
const Barrier = preload("res://tests/online_barrier.gd")
var game
var barrier: Node
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
	barrier = Barrier.new()
	barrier.name = "OnlineBarrier"
	game.session.add_child(barrier)
	game.session.configure("host" if role == "host" else "join", "127.0.0.1", 27843, role)
	started = Time.get_ticks_msec()
func succeed(message: String) -> void:
	print(message)
	if is_instance_valid(game):
		game._shutdown_tree(game)
		game.free()
		game = null
	quit(0)
func fail(message: String) -> void:
	printerr("FAIL: ", role, " ", message)
	if is_instance_valid(game):
		game._shutdown_tree(game)
		game.free()
		game = null
	quit(1)
func act(action: String, station: int, extra := {}) -> void:
	var value := {"action": action, "station": station}
	value.merge(extra)
	game.session.request_action(value)
func member_named(name: String) -> int:
	for id in game.session.members:
		if game.session.members[id] == name: return id
	return 0
func kitchen_phase() -> String:
	var kitchen = game.service.by_id(4) if is_instance_valid(game) else null
	return kitchen.training.phase if kitchen != null else "?"
func expected_stage() -> String:
	if role == "host":
		return ["wait-guest", "parallel-recording", "start-kitchen", "shared-zones", "observer-ack", "kitchen-idle", "quit"][clampi(stage, 0, 6)]
	if role == "guest":
		return ["host-wine", "open-potato", "potato-ready", "book-and-roster", "kitchen-role", "ack-then-leave", "local-restore"][clampi(stage, 0, 6)] if stage < 30 else ("guest-bell" if stage == 30 else "guest-resume")
	return ["count-stations", "kitchen-recording", "kitchen-idle"][clampi(stage, 0, 2)]
func timeout_message() -> String:
	var first = game.service.by_id(1) if is_instance_valid(game) else null
	var second = game.service.by_id(2) if is_instance_valid(game) else null
	return "Timeout role=%s stage=%d expected=%s kitchen=%s station1=%s station2=%s acks=%s members=%s" % [
		role, stage, expected_stage(), kitchen_phase(),
		first.training.phase if first != null else "?",
		second.training.phase if second != null else "?",
		barrier.dump() if is_instance_valid(barrier) else "{}",
		str(game.session.members) if is_instance_valid(game) else "{}"
	]
func _process(delta: float) -> bool:
	if started == 0: return false
	timer += delta
	if Time.get_ticks_msec() - started > 30000:
		fail(timeout_message())
		return false
	if not game.session.is_guest(): game.service.advance(delta)
	var teaching = game.local_station()
	if teaching != null and teaching.training.phase == "recording":
		game.bind_training()
		game.session.send_input(teaching, game.build_motion(teaching, delta))
		if role == "guest" and game.session.synced:
			game.session._presence.rpc_id(1, game.session.capture_player())
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
		var guest_id := member_named("guest")
		act("pass", 4, {"participants": [1, guest_id]})
		game.session.send_input(kitchen, {}, {"grab": "pasta_salt_tool"})
		stage = 3
	elif stage == 3 and kitchen.training.phase == "recording" and kitchen.model.hands[1] == "salt":
		if kitchen.model.hands[0] != "pasta_salt_tool": fail("Host cross-zone tool missing")
		print("CHECK: both live roles share zones")
		stage = 4
	elif stage == 4 and barrier.has_from("kitchen-live", member_named("observer")):
		print("CHECK: host held kitchen until observer ack")
		stage = 5
	elif stage == 5 and kitchen.training.phase == "idle" and game.session.members.size() < 3:
		if not saw_parallel: fail("No concurrent sessions")
		print("PASS: host simultaneous lessons, dynamic station, late join, shared live zones, disconnect cleanup")
		stage = 6
		quit_at = timer + 2
	elif stage == 6 and timer > quit_at:
		game.session.leave("")
		if is_instance_valid(game):
			game._shutdown_tree(game)
			game.free()
			game = null
		quit(0)
func guest_tick() -> void:
	if stage == 6:
		if game.service.revenue != 73 or game.service.stations.size() != 4: fail("Guest local cafe not restored")
		succeed("PASS: guest independent lesson, mixed participants, cross-zone access and local backup")
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
		game.cookbook.toggle()
		stage = 3
	elif stage == 3 and game.session.members.size() == 3 and second.training.phase == "recording":
		if not second.model.presentation.book: return
		game.cookbook.close()
		saw_parallel = true
		act("ring", 2)
		stage = 30
	elif stage == 30 and second.training.phase == "confirm_finish":
		act("resume", 2)
		stage = 31
	elif stage == 31 and second.training.phase == "recording":
		if second.bell_count() != 1: fail("Guest bell not replicated")
		print("CHECK: guest book, bell, confirmation and resume replicated")
		act("cancel", 2)
		stage = 4
	elif stage == 4 and kitchen.training.phase == "recording":
		if kitchen.training.role_for(game.session.local_id()) != 1: fail("Wrong assignment")
		game.session.send_input(kitchen, {}, {"grab": "salt"})
		stage = 5
	elif stage == 5 and kitchen.model.hands[1] == "salt" and kitchen.model.hands[0] == "pasta_salt_tool" and barrier.has_from("kitchen-live", member_named("observer")):
		if not saw_parallel: fail("Parallel training not seen")
		game.session.leave("")
		stage = 6
func observer_tick() -> void:
	if not game.session.synced: return
	var kitchen = game.service.by_id(4)
	if stage == 0:
		if game.service.stations.size() != 5: fail("Late observer did not receive dynamic stations")
		stage = 1
	elif stage == 1 and kitchen.training.phase == "recording":
		if kitchen.training.dish != "meal": fail("Observer kitchen dish %s" % kitchen.training.dish)
		if kitchen.training.live_roles.size() != 2: fail("Observer live roles %s" % str(kitchen.training.live_roles))
		var live := 0
		for peer in kitchen.training.participants:
			if int(peer) > 0: live += 1
		if live != 2: fail("Observer participants %s" % str(kitchen.training.participants))
		print("CHECK: observer replicated kitchen recording with both roles")
		barrier.send("kitchen-live")
		stage = 2
	elif stage == 2 and kitchen.training.phase == "idle":
		if not barrier.has_from("kitchen-live", game.session.local_id()): fail("Observer finished without its own ack")
		print("PASS: late observer sees station sessions and cancelled live take")
		game.session.leave("")
		if is_instance_valid(game):
			game._shutdown_tree(game)
			game.free()
			game = null
		quit(0)
