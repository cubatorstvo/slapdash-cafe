extends Node3D
const Props = preload("res://scripts/props.gd")
const Player = preload("res://scripts/fps_player.gd")
const Service = preload("res://scripts/cafe_service.gd")
const SAVE_PATH := "user://station_cafe.save"
const ITEM_NAMES := {"jug": "кувшин", "cup": "стакан", "rag": "тряпка", "pan": "сковорода", "potato": "картошка", "sausage": "сосиска", "tomato": "помидор · ПКМ — бросить"}
var cookbook: CanvasLayer
var feedback: Node
var player: CharacterBody3D
var camera: Camera3D
var service: Node3D
var hud: CanvasLayer
var menu: CanvasLayer
var session: Node
var steam: Node
var session_paused := false
var bound_station := 0
var bound_revision := -1
var local_role := -1
var grip := Vector3.FORWARD
# The drag plane is anchored on pickup; lifting changes only item Y.
var grip_plane_y := 1.015
var height := 0.4
var target := Vector2.ZERO
var pan_tilt := Vector2.ZERO
var anchored_item := ""
var precise := false
var last_menu_revision := ""

func _ready() -> void:
	_build_room()
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 0.02, 6)
	camera = player.camera
	camera.rotation.x = -0.2
	hud = preload("res://scripts/cafe_hud.gd").new()
	add_child(hud)
	hud.resume_requested.connect(toggle_pause)
	menu = preload("res://scripts/cafe_menu.gd").new()
	add_child(menu)
	menu.game = self
	service = Service.new()
	service.game = self
	add_child(service)
	service.initial_stations()
	session = preload("res://scripts/coop_session.gd").new()
	session.name = "Session"
	add_child(session)
	session.setup(self)
	menu.command_requested.connect(func(action): menu.close(); session.request_action(action))
	menu.network_requested.connect(session.configure)
	menu.closed.connect(sync_mouse_mode)
	steam = preload("res://scripts/steam_lobby.gd").new()
	add_child(steam)
	menu.steam_requested.connect(func(action): steam.invite_friends() if action == "invite" else steam.create_lobby())
	steam.setup(self)
	cookbook = preload("res://scripts/cookbook.gd").new()
	add_child(cookbook)
	cookbook.attach(self)
	feedback = preload("res://scripts/cafe_feedback.gd").new()
	add_child(feedback)
	feedback.game = self
	load_cafe()
	sync_mouse_mode()

func input_blocked() -> bool:
	return (is_instance_valid(cookbook) and cookbook.opened) or awaiting_serving_confirmation() or session_paused or menu.opened() or (is_instance_valid(steam) and steam.overlay_open)

func awaiting_serving_confirmation() -> bool:
	if not is_instance_valid(service) or not is_instance_valid(session): return false
	var station := local_station()
	return station != null and station.training.phase == "confirm_finish"

func sync_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if input_blocked() else Input.MOUSE_MODE_CAPTURED

func toggle_pause() -> void:
	if cookbook.opened: cookbook.close()
	session_paused = not session_paused
	hud.pause_panel.visible = session_paused
	session.suspend_input()
	for loops in feedback.audio_nodes.values():
		for voice in loops.values(): voice.stream_paused = session_paused and not session.online()
	sync_mouse_mode()

func local_station() -> Node3D: return service.training_for(session.local_id())

func nearest_station() -> Node3D:
	var best: Node3D
	var distance := 4.6
	for station in service.stations:
		var direction: Vector3 = station.global_position + Vector3.UP - camera.global_position
		if direction.length() < distance and (-camera.global_basis.z).dot(direction.normalized()) > 0.3:
			distance = direction.length()
			best = station
	return best

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(steam) and steam.overlay_open: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B and not session_paused and not menu.opened() and not awaiting_serving_confirmation():
			cookbook.toggle()
			return
		if event.physical_keycode == KEY_ESCAPE:
			if cookbook.opened:
				cookbook.close()
				return
			if awaiting_serving_confirmation():
				var current := local_station()
				if current.training.lead == session.local_id():
					menu.close()
					session.request_action({"action": "resume", "station": current.station_id})
			elif menu.opened(): menu.close()
			else: toggle_pause()
			return
		if event.physical_keycode == KEY_F2:
			menu.net_panel.visible = not menu.net_panel.visible
			sync_mouse_mode()
			return
	if input_blocked(): return
	var station := local_station()
	var recording: bool = station != null and station.training.phase == "recording" and local_role >= 0
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				if recording and station.bell_hit(camera):
					session.request_action({"action": "ring", "station": station.station_id})
					return
				var selected := station if station != null else nearest_station()
				if selected != null: menu.show_station(selected)
			KEY_BACKSPACE:
				if recording: session.request_action({"action": "retake", "station": station.station_id})
			KEY_X:
				if station != null: session.request_action({"action": "cancel", "station": station.station_id})
			KEY_G: session.request_action({"action": "business"})
			KEY_SPACE:
				if player.is_on_floor(): player.velocity.y = 6.2
	if event is InputEventMouseMotion:
		if recording and held_item(station) == "pan" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			pan_tilt = (pan_tilt + event.screen_relative * 0.003).limit_length(0.18)
		elif recording and not held_item(station).is_empty() and Input.is_physical_key_pressed(KEY_SHIFT):
			var right: Vector3 = station.global_basis.inverse() * camera.global_basis.x
			var forward: Vector3 = station.global_basis.inverse() * -camera.global_basis.z
			target += (Vector2(right.x, right.z).normalized() * event.screen_relative.x - Vector2(forward.x, forward.z).normalized() * event.screen_relative.y) * 0.0035
			precise = true
		else:
			player.look(event.screen_relative)
			if recording and precise: anchor(station)
			precise = false
	if recording and event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if station.bell_hit(camera):
					session.request_action({"action": "ring", "station": station.station_id})
					return
				var item: String = held_item(station)
				var command: Dictionary = {"drop": true} if not item.is_empty() else {"grab": station.view.pick_item(camera)}
				session.send_input(station, {}, command)
			MOUSE_BUTTON_WHEEL_UP: height = minf(1.1, height + 0.08)
			MOUSE_BUTTON_WHEEL_DOWN: height = maxf(-1.0, height - 0.08)

func held_item(station: Node3D) -> String:
	if local_role < 0: return ""
	return station.model.held if station.type_id == "counter" else station.model.hands[local_role]

func anchor(station: Node3D) -> void:
	var item := held_item(station)
	if item.is_empty(): return
	target = station.model.get(item) if station.type_id == "counter" else station.model.positions[item]
	height = station.model.elevations[item] if station.type_id == "counter" else station.model.heights[item]
	grip_plane_y = 1.015 + height
	var at := station.to_global(Vector3(target.x, grip_plane_y, target.y))
	grip = camera.global_basis.inverse() * (at - camera.global_position).normalized()

func bind_training() -> void:
	var station := local_station()
	if station == null:
		bound_station = 0
		local_role = -1
		player.constrained = false
		return
	var run = station.training
	local_role = run.role_for(session.local_id())
	if run.phase == "recording" and local_role >= 0:
		last_menu_revision = ""
		if bound_station != station.station_id or bound_revision != run.revision:
			player.station = station
			var width: float = station.Definition.TYPES[station.type_id].width / 2 + 0.5
			player.zone_min = Vector2(-width, -2.3)
			player.zone_max = Vector2(width, 2.9)
			if station.role_count() > 1 and run.live_roles.size() == 1:
				if local_role == 0: player.zone_max.x = 0
				else: player.zone_min.x = 0
			player.global_position = station.to_global(Vector3((-1.35 if local_role == 0 else 1.35) if station.role_count() > 1 else 0, 0.02, 1.85))
			player.rotation.y = station.global_rotation.y
			camera.rotation.x = -0.35
			player.velocity = Vector3.ZERO
			anchored_item = ""
			precise = false
			pan_tilt = Vector2.ZERO
			menu.close()
			bound_station = station.station_id
			bound_revision = run.revision
		player.constrained = true
	else:
		player.constrained = run.phase == "confirm_finish"
		var stamp := "%d:%d:%s" % [station.station_id, run.revision, run.phase]
		if run.lead == session.local_id() and run.phase in ["ready", "review", "confirm_finish"] and stamp != last_menu_revision:
			last_menu_revision = stamp
			menu.show_station(station)

	sync_mouse_mode()

func build_motion(station: Node3D, delta: float) -> Dictionary:
	var item := held_item(station)
	if item != anchored_item:
		anchor(station)
		anchored_item = item
	var pose: Dictionary = player.pose_in(station)
	var command := {"pose": {"position": [pose.position.x, pose.position.y, pose.position.z], "yaw": pose.yaw, "pitch": pose.pitch, "presentation": {"book": cookbook.opened, "page": cookbook.recipe}}, "use": not input_blocked() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)}
	var aim: Vector3 = station.global_basis.inverse() * -camera.global_basis.z
	command.aim = [aim.x, aim.y, aim.z]
	if not item.is_empty():
		if not input_blocked(): height = clampf(height + (float(Input.is_physical_key_pressed(KEY_R)) - float(Input.is_physical_key_pressed(KEY_F))) * delta * 0.55, -1.0, 1.1)
		if not precise:
			var origin: Vector3 = station.to_local(camera.global_position)
			var ray: Vector3 = station.global_basis.inverse() * camera.global_basis * grip
			var reach := maxf(origin.y - grip_plane_y, 0.01) / maxf(-ray.y, 0.08)
			var point := origin + ray * reach
			target = Vector2(point.x, point.z)
		# Keep the requested height at the support surface, not just the rendered item.
		var current: Vector2 = station.model.get(item) if station.type_id == "counter" else station.model.positions[item]
		var limited_target: Vector2 = target.clamp(-station.model.BOUNDS, station.model.BOUNDS)
		var support: float = maxf(station.model.surface_at(current), station.model.surface_at(limited_target)) - station.model.BASE_Y
		height = clampf(height, support, 1.1)
		command.target = [target.x, target.y]
		command.height = height
		command.pan_tilt = [pan_tilt.x, pan_tilt.y]
	return command

func _physics_process(delta: float) -> void:
	bind_training()
	if cookbook.opened and (menu.opened() or awaiting_serving_confirmation()): cookbook.close()
	if session_paused and not session.online(): return
	var move := Vector2.ZERO if input_blocked() else Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if not awaiting_serving_confirmation(): player.advance(delta, move.limit_length())
	var station := local_station()
	if station != null and station.training.phase == "recording" and local_role >= 0: session.send_input(station, build_motion(station, delta))
	if not session.is_guest(): service.advance(delta)
	session.advance(delta)
	service.refresh_views(delta)
	refresh_hud()
	feedback.update(delta)
	if cookbook.opened or menu.opened(): hud.recipe_panel.hide()
	hud.bottom.visible = not cookbook.opened
	hud.crosshair.visible = not cookbook.opened and not menu.opened()
	if cookbook.opened: hud.prompt.text = ""

func refresh_hud() -> void:
	hud.clone_status.text = "%d станций · обслужено %d · выручка %d" % [service.stations.size(), service.served, service.revenue]
	hud.controls.text = "B  Книга    ·    E  Станция    ·    F2  Друзья"
	hud.supplies.text = ""
	hud.clock.text = "ОТКРЫТО" if service.open_for_business else "ГОСТИ: ПАУЗА"
	hud.goal.text = "Подойди к рабочей станции · [E]"
	hud.progress.value = 0
	hud.prompt.text = ""
	hud.recipe_panel.hide()
	var station := local_station()
	if station == null:
		station = nearest_station()
		if station != null:
			hud.prompt.text = "[E] Станция %d · %s" % [station.station_id, station.Definition.TYPES[station.type_id].title]
			if station.state == "cooking":
				hud.recipe_panel.show()
				hud.show_recipe(station.model.quality(), station.order_dish)
				hud.goal.text = station.Definition.DISHES[station.order_dish]
		return
	hud.recipe_panel.show()
	hud.show_recipe(station.model.quality(), station.training.dish)
	hud.notice.text = ""
	hud.goal.text = station.Definition.DISHES[station.training.dish]
	hud.clock.text = "%.1f с" % (station.training.tick / 60.0)
	hud.progress.value = 100 if station.model.success() else 0
	hud.supplies.text = "Закончил? Позвони в звонок на стойке."
	hud.controls.text = "ЛКМ  Взять    ·    ПКМ  Действие    ·    Колесо  Высота    ·    B  Книга"
	if local_role >= 0 and station.training.phase == "recording":
		if station.bell_hit(camera):
			hud.prompt.text = "ЛКМ / E  ·  Подать и закончить показ"
			return
		var item := held_item(station)
		if item.is_empty():
			item = station.view.pick_item(camera)
			if item.is_empty(): return
			var allowed: bool = station.type_id == "counter" or station.model.can_touch(local_role, item)
			hud.prompt.text = ("[ЛКМ] " if allowed else "Красная зона · записывай эту роль отдельно\n") + str(ITEM_NAMES.get(item.get_slice("_", 0) if item.begins_with("potato_") or item.begins_with("sausage_") else item, station.TeamModel.NAMES.get(item, "")))
		else: hud.prompt.text = "[ПКМ] Использовать · " + str(ITEM_NAMES.get(item.get_slice("_", 0) if item.begins_with("potato_") or item.begins_with("sausage_") else item, station.TeamModel.NAMES.get(item, "")))

func save_cafe() -> bool:
	if session.is_guest(): return false
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(var_to_bytes(service.save_data()).compress(FileAccess.COMPRESSION_DEFLATE))
	var error := file.get_error()
	file.close()
	if error != OK: return false
	return DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH) == OK

func load_cafe() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or file.get_length() > 134217728: return
	var bytes := file.get_buffer(file.get_length()).decompress_dynamic(268435456, FileAccess.COMPRESSION_DEFLATE)
	var data = bytes_to_var(bytes)
	if not data is Dictionary or not service.load_data(data): hud.notice.text = "Сохранение не прочитано. Открыто новое кафе."

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(session): save_cafe()
func _build_room() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1b3036")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("f4e2c7")
	environment.environment.ambient_light_energy = 0.35
	add_child(environment)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_color = Color("fff4e2")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	for x in range(-10, 16):
		for z in range(-8, 11):
			var color := Color("6c7c73") if (x + z) % 2 == 0 else Color("79887b")
			Props.box(self, Vector3(0.995, 0.09, 0.995), Vector3(x + 0.5, -0.05, z + 0.5), color)
	Props.collision_box(self, Vector3(26, 0.2, 19), Vector3(3, -0.10, 1.5))
	Props.solid_box(self, Vector3(26, 4.7, 0.18), Vector3(3, 2.3, -7.6), Color("244c50"))
	Props.solid_box(self, Vector3(26, 4.7, 0.18), Vector3(3, 2.3, 10.6), Color("244c50"))
	for x in [-9.8, 15.8]:
		Props.solid_box(self, Vector3(0.18, 4.7, 18.2), Vector3(x, 2.3, 1.5), Color("2e5355"))
	Props.box(self, Vector3(14, 0.10, 0.22), Vector3(0, 1.2, -7.45), Color("bb8d5e"))
	Props.box(self, Vector3(5.7, 0.85, 0.1), Vector3(0, 3.4, -7.40), Color("183237"))
	Props.text(self, "SLAPDASH CAFE", Vector3(0, 3.49, -7.31), 62, Color("f4cc86"))
	Props.text(self, "ПОКАЗЫВАЙ. Я ПОВТОРЮ.", Vector3(0, 2.85, -7.31), 25, Color("a5c8b6"))
	for x in [-5.1, 5.1]:
		Props.box(self, Vector3(1.6, 1.35, 0.13), Vector3(x, 2.7, -7.35), Color("edcb89"))
		Props.box(self, Vector3(1.37, 1.12, 0.07), Vector3(x, 2.7, -7.26), Color("9cc9c5"))
		Props.box(self, Vector3(0.05, 1.18, 0.06), Vector3(x, 2.7, -7.20), Color("edcb89"))
		Props.cylinder(self, 0.28, 0.44, Vector3(x, 0.22, -4.9), Color("bb7c56"), 0.35)
		for index in range(5):
			var leaf := Props.ball(self, 0.22, Vector3(x + sin(index * 1.4) * 0.18, 0.8 + index * 0.12, -4.9), Color("649b71"))
			leaf.scale = Vector3(0.8, 1.7, 0.8)
	Props.box(self, Vector3(2.0, 0.018, 0.65), Vector3(0, 0.006, 7.1), Color("c09b63"))

	for x in [-9.2, 15.2]:
		var sign := Props.text(self, "ВХОД" if x < 0 else "ВЫХОД", Vector3(x, 2.8, 1.6), 28, Color("f3cc85"))
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
