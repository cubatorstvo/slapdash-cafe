extends Node3D
const Model = preload("res://scripts/team_cooking_model.gd")
const View = preload("res://scripts/team_station_view.gd")
var game: Node3D
var model := Model.new()
var view: Node3D
var phase := "idle"
var mode := "roles"
var crew: Array = []
var partner := -1
var lead_peer := 1
var tapes: Array = [[], []]
var frames: Array = []
var tick := 0
var local_role := 0
var pending := {}
var remote_by_role: Array = [{}, {}]
var events_by_role: Array = [[], []]
var grip := Vector3.FORWARD
var height := 0.4
var precision := false
var need_anchor := false
var info := "Стол II: мясо с двух сторон, макароны, соль — подай на одну тарелку."

func setup(root_game: Node3D) -> void:
	game = root_game
	view = View.new()
	add_child(view)
	view.position = Vector3(8.7, 0, 5.3)
	view.build(false)
	view.update_view(model)

func active() -> bool: return phase != "idle"
func participating() -> bool: return active() and local_role >= 0
func role_for(peer_id: int) -> int:
	if not active(): return -1
	if mode == "together" or phase == "together":
		return 0 if peer_id == lead_peer else (1 if peer_id == partner else -1)
	return (1 if phase == "role2" else 0) if peer_id == lead_peer else -1
func running() -> bool: return phase in ["role1", "role2", "together"]
func near() -> bool:
	var p: Vector3 = view.to_local(game.player.global_position)
	return absf(p.x) < 3.2 and p.z > 1.2 and p.z < 3.1

func start(selected_mode: String, ids: Array, selected_peer: int, initiator := 1) -> void:
	if game.session.is_guest() or game.recording or active(): return
	if ids.size() != 2 or ids[0] == ids[1]: return
	for id in ids:
		if game.service.get_clone(id).is_empty(): return
	if not selected_mode in ["roles", "together"]: return
	if selected_mode == "together" and (selected_peer == initiator or not game.session.members.has(selected_peer)): return
	lead_peer = initiator
	game.menu.close()
	game.lecture.clear_now()
	mode = selected_mode
	crew = ids.duplicate()
	partner = selected_peer if mode == "together" else -1
	var names: Array = []
	var starts: Array = []
	var homes: Array = []
	for role in range(2):
		names.append(game.service.get_clone(ids[role]).name)
		starts.append(game.clone_home(ids[role]))
		homes.append(game.service.stations[3].view.to_global(Vector3(-1.35 if role == 0 else 1.35, 0, 1.85)))
	game.service.reserve_team(ids)
	game.lecture.begin(names, starts, view, game.session.actor_for(lead_peer), func(): game.service.release_station(3), homes)
	tapes = [[], []]
	_reset("role1" if mode == "roles" else "together", 0)
	info = "Роль 1: покажи свою часть. Enter — записывать роль 2." if mode == "roles" else "Готовьте вместе. Общие предметы берутся по очереди. Enter — сохранить."

func _reset(next_phase: String, role: int) -> void:
	model.reset()
	frames.clear()
	tick = 0
	pending.clear()
	remote_by_role = [{}, {}]
	events_by_role = [[], []]
	view.station_label.hide()
	view.status.hide()
	phase = next_phase
	game.session.restart_id += 1
	local_role = role_for(game.session.local_id())
	height = 0.4
	need_anchor = false
	precision = false
	if local_role >= 0: _place_player(local_role)

func _place_player(role: int) -> void:
	game.player.station = view
	game.player.zone_min = Vector2(-3.4, -1.6)
	game.player.zone_max = Vector2(3.4, 3.2)
	game.player.constrained = true
	var pose := Model.default_pose(role)
	game.player.global_position = view.to_global(Vector3(pose.position[0], 0.02, pose.position[2]))
	game.player.rotation.y = view.global_rotation.y
	game.camera.rotation.x = -0.35
	for wall in view.bounds: wall.show()

func handle(event: InputEvent) -> void:
	if not participating(): return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if game.session.is_guest(): game.session.send_event({"finish": true})
				else: finish()
			KEY_X:
				if game.session.is_guest(): game.session.send_event({"cancel": true})
				else: cancel()
			KEY_BACKSPACE:
				if game.session.is_guest(): game.session.send_event({"retake": true})
				else: retake()
	if not running(): return
	var item: String = model.hands[local_role]
	if event is InputEventMouseMotion:
		if not item.is_empty() and Input.is_physical_key_pressed(KEY_SHIFT):
			var right: Vector3 = view.global_basis.inverse() * game.camera.global_basis.x
			var forward: Vector3 = view.global_basis.inverse() * -game.camera.global_basis.z
			var point: Vector2 = model.positions[item] + (Vector2(right.x, right.z).normalized() * event.screen_relative.x - Vector2(forward.x, forward.z).normalized() * event.screen_relative.y) * 0.0035
			pending.target = [point.x, point.y]
			precision = true
		else:
			game.player.look(event.screen_relative)
			if precision: _anchor()
			precision = false
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var command := {"grab": view.pick_item(game.camera)} if item.is_empty() else {"drop": true}
				if game.session.is_guest(): game.session.send_event(command)
				else: pending.merge(command, true)
				need_anchor = item.is_empty()
			MOUSE_BUTTON_WHEEL_UP: height = minf(1.1, height + 0.08)
			MOUSE_BUTTON_WHEEL_DOWN: height = maxf(0, height - 0.08)

func _anchor() -> void:
	var item: String = model.hands[local_role]
	if item.is_empty(): return
	var point: Vector2 = model.positions[item]
	var anchor: Vector3 = view.to_global(Vector3(point.x, Model.BASE_Y, point.y))
	grip = game.camera.global_basis.inverse() * (anchor - game.camera.global_position).normalized()

func command(delta: float) -> Dictionary:
	var item: String = model.hands[local_role]
	if need_anchor and not item.is_empty():
		_anchor()
		height = model.heights[item]
		need_anchor = false
	var result := pending.duplicate(true)
	pending.clear()
	var pose: Dictionary = game.player.pose_in(view)
	result.pose = {"position": [pose.position.x, pose.position.y, pose.position.z], "yaw": pose.yaw, "pitch": pose.pitch}
	result.use = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	height = clampf(height + (float(Input.is_physical_key_pressed(KEY_R)) - float(Input.is_physical_key_pressed(KEY_F))) * delta * 0.55, 0, 1.1)
	# A grab uses the model's initial lift; subsequent ticks use the player's wheel height.
	if not item.is_empty(): result.height = height
	if not result.has("target") and not precision and not item.is_empty():
		var origin: Vector3 = view.to_local(game.camera.global_position)
		var ray: Vector3 = view.global_basis.inverse() * game.camera.global_basis * grip
		var reach := maxf(origin.y - Model.BASE_Y, 0.01) / maxf(-ray.y, 0.08)
		var point := origin + ray * reach
		var xy := Vector2(point.x, point.z).clamp(-Model.BOUNDS, Model.BOUNDS)
		result.target = [xy.x, xy.y]
	return result

func advance(delta: float) -> void:
	if not running():
		view.update_view(model)
		return
	if game.session.is_guest():
		if participating() and not game.input_blocked(): game.session.send_motion(command(delta))
		view.update_view(model)
		_update_actors()
		return
	var commands: Array = [{}, {}]
	for role in range(2):
		if role == local_role:
			commands[role] = command(delta) if not game.input_blocked() else {"pose": model.poses[role], "use": false}
		else:
			commands[role] = remote_by_role[role].duplicate(true)
			if not events_by_role[role].is_empty(): commands[role].merge(events_by_role[role].pop_front(), true)
	if phase == "role2" and tick < tapes[0].size(): commands[0] = tapes[0][tick]
	model.step(commands, delta)
	if phase == "role1": tapes[0].append(commands[0].duplicate(true))
	else: tapes[1].append(commands[1].duplicate(true))
	frames.append(model.snapshot())
	tick += 1
	if not model.conflicts.is_empty(): info = model.conflicts[0] + ". Освободи предмет или перезапиши дубль (Backspace)."
	view.update_view(model)
	_update_actors()

func _update_actors() -> void:
	view.actors[0].visible = phase == "role2" or (active() and local_role != 0)
	view.actors[1].visible = phase == "together" and local_role != 1
	view.actors[0].caption.text = "Дубль роли 1" if phase == "role2" else str(game.session.members.get(lead_peer, "Напарник")) + " · роль 1"
	view.actors[1].caption.text = str(game.session.members.get(partner, "Напарник")) + " · роль 2"

func finish() -> void:
	if phase == "role1":
		var release := {"drop": true, "pose": model.poses[0].duplicate(true)}
		tapes[0].append(release)
		model.drop(0)
		phase = "between"
		info = "Роль 1 записана. Enter — сбросить кухню и записать роль 2 вместе с первым дублем. Backspace — переделать роль 1."
		return
	if phase == "between":
		tapes[1] = []
		_reset("role2", 1)
		info = "Роль 2. Первый дубль уже действует: оставляй ему инструменты вовремя. Enter — сохранить всю бригаду."
		return
	if not running(): return
	if not model.success() or (phase == "role2" and tick < tapes[0].size()):
		info = "Нужны обе стороны мяса, соль в обоих блюдах, 100 г сваренных и перемешанных макарон на тарелке. Дождись конца роли 1."
		return
	model.drop(0)
	model.drop(1)
	frames.append(model.snapshot())
	game.service.team_recipe = {"clone_ids": crew.duplicate(), "frames": frames.duplicate(true), "duration": frames.size() / 60.0}
	var saved: bool = game._save_staff()
	info = "Бригада обучена: %s. Клоны возвращаются на стойку 4." % Model.pace(model.elapsed)
	if not saved: info += " Не удалось сохранить на диск."
	_end()

func retake() -> void:
	if phase in ["role1", "between"]:
		tapes[0] = []
		_reset("role1", 0)
	elif phase == "role2":
		tapes[1] = []
		_reset("role2", 1)
	elif phase == "together":
		tapes = [[], []]
		_reset("together", 0)
	info = "Кухня сброшена. Запиши текущую роль заново."

func cancel() -> void:
	if not active(): return
	info = "Показ отменён. Прежняя успешная запись бригады сохранена."
	_end()

func _end() -> void:
	phase = "idle"
	game.session.restart_id += 1
	local_role = -1
	view.station_label.show()
	view.status.show()
	partner = -1
	game.player.constrained = false
	game.player.station = game.training
	game.player.zone_min = game.player.ZONE_MIN
	game.player.zone_max = game.player.ZONE_MAX
	for wall in view.bounds: wall.hide()
	for actor in view.actors: actor.hide()
	game.lecture.finish()
	game.hud.notice.text = info

func apply_remote(data: Dictionary) -> void:
	var was_participating := participating()
	var old_phase := phase
	model.restore(data.model)
	phase = data.phase
	mode = "together" if phase == "together" else "roles"
	partner = data.partner
	lead_peer = data.lead
	local_role = role_for(game.session.local_id())
	view.station_label.visible = not active()
	view.status.visible = not active()
	if participating() and (not was_participating or old_phase != phase or data.restart != game.session.seen_restart):
		game.menu.close()
		_place_player(local_role)
		pending.clear()
		precision = false
		need_anchor = false
	game.session.seen_restart = data.restart
	info = data.info
	if was_participating and not participating():
		game.player.constrained = false
		for wall in view.bounds: wall.hide()
	view.update_view(model)
	_update_actors()

func refresh_hud() -> void:
	if not active(): return
	game.hud.goal.text = "СТЕЙК С МАКАРОНАМИ · " + {"role1": "РОЛЬ 1", "role2": "РОЛЬ 2", "between": "ПЕРВЫЙ ДУБЛЬ ГОТОВ", "together": "ВМЕСТЕ"}[phase]
	game.hud.clock.text = "%05.1f с / %s" % [model.elapsed, Model.pace(model.elapsed)]
	game.hud.progress.value = 100 if model.success() else (float(model.meat_sides[0]) + float(model.meat_sides[1]) + model.cooked + model.stirred) * 20
	game.hud.supplies.text = "Мясо: %d%% / %d%% · Вода: %d/500 мл · Макароны: %d/100 г · %d°C · Варка: %d%%\nСоль: мясо %s / макароны %s · Перемешано: %d%% · На тарелке: %d г" % [model.meat_sides[0] * 100, model.meat_sides[1] * 100, model.water, model.pasta + model.served_pasta, model.temperature, model.cooked * 100, "✓" if model.meat_salt >= 1 else "—", "✓" if model.pasta_salt >= 1 else "—", model.stirred * 100, model.served_pasta]
	game.hud.controls.text = "ЛКМ — взять / поставить · ПКМ — налить / посолить / перевернуть / мешать\nКолесо, R/F — высота · Shift + мышь — точнее · Enter — готово · Backspace — дубль заново · X — отмена"
	if not participating():
		game.hud.prompt.text = "Идёт показ другой бригады"
		return
	var item: String = model.hands[local_role]
	if item.is_empty():
		var hovered: String = view.pick_item(game.camera)
		game.hud.prompt.text = "Наведи на предмет" if hovered.is_empty() else "[ЛКМ] Взять: " + Model.NAMES[hovered]
		if not hovered.is_empty() and model.owners[hovered] >= 0: game.hud.prompt.text = "%s · занята ролью %d" % [Model.NAMES[hovered], model.owners[hovered] + 1]
	else:
		var hint: String = {"steak": "[ЛКМ] Положить на жаровню / тарелку", "pot": "[ПКМ] Переложить готовые макароны на тарелку", "water": "[ПКМ] Лить над кастрюлей · подними на 50–60 см", "pasta_bag": "[ПКМ] Сыпать над кастрюлей · подними на 50–60 см", "salt": "[ПКМ] Солить мясо или макароны", "spatula": "[ПКМ] Нажать — перевернуть мясо; удерживать — мешать"}[item]
		game.hud.prompt.text = "%s · %d см\n%s" % [Model.NAMES[item], model.heights[item] * 100, hint]
	game.hud.notice.text = info
