extends Node3D
## Both actors use one station-local workspace, rotated 180 degrees in the room.

const Model = preload("res://scripts/station_model.gd")
const View = preload("res://scripts/station_view.gd")
const Props = preload("res://scripts/props.gd")
const Player = preload("res://scripts/fps_player.gd")
const Hud = preload("res://scripts/cafe_hud.gd")
const SAVE_PATH := "user://fps_station_recording.json"
const TICK := 1.0 / 60.0
const DELAY_TICKS := 120
const ITEM_NAMES := {"jug": "кувшин", "cup": "стакан", "rag": "тряпка"}

var live := Model.new()
var playback := Model.new()
var training: Node3D
var production: Node3D
var player: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var frames: Array = []
var deployed: Array = []
var recording := false
var echo_active := false
var echo_clock := 0
var echo_index := -1
var production_running := false
var elapsed := 0.0
var deployed_duration := 0.0
var replay_tick := 0
var completed_orders := 0
var cycle_time := 0.0
var session_paused := false
var precision_active := false
var grip_offset := Vector2.ZERO
var tick_count := 0
var barrier_bodies: Array[StaticBody3D] = []
var barrier_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_room()
	training = View.new()
	add_child(training)
	training.position.z = 1.9
	training.build(false)
	production = View.new()
	add_child(production)
	production.position.z = -1.9
	production.rotation.y = PI
	production.build(true)
	_build_zone()
	player = Player.new()
	add_child(player)
	player.global_position = Vector3(0, 0.02, 6.2)
	player.station = training
	camera = player.camera
	camera.rotation.x = -0.15
	hud = Hud.new()
	add_child(hud)
	hud.resume_requested.connect(toggle_pause)
	_load_recording()
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
	for x in range(-7, 7):
		for z in range(-7, 9):
			var color := Color("6c7c73") if (x + z) % 2 == 0 else Color("79887b")
			Props.box(self, Vector3(0.995, 0.09, 0.995), Vector3(x + 0.5, -0.05, z + 0.5), color)
	Props.collision_box(self, Vector3(14, 0.2, 16), Vector3(0, -0.10, 1))
	Props.solid_box(self, Vector3(14, 4.7, 0.18), Vector3(0, 2.3, -6.6), Color("244c50"))
	Props.solid_box(self, Vector3(14, 4.7, 0.18), Vector3(0, 2.3, 8.6), Color("244c50"))
	for x in [-6.8, 6.8]:
		Props.solid_box(self, Vector3(0.18, 4.7, 15.4), Vector3(x, 2.3, 1), Color("2e5355"))
	Props.box(self, Vector3(14, 0.10, 0.22), Vector3(0, 1.2, -6.45), Color("bb8d5e"))
	Props.box(self, Vector3(5.7, 0.85, 0.1), Vector3(0, 3.4, -6.40), Color("183237"))
	Props.text(self, "SLAPDASH CAFE", Vector3(0, 3.49, -6.31), 62, Color("f4cc86"))
	Props.text(self, "ПОКАЗЫВАЙ. Я ПОВТОРЮ.", Vector3(0, 2.85, -6.31), 25, Color("a5c8b6"))
	for x in [-5.1, 5.1]:
		Props.box(self, Vector3(1.6, 1.35, 0.13), Vector3(x, 2.7, -6.35), Color("edcb89"))
		Props.box(self, Vector3(1.37, 1.12, 0.07), Vector3(x, 2.7, -6.26), Color("9cc9c5"))
		Props.box(self, Vector3(0.05, 1.18, 0.06), Vector3(x, 2.7, -6.20), Color("edcb89"))
		Props.cylinder(self, 0.28, 0.44, Vector3(x, 0.22, -4.9), Color("bb7c56"), 0.35)
		for index in range(5):
			var leaf := Props.ball(self, 0.22, Vector3(x + sin(index * 1.4) * 0.18, 0.8 + index * 0.12, -4.9), Color("649b71"))
			leaf.scale = Vector3(0.8, 1.7, 0.8)
	Props.box(self, Vector3(2.0, 0.018, 0.65), Vector3(0, 0.006, 4.2), Color("c09b63"))

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
	if recording or session_paused: return false
	var local := training.to_local(player.global_position)
	var facing := -camera.global_basis.z
	var towards := (training.global_position + Vector3(0, 1, 0) - camera.global_position).normalized()
	return absf(local.x) < 2.25 and local.z > 1.25 and local.z < 2.55 and facing.dot(towards) > 0.25

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
			return
		if session_paused: return
		match event.physical_keycode:
			KEY_E: start_recording()
			KEY_ENTER, KEY_KP_ENTER: finish_recording()
			KEY_X: cancel_recording()
			KEY_G: toggle_production()
	if session_paused: return
	if event is InputEventMouseMotion:
		var movement: Vector2 = event.screen_relative
		if recording and not live.held.is_empty() and Input.is_physical_key_pressed(KEY_SHIFT):
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

func _aim_on_table() -> Variant:
	var ray := -camera.global_basis.z
	if ray.y > -0.035: return null
	var plane := Plane(Vector3.UP, training.global_position.y + Model.BASE_Y)
	var hit = plane.intersects_ray(camera.global_position, ray)
	if hit == null or camera.global_position.distance_to(hit) > 3.4: return null
	var local := training.to_local(hit)
	return Vector2(local.x, local.z)

func _grab(item: String) -> void:
	if not recording or session_paused or item.is_empty(): return
	live.pick_up(item)
	_reanchor_grip()

func _reanchor_grip() -> void:
	var aim = _aim_on_table()
	if aim != null and not live.held.is_empty(): grip_offset = live.get(live.held) - aim

func _move_precisely(movement: Vector2) -> void:
	var right := training.global_basis.inverse() * camera.global_basis.x
	var forward := training.global_basis.inverse() * -camera.global_basis.z
	var horizontal := Vector2(right.x, right.z).normalized() * movement.x
	horizontal -= Vector2(forward.x, forward.z).normalized() * movement.y
	live.move_item(live.held, live.get(live.held) + horizontal * 0.0035)
	_reanchor_grip()

func _physics_process(delta: float) -> void:
	if session_paused: return
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
			if not precise:
				var aim = _aim_on_table()
				if aim != null: live.move_item(live.held, aim + grip_offset)
			var lift := float(Input.is_physical_key_pressed(KEY_R)) - float(Input.is_physical_key_pressed(KEY_F))
			live.lift_held(lift * 0.55 * delta)
		var tipping := live.held == "jug" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		live.step(delta, tipping, not tipping, Input.is_physical_key_pressed(KEY_SPACE))
		_capture_pose()
		frames.append(live.snapshot())
		elapsed = frames.size() * TICK
	if echo_active: _advance_echo()
	elif production_running: _advance_production(delta)
	_refresh_views()
	_refresh_hud()

func _capture_pose() -> void:
	var pose: Dictionary = player.pose_in(training)
	live.actor_position = pose.position
	live.actor_yaw = pose.yaw
	live.actor_pitch = pose.pitch

func _advance_echo() -> void:
	echo_clock += 1
	var target := echo_clock - DELAY_TICKS - 1
	if target >= 0 and target < frames.size():
		playback.restore(frames[target])
		echo_index = target
	if not recording and target >= frames.size() - 1:
		echo_active = false

func _advance_production(delta: float) -> void:
	if deployed.is_empty(): return
	cycle_time += delta
	if replay_tick < deployed.size():
		playback.restore(deployed[replay_tick])
		replay_tick += 1
		if replay_tick == deployed.size(): completed_orders += 1
	else:
		playback.flowing = false
		playback.squeezing = false
	if cycle_time >= maxf(60.0, deployed_duration + 1.0):
		cycle_time = 0.0
		replay_tick = 0

func start_recording() -> void:
	if not can_start_recording(): return
	live.reset()
	_capture_pose()
	frames.clear()
	elapsed = 0.0
	echo_clock = 0
	echo_index = -1
	echo_active = true
	production_running = false
	recording = true
	precision_active = false
	playback.restore(live.snapshot())
	_set_zone(true)
	hud.notice.text = "Запись началась. Клон повторяет через 2 секунды. Enter — закончить; X — отменить."
	_refresh_views()
	_refresh_hud()

func finish_recording() -> void:
	if not recording or session_paused: return
	if not live.success():
		hud.notice.text = "Пока %d мл. Нужно минимум 225 мл — запись продолжается." % roundi(live.filled)
		return
	live.put_down()
	_capture_pose()
	frames.append(live.snapshot())
	elapsed = frames.size() * TICK
	deployed = frames.duplicate(true)
	deployed_duration = elapsed
	recording = false
	_set_zone(false)
	var saved := _save_recording()
	hud.notice.text = "Клон обучен: %s / %d%%. Можно идти дальше. G — посмотреть работу, когда захочешь." % [Model.pace(elapsed), roundi(Model.efficiency(elapsed) * 100)]
	if not saved: hud.notice.text += " Запись действует до выхода: сохранить файл не удалось."
	_refresh_hud()

func cancel_recording() -> void:
	if not recording or session_paused: return
	recording = false
	echo_active = false
	frames.clear()
	live.reset()
	playback.reset()
	_set_zone(false)
	hud.notice.text = "Показ отменён. Прежнее обучение сохранено. E — начать заново у стойки."
	_refresh_views()
	_refresh_hud()

func toggle_production() -> void:
	if session_paused or recording or deployed.is_empty(): return
	production_running = not production_running
	echo_active = false
	if production_running:
		replay_tick = 0
		cycle_time = 0.0
		playback.restore(deployed[0])
	else:
		playback.flowing = false
		playback.squeezing = false
	_refresh_hud()

func toggle_pause() -> void:
	session_paused = not session_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if session_paused else Input.MOUSE_MODE_CAPTURED
	hud.pause_panel.visible = session_paused
	_refresh_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and not session_paused:
		toggle_pause()

func _refresh_views() -> void:
	training.update_view(live, tick_count * TICK)
	production.update_view(playback, tick_count * TICK, not recording and not echo_active and not production_running)
	if recording:
		var local := training.to_local(player.global_position)
		var distances := [absf(local.x - Player.ZONE_MIN.x), absf(local.x - Player.ZONE_MAX.x), absf(local.z - Player.ZONE_MIN.y), absf(local.z - Player.ZONE_MAX.y)]
		for index in range(barrier_meshes.size()):
			barrier_meshes[index].material_override.albedo_color.a = lerpf(0.16, 0.025, clampf(distances[index] / 0.8, 0, 1))

func _refresh_hud() -> void:
	hud.goal.text = "ВИНО: %d / 225 мл" % roundi(live.filled)
	hud.progress.value = live.filled
	hud.clock.text = "%s  %05.1f с / %s" % ["●" if recording else "", elapsed, Model.pace(elapsed)]
	hud.supplies.text = "Кувшин: %d мл  •  На столе: %d мл  •  Тряпка: %d / 300 мл  •  На полу: %d мл" % [roundi(live.wine), roundi(live.spilled()), roundi(live.soaked), roundi(live.lost)]
	hud.controls.text = "WASD — ходить  •  Мышь — обзор  •  E — обучение у стойки  •  G — работа клона  •  Esc — пауза"
	hud.prompt.text = "[E] Обучить клона" if can_start_recording() else ""
	if recording:
		hud.controls.text = "ЛКМ — взять / поставить  •  Колесо или R/F — высота  •  Shift + мышь — точное движение\nПКМ — наклон кувшина  •  Пробел — выжать тряпку  •  Enter — закончить  •  X — отменить"
		if live.held.is_empty():
			var hovered: String = training.pick_item(camera)
			hud.prompt.text = "[ЛКМ] Взять: " + ITEM_NAMES[hovered] if not hovered.is_empty() else "Наведи прицел на предмет"
		else:
			var height := float(live.elevations[live.held])
			hud.prompt.text = "%s  /  Высота: %d см" % [ITEM_NAMES[live.held].capitalize(), roundi(height * 100)]
			if live.held == "rag":
				hud.prompt.text += "\nОпусти к столу, чтобы вытереть" if height > 0.10 and not Input.is_physical_key_pressed(KEY_SPACE) else ""
			var aim: Vector2 = live.rag if live.held == "rag" else live.spout_target()
			if live.held in ["jug", "rag"] and aim.distance_to(live.cup) <= Model.CUP_RADIUS and not live.can_fill_at(aim, live.source_height()):
				hud.prompt.text += "\nПодними выше края стакана: колесо ↑"
	if recording or echo_active:
		hud.clone_status.text = "Клон повторяет с задержкой 2 с" if echo_index >= 0 else "Клон наблюдает…"
	elif production_running:
		hud.clone_status.text = "Работает: %s  •  Подано: %d" % [Model.pace(deployed_duration), completed_orders]
	elif not deployed.is_empty():
		hud.clone_status.text = "Обучен: %s  •  G — запустить" % Model.pace(deployed_duration)
	else:
		hud.clone_status.text = "Клон ждёт первого показа"
	hud.crosshair.visible = not session_paused
	hud.prompt.visible = not session_paused

func _save_recording() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"format": "fps-station", "tick": TICK, "frames": deployed}))
	file.close()
	return true

func _load_recording() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("format") != "fps-station": return
	if not is_equal_approx(float(data.get("tick", 0)), TICK): return
	var saved = data.get("frames", [])
	if not saved is Array or saved.is_empty(): return
	for frame in saved:
		if not _valid_frame(frame): return
	var check := Model.new()
	check.restore(saved.back())
	if not check.success(): return
	deployed = saved
	deployed_duration = deployed.size() * TICK
	hud.notice.text = "Обучение загружено. E у стойки — новый показ. G — запустить клона."

func _valid_frame(frame: Variant) -> bool:
	if not frame is Dictionary: return false
	for key in ["jug", "cup", "rag", "landing", "actor_position"]:
		var pair = frame.get(key)
		if not pair is Array or pair.size() != (3 if key == "actor_position" else 2): return false
		for value in pair:
			if not _finite_number(value): return false
	for key in ["tilt", "wine", "filled", "soaked", "lost", "squeezed_total", "actor_yaw", "actor_pitch"]:
		if not _finite_number(frame.get(key)): return false
	if not frame.get("held") in ["", "jug", "cup", "rag"]: return false
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
	return true

func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
