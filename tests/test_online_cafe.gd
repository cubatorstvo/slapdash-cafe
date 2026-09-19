extends SceneTree
const Scene = preload("res://scenes/cafe.tscn")
const Barrier = preload("res://tests/online_barrier.gd")
const MasterclassLibrary = preload("res://scripts/masterclass_library.gd")
var game
var barrier: Node
var role := "host"
var stage := 0
var timer := 0.0
var started := 0
var quit_at := 0.0
var saw_parallel := false
var saw_staff_training := false
var started_staff_training := false
func _initialize() -> void: setup.call_deferred()
func setup() -> void:
	role = OS.get_cmdline_user_args()[0]
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.service.open_for_business = false
	game.service.clear_world()
	game.service.initial_stations(true)
	game.service.revenue = 73 if role == "guest" else 0
	if role == "host":
		game.service.progress.stars = 1
		game.service.progress.cash = 200
		# Seed owned assets; this test covers transport, shop purchases have their own integration test.
		game.service.progress.decorations=["sign"]
		game.service.progress.popularity=10
		game.service.by_id(3).upgrades=["sauce_ramp"]
		game.service.by_id(3).apply_upgrades()
		game.shop.order("rag",1) # already installed: explicit rejection, no duplicate delivery
		game.shop.order_bundle(["sauce_ramp"],1)
		game.service.progress.free_clones=2
		game.service.normalize_workers()
		game.service.progress.free_workers[0].tempo=0.85
		game.service.progress.lab_upgrades=["lab_valve"]
		game.service.by_id(1).crew[0].tempo=1.25
		game.service.progress.lounge_items=["sofa","television"]
		var movie_source=game.service.by_id(4)
		movie_source.model.reset("meal")
		var movie_tracks: Array=[]
		for movie_role in range(2):
			var frame: Dictionary=movie_source.model.zone_snapshot(movie_role)
			var frames: Array=[]
			for i in range(900): frames.append(frame.duplicate(true))
			movie_tracks.append({"group":movie_role+1,"frames":frames})
		game.service.masterclasses=[MasterclassLibrary.make_record(501,"meal","kitchen",movie_tracks,15.0,movie_source.model.quality(),"Сетевые хайлайты")]
		var counter_source=game.service.by_id(3)
		counter_source.model.reset("potato")
		var counter_frames: Array=[]
		var counter_frame: Dictionary=counter_source.model.snapshot()
		for i in range(60): counter_frames.append(counter_frame.duplicate(true))
		game.service.masterclasses.append(MasterclassLibrary.make_record(502,"potato","counter",[{"group":1,"frames":counter_frames}],1.0,counter_source.model.quality(),"Сетевая картошка"))
		game.service.next_masterclass_id=503
		game.service.table_group_names["2-3"]="Сетевые стойки"
		game.service.guests_arrived=5
		game.service.order_stats={"orders_arrived":5,"orders_completed":2,"orders_partial":1,"orders_failed":2,"portions_ordered":16,"portions_served":11,"portions_unserved":5}
		game.service.analytics.losses.busy=3
		game.service.analytics.loss_details["busy|potato|2-3"]={"reason":"busy","dish":"potato","count":3,"portions_unserved":3,"stations":[2,3],"group":"2-3"}
		game.service.feed_system("batch",{"stations":[7,8]},2)
		game.service.by_id(3).order_portions_total=10
		game.service.by_id(3).order_portions_done=4
		game.service.by_id(3).order_paid=100
		var assembler_parcel: Dictionary=game.shop._new_delivery("counter",20,["counter"],true,0.0,{})
		game.service.progress.deliveries.append(assembler_parcel)
		game.annex.refresh_shell()
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
		return ["wait-guest", "parallel-recording", "start-kitchen", "shared-zones", "observer-ack", "await-idle-after-release", "quit"][clampi(stage, 0, 6)]
	if role == "guest":
		if stage==20: return "move-to-tv"
		if stage==21: return "shared-highlights"
		return ["host-wine", "open-potato", "potato-ready", "book-and-roster", "kitchen-role", "host-release-then-leave", "local-restore"][clampi(stage, 0, 6)] if stage < 30 else ("guest-bell" if stage == 30 else "guest-resume")
	return ["count-stations", "kitchen-recording", "wait-release", "wait-idle"][clampi(stage, 0, 3)]
func timeout_message() -> String:
	var first = game.service.by_id(1) if is_instance_valid(game) else null
	var second = game.service.by_id(2) if is_instance_valid(game) else null
	return "Timeout role=%s stage=%d expected=%s kitchen=%s station1=%s station2=%s acks=%s members=%s" % [
		role, stage, expected_stage(), kitchen_phase(),
		first.training.phase if first != null else "?",
		second.training.phase if second != null else "?",
		barrier.dump() if is_instance_valid(barrier) else "{}",
		str(game.session.members) if is_instance_valid(game) else "{}"
	] + (" staff=%s saw_staff=%s source=%s"%[game.service.staff_training.phase if is_instance_valid(game) and game.service.staff_training.is_active() else "idle",str(saw_staff_training),str(game.service.by_id(3).method_sources.get("potato",{})) if is_instance_valid(game) and game.service.by_id(3)!=null else "{}"])
func _process(delta: float) -> bool:
	if started == 0: return false
	timer += delta
	if Time.get_ticks_msec() - started > 30000:
		fail(timeout_message())
		return false
	if game.session.is_guest() and game.session.synced and stage < 6:
		if game.service.progress.popularity != 10 or not "sign" in game.service.progress.decorations or not is_instance_valid(game.service.by_id(3).upgrade_view):
			fail("Shared cafe progression missing")
			return false
		if str(game.service.table_group_names.get("2-3",""))!="Сетевые стойки":
			fail("Shared table group name missing")
			return false
		if game.service.staff_training.is_active(): saw_staff_training=true
	if not game.session.is_guest():
		game.service.advance(delta)
		if started_staff_training and game.service.staff_training.is_active(): game.service.staff_training.advance(delta*4.0)
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
		if game.service.progress.popularity != 10: fail("Host decoration purchase missing"); return
		game.player.global_position = first.to_global(Vector3(0, 0.02, 1.8))
		act("open", 1, {"dish": "wine"})
		act("pass", 1, {"participants": [1]})
		first.model.pick_up("cup")
		first.model.cup=Vector2(0,-1.61)
		first.model.elevations.cup=0.135
		first.model.filled=225
		first.model.wine=775
		game.session.send_input(first,{}, {"feed":true})
		stage = 1
	elif stage == 1:
		var guest_id:=member_named("guest")
		if not started_staff_training and guest_id>0 and barrier.has_from("movie-checked",guest_id) and not bool(game.service.movie_state.get("playing",false)):
			var lesson_error: String=game.service.start_group_training(502,[3])
			if not lesson_error.is_empty(): fail("Staff training did not start: "+lesson_error); return
			started_staff_training=true
			barrier.send("staff-started")
			print("CHECK: host assigned shared staff television training")
		if started_staff_training and first.training.phase == "recording" and second.training.phase == "recording":
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
		if kitchen.training.phase != "recording": fail("Host lost kitchen recording before observer ack")
		print("CHECK: host received observer ack and released kitchen")
		barrier.send("kitchen-release")
		stage = 5
	elif stage == 5 and kitchen.training.phase == "idle" and game.session.members.size() < 3:
		if not saw_parallel: fail("No concurrent sessions")
		print("PASS: host simultaneous lessons, fixed slots, late join, shared live zones, disconnect cleanup")
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
	if first.model.potatoes.size() != 3 or first.model.sausages.size() != 3 or first.model.vessels.cup == null: fail("New stock and vessels not replicated")
	if stage == 0 and first.training.phase == "recording":
		if first.model.guest_serving.drunk != 225 or first.model.item_available("cup"): return
		var saw_bundle:=false
		var saw_installer_delivery:=false
		for parcel in game.service.progress.deliveries:
			if parcel.get("items",[])==["sauce_ramp"]: saw_bundle=true
			if bool(parcel.get("installer",false)) and int(parcel.get("station",0))==20: saw_installer_delivery=true
		game.shop._process(0.016)
		if not saw_bundle or not saw_installer_delivery or game.shop.installers.is_empty() or game.service.progress.free_clones!=2: fail("Bundle, assembler or free clones missing"); return
		if game.service.progress.free_workers[0].tempo!=0.85 or first.crew[0].tempo!=1.25 or "lab_valve" not in game.service.progress.lab_upgrades: fail("Individual tempo or lab upgrades missing"); return
		print("CHECK: individual tempo, analytics feed, multi-order progress, consumed cup, deliveries and assembler actor replicated")
		game.player.global_position=Vector3(6.5,0.02,13.2)
		stage=20
		quit_at=timer+0.45
	elif stage==20 and timer>quit_at:
		act("masterclass_watch",0,{"id":501})
		stage=21
	elif stage==21 and bool(game.service.movie_state.get("playing",false)) and not game.service.remote_movie_record.is_empty():
		if first.training.phase!="recording": fail("Shared TV playback interrupted host lesson"); return
		if game.service.remote_movie_record.get("tracks",[]).is_empty(): fail("Guest did not receive highlight frames"); return
		print("CHECK: guest watches shared highlights while host lesson keeps running")
		barrier.send("movie-checked")
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
	elif stage == 5 and kitchen.model.hands[1] == "salt" and kitchen.model.hands[0] == "pasta_salt_tool" and barrier.has_from("kitchen-release", 1):
		if kitchen.training.phase != "recording": fail("Guest left after kitchen already idle")
		if not saw_parallel: fail("Parallel training not seen")
		if not barrier.has_from("kitchen-release", 1): fail("kitchen-release not from host")
		if not saw_staff_training: return
		var trained_source: Dictionary=game.service.by_id(3).method_sources.get("potato",{})
		if int(trained_source.get("id",0))!=502: return
		print("CHECK: guest saw shared staff TV lesson and learned method source")
		print("CHECK: guest received host kitchen release")
		game.session.leave("")
		stage = 6
func observer_tick() -> void:
	if not game.session.synced: return
	var kitchen = game.service.by_id(4)
	if stage == 0:
		if game.service.stations.size() != 4: fail("Late observer did not receive all fixed station slots")
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
	elif stage == 2 and barrier.has_from("kitchen-release", 1):
		print("CHECK: observer received host kitchen release")
		stage = 3
	elif stage == 3 and kitchen.training.phase == "idle":
		if not barrier.has_from("kitchen-live", game.session.local_id()): fail("Observer finished without its own ack")
		print("PASS: late observer sees station sessions and host-released live take cleanup")
		game.session.leave("")
		if is_instance_valid(game):
			game._shutdown_tree(game)
			game.free()
			game = null
		quit(0)
