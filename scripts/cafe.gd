extends Node3D
## FPS teaching feeds employee recordings into the three-counter cafe.

const Model = preload("res://scripts/cooking_model.gd")
const View = preload("res://scripts/station_view.gd")
const Props = preload("res://scripts/props.gd")
const Player = preload("res://scripts/fps_player.gd")
const Hud = preload("res://scripts/cafe_hud.gd")
const SAVE_PATH := "user://cafe_staff.json"
const Service = preload("res://scripts/cafe_service.gd")
const TICK := 1.0 / 60.0
const Team = preload("res://scripts/team_training.gd")
const Lecture = preload("res://scripts/lecture_group.gd")
const TeamMenu = preload("res://scripts/team_menu.gd")
const Session = preload("res://scripts/coop_session.gd")
const ITEM_MOVE_SPEED := 6.0
const ITEM_NAMES := {"jug": "кувшин", "cup": "стакан", "rag": "тряпка", "pan": "сковорода", "potato": "картошка", "sausage": "сосиска"}

var live := Model.new()
var playback := Model.new()
var training: Node3D
var production: Node3D
var player: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var frames: Array = []
var service: Node3D
var clone_machine: Node3D
var selected_clone_id := 1
var selected_slot := 1
var selected_dish := "wine"
var recording := false
var team: Node3D
var lecture: Node3D
var menu: CanvasLayer
var session: Node
var elapsed := 0.0
var session_paused := false
var precision_active := false
var grip_direction := Vector3.FORWARD
var tick_count := 0
var barrier_bodies: Array[StaticBody3D] = []
var barrier_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_room()
	training = View.new()
	add_child(training)
	training.position.z = 4.8
	training.build(false)
	service = Service.new()
	add_child(service)
	production = service.stations[selected_slot].view
	playback = service.stations[selected_slot].model
	_build_zone()
	player = Player.new()
	add_child(player)
	player.global_position = Vector3(0, 0.02, 8.6)
	player.station = training
	camera = player.camera
	camera.rotation.x = -0.15
	hud = Hud.new()
	add_child(hud)
	hud.resume_requested.connect(toggle_pause)
	hud.training_requested.connect(_begin_selected_training)
	hud.teaching_closed.connect(close_teaching_menu)
	lecture = Lecture.new()
	add_child(lecture)
	team = Team.new()
	add_child(team)
	team.setup(self)
	menu = TeamMenu.new()
	add_child(menu)
	menu.start_requested.connect(team.start)
	session = Session.new()
	session.name = "Session"
	add_child(session)
	session.setup(self)
	menu.network_requested.connect(session.configure)
	_load_staff()
	_refresh_views()
	_refresh_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

	clone_machine = Node3D.new()
	add_child(clone_machine)
	clone_machine.position = Vector3(-5.8, 0, 5.3)
	Props.solid_box(clone_machine, Vector3(1.25, 1.1, 1.0), Vector3(0, 0.55, 0), Color("53687a"))
	Props.cylinder(clone_machine, 0.42, 0.60, Vector3(0, 1.40, 0), Color("88c6b8"))
	Props.cylinder(clone_machine, 0.48, 0.12, Vector3(0, 1.75, 0), Color("e5c184"))
	Props.box(clone_machine, Vector3(0.28, 0.20, 0.10), Vector3(0, 0.9, 0.55), Color("d77570"))
	var machine_label := Props.text(clone_machine, "КЛОНОМАТ\n[E] Новый сотрудник", Vector3(0, 2.30, 0), 25, Color("f3cf8b"))
	machine_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	for x in [-9.2, 15.2]:
		var sign := Props.text(self, "ВХОД" if x < 0 else "ВЫХОД", Vector3(x, 2.8, 1.6), 28, Color("f3cc85"))
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _build_zone() -> void:
	var lower: Vector2 = Player.ZONE_MIN
	var upper: Vector2 = Player.ZONE_MAX
	var depth := upper.y - lower.y
	var width := upper.x - lower.x
	var walls := [
		[Vector3(0.035, 2.7, depth), Vector3(lower.x, 1.35, (lower.y + upper.y) * 0.5)],
		[Vector3(0.035, 2.7, depth), Vector3(upper.x, 1.35, (lower.y + upper.y) * 0.5)],
		[Vector3(width, 2.7, 0.035), Vector3(0, 1.35, lower.y)],
		[Vector3(width, 2.7, 0.035), Vector3(0, 1.35, upper.y)]]
	for wall in walls:
		var mesh := Props.box(training, wall[0], wall[1], Color("86d7c2"))
		var material := mesh.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.025
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		barrier_meshes.append(mesh)
		barrier_bodies.append(Props.collision_box(training, wall[0], wall[1]))
		var stripe_size: Vector3 = wall[0]
		stripe_size.y = 0.01
		var stripe_position: Vector3 = wall[1]
		stripe_position.y = 0.01
		Props.box(training, stripe_size, stripe_position, Color("d3b775"))
	_set_zone(false)

func _set_zone(enabled: bool) -> void:
	for body in barrier_bodies: body.collision_layer = 1 if enabled else 0
	for mesh in barrier_meshes: mesh.visible = enabled
	if is_instance_valid(player): player.constrained = enabled

func can_start_recording() -> bool:
	if recording or session_paused or (is_instance_valid(team) and team.active()): return false
	var local := training.to_local(player.global_position)
	var facing := -camera.global_basis.z
	var towards := (training.global_position + Vector3(0, 1, 0) - camera.global_position).normalized()
	return absf(local.x) < 2.25 and local.z > 1.25 and local.z < 2.55 and facing.dot(towards) > 0.25

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		if not recording and not team.active():
			menu.net_panel.visible = not menu.net_panel.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu.opened() else Input.MOUSE_MODE_CAPTURED
		return
	if menu.opened():
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE: menu.close()
		return
	if team.active() and not session_paused:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE: toggle_pause()
		else: team.handle(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if hud.teaching_panel.visible: close_teaching_menu()
			else: toggle_pause()
			return
		if session_paused or hud.teaching_panel.visible: return
		match event.physical_keycode:
			KEY_E: interact()
			KEY_ENTER, KEY_KP_ENTER: finish_recording()
			KEY_X: cancel_recording()
			KEY_G:
				if not session.is_guest(): service.open_for_business = not service.open_for_business
	if session_paused or hud.teaching_panel.visible: return
	if event is InputEventMouseMotion:
		var movement: Vector2 = event.screen_relative
		if recording and live.held == "pan" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			live.tilt_pan(movement)
		elif recording and not live.held.is_empty() and Input.is_physical_key_pressed(KEY_SHIFT):
			_move_precisely(movement)
		else:
			player.look(movement)
	if event is InputEventMouseButton and event.pressed and recording:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if live.held.is_empty(): _grab(training.pick_item(camera))
				else: live.put_down()
			MOUSE_BUTTON_WHEEL_UP: live.lift_held(0.08)
			MOUSE_BUTTON_WHEEL_DOWN: live.lift_held(-0.08)

func _held_target() -> Vector2:
	var origin := training.to_local(camera.global_position)
	var ray := training.global_basis.inverse() * camera.global_basis * grip_direction
	# A shallow/upward gaze continues along the far edge instead of losing the ray.
	var reach := maxf(origin.y - Model.BASE_Y, 0.01) / maxf(-ray.y, 0.08)
	var point := origin + ray * reach
	return Vector2(point.x, point.z).clamp(-Model.BOUNDS, Model.BOUNDS)

func _grab(item: String) -> void:
	if not recording or session_paused or item.is_empty(): return
	live.pick_up(item)
	_reanchor_grip()

func _reanchor_grip() -> void:
	if live.held.is_empty(): return
	var point: Vector2 = live.get(live.held)
	var anchor := training.to_global(Vector3(point.x, Model.BASE_Y, point.y))
	# Anchor the actual item, even when the crosshair picked its handle or upper rim.
	grip_direction = camera.global_basis.inverse() * (anchor - camera.global_position).normalized()

func _move_precisely(movement: Vector2) -> void:
	var right := training.global_basis.inverse() * camera.global_basis.x
	var forward := training.global_basis.inverse() * -camera.global_basis.z
	var horizontal := Vector2(right.x, right.z).normalized() * movement.x
	horizontal -= Vector2(forward.x, forward.z).normalized() * movement.y
	live.move_item(live.held, live.get(live.held) + horizontal * 0.0035)
	_reanchor_grip()

func _physics_process(delta: float) -> void:
	if session_paused or hud.teaching_panel.visible or menu.opened():
		session.advance(delta)
		return
	tick_count += 1
	var movement := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	player.advance(delta, movement.limit_length())
	if recording:
		var precise := not live.held.is_empty() and Input.is_physical_key_pressed(KEY_SHIFT)
		if precision_active and not precise: _reanchor_grip()
		precision_active = precise
		if not live.held.is_empty():
			if not precise and live.held != "pan":
				var current: Vector2 = live.get(live.held)
				live.move_item(live.held, current.move_toward(_held_target(), ITEM_MOVE_SPEED * delta))
			var lift := float(Input.is_physical_key_pressed(KEY_R)) - float(Input.is_physical_key_pressed(KEY_F))
			live.lift_held(lift * 0.55 * delta)
		var using_item := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		live.step(delta, using_item, not using_item, using_item)
		_capture_pose()
		frames.append(live.snapshot())
		elapsed = frames.size() * TICK
	team.advance(delta)
	if not session.is_guest():
		lecture.advance(delta)
		service.advance(delta)
	session.advance(delta)
	_refresh_views()
	_refresh_hud()

func _capture_pose() -> void:
	var pose: Dictionary = player.pose_in(training)
	live.actor_position = pose.position
	live.actor_yaw = pose.yaw
	live.actor_pitch = pose.pitch

func clone_home(id: int) -> Vector3:
	var slot: int = service.slot_of(id)
	if slot < 0:
		var clone: Dictionary = service.get_clone(id)
		for person in service.reserve_people:
			if person.caption.text.begins_with(clone.get("name", "?") + "\n"): return person.global_position
		return Vector3(-6.5, 0, -6.6)
	var station: Dictionary = service.stations[slot]
	if slot == 3:
		var role: int = station.clone_ids.find(id)
		return station.view.to_global(Vector3(-1.35 if role == 0 else 1.35, 0, 1.85))
	return station.view.to_global(Vector3(0, 0, 1.85))

func near_machine() -> bool:
	if recording: return false
	var offset := clone_machine.global_position + Vector3(0, 1.1, 0) - camera.global_position
	return offset.length() < 2.8 and (-camera.global_basis.z).dot(offset.normalized()) > 0.6

func interact() -> void:
	if session.is_guest():
		hud.notice.text = "Хост выбирает сотрудников и запускает совместный показ у стола II."
		return
	if team.near() and not recording:
		menu.show_training(service.clones, session.members)
		return
	if near_machine():
		var clone: Dictionary = service.create_clone()
		_save_staff()
		hud.notice.text = "%s появился. Первые три сотрудника занимают стойки; остальных выбирай в меню обучения." % clone.name
	elif can_start_recording():
		var assigned: Array = []
		for index in range(3): assigned.append(service.stations[index].clone_id)
		hud.show_teaching(service.clones, assigned, selected_clone_id, selected_dish)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_teaching_menu() -> void:
	hud.teaching_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if session_paused else Input.MOUSE_MODE_CAPTURED

func _begin_selected_training(recipe: String, clone_id: int, slot: int) -> void:
	close_teaching_menu()
	lecture.clear_now()
	selected_dish = recipe
	selected_clone_id = clone_id
	selected_slot = slot
	start_recording()

func start_recording() -> void:
	if not can_start_recording(): return
	lecture.clear_now()
	var home := clone_home(selected_clone_id)
	service.reserve_station(selected_slot, selected_clone_id)
	production = service.stations[selected_slot].view
	playback = service.stations[selected_slot].model
	live.reset(selected_dish)
	_capture_pose()
	frames.clear()
	elapsed = 0.0
	lecture.begin([service.get_clone(selected_clone_id).name], [home], training, player, func(): service.release_station(selected_slot), [production.to_global(Vector3(0, 0, 1.85))])
	recording = true
	precision_active = false
	player.station = training
	player.zone_min = Player.ZONE_MIN
	player.zone_max = Player.ZONE_MAX
	_set_zone(true)
	hud.notice.text = "Запись началась. Клон подходит с блокнотом и наблюдает. Enter — закончить; X — отменить."
	_refresh_views()
	_refresh_hud()

func finish_recording() -> void:
	if not recording or session_paused: return
	if not live.success():
		hud.notice.text = "Показ продолжается. " + live.goal_text()
		return
	live.put_down()
	_capture_pose()
	frames.append(live.snapshot())
	elapsed = frames.size() * TICK
	var clone: Dictionary = service.get_clone(selected_clone_id)
	clone.recipes[selected_dish] = {"frames": frames.duplicate(true), "duration": elapsed}
	recording = false
	lecture.finish()
	_set_zone(false)
	var saved := _save_staff()
	hud.notice.text = "%s: %s, %s. Возвращается к стойке; покажет запись на реальном заказе." % [clone.name, Service.SHORT_NAMES[selected_dish], Model.pace(elapsed)]
	if not saved: hud.notice.text += " Запись действует до выхода: сохранить файл не удалось."
	_refresh_hud()

func cancel_recording() -> void:
	if not recording or session_paused: return
	recording = false
	frames.clear()
	live.reset()
	playback.reset(selected_dish)
	lecture.finish()
	_set_zone(false)
	hud.notice.text = "Показ отменён. Прежнее обучение сохранено. E — начать заново у стойки."
	_refresh_views()
	_refresh_hud()

func toggle_pause() -> void:
	session_paused = not session_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if session_paused else Input.MOUSE_MODE_CAPTURED
	hud.pause_panel.visible = session_paused
	_refresh_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and not session_paused and not hud.teaching_panel.visible and (not is_instance_valid(session) or not session.online()):
		toggle_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(service): _save_staff()

func _refresh_views() -> void:
	training.update_view(live, tick_count * TICK)
	service.refresh_views()
	if recording:
		var local := training.to_local(player.global_position)
		var distances := [absf(local.x - Player.ZONE_MIN.x), absf(local.x - Player.ZONE_MAX.x), absf(local.z - Player.ZONE_MIN.y), absf(local.z - Player.ZONE_MAX.y)]
		for index in range(barrier_meshes.size()):
			barrier_meshes[index].material_override.albedo_color.a = lerpf(0.16, 0.025, clampf(distances[index] / 0.8, 0, 1))

func _refresh_hud() -> void:
	hud.bottom.offset_top = -200 if team.active() else -136
	hud.prompt.offset_top = 34
	hud.prompt.offset_bottom = 94
	hud.goal.text = live.goal_text()
	hud.progress.value = live.progress_value()
	hud.clock.text = "%s %05.1f с / %s" % ["●" if recording else "", elapsed, Model.pace(elapsed)]
	hud.clone_status.text = "Сотрудники: %d · Подано: %d · $%d" % [service.clones.size(), service.served, service.revenue]
	hud.supplies.text = "Кафе %s · Гостей: %d · Ушли без заказа: %d" % ["открыто" if service.open_for_business else "закрыто", session.remote_customers.size() if session.is_guest() else service.customers.size(), service.missed]
	hud.controls.text = "WASD — ходить  •  E — обучение / клономат  •  G — открыть / закрыть кафе  •  F2 — онлайн  •  Esc — пауза"
	hud.prompt.text = "[E] Выбрать блюдо и клона" if can_start_recording() else ("[E] Создать сотрудника" if near_machine() else "")
	if recording:
		hud.controls.text = "ЛКМ — взять / поставить  •  ПКМ — использовать  •  Колесо или R/F — высота\nShift + мышь — точное движение  •  Enter — закончить  •  X — отменить"
		if live.dish == "wine":
			hud.supplies.text = "Кувшин: %d мл  •  На столе: %d мл  •  Тряпка: %d мл  •  Голубой — предмет, цветной — струя" % [roundi(live.wine), roundi(live.spilled()), roundi(live.soaked)]
		elif live.dish == "potato":
			var sides: Array[String] = []
			for index in range(6): sides.append("%s %d%%" % [Model.FACE_NAMES[index], roundi(live.potato_heat[index] * 100)])
			hud.supplies.text = "Бока: " + " · ".join(sides) + " · Падений: %d" % live.falls
		else:
			hud.supplies.text = "Соус: %d%%  •  Выскальзывание: %d%%  •  Падений: %d  •  У стола можно катить, вертикально — нести" % [roundi(live.sausage_coating * 100), roundi(live.sausage_slip * 100), live.falls]
		if live.held.is_empty():
			var hovered: String = training.pick_item(camera)
			hud.prompt.text = "[ЛКМ] Взять: " + ITEM_NAMES[hovered] if not hovered.is_empty() else "Наведи прицел на предмет"
		else:
			var height := float(live.elevations[live.held])
			hud.prompt.text = "%s / Высота: %d см" % [ITEM_NAMES[live.held].capitalize(), roundi(height * 100)]
			match live.held:
				"jug": hud.prompt.text += "\n[ПКМ] Наклонять и наливать"
				"rag": hud.prompt.text += "\n[ПКМ] Выжать над стаканом" if live.soaked > 0 else "\nОпусти на лужу, чтобы вытереть"
				"pan":
					hud.prompt.text = "[ПКМ + мышь] Наклонять сковороду\nОтпусти ПКМ — выровнять. ЛКМ — отпустить ручку."
					hud.prompt.offset_top = 150
					hud.prompt.offset_bottom = 220
				"potato": hud.prompt.text += "\n[ЛКМ] Положить на сковороду или тарелку"
				"sausage": hud.prompt.text += "\n[ПКМ] Держать вертикально · F — опустить к соусу / столу"
			if live.held in ["jug", "rag"]:
				var aim: Vector2 = live.rag if live.held == "rag" else live.spout_target()
				if aim.distance_to(live.cup) <= Model.CUP_RADIUS and not live.can_fill_at(aim, live.source_height()): hud.prompt.text += "\nПодними выше края стакана: колесо ↑"
	if recording:
		var clone: Dictionary = service.get_clone(selected_clone_id)
		hud.clone_status.text = "%s · наблюдает и записывает" % clone.name
	hud.crosshair.visible = not session_paused and not hud.teaching_panel.visible
	hud.prompt.visible = hud.crosshair.visible
	if not recording and team.near(): hud.prompt.text = "[E] Стол II · Обучить бригаду"
	team.refresh_hud()

func _save_staff() -> bool:
	if is_instance_valid(session) and session.is_guest(): return false
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(service.save_data()))
	file.close()
	return DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH) == OK

func _load_staff() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary and service.load_data(data, _valid_frame):
			selected_clone_id = service.clones[0].id
			hud.notice.text = "Сотрудники и их записи загружены. Обслуживание начнётся автоматически."
		return
	# One-time import preserves the user's successful wine demonstration.
	var old_path := "user://fps_station_recording.json"
	if not FileAccess.file_exists(old_path): return
	var old = JSON.parse_string(FileAccess.get_file_as_string(old_path))
	if not old is Dictionary or old.get("format") != "fps-station" or not old.get("frames") is Array or old.frames.is_empty(): return
	for frame in old.frames:
		if not _valid_frame(frame): return
	var result := Model.new()
	result.restore(old.frames.back())
	if not result.success(): return
	service.clones[0].recipes.wine = {"frames": old.frames, "duration": old.frames.size() * TICK}
	_save_staff()
	hud.notice.text = "Первый сотрудник получил прежнюю запись вина. Можно обучать новым блюдам."

func _valid_frame(frame: Variant) -> bool:
	if not frame is Dictionary: return false
	for key in ["jug", "cup", "rag", "landing", "actor_position"]:
		var pair = frame.get(key)
		if not pair is Array or pair.size() != (3 if key == "actor_position" else 2): return false
		for value in pair:
			if not _finite_number(value): return false
	for key in ["tilt", "wine", "filled", "soaked", "lost", "squeezed_total", "actor_yaw", "actor_pitch"]:
		if not _finite_number(frame.get(key)): return false
	if not frame.get("held") in ["", "jug", "cup", "rag", "pan", "potato", "sausage"]: return false
	if not frame.get("flowing") is bool or not frame.get("squeezing") is bool: return false
	if not frame.get("elevations") is Dictionary: return false
	for key in ["jug", "cup", "rag"]:
		var elevation = frame.elevations.get(key)
		if not _finite_number(elevation) or elevation < 0 or elevation > Model.MAX_LIFT: return false
	if not frame.get("puddles") is Array: return false
	for puddle in frame.puddles:
		if not puddle is Array or puddle.size() != 3: return false
		for value in puddle:
			if not _finite_number(value): return false
	var recipe: String = str(frame.get("dish", "wine"))
	if not recipe in Model.DISHES: return false
	if recipe != "wine":
		for key in ["pan", "potato", "sausage"]:
			var height = frame.elevations.get(key)
			if not _finite_number(height) or height < 0 or height > Model.MAX_LIFT: return false
		var food = frame.get("food")
		if not food is Dictionary: return false
		for key in ["pan_tilt", "potato", "potato_velocity", "sausage", "sausage_velocity", "potato_orientation", "potato_heat"]:
			var count := 4 if key == "potato_orientation" else (6 if key == "potato_heat" else 2)
			if not food.get(key) is Array or food[key].size() != count: return false
			for number in food[key]:
				if not _finite_number(number): return false
		for key in ["fall_speed", "falls", "sausage_angle", "sausage_phase", "sausage_coating", "sausage_slip"]:
			if not _finite_number(food.get(key)): return false
		if not food.get("potato_state") in ["pan", "falling", "table", "held", "plate"]: return false
		if not food.get("sausage_state") in ["falling", "table", "held", "plate"]: return false
	return true

func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
