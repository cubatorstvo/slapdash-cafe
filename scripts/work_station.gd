extends Node3D
const Definition = preload("res://scripts/station_definition.gd")
const Model = preload("res://scripts/cooking_model.gd")
const TeamModel = preload("res://scripts/team_cooking_model.gd")
const Run = preload("res://scripts/training_run.gd")
const Avatar = preload("res://scripts/cook_avatar.gd")
const Person = preload("res://scripts/customer_view.gd")
const Props = preload("res://scripts/props.gd")
var station_id := 1
var type_id := "counter"
var crew: Array = []
var upgrades: Array = []
var recipes := {}
var drafts := {}
var model
var view: Node3D
var training = Run.new()
var state := "idle"
var order_dish := ""
var order_tick := 0
var customer_id := -1
var pending_teacher := 0
var pending_dish := ""
var students: Array = []
var zone_panels: Array = []
var zone_labels: Array = []
var taster: Node3D
var taster_real := false
var reaction := 0.0
var remote_summary := {}
var age := 0.0
var observing := false
var student_paths: Array = []
var walls: Array = []

func role_count() -> int: return Definition.TYPES[type_id].roles.size()
func dishes() -> Array: return Definition.TYPES[type_id].dishes

func _ready() -> void:
	if crew.is_empty(): crew = Definition.crew(type_id, station_id)
	model = Model.new() if type_id == "counter" else TeamModel.new()
	view = preload("res://scripts/station_view.gd").new() if type_id == "counter" else preload("res://scripts/team_station_view.gd").new()
	add_child(view)
	view.build(true)
	view.station_label.text = "СТАНЦИЯ %d · [E] ПОКАЖИ КАК" % station_id
	view.station_label.position = Vector3(0, 1.32, -1.1)
	view.station_label.pixel_size = 0.005
	view.station_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	training.setup(self)
	for role in range(role_count()):
		var student := Avatar.new()
		add_child(student)
		student.caption.text = crew[role].name
		student.hide()
		students.append(student)
		student_paths.append([])
		var half: float = Definition.TYPES[type_id].width / role_count()
		var panel := Props.box(self, Vector3(half - 0.03, 0.018, 2.15), Vector3((role - (role_count() - 1) / 2.0) * half, 1.015, 0), Color("eb6267"))
		panel.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		panel.material_override.albedo_color.a = 0.42
		panel.hide()
		zone_panels.append(panel)
		var label := Props.text(self, "ЗОНА ДУБЛЯ", Vector3((role - (role_count() - 1) / 2.0) * half, 1.6, -0.85), 18, Color("ff8585"))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.004
		label.hide()
		zone_labels.append(label)
	var extent: float = Definition.TYPES[type_id].width / 2 + 0.6
	for z in [-2.1, 2.8]: Props.box(self, Vector3(extent * 2, 0.01, 0.035), Vector3(0, 0.01, z), Color("cbad72"))
	for spec in [[Vector3(0.02, 2.5, 5.2), Vector3(-extent, 1.25, 0.3)], [Vector3(0.02, 2.5, 5.2), Vector3(extent, 1.25, 0.3)], [Vector3(extent * 2, 2.5, 0.02), Vector3(0, 1.25, -2.3)], [Vector3(extent * 2, 2.5, 0.02), Vector3(0, 1.25, 2.9)]]:
		var wall := Props.box(self, spec[0], spec[1], Color("86d7c2"))
		wall.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wall.material_override.albedo_color.a = 0.03
		wall.hide()
		walls.append(wall)
	reset_model()

func reset_model() -> void:
	model.reset(dishes()[0]) if type_id == "counter" else model.reset()

func apply_single(command: Dictionary, delta: float) -> void:
	if command.get("drop", false): model.put_down()
	var item: String = command.get("grab", "")
	if item in ["jug", "cup", "rag", "pan", "potato", "sausage", "tomato"] and model.held.is_empty(): model.pick_up(item)
	item = model.held
	if not item.is_empty():
		if command.has("target") and item != "pan":
			model.move_item(item, model.get(item).move_toward(Vector2(command.target[0], command.target[1]), delta * 6))
		if command.has("height"): model.lift_held(float(command.height) - model.elevations[item])
		if item == "pan" and command.has("pan_tilt"): model.pan_tilt = Vector2(command.pan_tilt[0], command.pan_tilt[1]).limit_length(0.18)
	if command.has("aim"): model.throw_direction = Vector3(command.aim[0], command.aim[1], command.aim[2])
	var use_item: bool = command.get("use", false)
	model.step(delta, use_item, not use_item, use_item)
	if command.has("pose"):
		model.actor_position = Vector3(command.pose.position[0], command.pose.position[1], command.pose.position[2])
		model.actor_yaw = command.pose.yaw
		model.actor_pitch = command.pose.pitch

func show_tracks(tracks: Array, tick: int) -> void:
	if type_id == "counter":
		if not tracks.is_empty() and not tracks[0].is_empty() and not tracks[0].frames.is_empty(): model.restore(tracks[0].frames[clampi(tick, 0, tracks[0].frames.size() - 1)])
	else:
		for role in range(role_count()):
			if role < tracks.size() and not tracks[role].is_empty() and not tracks[role].frames.is_empty(): model.restore_zone(role, tracks[role].frames[clampi(tick, 0, tracks[role].frames.size() - 1)])
		model.elapsed = maxf(0, tick / 60.0)

func ensure_taster() -> void:
	if not is_instance_valid(taster):
		taster = Person.new()
		add_child(taster)
		taster_real = false
	reset_taster()

func reset_taster() -> void:
	if not is_instance_valid(taster): return
	taster.global_position = to_global(Vector3(0, 0, -1.85))
	taster.global_rotation.y = global_rotation.y + PI
	taster.caption.text = "Гость · смотрит показ" if taster_real else "Дегустатор · можно пробовать сколько угодно"
	reaction = 0

func finish_taster(accepted: bool) -> void:
	if not is_instance_valid(taster): return
	if taster_real:
		get_parent().finish_customer(customer_id, accepted)
	else: taster.queue_free()
	taster = null
	taster_real = false

func refresh(local_peer: int, delta: float) -> void:
	age += delta
	if is_instance_valid(taster) and type_id == "counter": taster.react(model.customer_reaction)
	view.update_view(model, age, state != "cooking")
	var active: bool = training.active()
	view.station_label.visible = not active
	var local_role: int = training.role_for(local_peer)
	for wall in walls: wall.visible = active and local_role >= 0 and training.phase == "recording"
	if active and not observing:
		for role in range(role_count()):
			var side := -1 if role == 0 else 1
			var edge: float = side * (Definition.TYPES[type_id].width / 2 + 0.3)
			students[role].position = Vector3((-1.35 if role == 0 else 1.35) if role_count() == 2 else 0, 0, 1.85)
			student_paths[role] = [Vector3(edge, 0, 1.65), Vector3(edge, 0, -1.6), Vector3(-1.4 + role * 2.8 if role_count() == 2 else 1.5, 0, -1.6)]
	observing = active
	var performing: bool = training.phase in ["recording", "review"]
	if type_id == "counter":
		view.is_production = not (active and local_role == 0)
		view._update_worker(model, age, state != "cooking")
		for node in [view.worker, view.left_hand, view.right_hand, view.left_arm, view.right_arm]: node.visible = not active
		view.name_label.text = crew[0].name + ("\nГотовит" if state == "cooking" else "\nЖдёт показа" if recipes.is_empty() else "\nЖдёт заказ")
	else:
		view.status.visible = state == "cooking"
		for role in range(role_count()):
			view.actors[role].visible = not active or (performing and not role in training.live_roles)
			view.actors[role].caption.text = crew[role].name + (" · дубль" if active else "")
	for role in range(role_count()):
		var student: Node3D = students[role]
		student.visible = active and (role in training.live_roles or training.phase == "ready")
		if student.visible:
			var target := Vector3(-1.4 + role * 2.8 if role_count() == 2 else 1.5, 0, -1.5)
			if not student_paths[role].is_empty():
				if student.walk_to(student_paths[role][0], delta): student_paths[role].pop_front()
			else: student.rotation.y = PI
			student.observe(to_global(Vector3(0, 1.7, 1.8)), to_global(target), delta, role)
		zone_panels[role].visible = active and local_role >= 0 and not role in training.live_roles
		if local_role >= 0 and not performing: zone_panels[role].hide()
		zone_labels[role].visible = zone_panels[role].visible

func save_entry() -> Dictionary:
	return {"id": station_id, "type": type_id, "crew": crew, "upgrades": upgrades, "position": [position.x, position.y, position.z], "yaw": rotation.y, "recipes": recipes, "drafts": drafts}

func world_entry() -> Dictionary:
	var data := save_entry()
	data.erase("recipes")
	data.erase("drafts")
	data.known = recipes.keys()
	data.recipe_times = {}
	for key in recipes: data.recipe_times[key] = recipes[key].duration
	data.state = state
	data.model = model.snapshot()
	data.training = training.summary()
	return data
