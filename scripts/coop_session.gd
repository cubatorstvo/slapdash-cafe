extends Node
## Shared cafe authority, transport-independent RPCs and replicated player presence.
const M = preload("res://scripts/team_cooking_model.gd")
const Person = preload("res://scripts/customer_view.gd")
const Avatar = preload("res://scripts/cook_avatar.gd")
const PROTOCOL := "slapdash-cafe-steam-3"
var game: Node3D
var transport := "offline"
var synced := false
var connection_deadline := 0
var handshakes := {}
var player_poses := {}
var player_avatars := {}
var remote_reserves: Array = []
var input_clock := 0.0
var single_motion := {}
var single_events: Array = []
var last_single_ms := 0
var motion_times := {}
var action_times := {}
var single_revision := 0
var members := {}
var display_name := "Повар"
var connected := false
var guest := false
var restart_id := 0
var seen_restart := -1
var broadcast_clock := 0.0
var remote_customers := {}
var remote_students: Array = []
var last_motion_ms := 0
var local_backup: Dictionary = {}
var local_station_backup: Array = []
var local_live_backup: Dictionary = {}
var local_open := true
var local_missed := 0
var event_count := 0
var event_window := 0

func setup(root_game: Node3D) -> void:
	game = root_game
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_joined)
	multiplayer.connection_failed.connect(func(): leave("Не удалось подключиться. Проверь IP и UDP-порт."))
	multiplayer.server_disconnected.connect(func(): leave("Хост отключился. Возвращено локальное кафе."))

func local_id() -> int: return multiplayer.get_unique_id() if connected else 1
func is_guest() -> bool: return guest
func online() -> bool: return connected

func configure(action: String, address: String, port: int, player_name: String) -> void:
	if action != "leave" and (game.recording or game.team.active()):
		_status("Сначала заверши или отмени текущий показ.")
		return
	leave("")
	if action == "leave":
		_status("Сессия закрыта.")
		return
	display_name = player_name.strip_edges().left(24)
	if display_name.is_empty(): display_name = "Повар"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 3) if action == "host" else peer.create_client(address.strip_edges(), port)
	if error != OK:
		_status("Ошибка ENet: %s" % error_string(error))
		return
	attach_peer(peer, action == "join", display_name, "enet")
	if not guest: _status("Сессия по IP создана · UDP %d" % port)
	else: _status("Подключение к %s:%d…" % [address, port])

func attach_peer(peer: MultiplayerPeer, joining: bool, player_name: String, kind: String) -> void:
	display_name = player_name.strip_edges().left(24)
	guest = joining
	transport = kind
	if guest:
		local_backup = game.service.save_data().duplicate(true)
		local_live_backup = game.live.snapshot()
		local_open = game.service.open_for_business
		local_missed = game.service.missed
		local_station_backup.clear()
		for station in game.service.stations:
			local_station_backup.append({"state": station.state, "model": station.model.snapshot(), "frames": station.frames, "tick": station.tick, "customer_id": station.customer_id})
	connected = true
	synced = not joining
	connection_deadline = Time.get_ticks_msec() + 20000 if joining else 0
	multiplayer.multiplayer_peer = peer
	if not joining:
		members = {1: display_name}
		player_poses[1] = capture_player()


func leave(message: String) -> void:
	var was_guest := guest
	if game != null and game.recording: game.cancel_recording(true)
	if game != null and is_instance_valid(game.steam): game.steam.leave_lobby()
	if game != null and game.team.active(): game.team.cancel()
	if multiplayer.multiplayer_peer != null: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
	synced = false
	transport = "offline"
	connection_deadline = 0
	handshakes.clear()
	player_poses.clear()
	for avatar in player_avatars.values(): avatar.queue_free()
	player_avatars.clear()
	for avatar in remote_reserves: avatar.queue_free()
	remote_reserves.clear()
	single_motion.clear()
	single_events.clear()
	motion_times.clear()
	guest = false
	members.clear()
	for person in remote_customers.values(): person.queue_free()
	remote_customers.clear()
	for person in remote_students: person.queue_free()
	remote_students.clear()
	if was_guest and game != null:
		game.service.load_data(local_backup, game._valid_frame)
		local_backup.clear()
		for i in range(local_station_backup.size()):
			var station: Dictionary = game.service.stations[i]
			var backup: Dictionary = local_station_backup[i]
			station.model.restore(backup.model)
			for key in ["state", "frames", "tick", "customer_id"]: station[key] = backup[key]
		local_station_backup.clear()
		game.live.restore(local_live_backup)
		game.team.model.reset()
		game.lecture.show()
		game.service.open_for_business = local_open
		game.service.missed = local_missed
		for customer in game.service.customers: customer.view.show()
		game.service.refresh_views()
	if not message.is_empty(): _status(message)

func _status(value: String) -> void:
	game.menu.net_status.text = value
	game.hud.notice.text = value

func _peer_connected(id: int) -> void:
	if not guest: handshakes[id] = Time.get_ticks_msec() + 7000
func _peer_left(id: int) -> void:
	members.erase(id)
	player_poses.erase(id)
	handshakes.erase(id)
	if player_avatars.has(id):
		player_avatars[id].queue_free()
		player_avatars.erase(id)
	if not guest:
		if game.team.partner == id or game.team.lead_peer == id: game.team.cancel()
		if game.recording and game.teacher_peer == id: game.cancel_recording(true)
		broadcast_roster()
		_status("Напарник отключился. Успешные записи сохранены.")

func _joined() -> void:
	_register.rpc_id(1, display_name, PROTOCOL)
	for customer in game.service.customers: customer.view.hide()
	for person in game.service.reserve_people: person.hide()
	game.lecture.hide()
	game.menu.close()
	_status("Подключено. Получаю состояние кафе…")

@rpc("any_peer", "call_remote", "reliable", 0)
func _register(value: String, version: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if version != PROTOCOL or (members.size() >= 4 and not members.has(sender)) or (transport == "steam" and not game.steam.accepts_peer(sender)):
		_rejected.rpc_id(sender, "Версии игры различаются, кафе заполнено или приглашение недействительно.")
		return
	handshakes.erase(sender)
	members[sender] = game.steam.peer_name(sender) if transport == "steam" else value.strip_edges().left(24)
	player_poses[sender] = {"position": [-7.0, 0.02, 8.0], "yaw": 0.0, "pitch": -0.15}
	broadcast_roster()
	_status("В кафе %d игрока. Режим «Вместе» доступен у стола II." % members.size())

func broadcast_roster() -> void:
	for id in members:
		if id != 1: _roster.rpc_id(id, members)

@rpc("authority", "call_remote", "reliable", 0)
func _rejected(message: String) -> void: leave(message)

@rpc("authority", "call_remote", "reliable", 0)
func _roster(value: Dictionary) -> void:
	members = value
	for id in player_avatars.keys():
		if not members.has(id):
			player_avatars[id].queue_free()
			player_avatars.erase(id)

func send_motion(value: Dictionary) -> void:
	if guest and connected and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		value["revision"] = seen_restart
		_motion.rpc_id(1, value)

func send_event(value: Dictionary) -> void:
	if guest and connected and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		value["revision"] = seen_restart
		_event.rpc_id(1, value)

func _authorized() -> bool:
	return multiplayer.is_server() and members.has(multiplayer.get_remote_sender_id()) and game.team.active() and game.team.role_for(multiplayer.get_remote_sender_id()) >= 0

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _motion(value: Dictionary) -> void:
	if not _authorized() or value.get("revision", -1) != restart_id or not M.valid_pose(value.get("pose")): return
	var clean := {"use": value.get("use", false) == true}
	var p: Array = value.pose.position
	clean.pose = {"position": [clampf(p[0], -3.15, 3.15), clampf(p[1], 0, 0.2), clampf(p[2], -1.35, 2.95)], "yaw": wrapf(value.pose.yaw, -PI, PI), "pitch": clampf(value.pose.pitch, -1.4, 1.3)}
	if M.numbers(value.get("target"), 2): clean.target = [clampf(value.target[0], -M.BOUNDS.x, M.BOUNDS.x), clampf(value.target[1], -M.BOUNDS.y, M.BOUNDS.y)]
	if M.finite(value.get("height")): clean.height = clampf(value.height, 0, 1.1)
	var role: int = game.team.role_for(multiplayer.get_remote_sender_id())
	game.team.remote_by_role[role] = clean
	motion_times[role] = Time.get_ticks_msec()

@rpc("any_peer", "call_remote", "reliable", 0)
func _event(value: Dictionary) -> void:
	if not _authorized() or value.get("revision", -1) != restart_id: return
	var sender := multiplayer.get_remote_sender_id()
	if not accept_action(sender): return
	var role: int = game.team.role_for(sender)
	if value.get("cancel", false) == true: game.team.cancel()
	elif value.get("retake", false) == true: game.team.retake()
	elif value.get("finish", false) == true: game.team.finish()
	elif game.team.events_by_role[role].size() < 8:
		if value.get("drop", false) == true: game.team.events_by_role[role].append({"drop": true})
		elif value.get("grab", "") in M.ITEMS: game.team.events_by_role[role].append({"grab": value.grab})

func accept_action(sender: int) -> bool:
	var now := Time.get_ticks_msec()
	var times: Array = action_times.get(sender, [])
	while not times.is_empty() and now - times[0] > 1000: times.pop_front()
	if times.size() >= 30: return false
	times.append(now)
	action_times[sender] = times
	return true


func advance(delta: float) -> void:
	_draw_players(delta)
	if not connected: return
	if guest:
		if connection_deadline > 0 and Time.get_ticks_msec() > connection_deadline:
			leave("Не удалось получить состояние кафе. Проверь соединение и версии игры.")
			return
		input_clock += delta
		if input_clock >= 1.0 / 30.0 and synced:
			input_clock = 0
			_presence.rpc_id(1, capture_player())
		return
	player_poses[1] = capture_player()
	for id in handshakes.keys():
		if Time.get_ticks_msec() > handshakes[id]:
			handshakes.erase(id)
			multiplayer.multiplayer_peer.disconnect_peer(id)
	for role in range(2):
		if Time.get_ticks_msec() - int(motion_times.get(role, 0)) > 500: game.team.remote_by_role[role]["use"] = false
	if Time.get_ticks_msec() - last_single_ms > 500: single_motion["use"] = false
	broadcast_clock += delta
	if broadcast_clock < 1.0 / 30.0: return
	broadcast_clock = 0
	if members.size() < 2: return
	var stations: Array = []
	for station in game.service.stations:
		stations.append({"model": station.model.snapshot(), "state": station.state, "clone_id": station.clone_id, "clone_ids": station.get("clone_ids", [])})
	var clones: Array = []
	for clone in game.service.clones: clones.append({"id": clone.id, "name": clone.name, "recipes": {}, "known": clone.recipes.keys()})
	var customers: Array = []
	for customer in game.service.customers:
		customers.append({"id": customer.id, "position": customer.view.position, "yaw": customer.view.rotation.y, "text": customer.view.caption.text})
	var students: Array = []
	for entry in game.lecture.students:
		students.append({"position": entry.actor.position, "yaw": entry.actor.rotation.y, "text": entry.actor.caption.text, "notebook": entry.actor.notebook.visible, "head": entry.actor.head.rotation})
	var reserves: Array = []
	for person in game.service.reserve_people: reserves.append({"position": person.position, "yaw": person.rotation.y, "text": person.caption.text})
	var packet := {"protocol": PROTOCOL, "players": player_poses, "reserves": reserves, "single": {"active": game.recording, "teacher": game.teacher_peer, "dish": game.selected_dish, "clone": game.selected_clone_id, "slot": game.selected_slot, "elapsed": game.elapsed, "revision": single_revision}, "team": {"model": game.team.model.snapshot(), "phase": game.team.phase, "partner": game.team.partner, "lead": game.team.lead_peer, "info": game.team.info, "restart": restart_id}, "training": game.live.snapshot(), "stations": stations, "clones": clones, "customers": customers, "students": students, "revenue": game.service.revenue, "served": game.service.served, "open": game.service.open_for_business, "missed": game.service.missed}
	var bytes := var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)
	for id in members:
		if id != 1: _world.rpc_id(id, bytes)

@rpc("authority", "call_remote", "reliable", 2)
func _world(packet: PackedByteArray) -> void:
	if not guest: return
	var decoded = bytes_to_var(packet.decompress_dynamic(1048576, FileAccess.COMPRESSION_DEFLATE))
	if not decoded is Dictionary or decoded.get("protocol") != PROTOCOL: return
	var data: Dictionary = decoded
	if not synced:
		synced = true
		connection_deadline = 0
		game.menu.close()
		game.hud.notice.text = "В кафе друга. Можно создавать клонов, обучать и готовить вместе."
	player_poses = data.players
	game.team.apply_remote(data.team)
	game.apply_single_remote(data.single)
	game.live.restore(data.training)
	game.service.clones = data.clones
	game.service.revenue = data.revenue
	game.service.served = data.served
	game.service.open_for_business = data.open
	game.service.missed = data.missed
	for i in range(4):
		var station: Dictionary = game.service.stations[i]
		station.model.restore(data.stations[i].model)
		station.state = data.stations[i].state
		station.clone_id = data.stations[i].clone_id
		if i == 3: station.clone_ids = data.stations[i].clone_ids
	var ids: Array = []
	for entry in data.customers:
		ids.append(entry.id)
		if not remote_customers.has(entry.id):
			var person := Person.new()
			game.add_child(person)
			remote_customers[entry.id] = person
		var person: Node3D = remote_customers[entry.id]
		person.position = entry.position
		person.rotation.y = entry.yaw
		person.caption.text = entry.text
	for id in remote_customers.keys():
		if not id in ids:
			remote_customers[id].queue_free()
			remote_customers.erase(id)
	while remote_students.size() > data.students.size(): remote_students.pop_back().queue_free()
	while remote_students.size() < data.students.size():
		var person := Avatar.new()
		game.add_child(person)
		remote_students.append(person)
	for i in range(data.students.size()):
		var entry: Dictionary = data.students[i]
		var person: Node3D = remote_students[i]
		person.position = entry.position
		person.rotation.y = entry.yaw
		person.caption.text = entry.text
		person.observe(game.player.global_position + Vector3.UP * 1.5, game.player.global_position, 0.08, i)
		person.notebook.visible = entry.notebook
		person.head.rotation = entry.head
	game.service.refresh_views()
	while remote_reserves.size() > data.reserves.size(): remote_reserves.pop_back().queue_free()
	while remote_reserves.size() < data.reserves.size():
		var person := Person.new()
		person.chef = true
		person.color = Color("63aa98")
		game.add_child(person)
		remote_reserves.append(person)
	for i in range(data.reserves.size()):
		remote_reserves[i].position = data.reserves[i].position
		remote_reserves[i].rotation.y = data.reserves[i].yaw
		remote_reserves[i].caption.text = data.reserves[i].text

func capture_player() -> Dictionary:
	var p: Vector3 = game.player.global_position
	return {"position": [p.x, p.y, p.z], "yaw": game.player.rotation.y, "pitch": game.camera.rotation.x}

@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _presence(pose: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if guest or not members.has(sender) or not M.valid_pose(pose): return
	var p: Array = pose.position
	player_poses[sender] = {"position": [clampf(p[0], -9.5, 15.5), clampf(p[1], 0, 0.3), clampf(p[2], -7.2, 10.2)], "yaw": wrapf(pose.yaw, -PI, PI), "pitch": clampf(pose.pitch, -1.4, 1.3)}

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
		var point := Vector3(pose.position[0], pose.position[1], pose.position[2])
		var blended := avatar.position.lerp(point, minf(1, delta * 18)) if avatar.position.distance_to(point) < 3 else point
		pose.position = [blended.x, blended.y, blended.z]
		var held := false
		var target := Vector3.ZERO
		if game.recording and game.teacher_peer == id and not game.live.held.is_empty():
			held = true
			var item: Vector2 = game.live.get(game.live.held)
			target = game.training.to_global(Vector3(item.x, 1.2 + game.live.elevations[game.live.held], item.y))
		avatar.perform(pose, target, held)
		avatar.caption.text = str(members[id])
		avatar.visible = not (game.team.active() and game.team.role_for(id) >= 0)

func actor_for(id: int) -> Node3D:
	return game.player if id == local_id() or not player_avatars.has(id) else player_avatars[id]

func near_peer(id: int, object: Node3D, radius: float) -> bool:
	if id == 1: return game.player.global_position.distance_to(object.global_position) < radius
	if not player_poses.has(id): return false
	var p: Array = player_poses[id].position
	return Vector3(p[0], p[1], p[2]).distance_to(object.global_position) < radius

func request_action(action: Dictionary) -> void:
	if guest:
		if synced: _action.rpc_id(1, action)
	else: execute_action(1, action)

@rpc("any_peer", "call_remote", "reliable", 0)
func _action(action: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if guest or not members.has(sender) or not accept_action(sender): return
	execute_action(sender, action)

func execute_action(sender: int, action: Dictionary) -> void:
	match action.get("action", ""):
		"clone":
			if near_peer(sender, game.clone_machine, 3.2):
				game.service.create_clone()
				game._save_staff()
		"business": game.service.open_for_business = not game.service.open_for_business
		"team":
			if game.recording or game.team.active() or not near_peer(sender, game.team.view, 4.8):
				message_to(sender, "Презентационный стол занят или слишком далеко.")
				return
			var ids = action.get("ids", [])
			if not ids is Array: return
			game.team.start(str(action.get("mode", "roles")), ids, int(action.get("partner", -1)), sender)
		"single":
			if game.recording or game.team.active() or not near_peer(sender, game.training, 3.6):
				message_to(sender, "Презентационный стол занят или слишком далеко.")
				return
			var dish: String = str(action.get("dish", ""))
			var id := int(action.get("clone", -1))
			var slot := int(action.get("slot", -1))
			if dish in game.Model.DISHES and not game.service.get_clone(id).is_empty() and slot in [0, 1, 2]:
				game.begin_network_teaching(dish, id, slot, sender)

func message_to(id: int, text: String) -> void:
	if id == 1: _status(text)
	else: _message.rpc_id(id, text)

@rpc("authority", "call_remote", "reliable", 0)
func _message(value: String) -> void: _status(value)

func send_single_motion(value: Dictionary) -> void:
	if guest and synced:
		value["revision"] = single_revision
		_single_motion.rpc_id(1, value)

func send_single_event(value: Dictionary) -> void:
	if guest and synced:
		value["revision"] = single_revision
		_single_event.rpc_id(1, value)

func authorized_single(value: Dictionary) -> bool:
	return not guest and game.recording and multiplayer.get_remote_sender_id() == game.teacher_peer and value.get("revision", -1) == single_revision

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _single_motion(value: Dictionary) -> void:
	if not authorized_single(value) or not M.valid_pose(value.get("pose")): return
	var clean := {"pose": value.pose, "use": value.get("use", false) == true}
	if M.numbers(value.get("target"), 2): clean.target = [clampf(value.target[0], -game.Model.BOUNDS.x, game.Model.BOUNDS.x), clampf(value.target[1], -game.Model.BOUNDS.y, game.Model.BOUNDS.y)]
	if M.finite(value.get("height")): clean.height = clampf(value.height, 0, 1.1)
	if M.numbers(value.get("pan_tilt"), 2):
		var tilt := Vector2(value.pan_tilt[0], value.pan_tilt[1]).limit_length(0.18)
		clean.pan_tilt = [tilt.x, tilt.y]
	var p: Array = clean.pose.position
	clean.pose = {"position": [clampf(p[0], -2.35, 2.35), 0.0, clampf(p[2], -1.15, 2.6)], "yaw": wrapf(value.pose.yaw, -PI, PI), "pitch": clampf(value.pose.pitch, -1.4, 1.3)}
	single_motion = clean
	last_single_ms = Time.get_ticks_msec()

@rpc("any_peer", "call_remote", "reliable", 0)
func _single_event(value: Dictionary) -> void:
	if not authorized_single(value) or not accept_action(multiplayer.get_remote_sender_id()): return
	if value.get("finish", false) == true: game.finish_recording()
	elif value.get("cancel", false) == true: game.cancel_recording(true)
	elif single_events.size() < 8:
		if value.get("drop", false) == true: single_events.append({"drop": true})
		elif value.get("grab", "") in game.ITEM_NAMES: single_events.append({"grab": value.grab})

func advance_single(delta: float) -> void:
	if not single_events.is_empty():
		var action: Dictionary = single_events.pop_front()
		if action.get("drop", false): game.live.put_down()
		elif action.has("grab"):
			var allowed: Array = {"wine": ["jug", "cup", "rag"], "potato": ["pan", "potato"], "sausage": ["sausage"]}[game.live.dish]
			if action.grab in allowed: game.live.pick_up(action.grab)
	var item: String = game.live.held
	if not item.is_empty():
		if single_motion.has("target") and item != "pan":
			var target := Vector2(single_motion.target[0], single_motion.target[1])
			var point: Vector2 = game.live.get(item)
			game.live.move_item(item, point.move_toward(target, game.ITEM_MOVE_SPEED * delta))
		if single_motion.has("height"): game.live.lift_held(single_motion.height - game.live.elevations[item])
		if item == "pan" and single_motion.has("pan_tilt"): game.live.pan_tilt = Vector2(single_motion.pan_tilt[0], single_motion.pan_tilt[1])
	var using_item: bool = single_motion.get("use", false)
	game.live.step(delta, using_item, not using_item, using_item)
	if single_motion.has("pose"):
		var pose: Dictionary = single_motion.pose
		game.live.actor_position = Vector3(pose.position[0], pose.position[1], pose.position[2])
		game.live.actor_yaw = pose.yaw
		game.live.actor_pitch = pose.pitch

func suspend_input() -> void:
	if guest:
		if game.team.participating(): send_motion({"pose": game.team.model.poses[game.team.local_role], "use": false})
		if game.is_local_teaching(): send_single_motion({"pose": {"position": [game.live.actor_position.x, game.live.actor_position.y, game.live.actor_position.z], "yaw": game.live.actor_yaw, "pitch": game.live.actor_pitch}, "use": false})
