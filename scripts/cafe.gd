extends Node3D
const Props = preload("res://scripts/props.gd")
const Player = preload("res://scripts/fps_player.gd")
const Service = preload("res://scripts/cafe_service.gd")
const Annex = preload("res://scripts/cafe_annex.gd")
const SAVE_PATH := "user://shop_cafe.save"
const ITEM_NAMES := {"plate_0": "тарелка", "plate_1": "тарелка", "plate_2": "тарелка","jug": "кувшин", "cup": "стакан", "rag": "тряпка", "pan": "сковорода", "potato": "картошка", "sausage": "сосиска", "tomato": "помидор · ПКМ — бросить"}
var sleep_cinematic: Node3D
var evening: Node3D
var annex: Node3D
var laboratory: Node3D
var shop: Node3D
var telemetry: Node
var daylight: DirectionalLight3D
var room_environment: WorldEnvironment
var save_writer: Node
var office: CanvasLayer
var development: Node3D
var development_stamp := ""
var event_phase_seen := "none"
var cookbook: Node
var feedback: Node
var player: CharacterBody3D
var camera: Camera3D
var service: Node3D
var hud: CanvasLayer
var menu: CanvasLayer
var session: Node
var steam: Node
var journey_markers := true
var journey_marker: Node3D
var session_paused := false
var bound_station := 0
var bound_revision := -1
var local_role := -1
var sleep_bed_bound := -1
var grip := Vector3.FORWARD
# Camera-relative reach is stable even when looking above the horizon.
var grip_distance := 1.5
var previous_grip_y := 1.015
var height := 0.4
var target := Vector2.ZERO
var pan_tilt := Vector2.ZERO
var anchored_item := ""
var precise := false
var last_menu_revision := ""
var taught := {"book": false, "grab": false, "use": false, "height": false}

func _ready() -> void:
	save_writer = preload("res://scripts/cafe_save_writer.gd").new()
	add_child(save_writer)
	_build_room()
	player = Player.new()
	add_child(player)
	player.position = Vector3(-6.0, 0.02, 5.0)
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
	office = preload("res://scripts/cafe_office.gd").new()
	office.game = self
	add_child(office)
	development = preload("res://scripts/cafe_development_view.gd").new()
	add_child(development)
	development.build(self)
	shop = preload("res://scripts/cafe_shop.gd").new()
	add_child(shop)
	shop.setup(self)
	laboratory = preload("res://scripts/clone_laboratory.gd").new()
	add_child(laboratory)
	Annex.place_lab(laboratory)
	laboratory.setup(self)
	evening=preload("res://scripts/staff_evening.gd").new()
	add_child(evening)
	evening.setup(self)
	annex=Annex.new()
	add_child(annex)
	annex.setup(self)
	journey_marker=preload("res://scripts/journey_marker.gd").new()
	add_child(journey_marker); journey_marker.game=self
	sleep_cinematic=preload("res://scripts/sleep_cinematic.gd").new()
	add_child(sleep_cinematic)
	sleep_cinematic.setup(self)
	telemetry = preload("res://scripts/playtest_log.gd").new()
	add_child(telemetry)
	telemetry.begin(self)
	load_cafe()
	event_phase_seen = service.progress.phase
	development.refresh()
	hud.office_requested.connect(func(): office.open())
	sync_mouse_mode()

func input_blocked() -> bool:
	return (is_instance_valid(laboratory) and is_instance_valid(laboratory.ui) and laboratory.ui.opened()) or (is_instance_valid(session) and session.sleep_scene_active()) or (is_instance_valid(office) and office.opened()) or (is_instance_valid(cookbook) and cookbook.opened) or awaiting_serving_confirmation() or session_paused or menu.opened() or (is_instance_valid(steam) and steam.overlay_open)

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
	if is_instance_valid(session) and session.sleep_scene_active():
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_SPACE:
			session.request_action({"action":"skip_sleep"})
		return
	if is_instance_valid(laboratory) and laboratory.ui.handle_input(event): return
	if is_instance_valid(session) and session.local_sleeping():
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
			session.request_action({"action":"wake"})
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_F8,KEY_F9,KEY_F10]:
			var label: String = {KEY_F8:"скучно",KEY_F9:"непонятно",KEY_F10:"прикольно"}[event.physical_keycode]
			telemetry.event("player_mark",{"label":label,"day":service.progress.day,"activity":telemetry.activity,"journey":preload("res://scripts/cafe_journey.gd").current(service.progress,service.stations,service.served,service.open_for_business).key,"visit":service.progress.visit.get("phase","")})
			hud.show_toast("В плейтест записано: "+label)
			return
		if event.physical_keycode == KEY_B and not office.opened() and not session_paused and not menu.opened() and not awaiting_serving_confirmation():
			cookbook.toggle()
			return
		if event.physical_keycode == KEY_ESCAPE:
			if office.opened():
				office.close()
				return
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
			office.close()
			menu.net_panel.visible = not menu.net_panel.visible
			sync_mouse_mode()
			return
	if input_blocked(): return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var action: Dictionary=laboratory.target(camera,session.local_id())
		if action.get("action","")=="lab_pull" or (action.get("action","")=="lab_press" and laboratory.researching(session.local_id()) and laboratory.state.phase!="fill"):
			session.request_action(action)
			return
	var station := local_station()
	var recording: bool = station != null and station.training.phase == "recording" and local_role >= 0
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				if recording and station.type_id == "solyanka_kitchen" and station.model.can_dump(local_role):
					session.send_input(station,{}, {"dump":true})
					return
				if not recording:
					var night: Dictionary = interaction_target()
					if not night.is_empty():
						session.request_action(night)
						return
				if not recording and shop.computer_hit(camera):
					office.open()
					return
				if recording and feed_target(station):
					session.send_input(station,{}, {"feed":true})
					return
				if recording and station.bell_hit(camera):
					session.request_action({"action": "ring", "station": station.station_id})
					return
				var selected := station if station != null else nearest_station()
				if selected != null: menu.show_station(selected)
			KEY_BACKSPACE:
				if recording: session.request_action({"action": "retake", "station": station.station_id})
			KEY_X:
				if station != null: session.request_action({"action": "cancel", "station": station.station_id})
			KEY_G: hud.show_toast("Открыть и закрыть кафе можно у компьютера.")
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
				var item: String = held_item(station)
				var command: Dictionary = {"drop": true} if not item.is_empty() else {"grab": station.view.pick_item(camera)}
				if command.has("grab") and not str(command.grab).is_empty(): taught.grab = true
				session.send_input(station, {}, command)
			MOUSE_BUTTON_RIGHT:
				if not held_item(station).is_empty(): taught.use = true
			MOUSE_BUTTON_WHEEL_UP:
				taught.height = true
				if Input.is_physical_key_pressed(KEY_ALT): grip_distance = minf(3.6, grip_distance + 0.10)
				else: height = minf(1.1, height + 0.08)
			MOUSE_BUTTON_WHEEL_DOWN:
				taught.height = true
				if Input.is_physical_key_pressed(KEY_ALT): grip_distance = maxf(0.5, grip_distance - 0.10)
				else: height = maxf(-1.0, height - 0.08)

func held_item(station: Node3D) -> String:
	if local_role < 0: return ""
	return station.model.held if station.type_id == "counter" else station.model.hands[local_role]

func anchor(station: Node3D) -> void:
	var item := held_item(station)
	if item.is_empty(): return
	target = station.model.get(item) if station.type_id == "counter" else station.model.positions[item]
	height = station.model.elevations[item] if station.type_id == "counter" else station.model.heights[item]
	var at := station.to_global(Vector3(target.x, station.model.BASE_Y + height, target.y))
	var offset := at - camera.global_position
	grip_distance = clampf(offset.length(), 0.5, 3.6)
	grip = camera.global_basis.inverse() * offset.normalized()
	previous_grip_y = station.to_local(camera.global_position + camera.global_basis * grip * grip_distance).y

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
			player.zone_min = station.training_zone_min()
			player.zone_max = station.training_zone_max()
			if station.role_count() > 1 and run.live_roles.size() == 1:
				var role_zone: Vector2 = station.role_zone_x(local_role)
				player.zone_min.x = role_zone.x
				player.zone_max.x = role_zone.y
			player.global_position = station.to_global(Vector3(station.role_home_x(local_role), 0.02, 1.85))
			player.rotation.y = station.global_rotation.y
			camera.rotation.x = -0.35
			player.velocity = Vector3.ZERO
			anchored_item = ""
			precise = false
			pan_tilt = Vector2.ZERO
			menu.close()
			office.close()
			bound_station = station.station_id
			bound_revision = run.revision
		player.constrained = true
	else:
		player.constrained = run.phase == "confirm_finish"
		var stamp := "%d:%d:%s" % [station.station_id, run.revision, run.phase]
		if run.lead == session.local_id() and not office.opened() and run.phase in ["ready", "review", "confirm_finish"] and stamp != last_menu_revision:
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
			var point: Vector3 = station.to_local(camera.global_position + camera.global_basis * grip * grip_distance)
			target = Vector2(point.x, point.z)
			height += point.y - previous_grip_y
			previous_grip_y = point.y
		# Keep the requested height at the support surface, not just the rendered item.
		var current: Vector2 = station.model.get(item) if station.type_id == "counter" else station.model.positions[item]
		var limited_target: Vector2 = target.clamp(-station.model.BOUNDS, station.model.BOUNDS)
		var support: float = maxf(station.model.surface_at(current), station.model.surface_at(limited_target)) - station.model.BASE_Y
		if station.type_id == "counter": support = maxf(station.model.support_at(current, station.model.BASE_Y + height), station.model.support_at(limited_target, station.model.BASE_Y + height)) - station.model.BASE_Y
		height = clampf(height, support, 1.1)
		command.target = [target.x, target.y]
		command.height = height
		command.pan_tilt = [pan_tilt.x, pan_tilt.y]
	return command

func sync_sleep_pose() -> void:
	var bed: int = session.local_sleep_bed() if is_instance_valid(session) else -1
	if bed >= 0:
		if sleep_bed_bound != bed:
			player.enter_sleep(Annex.player_sleep_position(bed,service.progress.lounge_tier),Annex.player_sleep_yaw(bed))
			sleep_bed_bound = bed
	elif sleep_bed_bound >= 0:
		var previous_bed := sleep_bed_bound
		sleep_bed_bound = -1
		player.exit_sleep(Annex.player_bed_exit(previous_bed,service.progress.lounge_tier))

func _physics_process(delta: float) -> void:
	if session.sleep_scene_active():
		session.advance(delta)
		sync_sleep_pose()
		return
	bind_training()
	sync_sleep_pose()
	if cookbook.opened and (menu.opened() or awaiting_serving_confirmation()): cookbook.close()
	if session_paused and not session.online(): return
	var move := Vector2.ZERO if input_blocked() or session.local_sleeping() else Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if not awaiting_serving_confirmation() and not session.local_sleeping(): player.advance(delta, move.limit_length())
	var station := local_station()
	if station != null and station.training.phase == "recording" and local_role >= 0: session.send_input(station, build_motion(station, delta))
	if not session.is_guest(): service.advance(delta)
	session.advance(delta)
	service.refresh_views(delta)
	refresh_hud()
	if event_phase_seen != service.progress.phase:
		event_phase_seen = service.progress.phase
		if event_phase_seen in ["won", "lost"]:
			if event_phase_seen == "won": feedback.play_ui("ready")
			menu.close()
			hud.show_toast(service.progress.result)
	var display_stamp := "%d:%d" % [service.progress.revision, service.stations.size()]
	if display_stamp != development_stamp:
		development_stamp = display_stamp
		development.refresh()
	var night: bool = service.progress.shift == "night"
	daylight.light_energy = lerpf(daylight.light_energy, 0.12 if night else 0.75, minf(1, delta * 0.6))
	room_environment.environment.ambient_light_energy = lerpf(room_environment.environment.ambient_light_energy, 0.26 if night else 0.35, minf(1, delta * 0.6))
	feedback.update(delta)
	if menu.opened() or cookbook.opened or office.opened(): hud.recipe_panel.hide()
	hud.bottom.visible = false
	hud.crosshair.visible = not laboratory.ui.opened() and not cookbook.opened and not menu.opened() and not office.opened() and not session.local_sleeping()
	if cookbook.opened and not hud.prompt.text.begins_with("(E)"): hud.prompt.text = ""

func refresh_hud() -> void:
	hud.clone_status.text = "День %d · %d денег · популярность %d · ★ %d/5 · %d станций · %d гостей" % [service.progress.day, service.progress.cash, service.progress.popularity, service.progress.stars, service.stations.size(), service.served]
	hud.controls.text = ""
	hud.supplies.text = ""
	hud.clock.text = "ОТКРЫТО" if service.open_for_business else "НОЧЬ" if service.progress.shift == "night" else "ЗАКРЫВАЕМСЯ" if service.progress.shift == "closing" else "ДО ОТКРЫТИЯ"
	var next: Dictionary=preload("res://scripts/cafe_journey.gd").current(service.progress,service.stations,service.served,service.open_for_business)
	hud.goal.text=str(next.title)
	hud.journey.text=str(next.detail)
	hud.visit_status.text=service.Visits.status(service.progress) if service.progress.visit.get("phase","") in ["offered","scheduled","active"] else ""
	if service.progress.rest_multiplier>1.0: hud.goal.text+=" · отдых +%d%%"%roundi((service.progress.rest_multiplier-1.0)*100)
	hud.progress.value = 0
	hud.prompt.text = ""
	hud.recipe_panel.hide()
	if session.local_sleeping():
		hud.goal.text = "Сон · ожидание остальных игроков"
		hud.journey.text = "Утром вернёмся к следующей цели кафе."
		hud.prompt.text = session.sleep_status_text() + " · E встать"
		return
	if laboratory.nursery.pulling(session.local_id()):
		hud.prompt.text="Удерживай E / ЛКМ и тяни назад · отпусти, чтобы перехватить"
		return
	if laboratory.nursery.holding(session.local_id()):
		hud.prompt.text="В руках: "+str(laboratory.nursery.TOOLS.get(laboratory.nursery.tool(session.local_id()),"Образец жидкости"))+" · верни на полку или используй"
	elif not taught.book and not cookbook.opened: hud.prompt.text = "B · Книга"
	var station := local_station()
	if station == null:
		var night: Dictionary = interaction_target()
		if not night.is_empty(): hud.prompt.text = night.get("hint", "(E) Взаимодействовать")
		if service.progress.shift == "open":
			var left: int = ceili(service.Progression.SHIFT_SECONDS - service.progress.shift_elapsed)
			hud.clock.text = "%d:%02d до закрытия" % [left / 60, left % 60]
		if service.progress.phase in ["showcase", "service"]: hud.clock.text = "%d:%02d" % [ceili(service.progress.remaining) / 60, ceili(service.progress.remaining) % 60]
		if shop.computer_hit(camera) and shop.carried(session.local_id())<0: hud.prompt.text = "(E) Компьютер · заказы и кафе"
		station = nearest_station()
		if station != null:
			if hud.prompt.text.is_empty() or hud.prompt.text == "B · Книга": hud.prompt.text = "(E) Личная стойка · приготовить" if station.manual_station else "[E] %s" % station.Definition.TYPES[station.type_id].title
			if station.manual_station and not service.manual_order(station).is_empty():
				hud.show_chef_request(station.customer_order)
		return
	hud.notice.text = ""
	hud.goal.text = station.Definition.DISHES[station.training.dish]
	hud.journey.text = str(next.title)+". "+str(next.detail) if station.training.purpose=="lesson" else "Цель кафе: "+str(next.title)
	if station.manual_station and not service.manual_order(station).is_empty(): hud.show_chef_request(station.customer_order)
	hud.clock.text = "%.1f с" % (station.training.tick / 60.0)
	if service.progress.shift == "open" and not service.progress.busy():
		hud.clock.text += " · закрытие через %d:%02d" % [ceili(maxf(0, service.Progression.SHIFT_SECONDS-service.progress.shift_elapsed))/60, ceili(maxf(0,service.Progression.SHIFT_SECONDS-service.progress.shift_elapsed))%60]
	if service.progress.shift == "closing": hud.clock.text += " · последний заказ"
	if service.progress.phase == "showcase":
		hud.goal.text = "Инспектор · картофель на B или лучше"
		hud.clock.text = "%d:%02d" % [ceili(service.progress.remaining) / 60, ceili(service.progress.remaining) % 60]
	hud.progress.value = 100 if station.model.success() else 0
	if local_role >= 0 and station.training.phase == "recording":
		if station.type_id == "solyanka_kitchen" and station.model.can_dump(local_role):
			hud.prompt.text = "(E) Булькнуть в котёл"
			return
		if feed_target(station):
			hud.prompt.text = "(E) Скормить"
			return
		if station.bell_hit(camera):
			hud.prompt.text = "(E) Подать блюдо" if station.training.purpose != "lesson" else "(E) Подать инспектору" if service.is_showcase(station) else "(E) Завершить показ"
			return
		var item := held_item(station)
		if item.is_empty():
			item = station.view.pick_item(camera)
			if item.is_empty():
				if not taught.grab: hud.prompt.text = "ЛКМ · Взять"
				return
			var allowed: bool = station.type_id == "counter" or station.model.can_touch(local_role, item)
			var name := str(ITEM_NAMES.get(item.get_slice("_", 0) if item.begins_with("potato_") or item.begins_with("sausage_") else item, station.model.NAMES.get(item, "") if station.type_id != "counter" else ""))
			hud.prompt.text = ("[ЛКМ] " if allowed else "Красная зона · записывай эту роль отдельно\n") + name
		else:
			var name := str(ITEM_NAMES.get(item.get_slice("_", 0) if item.begins_with("potato_") or item.begins_with("sausage_") else item, station.model.NAMES.get(item, "") if station.type_id != "counter" else ""))
			if not taught.use: hud.prompt.text = "ПКМ · %s" % name
			elif not taught.height: hud.prompt.text = "Колесо · Высота   Alt + колесо · Расстояние   Shift · Точно"
			else: hud.prompt.text = name

func save_cafe() -> bool:
	if session.is_guest() or "--fresh-cafe" in OS.get_cmdline_user_args(): return false
	save_writer.request(service.save_data(), SAVE_PATH)
	return true

func load_cafe() -> void:
	if "--fresh-cafe" in OS.get_cmdline_user_args(): return
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or file.get_length() > 134217728: return
	var bytes := file.get_buffer(file.get_length()).decompress_dynamic(268435456, FileAccess.COMPRESSION_DEFLATE)
	var data = bytes_to_var(bytes)
	if not data is Dictionary or not service.load_data(data): hud.notice.text = "Сохранение не прочитано. Открыто новое кафе."

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(session):
		save_cafe()
		save_writer.flush()
	elif what == NOTIFICATION_PREDELETE:
		_shutdown_tree(self)

func hush_audio() -> void:
	_shutdown_tree(self)

func _shutdown_tree(node: Node) -> void:
	if node.has_method("shutdown"): node.shutdown()
	for child in node.get_children():
		_shutdown_tree(child)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null

func _build_room() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1b3036")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("f4e2c7")
	environment.environment.ambient_light_energy = 0.35
	add_child(environment)
	room_environment = environment
	var sun := DirectionalLight3D.new()
	daylight = sun
	add_child(sun)
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_color = Color("fff4e2")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	for x in range(-12, 18):
		for z in range(-8, 11):
			var color := Color("6c7c73") if (x + z) % 2 == 0 else Color("79887b")
			Props.box(self, Vector3(0.995, 0.09, 0.995), Vector3(x + 0.5, -0.05, z + 0.5), color)
	Props.collision_box(self, Vector3(30, 0.2, 19), Vector3(3, -0.10, 1.5))
	Props.solid_box(self, Vector3(30, 4.7, 0.18), Vector3(3, 2.3, -7.6), Color("244c50"))
	for x in [-11.8,17.8]: Props.solid_box(self, Vector3(0.18, 4.7, 18.2), Vector3(x, 2.3, 1.5), Color("2e5355"))
	Annex.build_shell(self)
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

	for x in [-11.2, 17.2]:
		var sign := Props.text(self, "ВХОД" if x < 0 else "ВЫХОД", Vector3(x, 2.8, 1.6), 28, Color("f3cc85"))
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED



func new_cafe() -> void:
	if is_instance_valid(session): session.clear_sleeping()
	laboratory.reset()
	service.clear_world()
	service.progress = service.Progression.new()
	service.served = 0
	service.missed = 0
	service.revenue = 0
	service.open_for_business = false
	service.initial_stations()
	laboratory.recover()
	service.spawn_clock = 3.0
	bound_revision = -1
	last_menu_revision = ""
	development_stamp = ""
	player.position = Vector3(-6.0, 0.02, 5.0)
	player.velocity = Vector3.ZERO
	development.refresh()
	save_cafe()

func interaction_target() -> Dictionary:
	if is_instance_valid(annex):
		var sleep_target: Dictionary = annex.sleep_target(camera,session.local_id())
		if not sleep_target.is_empty(): return sleep_target
	if is_instance_valid(shop):
		var target: Dictionary = shop.target(camera,session.local_id())
		if not target.is_empty(): return target
	return {}

func feed_target(station: Node3D) -> bool:
	if not (station.model.can_feed() if station.type_id=="counter" else station.model.can_feed(local_role)): return false
	var mouth: Vector3=station.to_global(station.model.GUEST_MOUTH)
	var direction := -camera.global_basis.z
	var offset := mouth-camera.global_position
	var along := offset.dot(direction)
	return along>0 and (camera.global_position+direction*along).distance_to(mouth)<0.55
