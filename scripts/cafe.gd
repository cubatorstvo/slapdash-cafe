extends Node3D
## Live demonstration on the left; station-local, fixed-tick playback on the right.

const Model = preload("res://scripts/station_model.gd")
const View = preload("res://scripts/station_view.gd")
const Props = preload("res://scripts/props.gd")
const SAVE_PATH := "user://station_recording.json"
const TICK := 1.0 / 30.0

var live := Model.new()
var playback := Model.new()
var training: Node3D
var production: Node3D
var camera: Camera3D
var frames: Array = []
var pending: Array = []
var deployed: Array = []
var recording := false
var elapsed := 0.0
var pending_duration := 0.0
var deployed_duration := 0.0
var replay_tick := 0
var completed_orders := 0
var cycle_time := 0.0
var show_help := true
var focused := true
var session_paused := false
var drag_offset := Vector2.ZERO
var tick_count := 0

var status_label: Label
var volume_label: Label
var supplies_label: Label
var clock_label: Label
var production_label: Label
var notice_label: Label
var help_label: Label
var fill_bar: ProgressBar
var finish_button: Button
var deploy_button: Button
var record_button: Button
var pause_button: Button

func _ready() -> void:
	_build_room()
	training = View.new()
	add_child(training)
	training.position.x = -2.65
	training.build(false)
	production = View.new()
	add_child(production)
	production.position.x = 2.65
	production.build(true)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 48.0
	_set_camera()
	_build_ui()
	_load_recording()
	_refresh()
	training.update_view(live)
	production.update_view(playback)
	# Deterministic fixture and capture hooks for integration/visual tests.
	if "--showcase" in OS.get_cmdline_user_args():
		_showcase()

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
		for z in range(-4, 5):
			var color := Color("6c7c73") if (x + z) % 2 == 0 else Color("79887b")
			Props.box(self, Vector3(0.995, 0.09, 0.995), Vector3(x + 0.5, -0.05, z + 0.5), color)
	Props.box(self, Vector3(14, 4.7, 0.18), Vector3(0, 2.3, -3.45), Color("244c50"))
	Props.box(self, Vector3(14, 0.10, 0.22), Vector3(0, 1.2, -3.30), Color("bb8d5e"))
	Props.box(self, Vector3(5.7, 0.85, 0.1), Vector3(0, 3.43, -3.25), Color("183237"))
	Props.text(self, "SLAPDASH CAFE", Vector3(0, 3.49, -3.16), 62, Color("f4cc86"))
	Props.text(self, "ЛИШЬ БЫ НАЛИТО.", Vector3(0, 2.92, -3.15), 25, Color("a5c8b6"))
	for x in [-5.3, 5.3]:
		Props.box(self, Vector3(1.6, 1.35, 0.13), Vector3(x, 2.7, -3.24), Color("edcb89"))
		Props.box(self, Vector3(1.37, 1.12, 0.07), Vector3(x, 2.7, -3.15), Color("9cc9c5"))
		Props.box(self, Vector3(0.05, 1.18, 0.06), Vector3(x, 2.7, -3.09), Color("edcb89"))
		Props.box(self, Vector3(1.42, 0.05, 0.06), Vector3(x, 2.7, -3.09), Color("edcb89"))
		Props.cylinder(self, 0.28, 0.44, Vector3(x, 0.22, -1.5), Color("bb7c56"), 0.35)
		for i in range(5):
			var leaf := Props.ball(self, 0.22, Vector3(x + sin(i * 1.4) * 0.18, 0.8 + i * 0.12, -1.5), Color("649b71"))
			leaf.scale = Vector3(0.8, 1.7, 0.8)
	Props.box(self, Vector3(0.85, 0.08, 1.6), Vector3(0, 0.04, 0), Color("c09b63"))

func _set_camera() -> void:
	if focused:
		camera.position = Vector3(-2.65, 6.8, 6.2)
		camera.look_at(Vector3(-2.65, 1.2, 0))
	else:
		camera.position = Vector3(0, 8.4, 11.8)
		camera.look_at(Vector3(0, 1.2, -0.15))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("f5ead7"))
	theme.set_color("font_color", "Button", Color("f9ebd1"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("35545b") if state == "normal" else Color("477078")
		if state == "disabled": style.bg_color = Color("243940")
		style.set_corner_radius_all(8)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 11
		style.content_margin_bottom = 11
		theme.set_stylebox(state, "Button", style)
	root.theme = theme
	var top := _panel(root)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_top = 18
	top.offset_right = -22
	top.offset_bottom = 112
	var row := HBoxContainer.new()
	top.add_child(row)
	row.add_theme_constant_override("separation", 36)
	var brand := VBoxContainer.new()
	row.add_child(brand)
	_label(brand, "SLAPDASH CAFE", 25, Color("f2c578"))
	_label(brand, "Покажи. Размножь. Пусть работает.", 16)
	var goal := VBoxContainer.new()
	goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(goal)
	volume_label = _label(goal, "", 21)
	fill_bar = ProgressBar.new()
	fill_bar.custom_minimum_size.y = 9
	fill_bar.max_value = 250.0
	fill_bar.show_percentage = false
	goal.add_child(fill_bar)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("cf6c77")
	fill_style.set_corner_radius_all(4)
	fill_bar.add_theme_stylebox_override("fill", fill_style)
	var clock := VBoxContainer.new()
	row.add_child(clock)
	clock_label = _label(clock, "", 22, Color("f2c578"))
	_label(clock, "Fast <15с  /  Medium ≤60с  /  Slow >60с", 14)
	var bottom := _panel(root)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 22
	bottom.offset_right = -22
	bottom.offset_top = -217
	bottom.offset_bottom = -18
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	bottom.add_child(column)
	var status_row := HBoxContainer.new()
	column.add_child(status_row)
	status_label = _label(status_row, "", 19, Color("f2c578"))
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	production_label = _label(status_row, "", 17, Color("85cfb9"))
	supplies_label = _label(column, "", 15)
	help_label = _label(column, "ЛКМ: взять / поставить  •  Мышь: двигать  •  ПКМ: наклонить кувшин  •  Пробел: выжать тряпку\n1 / 2 / 3: кувшин / стакан / тряпка  •  Tab: приблизить станцию  •  Esc: пауза  •  H: подсказки", 16)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	record_button = _button(buttons, "●  Новый показ [R]", start_recording)
	finish_button = _button(buttons, "Завершить [Enter]", finish_recording)
	deploy_button = _button(buttons, "Обучить клона", deploy_recording)
	_button(buttons, "Очистить стол", reset_practice)
	pause_button = _button(buttons, "Пауза", toggle_pause)
	notice_label = _label(column, "Начни новый показ. Наполни стакан до золотой отметки любым способом.", 16, Color("b7d3cc"))

func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.12, 0.15, 0.96)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(parent: Node, value: String, size: int, color := Color("e4e4d5")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: toggle_pause()
			KEY_TAB:
				focused = not focused
				_set_camera()
			KEY_H:
				show_help = not show_help
				help_label.visible = show_help
			KEY_R: start_recording()
			KEY_ENTER, KEY_KP_ENTER: finish_recording()
			KEY_1: _grab("jug")
			KEY_2: _grab("cup")
			KEY_3: _grab("rag")
	if session_paused or not pending.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if live.held.is_empty():
			_grab(training.pick_item(camera, event.position))
		else:
			live.held = ""
	if event is InputEventMouseMotion and not live.held.is_empty():
		live.move_item(live.held, _mouse_on_table(event.position) + drag_offset)

func _mouse_on_table(mouse: Vector2) -> Vector2:
	var plane := Plane(Vector3.UP, View.TABLE_HEIGHT + 0.05)
	var hit = plane.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit == null:
		return Vector2.ZERO
	var point: Vector3 = hit - training.global_position
	return Vector2(point.x, point.z)

func _grab(item: String) -> void:
	if session_paused or not pending.is_empty() or item.is_empty(): return
	if live.held == item:
		live.held = ""
		return
	live.held = item
	var point: Vector2 = live.get(item)
	drag_offset = point - _mouse_on_table(get_viewport().get_mouse_position())

func _physics_process(delta: float) -> void:
	if session_paused: return
	tick_count += 1
	if pending.is_empty():
		var tipping := live.held == "jug" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		live.step(delta, tipping, not tipping, Input.is_physical_key_pressed(KEY_SPACE))
	if recording:
		frames.append(live.snapshot())
		elapsed = frames.size() * TICK
	_advance_production(delta)
	training.update_view(live, tick_count * TICK)
	production.update_view(playback, cycle_time, replay_tick >= deployed.size())
	_refresh()
	if "--capture" in OS.get_cmdline_user_args() and tick_count == 30:
		_capture.call_deferred()

func _advance_production(delta: float) -> void:
	if deployed.is_empty(): return
	cycle_time += delta
	if replay_tick < deployed.size():
		playback.restore(deployed[replay_tick])
		replay_tick += 1
		if replay_tick == deployed.size():
			completed_orders += 1
	else:
		playback.flowing = false
		playback.squeezing = false
		playback.held = ""
	# Everyone within Medium's window serves once per minute, however silly the path.
	var period := maxf(60.0, deployed_duration + 1.0)
	if cycle_time >= period:
		cycle_time = 0.0
		replay_tick = 0
		playback.reset()

func start_recording() -> void:
	if session_paused: return
	live.reset()
	frames.clear()
	pending.clear()
	elapsed = 0.0
	recording = true
	_notice("Идёт запись. Все движения, лужи и тряпка попадут в показ. Enter — закончить.")
	_refresh()

func finish_recording() -> void:
	if not recording or session_paused: return
	if not live.success():
		_notice("Пока только %d мл. Нужно минимум 225 мл — запись продолжается." % roundi(live.filled))
		return
	recording = false
	live.held = ""
	live.flowing = false
	live.squeezing = false
	live.tilt = 0.0
	frames.append(live.snapshot())
	pending = frames.duplicate(true)
	pending_duration = pending.size() * TICK
	elapsed = pending_duration
	_notice("Готово! %s / %d%%. %s Нажми «Обучить клона»." % [Model.pace(pending_duration), roundi(Model.efficiency(pending_duration) * 100.0), "Тряпочный винтаж принят." if live.squeezed_total > 1.0 else "Клиент доволен."])
	_refresh()

func deploy_recording() -> void:
	if pending.is_empty() or session_paused: return
	deployed = pending.duplicate(true)
	deployed_duration = pending_duration
	pending.clear()
	frames.clear()
	replay_tick = 0
	cycle_time = 0.0
	playback.reset()
	live.reset()
	focused = false
	_set_camera()
	_save_recording()
	_notice("Клон обучен и повторяет твой способ справа. Теперь можно придумать другой.")
	_refresh()

func reset_practice() -> void:
	if session_paused: return
	recording = false
	frames.clear()
	pending.clear()
	elapsed = 0.0
	live.reset()
	_notice("Учебный стол очищен. Запись действующего клона сохранена.")
	_refresh()

func toggle_pause() -> void:
	session_paused = not session_paused
	pause_button.text = "Продолжить" if session_paused else "Пауза"
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(pause_button):
		session_paused = true
		pause_button.text = "Продолжить"

func _notice(value: String) -> void:
	notice_label.text = value

func _refresh() -> void:
	if not is_instance_valid(volume_label): return
	volume_label.text = "ЗАКАЗ: ВИНО  •  %d / 225 мл" % roundi(live.filled)
	fill_bar.value = live.filled
	clock_label.text = "%05.1f с  /  %s" % [elapsed, Model.pace(elapsed)]
	var item_names := {"": "руки свободны", "jug": "кувшин в руках", "cup": "стакан в руках", "rag": "тряпка в руках"}
	status_label.text = "● ЗАПИСЬ  /  " if recording else "ПЕСОЧНИЦА  /  "
	if not pending.is_empty(): status_label.text = "ПОКАЗ ГОТОВ  /  "
	status_label.text += item_names[live.held]
	if session_paused: status_label.text = "ПАУЗА — Esc, чтобы продолжить"
	supplies_label.text = "Кувшин: %d мл    •    На столе: %d мл    •    В тряпке: %d / 300 мл    •    На полу: %d мл" % [roundi(live.wine), roundi(live.spilled()), roundi(live.soaked), roundi(live.lost)]
	finish_button.disabled = not recording or session_paused
	deploy_button.disabled = pending.is_empty() or session_paused
	record_button.disabled = session_paused
	if deployed.is_empty():
		production_label.text = "Клон ждёт первого показа"
	else:
		var remaining := maxf(0.0, maxf(60.0, deployed_duration + 1.0) - cycle_time)
		production_label.text = "Клон: %s  •  Подано: %d  •  Следующий цикл: %02d с" % [Model.pace(deployed_duration), completed_orders, ceili(remaining)]

func _save_recording() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save recording: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"format": 1, "tick": TICK, "frames": deployed}))

func _load_recording() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("format") != 1: return
	var saved = data.get("frames", [])
	if not saved is Array or saved.is_empty(): return
	# Validate before restoring user-writable data into the view.
	for frame in saved:
		if not _valid_frame(frame): return
	var check := Model.new()
	check.restore(saved.back())
	if not check.success(): return
	deployed = saved
	deployed_duration = deployed.size() * TICK
	_notice("Предыдущий показ загружен. Клон работает справа; слева можно записать новый.")

func _valid_frame(frame: Variant) -> bool:
	if not frame is Dictionary: return false
	for key in ["jug", "cup", "rag", "landing"]:
		var pair = frame.get(key)
		if not pair is Array or pair.size() != 2: return false
		for value in pair:
			if not (value is float or value is int): return false
	for key in ["tilt", "wine", "filled", "soaked", "lost", "squeezed_total"]:
		if not (frame.get(key) is float or frame.get(key) is int): return false
	if not frame.get("held") in ["", "jug", "cup", "rag"]: return false
	if not frame.get("flowing") is bool or not frame.get("squeezing") is bool: return false
	if not frame.get("puddles") is Array: return false
	for puddle in frame.puddles:
		if not puddle is Array or puddle.size() != 3: return false
		for value in puddle:
			if not (value is float or value is int): return false
	return true

func _showcase() -> void:
	focused = false
	_set_camera()
	live.jug = Vector2(-0.35, 0.05)
	live.held = "jug"
	live.tilt = 62.0
	live.filled = 158.0
	live.wine = 605.0
	live.puddles = [[-0.05, 0.40, 90.0], [0.2, 0.35, 147.0]]
	playback.restore(live.snapshot())
	playback.held = "rag"
	playback.rag = playback.cup
	playback.soaked = 130.0
	playback.squeezing = true
	playback.landing = playback.cup
	# Freeze models but keep a rendered showcase for visual inspection.
	pending = [live.snapshot()]
	training.update_view(live)
	production.update_view(playback)

func _capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/slapdash-cafe-preview.png")
	get_tree().quit()
