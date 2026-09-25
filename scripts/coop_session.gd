extends Node
## Host-owned station sessions. Inputs and actions are addressed by station ID and take revision.
const M = preload("res://scripts/team_cooking_model.gd")
const Avatar = preload("res://scripts/cook_avatar.gd")
const Person = preload("res://scripts/customer_view.gd")
const MasterclassLibrary = preload("res://scripts/masterclass_library.gd")
const Insights = preload("res://scripts/cafe_insights.gd")
const Expansion = preload("res://scripts/cafe_expansion_layout.gd")
const PROTOCOL := "slapdash-cafe-scale-38"
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
var sleeping_peers := {}
var sleep_scene := {}
var sleep_revision := 0
var last_movie_record_id := 0
const SLEEP_SECONDS := 7.0
const WAKE_SECONDS := 5.8

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
		if is_instance_valid(actor):
			var remote_root: Node=actor.get_meta("remote_root",actor)
			remote_root.free()
	for actor in remote_customers.values():
		if is_instance_valid(actor): actor.free()
	player_avatars.clear()
	remote_customers.clear()
	clear_sleeping()
	sleep_revision=0
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
		if is_instance_valid(game.laboratory): game.laboratory.recover()
	if not message.is_empty(): _status(message)

func _status(value: String) -> void:
	game.menu.net_status.text = value
	game.hud.notice.text = value
	game.hud.show_toast(value)
	if is_instance_valid(game.office) and game.office.opened(): game.office.flash_notice(value)

func _peer_left(id: int) -> void:
	members.erase(id)
	sleeping_peers.erase(id)
	_compact_sleep_stack()
	if sleep_scene_active():
		sleep_scene.participants.erase(id)
		sleep_scene.skips.erase(id)
	player_poses.erase(id)
	handshakes.erase(id)
	if player_avatars.has(id):
		var avatar: Node=player_avatars[id]
		var remote_root: Node=avatar.get_meta("remote_root",avatar)
		remote_root.queue_free()
		player_avatars.erase(id)
	if not guest:
		game.laboratory.nursery.release_peer(id)
		if is_instance_valid(game.service.live_training) and game.service.live_training.is_active() and int(game.service.live_training.teacher_peer)==id:
			game.service.live_training.cancel("Преподаватель вышел из игры.")
		for parcel in game.service.progress.deliveries:
			if parcel.owner == id: parcel.owner = 0
		if game.service.progress.garland_builder == id: game.service.progress.garland_builder = 0
		for station in game.service.stations:
			if station.training.lead == id or station.training.role_for(id) >= 0: station.training.close()
		broadcast_roster()
		_broadcast_sleep_state()
		_try_finish_sleep()
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
	var spawn:=Expansion.player_spawn(Expansion.stage_for_progress(game.service.progress))
	player_poses[sender] = {"position": [spawn.x, spawn.y, spawn.z], "yaw": 0.0, "pitch": -0.15}
	broadcast_roster()
	if bool(game.service.movie_state.get("playing",false)): _send_movie_record(sender)

func broadcast_roster() -> void:
	for id in members:
		if id != 1: _roster.rpc_id(id, members)

@rpc("authority", "call_remote", "reliable", 0)
func _rejected(message: String) -> void: leave(message)

@rpc("authority", "call_remote", "reliable", 0)
func _roster(value: Dictionary) -> void: members = value

func _send_movie_record(peer: int) -> void:
	var record: Dictionary=game.service.movie_record()
	if record.is_empty(): return
	var payload: Dictionary=MasterclassLibrary.movie_payload(record)
	var packet:=var_to_bytes(payload).compress(FileAccess.COMPRESSION_DEFLATE)
	if peer==1:
		game.service.remote_movie_record=payload
	elif connected and members.has(peer):
		_movie_record.rpc_id(peer,packet)

func _broadcast_movie_record() -> void:
	for id in members:
		if int(id)!=1: _send_movie_record(int(id))

@rpc("authority","call_remote","reliable",0)
func _movie_record(packet: PackedByteArray) -> void:
	if not guest: return
	var bytes:=packet.decompress_dynamic(16777216,FileAccess.COMPRESSION_DEFLATE)
	var value=bytes_to_var(bytes)
	if value is Dictionary: game.service.remote_movie_record=value

func sleep_participants() -> Array:
	var result: Array = []
	if members.is_empty():
		result.append(1)
	else:
		for id in members: result.append(int(id))
	return result

func local_sleep_bed() -> int:
	return int(sleeping_peers.get(local_id(),-1))

func local_sleeping() -> bool:
	return local_sleep_bed() >= 0

func sleep_scene_active() -> bool:
	return bool(sleep_scene.get("active",false))

func sleep_scene_age() -> float:
	return float(sleep_scene.get("age",0.0))

func sleep_scene_phase() -> String:
	return str(sleep_scene.get("phase","sleep"))

func _compact_sleep_stack() -> void:
	var ids: Array=sleeping_peers.keys()
	ids.sort_custom(func(a,b):return int(sleeping_peers[a])<int(sleeping_peers[b]))
	for i in range(ids.size()): sleeping_peers[ids[i]]=i

func sleep_status_text() -> String:
	var total := sleep_participants().size()
	var ready := 0
	for id in sleep_participants():
		if sleeping_peers.has(id): ready += 1
	if total<=1: return "Спит"
	return "Спят %d/%d" % [ready,total]

func clear_sleeping() -> void:
	sleeping_peers.clear()
	sleep_scene.clear()
	sleep_revision+=1

func _peer_world_position(id: int) -> Vector3:
	if id == 1: return game.player.global_position
	var raw: Array = player_poses.get(id,{}).get("position",[])
	return Vector3(raw[0],raw[1],raw[2]) if raw.size()==3 else Vector3.INF

func _broadcast_sleep_state() -> void:
	sleep_revision+=1
	if not connected or guest: return
	for id in members:
		if id != 1: _sleep_state.rpc_id(id,sleeping_peers,sleep_scene,sleep_revision)

@rpc("authority", "call_remote", "reliable", 0)
func _sleep_state(value: Dictionary, scene: Dictionary, revision: int) -> void:
	if revision<sleep_revision: return
	sleep_revision=revision
	sleeping_peers=value.duplicate(true)
	var previous_age:=sleep_scene_age()
	var same_scene: bool=sleep_scene.get("serial",-1)==scene.get("serial",-2)
	var same_phase: bool=sleep_scene_phase()==str(scene.get("phase","sleep"))
	sleep_scene=scene.duplicate(true)
	if same_scene and same_phase and sleep_scene_active(): sleep_scene.age=maxf(previous_age,sleep_scene_age())

func _try_finish_sleep() -> bool:
	if guest or sleep_scene_active() or game.service.progress.shift!="night": return false
	if game.service.any_training(): return false
	if game.laboratory.blocks_sleep(): return false
	var participants:=sleep_participants()
	if participants.is_empty(): return false
	for id in participants:
		if not sleeping_peers.has(id): return false
	game.laboratory.prepare_sleep()
	sleep_scene={"active":true,"phase":"sleep","age":0.0,"serial":sleep_revision+1,"participants":participants,"skips":[],"night_start":game.service.progress.night_elapsed}
	_broadcast_sleep_state()
	return true

func _scene_unanimous() -> bool:
	var participants: Array=sleep_scene.get("participants",[])
	var skips: Array=sleep_scene.get("skips",[])
	if participants.is_empty(): return false
	for id in participants:
		if id not in skips: return false
	return true

func _advance_sleep(delta: float) -> void:
	if not sleep_scene_active(): return
	var phase: String=sleep_scene_phase()
	var duration: float=SLEEP_SECONDS if phase=="sleep" else WAKE_SECONDS
	sleep_scene.age=minf(duration,sleep_scene_age()+delta)
	if guest: return
	if phase=="sleep" and game.service.progress.shift!="night":
		clear_sleeping(); _broadcast_sleep_state(); return
	if phase=="wake" and game.service.progress.shift!="open":
		clear_sleeping(); _broadcast_sleep_state(); return
	if sleep_scene_age()<duration and not _scene_unanimous(): return
	if phase=="sleep":
		var error: String=game.service.next_day()
		if not error.is_empty():
			clear_sleeping()
			_broadcast_sleep_state()
			game.service.announce(error)
			return
		sleep_scene.phase="wake"
		sleep_scene.age=0.0
		sleep_scene.skips=[]
		sleep_scene.morning_day=game.service.progress.day
		_broadcast_sleep_state()
		game.save_cafe()
		return
	clear_sleeping()
	_broadcast_sleep_state()
	var bonus:=roundi((game.service.progress.rest_multiplier-1.0)*100)
	game.service.announce("День %d · кафе открыто · отдых: +%d%% к темпу клонов."%[game.service.progress.day,bonus])
	game.save_cafe()

func _sleep_action(sender: int, value: Dictionary) -> String:
	var action := str(value.get("action",""))
	if action == "wake":
		if sleeping_peers.has(sender):
			sleeping_peers.erase(sender)
			_compact_sleep_stack()
			_broadcast_sleep_state()
		return ""
	if game.service.progress.shift != "night": return "Спать можно после окончания смены."
	if game.service.any_training(): return "Сначала заверши все показы."
	if game.laboratory.hands_busy(sender): return "Сначала освободи руки."
	if game.laboratory.blocks_sleep(): return "Сначала заверши опыт, ручную рекалибровку или извлечение клона."
	var bed := int(value.get("bed",-1))
	if bed < 0 or bed >= game.annex.PLAYER_BED_COUNT: return "Кровать не найдена."
	var center: Vector3 = game.annex.player_bed_center(bed,game.service.progress.lounge_tier,game.annex.play_stage(game.service.progress))
	if _peer_world_position(sender).distance_to(center) > 4.5: return "Подойди к кровати."
	if not sleeping_peers.has(sender): sleeping_peers[sender]=sleeping_peers.size()
	_broadcast_sleep_state()
	if not _try_finish_sleep():
		var name := str(members.get(sender,"Повар"))
		game.service.announce("%s лёг спать · %s" % [name,sleep_status_text()])
	return ""

func capture_player() -> Dictionary:
	var p: Vector3 = game.player.global_position
	return {"lab_pull":game.laboratory.local_pull_holding(), "lab_hold": game.laboratory.local_holding(), "position": [p.x, p.y, p.z], "yaw": game.player.rotation.y, "pitch": game.camera.rotation.x, "presentation": {"book": game.cookbook.opened, "page": game.cookbook.recipe}}

func clean_pose(pose: Dictionary) -> Dictionary:
	var appearance: Dictionary = pose.get("presentation", {}) if pose.get("presentation", {}) is Dictionary else {}
	return {"lab_pull":pose.get("lab_pull",false)==true, "lab_hold":pose.get("lab_hold",false)==true, "position": [clampf(pose.position[0], Expansion.HALL_X_MIN-1.0, Expansion.HALL_X_MAX+1.0), clampf(pose.position[1], 0, 4), clampf(pose.position[2], Expansion.entrance_z(4)-3.0, 31.5)], "yaw": wrapf(pose.yaw, -PI, PI), "pitch": clampf(pose.pitch, -1.4, 1.3), "presentation": {"book": appearance.get("book",false) == true, "page": preload("res://scripts/cookbook_data.gd").page(str(appearance.get("page","index")))}}

@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _presence(pose: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if guest or not members.has(sender) or not M.valid_pose(pose): return
	player_poses[sender] = clean_pose(pose)
	player_poses[sender].received_at = Time.get_ticks_msec()

func _host_at_shop(sender: int) -> bool:
	if sender == 1 and is_instance_valid(game.office) and game.office.opened(): return true
	return is_instance_valid(game.shop) and is_instance_valid(game.shop.computer) and near_peer(sender, game.shop.computer, 4.5)

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
	if action=="skip_sleep":
		if sleep_scene_active() and sender in sleep_scene.participants and sender not in sleep_scene.skips:
			sleep_scene.skips.append(sender)
			_broadcast_sleep_state()
		return
	if sleep_scene_active(): return
	if sleeping_peers.has(sender) and action!="wake": return
	if action in ["take_parcel","drop_parcel","install_parcel","unpack_garland","garland_remove","garland_anchor","worker_owned_parcel"]:
		var error: String = game.shop.action(sender,value)
		if not error.is_empty(): message_to(sender,error)
		else: game.save_cafe()
		return
	if action in ["sleep","wake"]:
		var error: String = _sleep_action(sender,value)
		if not error.is_empty(): message_to(sender,error)
		return
	if action in ["visit_accept","visit_decline","visit_cancel"]:
		if sender!=1:
			message_to(sender,"Общий визит подтверждает хозяин кафе."); return
		if not near_peer(sender,game.shop.computer,4.5):
			message_to(sender,"Подойди к компьютеру кафе."); return
		var error: String=game.service.Visits.action(game.service,action,int(value.get("id",-1)))
		if not error.is_empty(): message_to(sender,error)
		return
	if action in ["group_rename","group_train","group_create","group_dissolve","group_active","training_course_confirm","training_course_edit","training_cancel_course","training_cancel_lesson","training_resume"]:
		if sender!=1:
			message_to(sender,"Группами столов управляет хозяин кафе.")
			return
		if not near_peer(sender,game.shop.computer,4.5):
			message_to(sender,"Подойди к компьютеру кафе.")
			return
		var error: String=""
		match action:
			"group_rename":
				error=game.service.rename_table_group(str(value.get("group","")),str(value.get("name","")))
			"group_train":
				var ids: Array=value.get("stations",[]) if value.get("stations",[]) is Array else []
				if ids.size()>game.service.SLOT_COUNT: ids=ids.slice(0,game.service.SLOT_COUNT)
				var command: String=str(value.get("command","legacy:%d:%d:%s"%[sender,int(value.get("record",0)),",".join(ids.map(func(id):return str(int(id))))]))
				error=game.service.start_group_training(int(value.get("record",0)),ids,sender,command)
			"training_course_confirm":
				var assignments: Array=value.get("assignments",[]) if value.get("assignments",[]) is Array else []
				var command: String=str(value.get("command","course:%d:%d"%[sender,game.service.training_queue.next_course_id]))
				var group_order: Array=value.get("group_order",[]) if value.get("group_order",[]) is Array else []
				var result: Dictionary=game.service.queue_training_course(assignments,"together",command,sender,[])
				error=str(result.get("error",""))
			"training_course_edit":
				var assignments: Array=value.get("assignments",[]) if value.get("assignments",[]) is Array else []
				var group_order: Array=value.get("group_order",[]) if value.get("group_order",[]) is Array else []
				error=game.service.edit_training_course(int(value.get("course",0)),assignments,"together",sender,[])
			"training_resume":
				error=game.service.resume_training_assignment(int(value.get("station",0)),str(value.get("dish","")),sender)
			"training_cancel_course":
				error=game.service.cancel_training_course(int(value.get("course",0)))
			"training_cancel_batch":
				error=game.service.cancel_training_batch(int(value.get("batch",0)))
			"training_cancel_lesson":
				error=game.service.cancel_training_lesson(int(value.get("lesson",0)))
			"group_create":
				var ids: Array=value.get("stations",[]) if value.get("stations",[]) is Array else []
				error=game.service.create_table_group(ids,str(value.get("name","")))
			"group_dissolve":
				var groups: Array=value.get("groups",[]) if value.get("groups",[]) is Array else []
				error=game.service.dissolve_table_groups(groups)
			"group_active":
				error=game.service.set_group_dish_active(str(value.get("group","")),str(value.get("dish","")),bool(value.get("enabled",false)))
		if not error.is_empty(): message_to(sender,error)
		else:
			game.save_cafe()
			var success: String="Обучение добавлено в очередь." if action in ["group_train","training_course_confirm"] else "Очередь обучения обновлена." if action=="training_course_edit" else "Обучение возвращено в очередь." if action=="training_resume" else "Очередь обучения обновлена." if action.begins_with("training_") else "Группы столов обновлены."
			message_to(sender,success)
		return
	if action in ["masterclass_rename","masterclass_delete"]:
		if sender!=1:
			message_to(sender,"Видеотекой управляет хозяин кафе.")
			return
		var error: String=game.service.rename_masterclass(int(value.get("id",0)),str(value.get("name",""))) if action=="masterclass_rename" else game.service.delete_masterclass(int(value.get("id",0)))
		if not error.is_empty(): message_to(sender,error)
		else: game.save_cafe()
		return
	if action=="masterclass_watch":
		var lounge=game.get_tree().get_first_node_in_group("staff_lounge")
		var tv: Node3D=lounge.television_node() if is_instance_valid(lounge) else null
		if tv==null or not near_peer(sender,tv,4.8):
			message_to(sender,"Подойди к телевизору в комнате отдыха.")
			return
		var error: String=game.service.start_highlights(int(value.get("id",0)),sender)
		if not error.is_empty(): message_to(sender,error)
		else:
			_broadcast_movie_record()
			message_to(sender,"Хайлайты запущены на телевизоре.")
		return
	if action in ["live_lesson_start","live_lesson_begin","live_lesson_cancel"]:
		var chef: Node3D=game.service.by_id(1)
		if chef==null or not near_peer(sender,chef,5.5):
			message_to(sender,"Подойди к шеф-станции.")
			return
		var error: String=""
		if action=="live_lesson_start": error=game.service.request_live_lesson(str(value.get("dish","")),int(value.get("clone_id",0)),sender)
		elif action=="live_lesson_begin": error=game.service.begin_live_lesson(sender)
		else: error=game.service.cancel_live_lesson(sender)
		if not error.is_empty(): message_to(sender,error)
		else:
			message_to(sender,"Клон заканчивает работу и идёт к Шефу." if action=="live_lesson_start" else "Показ начался." if action=="live_lesson_begin" else "Личный урок отменён; прежний навык сохранён.")
		return
	if action=="masterclass_start":
		var chef: Node3D=game.service.by_id(1)
		if chef==null or not near_peer(sender,chef,5.0):
			message_to(sender,"Подойди к шеф-станции.")
			return
		var error: String=game.service.request_masterclass(str(value.get("dish","")),sender,value.get("equipment",null))
		if not error.is_empty(): message_to(sender,error)
		elif game.service.masterclass_active(): message_to(sender,"Мастер-класс готов. Выбери исполнителей ролей.")
		else: message_to(sender,"Мастер-класс запланирован после уже принятых заказов шефа. Новые личные заказы приостановлены.")
		return
	if action.begins_with("lab_"):
		var error: String=game.laboratory.action(sender,value)
		if not error.is_empty(): message_to(sender,error)
		elif action in ["lab_pot","lab_scan","lab_press","lab_restart","lab_production_config","lab_cal_auto","lab_cal_start"]: game.save_cafe()
		return
	if action in ["buy_station_batch","buy_bundle", "buy", "banquet", "cancel_banquet", "business", "save", "new_cafe"]:
		if sender != 1:
			message_to(sender, "Общие покупки и проверку подтверждает хозяин кафе.")
			return
		if action in ["buy_station_batch","buy_bundle","buy","business","banquet"] and not _host_at_shop(sender):
			message_to(sender,"Подойди к компьютеру кафе.")
			return
		var error := ""
		match action:
			"buy_station_batch":
				if value.get("stations",[]) is Array and value.get("equipment",[]) is Array: error=game.shop.order_station_batch(str(value.get("type","")),value.stations,value.equipment,str(value.get("group","")))
			"buy_bundle":
				if value.get("items") is Array: error=game.shop.order_bundle(value.items,int(value.get("station",0)))
			"buy": error = game.service.purchase(str(value.get("kind", "")), str(value.get("item", "")), int(value.get("station", 0)))
			"banquet": error = game.service.start_banquet(sender)
			"cancel_banquet": game.service.finish_banquet(false, "Проверка прервана.")
			"save":
				if game.service.any_training():
					message_to(sender,"Сначала заверши текущий показ или обучение сотрудников.")
					return
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
	if action in ["manual","open","pass"]:
		game.laboratory.nursery.discard_infinite_tool(sender)
		if game.laboratory.hands_busy(sender) or game.laboratory.researching(sender) or game.laboratory.calibrator.manual_owner()==sender:
			message_to(sender,"Сначала освободи руки или заверши текущее действие.")
			return
	if action == "manual":
		if near_peer(sender, station, 5.0): game.service.request_manual(station, str(value.get("dish", "wine")), sender)
		return
	if game.service.progress.phase == "tasting" and action == "cancel":
		if sender == run.lead: game.service.finish_banquet(false, "Дегустация прервана.")
		return
	if action == "open":
		if not near_peer(sender, station, 5.0): return
		message_to(sender,"Способ готовки записывается только на Шеф-станции через мастер-класс.")
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
			if run.purpose=="live_lesson" and run.phase=="ready":
				run.start_pass([sender])
			elif run.phase in ["recording", "review"]:
				var assignments: Array = run.participants.duplicate()
				run.phase = "ready"
				run.start_pass(assignments)
		"accept":
			var was_masterclass: bool=run.purpose=="masterclass"
			if run.accept():
				game.save_cafe()
				message_to(sender, "Мастер-класс сохранён в общей видеотеке." if was_masterclass else "Личный урок принят. Ученик запомнил способ." if run.purpose=="live_lesson" else "Бригада обучена. Запись будет повторяться на заказах.")
			else:
				run.revision += 1
				message_to(sender, run.info)
		"cancel":
			if run.purpose=="masterclass": game.service.cancel_masterclass()
			elif run.purpose=="live_lesson": game.service.cancel_live_lesson(sender)
			else: run.close()
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
		elif event.get("dump", false) == true and station.type_id == "solyanka_kitchen": run.queue_event(role, {"dump": true})
		elif event.get("drop", false) == true: run.queue_event(role, {"drop": true})
		elif event.get("grab", "") in (game.ITEM_NAMES.keys() + ["potato_0", "potato_1", "potato_2", "sausage_0", "sausage_1", "sausage_2"] if station.type_id == "counter" else station.model.ITEMS): run.queue_event(role, {"grab": event.grab})

func suspend_input() -> void:
	var station: Node3D = game.local_station()
	if station != null and station.training.role_for(local_id()) >= 0:
		var pose: Dictionary = game.player.pose_in(station)
		send_input(station, {"pose": {"position": [pose.position.x, pose.position.y, pose.position.z], "yaw": pose.yaw, "pitch": pose.pitch, "presentation": {"book": game.cookbook.opened, "page": game.cookbook.recipe}}, "use": false})

func advance(delta: float) -> void:
	_advance_sleep(delta)
	_draw_players(delta)
	if not guest and game.service.progress.shift != "night" and not sleep_scene_active() and not sleeping_peers.is_empty():
		clear_sleeping()
		_broadcast_sleep_state()
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
	var movie_id: int=int(game.service.movie_state.get("id",0)) if bool(game.service.movie_state.get("playing",false)) else 0
	if movie_id>0 and movie_id!=last_movie_record_id:
		_broadcast_movie_record()
		last_movie_record_id=movie_id
	elif movie_id==0: last_movie_record_id=0
	if members.size() < 2: return
	var entries: Array = []
	var customers: Array = []
	for station in game.service.stations:
		entries.append(station.world_entry())
		if is_instance_valid(station.taster) and not station.taster_real:
			customers.append({"playback_speed":station.taster.playback_speed,"mouth_amount":station.model.mouth_opening(), "drinking":station.taster.drinking,"drunk_ml":station.taster.drunk_ml,"chewing":station.taster.chewing,"watching": true, "food_target": station.taster.food_target, "cook_target": station.taster.cook_target, "following_food": station.taster.following_food, "id": -station.station_id, "position": station.taster.global_position, "yaw": station.taster.global_rotation.y, "text": station.taster.caption.text, "reaction": station.model.customer_reaction if station.type_id == "counter" else 0.0})
	for customer in game.service.customers:
		customers.append({"visit_kind":customer.get("visit_kind",""),"meal":customer.view.meal_items,"meal_age":customer.view.meal_age,"playback_speed":customer.view.playback_speed,"mouth_amount":customer.view.mouth_amount,"drinking":customer.view.drinking,"drunk_ml":customer.view.drunk_ml,"chewing":customer.view.chewing,"watching": customer.view.watching, "food_target": customer.view.food_target, "cook_target": customer.view.cook_target, "following_food": customer.view.following_food, "id": customer.id, "position": customer.view.global_position, "yaw": customer.view.global_rotation.y, "text": customer.view.caption.text, "reaction": game.service.by_id(customer.station).model.customer_reaction if game.service.by_id(customer.station) != null and game.service.by_id(customer.station).type_id == "counter" and customer.state in ["cooking", "training"] else 0.0})
	var data := {"laboratory":game.laboratory.snapshot(),"sleeping":sleeping_peers.duplicate(true),"sleep_scene":sleep_scene.duplicate(true),"sleep_revision":sleep_revision,"protocol":PROTOCOL,"stations":entries,"players":player_poses,"customers":customers,"served":game.service.served,"revenue":game.service.revenue,"missed":game.service.missed,"guests_arrived":game.service.guests_arrived,"order_stats":game.service.order_stats.duplicate(true),"analytics":game.service.analytics.duplicate(true),"open":game.service.open_for_business,"progression":game.service.progress.snapshot(),"masterclasses":game.service.masterclass_summaries(),"next_masterclass_id":game.service.next_masterclass_id,"movie":game.service.movie_snapshot(),"table_group_names":game.service.table_group_names.duplicate(true),"table_group_registry":game.service.group_snapshot(),"training_queue":game.service.training_queue.public_snapshot(),"staff_training":game.service.staff_training.snapshot(),"live_training":game.service.live_training.snapshot()}
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
	_sleep_state(data.get("sleeping",{}),data.get("sleep_scene",{}),int(data.get("sleep_revision",0)))
	var ids: Array = []
	for entry in data.stations:
		ids.append(entry.id)
		var station: Node3D = game.service.by_id(entry.id)
		if station!=null and (station.type_id!=entry.type or station.masterclass_station!=bool(entry.get("masterclass",false))):
			game.service.stations.erase(station)
			station.queue_free()
			station=null
		if station == null: station = game.service.add_station(entry.type, int(entry.slot), entry.get("manual", false))
		station.staffed = int(entry.get("staffed",station.role_count()))
		station.manual_station = entry.get("manual", false)
		station.masterclass_station=bool(entry.get("masterclass",false))
		station.method_sources=entry.get("method_sources",{}).duplicate(true)
		station.method_plan=entry.get("method_plan",{}).duplicate(true)
		station.active_dishes=entry.get("active_dishes",[]).duplicate()
		station.active_menu_initialized=bool(entry.get("active_menu_initialized",false))
		station.group_training_state=str(entry.get("group_training_state",""))
		station.pending_teacher=int(entry.get("pending_teacher",0))
		station.execution_method_id=int(entry.get("execution_method_id",0))
		station.execution_crew=entry.get("execution_crew",[]).duplicate(true)
		station.equipment = entry.get("equipment",station.equipment).duplicate()
		station.apply_equipment()
		station.customer_order = entry.get("customer_order",{}).duplicate(true)
		station.crew = entry.crew
		station.upgrades = entry.upgrades
		station.apply_upgrades()
		station.state = entry.state
		station.order_tempo=float(entry.get("order_tempo",1.0))
		station.order_portions_total=int(entry.get("order_portions_total",1))
		station.order_portions_done=int(entry.get("order_portions_done",0))
		station.order_paid=int(entry.get("order_paid",0))
		station.customer_id = int(entry.get("customer_id", -1))
		station.order_dish = str(entry.get("order_dish", ""))
		station.recipes = {}
		var qualities: Dictionary = entry.get("recipe_quality", {})
		var requirements: Dictionary=entry.get("recipe_requirements",{})
		for key in entry.known:
			station.recipes[key] = {"duration": entry.recipe_times[key], "quality": qualities.get(key, {}), "required_equipment":requirements.get(key,station.Definition.DISH_EQUIPMENT.get(key,[])).duplicate()}
		station.model.restore(entry.model)
		station.apply_equipment()
		station.training.apply_summary(entry.training)
		station.remote_summary = entry.training
		if station.role_count() > 1: station.model.live_roles = entry.training.live_roles
		for role in range(station.role_count()): station.students[role].caption.text = station.crew[role].name
	for i in range(game.service.stations.size() - 1, -1, -1):
		var station: Node3D = game.service.stations[i]
		if not station.station_id in ids:
			game.service.stations.remove_at(i)
			station.queue_free()
	game.service.sync_masterclass_live_scene()
	for key in ["served","revenue","missed","guests_arrived"]: game.service.set(key,int(data.get(key,0)))
	game.service.order_stats=data.get("order_stats",game.service.blank_order_stats()).duplicate(true)
	game.service.analytics=Insights.normalize(data.get("analytics",{}))
	game.service.open_for_business = data.open
	game.service.masterclasses=data.get("masterclasses",[]).duplicate(true)
	game.service.next_masterclass_id=int(data.get("next_masterclass_id",1))
	game.service.table_group_names=data.get("table_group_names",{}).duplicate(true)
	game.service.apply_group_snapshot(data.get("table_group_registry",{}))
	game.service.training_queue.apply_public_snapshot(data.get("training_queue",{}))
	game.service.apply_movie_snapshot(data.get("movie",{}))
	game.service.staff_training.apply_snapshot(data.get("staff_training",{}))
	game.service.live_training.apply_snapshot(data.get("live_training",{}))
	game.service.progress.restore(data.progression, true)
	game.laboratory.restore(data.laboratory)
	ids.clear()
	for entry in data.customers:
		ids.append(entry.id)
		if not remote_customers.has(entry.id):
			var person := Person.new()
			game.add_child(person)
			remote_customers[entry.id] = person
		var person: Node3D = remote_customers[entry.id]
		person.position = entry.position
		if entry.has("meal") and not entry.meal.is_empty() and person.meal_items.is_empty(): person.begin_meal(entry.meal)
		person.meal_age=float(entry.get("meal_age",person.meal_age))
		person.rotation.y = entry.yaw
		person.playback_speed = float(entry.get("playback_speed",1.0))
		person.mouth_amount = float(entry.get("mouth_amount",0))
		person.drinking = entry.get("drinking",false)
		person.drunk_ml = float(entry.get("drunk_ml",0))
		person.chewing = float(entry.get("chewing",0))
		person.caption.text = entry.text
		game.service.Visits.badge(person,str(entry.get("visit_kind","")))
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
			var remote_root:=preload("res://scripts/scene_runtime.gd").clone_warm("res://scenes/actors/remote_player.tscn") as Node3D
			var avatar:=remote_root.get_node("Avatar") as Node3D
			avatar.set_script(Avatar)
			avatar.tint = Color("789fce") if id == 1 else Color("c99a73")
			game.add_child(remote_root)
			avatar.set_meta("remote_root",remote_root)
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
		if sleeping_peers.has(id):
			var layer: int=int(sleeping_peers[id])
			if sleep_scene_active() and sleep_scene_phase()=="wake":
				var rise: float=smoothstep(0.0,1.0,clampf(sleep_scene_age()/1.15,0.0,1.0))
				avatar.morning_wake_pose(game.annex.player_bed_exit(layer,game.service.progress.lounge_tier,game.annex.play_stage(game.service.progress)),0.0,rise,int(id))
				avatar.caption.text += "\nПросыпается"
			else:
				game.annex.settle_player_avatar(avatar,layer)
				avatar.caption.text += "\nСпит"
		if station != null and avatar.book.current_page == station.training.dish:
			avatar.book.set_live(station.model)
		else:
			avatar.book.set_live(null)

func lab_result(peer: int, value: Dictionary) -> void:
	if peer==local_id(): _lab_result(value)
	elif connected and members.has(peer): _lab_result.rpc_id(peer,value)

@rpc("authority","call_remote","reliable",0)
func _lab_result(value: Dictionary) -> void:
	if value.get("kind","")=="controls": game.office.open("laboratory")
	else: game.laboratory.ui.open(value)
