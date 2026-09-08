extends Node
## Host-authoritative LAN/direct-IP co-op. No client can write staff saves or set food state.
const M = preload("res://scripts/team_cooking_model.gd")
const Person = preload("res://scripts/customer_view.gd")
const Avatar = preload("res://scripts/cook_avatar.gd")
var game: Node3D
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

func is_guest() -> bool: return guest
func online() -> bool: return connected

func configure(action: String, address: String, port: int, player_name: String) -> void:
	if game.recording or game.team.active():
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
	guest = action == "join"
	if guest:
		local_backup = game.service.save_data().duplicate(true)
		local_live_backup = game.live.snapshot()
		local_open = game.service.open_for_business
		local_missed = game.service.missed
		local_station_backup.clear()
		for station in game.service.stations:
			local_station_backup.append({"state": station.state, "model": station.model.snapshot(), "frames": station.frames, "tick": station.tick, "customer_id": station.customer_id})
	connected = true
	multiplayer.multiplayer_peer = peer
	if not guest:
		members = {1: display_name}
		_status("Сессия создана · UDP %d. Напарник подключается по IP хоста." % port)
	else: _status("Подключение к %s:%d…" % [address, port])

func leave(message: String) -> void:
	var was_guest := guest
	if game != null and game.team.active(): game.team.cancel()
	if multiplayer.multiplayer_peer != null: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
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

func _peer_connected(_id: int) -> void: pass
func _peer_left(id: int) -> void:
	members.erase(id)
	if not guest:
		if game.team.partner == id: game.team.cancel()
		_roster.rpc(members)
		_status("Напарник отключился. Успешные записи сохранены.")

func _joined() -> void:
	_register.rpc_id(1, display_name)
	for customer in game.service.customers: customer.view.hide()
	for person in game.service.reserve_people: person.hide()
	game.lecture.hide()
	game.menu.close()
	_status("Подключено. Подойди к столу II; хост выберет тебя в режиме «Вместе».")

@rpc("any_peer", "call_remote", "reliable", 0)
func _register(value: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	members[sender] = value.strip_edges().left(24)
	_roster.rpc(members)
	_status("В кафе %d игрока. Режим «Вместе» доступен у стола II." % members.size())

@rpc("authority", "call_remote", "reliable", 0)
func _roster(value: Dictionary) -> void: members = value

func send_motion(value: Dictionary) -> void:
	if guest and connected and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_motion.rpc_id(1, value)

func send_event(value: Dictionary) -> void:
	if guest and connected and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_event.rpc_id(1, value)

func _authorized() -> bool:
	return multiplayer.is_server() and game.team.phase == "together" and multiplayer.get_remote_sender_id() == game.team.partner

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _motion(value: Dictionary) -> void:
	if not _authorized() or not M.valid_pose(value.get("pose")): return
	var clean := {"use": value.get("use", false) == true}
	var p: Array = value.pose.position
	clean.pose = {"position": [clampf(p[0], -3.15, 3.15), clampf(p[1], 0, 0.2), clampf(p[2], -1.35, 2.95)], "yaw": wrapf(value.pose.yaw, -PI, PI), "pitch": clampf(value.pose.pitch, -1.4, 1.3)}
	if M.numbers(value.get("target"), 2): clean.target = [clampf(value.target[0], -M.BOUNDS.x, M.BOUNDS.x), clampf(value.target[1], -M.BOUNDS.y, M.BOUNDS.y)]
	if M.finite(value.get("height")): clean.height = clampf(value.height, 0, 1.1)
	game.team.remote = clean
	last_motion_ms = Time.get_ticks_msec()

@rpc("any_peer", "call_remote", "reliable", 0)
func _event(value: Dictionary) -> void:
	if not _authorized(): return
	var now := Time.get_ticks_msec()
	if now - event_window > 1000:
		event_window = now
		event_count = 0
	event_count += 1
	if event_count > 30: return
	if value.get("cancel", false) == true: game.team.cancel()
	elif value.get("retake", false) == true: game.team.retake()
	elif value.get("finish", false) == true: game.team.finish()
	elif game.team.remote_events.size() < 8:
		if value.get("drop", false) == true: game.team.remote_events.append({"drop": true})
		elif value.get("grab", "") in M.ITEMS: game.team.remote_events.append({"grab": value.grab})

func advance(delta: float) -> void:
	if not connected or guest: return
	if Time.get_ticks_msec() - last_motion_ms > 500: game.team.remote["use"] = false
	broadcast_clock += delta
	if broadcast_clock < 1.0 / 30.0: return
	broadcast_clock = 0
	if members.size() < 2: return
	var stations: Array = []
	for station in game.service.stations:
		stations.append({"model": station.model.snapshot(), "state": station.state, "clone_id": station.clone_id, "clone_ids": station.get("clone_ids", [])})
	var clones: Array = []
	for clone in game.service.clones: clones.append({"id": clone.id, "name": clone.name, "recipes": {}})
	var customers: Array = []
	for customer in game.service.customers:
		customers.append({"id": customer.id, "position": customer.view.position, "yaw": customer.view.rotation.y, "text": customer.view.caption.text})
	var students: Array = []
	for entry in game.lecture.students:
		students.append({"position": entry.actor.position, "yaw": entry.actor.rotation.y, "text": entry.actor.caption.text, "notebook": entry.actor.notebook.visible, "head": entry.actor.head.rotation})
	var packet := {"team": {"model": game.team.model.snapshot(), "phase": game.team.phase, "partner": game.team.partner, "info": game.team.info, "restart": restart_id}, "training": game.live.snapshot(), "stations": stations, "clones": clones, "customers": customers, "students": students, "revenue": game.service.revenue, "served": game.service.served, "open": game.service.open_for_business, "missed": game.service.missed}
	_world.rpc(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))

@rpc("authority", "call_remote", "reliable", 2)
func _world(packet: PackedByteArray) -> void:
	if not guest: return
	var decoded = bytes_to_var(packet.decompress_dynamic(1048576, FileAccess.COMPRESSION_DEFLATE))
	if not decoded is Dictionary: return
	var data: Dictionary = decoded
	game.team.apply_remote(data.team, data.team.phase == "together" and data.team.partner == multiplayer.get_unique_id())
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
