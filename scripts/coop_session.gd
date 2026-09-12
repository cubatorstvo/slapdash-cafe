extends Node
## Host-owned station sessions. Inputs and actions are addressed by station ID and take revision.
const M = preload("res://scripts/team_cooking_model.gd")
const Avatar = preload("res://scripts/cook_avatar.gd")
const Person = preload("res://scripts/customer_view.gd")
const PROTOCOL := "slapdash-cafe-shop-12"
var game: Node3D
var transport := "offline"
var synced := false
var connection_deadline := 0
var handshakes := {}
var player_poses := {}
var player_avatars := {}
var members := {}
var action_times := {}
var motion_times := {}
var display_name := "Повар"
var connected := false
var guest := false
var clock := 0.0
var local_backup := {}
var remote_customers := {}

func setup(root_game: Node3D) -> void:
	game = root_game
	multiplayer.peer_connected.connect(func(id):
		if not guest: handshakes[id] = Time.get_ticks_msec() + 7000)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_joined)
	multiplayer.connection_failed.connect(func(): leave("Не удалось подключиться."))
	multiplayer.server_disconnected.connect(func(): leave("Хост отключился. Возвращено локальное кафе."))

func local_id() -> int: return multiplayer.get_unique_id() if connected else 1
func is_guest() -> bool: return guest
func online() -> bool: return connected

func configure(action: String, address: String, port: int, player_name: String) -> void:
	if action != "leave" and game.service.any_training():
		_status("Сначала заверши текущие показы.")
		return
	leave("")
	if action == "leave": return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 3) if action == "host" else peer.create_client(address.strip_edges(), port)
	if error != OK:
		_status(error_string(error))
		return
	attach_peer(peer, action == "join", player_name, "enet")
	_status("Подключение…" if guest else "Кафе открыто · UDP %d" % port)

func attach_peer(peer: MultiplayerPeer, joining: bool, player_name: String, kind: String) -> void:
	display_name = player_name.strip_edges().left(24)
	if display_name.is_empty(): display_name = "Повар"
	guest = joining
	transport = kind
	if joining: local_backup = game.service.save_data().duplicate(true)
	connected = true
	synced = not joining
	connection_deadline = Time.get_ticks_msec() + 20000 if joining else 0
	multiplayer.multiplayer_peer = peer
	if not joining:
		members = {1: display_name}
		player_poses[1] = capture_player()

func leave(message: String) -> void:
	var was_guest := guest
	if game != null:
		for station in game.service.stations:
			if station.training.active(): station.training.close()
			station.pending_teacher = 0
		if is_instance_valid(game.steam): game.steam.leave_lobby()
	if multiplayer.multiplayer_peer != null: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
	guest = false
	synced = false
	transport = "offline"
	connection_deadline = 0
	for actor in player_avatars.values():
		if is_instance_valid(actor) and actor.book: actor.book.shutdown()
		if is_instance_valid(actor): actor.free()
	for actor in remote_customers.values():
		if is_instance_valid(actor): actor.free()
	player_avatars.clear()
	remote_customers.clear()
	player_poses.clear()
	members.clear()
	handshakes.clear()
	motion_times.clear()
	action_times.clear()
	if was_guest and not local_backup.is_empty(): game.service.load_data(local_backup)
	local_backup.clear()
	if game != null:
		if is_instance_valid(game.feedback): game.feedback.shutdown()
		game.player.constrained = false
		game.bound_revision = -1
		if is_instance_valid(game.cookbook): game.cookbook.close()
		game.menu.close()
		if is_instance_valid(game.office): game.office.close()
	if not message.is_empty(): _status(message)

func _status(value: String) -> void:
	game.menu.net_status.text = value
	game.hud.notice.text = value
	game.hud.show_toast(value)

func _peer_left(id: int) -> void:
	members.erase(id)
	player_poses.erase(id)
	handshakes.erase(id)
	if player_avatars.has(id):
		player_avatars[id].queue_free()
		player_avatars.erase(id)
	if not guest:
		for parcel in game.service.progress.deliveries:
			if parcel.owner == id: parcel.owner = 0
		if game.service.progress.garland_builder == id: game.service.progress.garland_builder = 0
		for station in game.service.stations:
			if station.training.lead == id or station.training.role_for(id) >= 0: station.training.close()
			if station.pending_teacher == id: station.pending_teacher = 0
		broadcast_roster()
		_status("Участник вышел. Его незаконченный проход отменён; рабочие рецепты сохранены.")

func _joined() -> void:
	_register.rpc_id(1, display_name, PROTOCOL)
	game.service.clear_world()
	game.menu.close()

@rpc("any_peer", "call_remote", "reliable", 0)
func _register(value: String, version: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if version != PROTOCOL or (members.size() >= 4 and not members.has(sender)) or (transport == "steam" and not game.steam.accepts_peer(sender)):
		_rejected.rpc_id(sender, "Версии игры различаются или кафе недоступно.")
		return
	handshakes.erase(sender)
	members[sender] = game.steam.peer_name(sender) if transport == "steam" else value.strip_edges().left(24)
	player_poses[sender] = {"position": [-7.0, 0.02, 6.0], "yaw": 0.0, "pitch": -0.15}
	broadcast_roster()

func broadcast_roster() -> void:
	for id in members:
		if id != 1: _roster.rpc_id(id, members)

@rpc("authority", "call_remote", "reliable", 0)
func _rejected(message: String) -> void: leave(message)

@rpc("authority", "call_remote", "reliable", 0)
func _roster(value: Dictionary) -> void: members = value

func capture_player() -> Dictionary:
	var p: Vector3 = game.player.global_position
	return {"position": [p.x, p.y, p.z], "yaw": game.player.rotation.y, "pitch": game.camera.rotation.x, "presentation": {"book": game.cookbook.opened, "page": game.cookbook.recipe}}

func clean_pose(pose: Dictionary) -> Dictionary:
	var appearance: Dictionary = pose.get("presentation", {}) if pose.get("presentation", {}) is Dictionary else {}
	return {"position": [clampf(pose.position[0], -20, 20), clampf(pose.position[1], 0, 4), clampf(pose.position[2], -20, 20)], "yaw": wrapf(pose.yaw, -PI, PI), "pitch": clampf(pose.pitch, -1.4, 1.3), "presentation": {"book": appearance.get("book",false) == true, "page": preload("res://scripts/cookbook_data.gd").page(str(appearance.get("page","index")))}}

@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _presence(pose: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if guest or not members.has(sender) or not M.valid_pose(pose): return
	player_poses[sender] = clean_pose(pose)

func near_peer(id: int, object: Node3D, radius: float) -> bool:
	if id == 1: return game.player.global_position.distance_to(object.global_position) < radius
	if not player_poses.has(id): return false
	var p: Array = player_poses[id].position
	return Vector3(p[0], p[1], p[2]).distance_to(object.global_position) < radius

func accept_action(sender: int) -> bool:
	var now := Time.get_ticks_msec()
	var times: Array = action_times.get(sender, [])
	while not times.is_empty() and now - times[0] > 1000: times.pop_front()
	if times.size() >= 40: return false
	times.append(now)
	action_times[sender] = times
	return true

func request_action(value: Dictionary) -> void:
	var station: Node3D = game.service.by_id(int(value.get("station", -1)))
	if station != null: value.revision = station.training.revision
	if guest:
		if synced: _action.rpc_id(1, value)
	else: execute_action(1, value)

@rpc("any_peer", "call_remote", "reliable", 0)
func _action(value: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if guest or not members.has(sender) or not accept_action(sender): return
	execute_action(sender, value)

func execute_action(sender: int, value: Dictionary) -> void:
	var action: String = value.get("action", "")
	if action in ["take_parcel","drop_parcel","install_parcel","garland_take","garland_remove","garland_anchor","garland_put"]:
		var error: String = game.shop.action(sender,value)
		if not error.is_empty(): message_to(sender,error)
		else: game.save_cafe()
		return
	if action == "next_day":
		if action in ["lab_begin", "garland_begin", "next_day"] and sender != 1:
			message_to(sender, "Это действие подтверждает хозяин кафе.")
			return
		var target: Vector3 = game.development.night_action_position(action, value)
		var location: Array = player_poses.get(sender, {}).get("position", [])
		var peer_position: Vector3 = game.player.global_position if sender == 1 else Vector3(location[0], location[1], location[2]) if location.size() == 3 else Vector3.INF
		if peer_position.distance_to(target) > 4.5: return
		var error: String = game.service.night_action(action, value, sender)
		if not error.is_empty(): message_to(sender, error)
		else: game.save_cafe()
		return
	if action in ["buy", "banquet", "cancel_banquet", "business", "save", "new_cafe"]:
		if sender != 1:
			message_to(sender, "Общие покупки и проверку подтверждает хозяин кафе.")
			return
		if action in ["buy","business","banquet"] and not near_peer(sender,game.shop.computer,4.5):
			message_to(sender,"Подойди к компьютеру кафе.")
			return
		var error := ""
		match action:
			"buy": error = game.service.purchase(str(value.get("kind", "")), str(value.get("item", "")), int(value.get("station", 0)))
			"banquet": error = game.service.start_banquet(sender)
			"cancel_banquet": game.service.finish_banquet(false, "Проверка прервана.")
			"save":
				message_to(sender, "Сохранение идёт в фоне." if game.save_cafe() else "Не удалось записать сохранение.")
				return
			"new_cafe":
				if not game.service.any_training() and not game.service.progress.busy(): game.new_cafe()
				return
			"business":
				if game.service.progress.busy(): return
				game.service.toggle_business()
		if not error.is_empty(): message_to(sender, error)
		else:
			game.service.progress.revision += 1
			game.save_cafe()
		return
	var station: Node3D = game.service.by_id(int(value.get("station", -1)))
	if station == null: return
	var run = station.training
	if game.service.is_showcase(station) and action in ["keep", "accept"]: return
	if game.service.is_showcase(station) and action == "cancel":
		if sender == run.lead: game.service.finish_banquet(false, "Личный показ прерван.")
		return
	if action in ["manual","open","pass"] and (game.shop.carried(sender)>=0 or game.service.progress.garland_builder==sender):
		message_to(sender,"Сначала положи коробку или катушку.")
		return
	if action == "manual":
		if near_peer(sender, station, 5.0): game.service.request_manual(station, str(value.get("dish", "wine")), sender)
		return
	if game.service.progress.phase == "tasting" and action == "cancel":
		if sender == run.lead: game.service.finish_banquet(false, "Дегустация прервана.")
		return
	if action == "open":
		if not near_peer(sender, station, 5.0): return
		if game.service.request_training(station, str(value.get("dish", "")), sender):
			message_to(sender, "Станция завершит заказ и начнёт показ." if station.pending_teacher > 0 else "Выбери роли для записи.")
		return
	if action == "ring":
		var role: int = run.role_for(sender)
		if role >= 0 and run.phase == "recording" and run.tick > 0 and int(value.get("revision",-1)) == run.revision and near_peer(sender,station.bell,3.3):
			station.ring(role)
			run.finish_pass()
		return
	if not run.active() or run.lead != sender or int(value.get("revision", -1)) != run.revision: return
	match action:
		"pass":
			var assignments = value.get("participants")
			if not assignments is Array: return
			for peer in assignments:
				if not peer is int or (peer != 0 and peer != 1 and not members.has(peer)): return
				var other: Node3D = game.service.training_for(peer) if peer > 0 else null
				if other != null and other != station:
					message_to(sender, "Этот игрок уже участвует в другом показе.")
					return
			if not run.start_pass(assignments): message_to(sender, "Назначь себя одной роли, а каждому напарнику — отдельную роль.")
		"finish": run.finish_pass()
		"confirm_finish":
			if run.phase == "confirm_finish": run.finish_pass(true)
		"resume": run.resume_pass()
		"keep":
			run.keep_pass()
			game.save_cafe()
		"retake":
			if run.phase in ["recording", "review"]:
				var assignments: Array = run.participants.duplicate()
				run.phase = "ready"
				run.start_pass(assignments)
		"accept":
			if run.accept():
				game.save_cafe()
				message_to(sender, "Бригада обучена. Запись будет повторяться на заказах.")
			else:
				run.revision += 1
				message_to(sender, run.info)
		"cancel":
			run.close()
			game.save_cafe()

func message_to(id: int, value: String) -> void:
	if id == 1: _status(value)
	elif connected and members.has(id): _message.rpc_id(id, value)

@rpc("authority", "call_remote", "reliable", 0)
func _message(value: String) -> void: _status(value)

func send_input(station: Node3D, motion: Dictionary, event: Dictionary = {}) -> void:
	var packet := {"station": station.station_id, "revision": station.training.revision, "motion": motion, "event": event}
	if guest:
		if not synced: return
		if not event.is_empty(): _input_event.rpc_id(1, packet)
		else: _input_motion.rpc_id(1, packet)
	else: apply_input(1, packet)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _input_motion(packet: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not guest and members.has(sender): apply_input(sender, packet)

@rpc("any_peer", "call_remote", "reliable", 0)
func _input_event(packet: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not guest and members.has(sender) and accept_action(sender): apply_input(sender, packet)

func apply_input(sender: int, packet: Dictionary) -> void:
	var station: Node3D = game.service.by_id(int(packet.get("station", -1)))
	if station == null: return
	var run = station.training
	var role: int = run.role_for(sender)
	if role < 0 or run.phase != "recording" or int(packet.get("revision", -1)) != run.revision: return
	var motion = packet.get("motion", {})
	if motion is Dictionary and M.valid_pose(motion.get("pose")):
		var clean := {"pose": clean_pose(motion.pose), "use": motion.get("use", false) == true}
		if M.numbers(motion.get("aim"), 3): clean.aim = motion.aim
		if M.numbers(motion.get("target"), 2):
			var bounds: Vector2 = station.model.BOUNDS
			clean.target = [clampf(motion.target[0], -bounds.x, bounds.x), clampf(motion.target[1], -bounds.y, bounds.y)]
		if M.finite(motion.get("height")): clean.height = clampf(motion.height, -1.0, 1.1)
		if M.numbers(motion.get("pan_tilt"), 2): clean.pan_tilt = motion.pan_tilt
		run.inputs[role] = clean
		motion_times[sender] = Time.get_ticks_msec()
	var event = packet.get("event", {})
	if event is Dictionary:
		if event.get("feed",false) == true:
			run.queue_event(role,{"feed":true})
			game.service.trace("feed_attempt",{"station":station.station_id,"peer":sender})
		elif event.get("drop", false) == true: run.queue_event(role, {"drop": true})
		elif event.get("grab", "") in (game.ITEM_NAMES.keys() + ["potato_0", "potato_1", "potato_2", "sausage_0", "sausage_1", "sausage_2"] if station.type_id == "counter" else M.ITEMS): run.queue_event(role, {"grab": event.grab})

func suspend_input() -> void:
	var station: Node3D = game.local_station()
	if station != null and station.training.role_for(local_id()) >= 0:
		var pose: Dictionary = game.player.pose_in(station)
		send_input(station, {"pose": {"position": [pose.position.x, pose.position.y, pose.position.z], "yaw": pose.yaw, "pitch": pose.pitch, "presentation": {"book": game.cookbook.opened, "page": game.cookbook.recipe}}, "use": false})

func advance(delta: float) -> void:
	_draw_players(delta)
	if not connected: return
	if guest and connection_deadline > 0 and Time.get_ticks_msec() > connection_deadline:
		leave("Не удалось получить состояние кафе.")
		return
	clock += delta
	if clock < 1.0 / 30.0: return
	clock = 0
	if guest:
		if synced: _presence.rpc_id(1, capture_player())
		return
	player_poses[1] = capture_player()
	for id in handshakes.keys():
		if Time.get_ticks_msec() > handshakes[id]:
			handshakes.erase(id)
			multiplayer.multiplayer_peer.disconnect_peer(id)
	for station in game.service.stations:
		for role in range(station.role_count()):
			var peer: int = station.training.participants[role]
			if peer > 1 and Time.get_ticks_msec() - int(motion_times.get(peer, 0)) > 500:
				if station.training.inputs.has(role): station.training.inputs[role].use = false
	if members.size() < 2: return
	var entries: Array = []
	var customers: Array = []
	for station in game.service.stations:
		entries.append(station.world_entry())
		if is_instance_valid(station.taster) and not station.taster_real:
			customers.append({"mouth_amount":station.model.mouth_opening(), "drinking":station.taster.drinking,"drunk_ml":station.taster.drunk_ml,"chewing":station.taster.chewing,"watching": true, "food_target": station.taster.food_target, "cook_target": station.taster.cook_target, "following_food": station.taster.following_food, "id": -station.station_id, "position": station.taster.global_position, "yaw": station.taster.global_rotation.y, "text": station.taster.caption.text, "reaction": station.model.customer_reaction if station.type_id == "counter" else 0.0})
	for customer in game.service.customers:
		customers.append({"mouth_amount":customer.view.mouth_amount,"drinking":customer.view.drinking,"drunk_ml":customer.view.drunk_ml,"chewing":customer.view.chewing,"watching": customer.view.watching, "food_target": customer.view.food_target, "cook_target": customer.view.cook_target, "following_food": customer.view.following_food, "id": customer.id, "position": customer.view.global_position, "yaw": customer.view.global_rotation.y, "text": customer.view.caption.text, "reaction": game.service.by_id(customer.station).model.customer_reaction if game.service.by_id(customer.station) != null and game.service.by_id(customer.station).type_id == "counter" and customer.state in ["cooking", "training"] else 0.0})
	var data := {"protocol": PROTOCOL, "stations": entries, "players": player_poses, "customers": customers, "served": game.service.served, "revenue": game.service.revenue, "missed": game.service.missed, "open": game.service.open_for_business, "progression": game.service.progress.snapshot()}
	var bytes := var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE)
	for id in members:
		if id != 1: _world.rpc_id(id, bytes)

@rpc("authority", "call_remote", "reliable", 2)
func _world(packet: PackedByteArray) -> void:
	if not guest: return
	var data = bytes_to_var(packet.decompress_dynamic(4194304, FileAccess.COMPRESSION_DEFLATE))
	if not data is Dictionary or data.get("protocol") != PROTOCOL: return
	synced = true
	connection_deadline = 0
	player_poses = data.players
	var ids: Array = []
	for entry in data.stations:
		ids.append(entry.id)
		var station: Node3D = game.service.by_id(entry.id)
		if station == null: station = game.service.add_station(entry.type, int(entry.slot), entry.get("manual", false))
		station.manual_station = entry.get("manual", false)
		station.equipment = entry.get("equipment",station.equipment).duplicate()
		station.apply_equipment()
		station.customer_order = entry.get("customer_order",{}).duplicate(true)
		station.crew = entry.crew
		station.upgrades = entry.upgrades
		station.apply_upgrades()
		station.state = entry.state
		station.customer_id = int(entry.get("customer_id", -1))
		station.order_dish = str(entry.get("order_dish", ""))
		station.recipes = {}
		var qualities: Dictionary = entry.get("recipe_quality", {})
		for key in entry.known:
			station.recipes[key] = {"duration": entry.recipe_times[key], "quality": qualities.get(key, {})}
		station.model.restore(entry.model)
		station.apply_equipment()
		station.training.apply_summary(entry.training)
		station.remote_summary = entry.training
		if station.type_id == "kitchen": station.model.live_roles = entry.training.live_roles
		for role in range(station.role_count()): station.students[role].caption.text = station.crew[role].name
	for i in range(game.service.stations.size() - 1, -1, -1):
		var station: Node3D = game.service.stations[i]
		if not station.station_id in ids:
			game.service.stations.remove_at(i)
			station.queue_free()
	for key in ["served", "revenue", "missed"]: game.service.set(key, data[key])
	game.service.open_for_business = data.open
	game.service.progress.restore(data.progression, true)
	ids.clear()
	for entry in data.customers:
		ids.append(entry.id)
		if not remote_customers.has(entry.id):
			var person := Person.new()
			game.add_child(person)
			remote_customers[entry.id] = person
		var person: Node3D = remote_customers[entry.id]
		person.position = entry.position
		person.rotation.y = entry.yaw
		person.mouth_amount = float(entry.get("mouth_amount",0))
		person.drinking = entry.get("drinking",false)
		person.drunk_ml = float(entry.get("drunk_ml",0))
		person.chewing = float(entry.get("chewing",0))
		person.caption.text = entry.text
		person.react(entry.get("reaction", 0.0))
		person.watching = entry.get("watching", false)
		person.food_target = entry.get("food_target", Vector3.ZERO)
		person.cook_target = entry.get("cook_target", Vector3.ZERO)
		person.following_food = entry.get("following_food", false)
	for id in remote_customers.keys():
		if not id in ids:
			remote_customers[id].queue_free()
			remote_customers.erase(id)

func _draw_players(delta: float) -> void:
	for id in player_poses:
		if id == local_id() or not members.has(id): continue
		if not player_avatars.has(id):
			var avatar := Avatar.new()
			avatar.tint = Color("789fce") if id == 1 else Color("c99a73")
			game.add_child(avatar)
			player_avatars[id] = avatar
		var avatar: Node3D = player_avatars[id]
		var pose: Dictionary = player_poses[id].duplicate(true)
		var target := Vector3.ZERO
		var held := false
		var station: Node3D = game.service.training_for(id)
		if station != null and station.training.phase == "recording":
			var role: int = station.training.role_for(id)
			if role >= 0:
				var item: String = station.model.held if station.type_id == "counter" else station.model.hands[role]
				held = not item.is_empty()
				if held:
					var point: Vector2 = station.model.get(item) if station.type_id == "counter" else station.model.positions[item]
					var height: float = station.model.elevations[item] if station.type_id == "counter" else station.model.heights[item]
					target = station.to_global(Vector3(point.x, 1.14 + height, point.y))
		avatar.perform(pose, target, held)
		avatar.caption.text = str(members[id])
		if station != null and avatar.book.current_page == station.training.dish:
			avatar.book.set_live(station.model)
		else:
			avatar.book.set_live(null)

