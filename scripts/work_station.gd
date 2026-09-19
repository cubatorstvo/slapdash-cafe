extends Node3D
const Definition = preload("res://scripts/station_definition.gd")
const Model = preload("res://scripts/cooking_model.gd")
const TeamModel = preload("res://scripts/team_cooking_model.gd")
const SpecialtyModel = preload("res://scripts/specialty_cooking_model.gd")
const SolyankaModel = preload("res://scripts/solyanka_cooking_model.gd")
const Run = preload("res://scripts/training_run.gd")
const Avatar = preload("res://scripts/cook_avatar.gd")
const Person = preload("res://scripts/customer_view.gd")
const Props = preload("res://scripts/props.gd")
const SLOT_WIDTH := 6.6
const SLOT_DEPTH := 5.72
const TRAINING_ZONE_CENTER_Z := 0.30
const TRAINING_ZONE_OUTLINE_THICKNESS := 0.04
var bell: Node3D
var bell_cap: Node3D
var bell_flash := 0.0
var equipment: Array = ["jug","cup","plates","pan","sauce","rag","meat_kit","pasta_kit"]
var customer_order := {}
var staffed := -1
var manual_station := false
var masterclass_station := false
var station_id := 1
var slot_index := 0
var type_id := "counter"
var crew: Array = []
var upgrades: Array = []
var recipes := {}
var drafts := {}
var method_sources := {}
var group_training_state := ""
var model
var view: Node3D
var training = Run.new()
var state := "idle"
var order_dish := ""
var order_tick := 0.0
var order_tempo := 1.0
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
var was_resting := true
var upgrade_view: Node3D

func ready_crew() -> bool:
	if not group_training_state.is_empty(): return false
	var game = get_parent().game if is_inside_tree() else null
	if game != null and is_instance_valid(game.laboratory) and game.laboratory.reserves_station(station_id): return false
	return manual_station or staffed < 0 or staffed >= role_count()

func crew_tempo() -> float:
	var slowest := 11.0
	for member in crew:
		var effective := float(member.get("tempo",1.0))*float(member.get("rest",1.0))
		slowest = minf(slowest,effective)
	return clampf(slowest,0.63,11.0)

func crew_name(role: int) -> String:
	var base := float(crew[role].get("tempo",1.0))
	var rest := float(crew[role].get("rest",1.0))
	var text := str(crew[role].name) + " · %d%%" % roundi(base*rest*100)
	if not is_equal_approx(rest,1.0): text += " · отдых %d%%" % roundi(rest*100)
	return text


func role_count() -> int: return Definition.TYPES[type_id].roles.size()
func dishes() -> Array: return Definition.TYPES[type_id].dishes
func is_team_station() -> bool: return role_count() > 1
static func model_for_type(value: String):
	if value == "counter": return Model.new()
	if value == "grill_kitchen": return SpecialtyModel.new()
	if value == "solyanka_kitchen": return SolyankaModel.new()
	return TeamModel.new()
func fresh_model(): return model_for_type(type_id)
func view_for_type():
	if type_id == "counter": return preload("res://scripts/station_view.gd").new()
	if type_id == "grill_kitchen": return preload("res://scripts/specialty_station_view.gd").new()
	if type_id == "solyanka_kitchen": return preload("res://scripts/solyanka_station_view.gd").new()
	return preload("res://scripts/team_station_view.gd").new()


func role_home_x(role: int) -> float:
	if role_count() <= 1: return 0.0
	if role_count() == 2: return -1.35 if role == 0 else 1.35
	return [-1.85,0.0,1.85][clampi(role,0,2)]

func role_zone_x(role: int) -> Vector2:
	var zone_min := training_zone_min()
	var zone_max := training_zone_max()
	var width := (zone_max.x-zone_min.x)/role_count()
	return Vector2(zone_min.x+width*role,zone_min.x+width*(role+1))

func training_zone_min() -> Vector2:
	return Vector2(-SLOT_WIDTH / 2.0, TRAINING_ZONE_CENTER_Z - SLOT_DEPTH / 2.0)

func training_zone_max() -> Vector2:
	return Vector2(SLOT_WIDTH / 2.0, TRAINING_ZONE_CENTER_Z + SLOT_DEPTH / 2.0)

func _ready() -> void:
	if crew.is_empty(): crew = Definition.crew(type_id, station_id)
	model = model_for_type(type_id)
	view = view_for_type()
	add_child(view)
	view.build(true)
	view.station_label.text = "СТАНЦИЯ %d · [E] ПОКАЖИ КАК" % station_id
	view.station_label.position = Vector3(0, 1.32, -1.1)
	view.station_label.pixel_size = 0.005
	view.station_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_build_bell()
	training.setup(self)
	for role in range(role_count()):
		var student := Avatar.new()
		add_child(student)
		student.caption.text = crew_name(role)
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
	var zone_min := training_zone_min()
	var zone_max := training_zone_max()
	var extent: float = zone_max.x
	var zone_depth: float = zone_max.y - zone_min.y
	var outline_color := Color("cbad72")
	var outline_thickness := TRAINING_ZONE_OUTLINE_THICKNESS
	var front := Props.box(self, Vector3(extent * 2 + outline_thickness, 0.01, outline_thickness), Vector3(0, 0.01, zone_min.y), outline_color)
	front.name = "ZoneEdgeFront"
	var back := Props.box(self, Vector3(extent * 2 + outline_thickness, 0.01, outline_thickness), Vector3(0, 0.01, zone_max.y), outline_color)
	back.name = "ZoneEdgeBack"
	var left_edge := Props.box(self, Vector3(outline_thickness, 0.01, zone_depth + outline_thickness), Vector3(-extent, 0.01, TRAINING_ZONE_CENTER_Z), outline_color)
	left_edge.name = "ZoneEdgeLeft"
	var right_edge := Props.box(self, Vector3(outline_thickness, 0.01, zone_depth + outline_thickness), Vector3(extent, 0.01, TRAINING_ZONE_CENTER_Z), outline_color)
	right_edge.name = "ZoneEdgeRight"
	for spec in [[Vector3(0.02, 2.5, zone_depth), Vector3(-extent, 1.25, TRAINING_ZONE_CENTER_Z)], [Vector3(0.02, 2.5, zone_depth), Vector3(extent, 1.25, TRAINING_ZONE_CENTER_Z)], [Vector3(extent * 2, 2.5, 0.02), Vector3(0, 1.25, zone_min.y)], [Vector3(extent * 2, 2.5, 0.02), Vector3(0, 1.25, zone_max.y)]]:
		var wall := Props.box(self, spec[0], spec[1], Color("86d7c2"))
		wall.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wall.material_override.albedo_color.a = 0.03
		wall.hide()
		walls.append(wall)
	apply_equipment()
	reset_model()

func apply_equipment() -> void:
	if type_id == "counter" and "rag" not in equipment: equipment.append("rag")
	model.equipment = equipment.duplicate()

func reset_model() -> void:
	model.reset(dishes()[0])

func apply_single(command: Dictionary, delta: float) -> void:
	if command.get("feed", false): model.feed()
	if command.get("drop", false): model.put_down()
	var item: String = command.get("grab", "")
	if item in ["jug", "cup", "rag", "pan", "potato", "sausage", "tomato", "potato_0", "potato_1", "potato_2", "sausage_0", "sausage_1", "sausage_2", "plate_0", "plate_1", "plate_2"] and model.held.is_empty(): model.pick_up(item)
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
		var raw = command.pose.get("presentation", {})
		var appearance: Dictionary = preload("res://scripts/cookbook_data.gd").presentation(raw if raw is Dictionary else {})
		model.presentation.book = appearance.book
		model.presentation.page = appearance.page
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
	apply_equipment()

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
	bell_flash = maxf(0, bell_flash-delta)
	bell_cap.position.y = -sin(bell_flash*45)*bell_flash*0.08
	if is_instance_valid(taster) and type_id == "counter": taster.react(model.customer_reaction)
	var active: bool = training.active()
	var resting: bool = not active and state != "cooking"
	var just_finished_training: bool = observing and not active
	view.station_label.visible = not active
	var local_role: int = training.role_for(local_peer)
	for wall in walls: wall.visible = active and local_role >= 0 and training.phase in ["recording", "confirm_finish"]
	if active and not observing:
		for role in range(role_count()):
			var side := -1 if role == 0 else 1
			var edge: float = side * (Definition.TYPES[type_id].width / 2 + 0.3)
			students[role].position = Vector3(role_home_x(role), 0, 1.85)
			student_paths[role] = [Vector3(edge if role_count()==2 else role_home_x(role), 0, 1.65), Vector3(edge if role_count()==2 else role_home_x(role), 0, -1.6), Vector3(role_home_x(role), 0, -1.6)]
	observing = active
	var performing: bool = training.phase in ["recording", "review", "confirm_finish"]
	if type_id == "counter":
		view.is_production = not (active and local_role == 0)
		for node in [view.worker, view.left_hand, view.right_hand, view.left_arm, view.right_arm]: node.visible = not active and not resting
		view.name_label.text = crew_name(0) + ("\nГотовит" if state == "cooking" else "\nЖдёт показа" if recipes.is_empty() else "\nЖдёт заказ")
	else:
		view.status.visible = state == "cooking"
		for role in range(role_count()):
			view.actors[role].visible = (not active and not resting) or (performing and not role in training.live_roles)
			view.actors[role].caption.text = crew_name(role) + (" · дубль" if active else "")
	view.update_view(model, age, state != "cooking")
	if is_team_station() and state=="cooking" and recipes.has(order_dish):
		var production_tracks: Array=recipes[order_dish].get("tracks",[])
		for role in range(mini(role_count(),production_tracks.size())):
			var track: Dictionary=production_tracks[role]
			if track.is_empty() or track.get("frames",[]).is_empty() or order_tick<float(track.frames.size()): continue
			var home:=Vector3(role_home_x(role),0,1.85)
			var partner: Vector3=view.actors[1-role].position if role_count()==2 else Vector3.ZERO
			view.actors[role].finished_role_activity(home,partner,delta,age,station_id*7+role)
			view.actors[role].caption.text=crew_name(role)+"\nЗакончил · теперь подсказывает"
	if type_id == "counter": view._update_worker(model, age, state != "cooking")
	for role in range(role_count()):
		var student: Node3D = students[role]
		var home := Vector3(role_home_x(role), 0, 1.85)
		if resting:
			if not was_resting and not just_finished_training:
				if type_id == "counter":
					student.position = model.actor_position
					student.rotation.y = model.actor_yaw
				else:
					var pose: Dictionary = model.poses[role]
					student.position = Vector3(pose.position[0], pose.position[1], pose.position[2])
					student.rotation.y = pose.yaw
			elif age <= delta * 1.5: student.position = home
			student.show()
			student.caption.text = crew_name(role) + ("\nЖдёт показа" if recipes.is_empty() else "\nЖдёт заказ")
			student.idle(home, delta, age, station_id * 3 + role, float(Definition.TYPES[type_id].width) / 2.0 + 0.35)
		else:
			student.visible = active and (role in training.live_roles or training.phase == "ready")
			student.caption.text = crew_name(role)
		if student.visible and active:
			var target := Vector3(role_home_x(role), 0, -1.5)
			if not student_paths[role].is_empty():
				if student.walk_to(student_paths[role][0], delta): student_paths[role].pop_front()
			else: student.rotation.y = PI
			student.observe(to_global(Vector3(0, 1.7, 1.8)), to_global(target), delta, role)
		zone_panels[role].visible = active and local_role >= 0 and not role in training.live_roles
		if local_role >= 0 and not performing: zone_panels[role].hide()
		zone_labels[role].visible = zone_panels[role].visible

	was_resting = resting
	if manual_station:
		for student in students: student.hide()
		if type_id=="counter":
			for node in [view.worker, view.left_hand, view.right_hand, view.left_arm, view.right_arm, view.name_label]: node.hide()
		view.station_label.text = "ШЕФ-СТАНЦИЯ · МАСТЕР-КЛАСС" if masterclass_station else "ТВОЯ СТОЙКА · [E] ГОТОВИТЬ"
	if not manual_station: view.station_label.text="СТАНЦИЯ %d · [E] ПОКАЖИ КАК"%station_id
	if not manual_station and staffed>=0:
		for role in range(role_count()):
			if role>=staffed:
				students[role].hide()
				if is_team_station(): view.actors[role].hide()
		if staffed<role_count():
			view.station_label.text="СТАНЦИЯ %d · НУЖНЫ КЛОНЫ %d/%d"%[station_id,staffed,role_count()]
			if type_id=="counter":
				for node in [view.worker,view.left_hand,view.right_hand,view.left_arm,view.right_arm,view.name_label]: node.hide()
	if get_parent().game != null and is_instance_valid(get_parent().game.laboratory) and get_parent().game.laboratory.reserves_station(station_id): view.station_label.text="СТАНЦИЯ %d · %s"%[station_id,"ПЕРЕКАЛИБРОВКА" if get_parent().game.laboratory.calibrator.reserves_station(station_id) else "СОТРУДНИК ИДЁТ К СТАНЦИИ"]
	if get_parent().game!=null and is_instance_valid(get_parent().game.laboratory):
		for role in range(role_count()):
			if get_parent().game.laboratory.presenting_clone(int(crew[role].get("clone_id",0))):
				students[role].hide()
				if is_team_station(): view.actors[role].hide()
				else:
					for node in [view.worker,view.left_hand,view.right_hand,view.left_arm,view.right_arm,view.name_label]: node.hide()
	if not manual_station and not group_training_state.is_empty():
		var training_text: String={"assigned":"НАЗНАЧЕНО ОБУЧЕНИЕ","gathering":"ЗАКАНЧИВАЕТ И СОБИРАЕТСЯ","walking":"ИДЁТ К ТЕЛЕВИЗОРУ","watching":"СМОТРИТ ХАЙЛАЙТЫ","returning":"ВОЗВРАЩАЕТСЯ"}.get(group_training_state,"ОБУЧЕНИЕ")
		view.station_label.text="СТАНЦИЯ %d · %s"%[station_id,training_text]
		if state!="cooking":
			for student in students: student.hide()
			if type_id=="counter":
				for node in [view.worker,view.left_hand,view.right_hand,view.left_arm,view.right_arm,view.name_label]: node.hide()
			else:
				for actor in view.actors: actor.hide()
	if is_instance_valid(taster): direct_attention(taster)
	if get_parent().progress.shift=="night" and not training.active() and not manual_station:
		for student in students: student.hide()
		if type_id=="counter":
			for node in [view.worker,view.left_hand,view.right_hand,view.left_arm,view.right_arm,view.name_label]: node.hide()
		else:
			for actor in view.actors: actor.hide()
		view.station_label.text="СТАНЦИЯ %d · ПОВАРА ОТДЫХАЮТ"%station_id

func direct_attention(person: Node3D) -> void:
	person.watching = true
	person.playback_speed = order_tempo if state == "cooking" else 1.0
	person.mouth_amount = model.mouth_opening()
	person.drinking = model.held in ["jug","cup","rag"] if type_id == "counter" else ("water" in model.hands or "pot" in model.hands)
	person.drunk_ml = float(model.guest_serving.drunk) if type_id == "counter" else model.guest_drunk()
	person.chewing = float(model.guest_serving.chew) if type_id == "counter" else model.guest_chewing()
	var role := int(age / 5.0) % role_count()
	person.cook_target = to_global(Vector3(role_home_x(role), 1.55, 1.85))
	var target := Vector3(0, 1.1, 0)
	person.following_food = false
	if type_id == "counter":
		person.cook_target = to_global(model.actor_position + Vector3(0, 1.5, 0)) if state == "cooking" or training.active() else students[0].global_position + Vector3.UP * 1.5
		var item: String = model.held
		person.following_food = not item.is_empty()
		if item.is_empty(): item = "potato" if model.dish == "potato" else "sausage" if model.dish == "sausage" else "cup"
		var point: Vector2 = model.get(item)
		target = Vector3(point.x, Model.BASE_Y + float(model.elevations.get(item, 0.0)) + 0.1, point.y)
	else:
		var item: String = model.hands[role]
		if item.is_empty():
			for other in range(role_count()):
				if other != role and not model.hands[other].is_empty(): item = model.hands[other]; break
		person.following_food = not item.is_empty()
		if item.is_empty():
			for candidate in model.ITEMS:
				if view.items.has(candidate) and model.item_available(candidate): item = candidate; break
		if view.items.has(item): target = view.items[item].position + Vector3.UP * 0.1
	person.food_target = to_global(target)

func save_entry() -> Dictionary:
	return {"staffed":staffed,"equipment":equipment, "manual": manual_station,"slot": slot_index, "type": type_id, "crew": crew, "upgrades": upgrades, "recipes": recipes, "drafts": drafts, "method_sources":method_sources}

func world_entry() -> Dictionary:
	var data := save_entry()
	data.id = station_id
	data.erase("recipes")
	data.erase("drafts")
	data.known = recipes.keys()
	data.order_dish = order_dish
	data.customer_id = customer_id
	data.customer_order = customer_order
	data.recipe_times = {}
	data.recipe_quality = {}
	for key in recipes:
		data.recipe_times[key] = recipes[key].duration
		data.recipe_quality[key] = recipes[key].get("quality", {})
	data.state = state
	data.order_tempo = order_tempo
	data.model = model.snapshot()
	data.training = training.summary()
	data.masterclass = masterclass_station
	data.group_training_state=group_training_state
	return data

func _build_bell() -> void:
	bell = Node3D.new()
	add_child(bell)
	bell.position = Vector3(0.70, 1.035, 0.95) if type_id == "counter" else Vector3(0, 1.035, 1.08)
	Props.cylinder(bell, 0.16, 0.035, Vector3.ZERO, Color("344c4c"))
	bell_cap = Node3D.new()
	bell.add_child(bell_cap)
	var dome := Props.ball(bell_cap, 0.135, Vector3(0,0.055,0), Color("ddb77a"))
	dome.scale.y = 0.65
	dome.material_override.metallic = 0.8
	dome.material_override.roughness = 0.25
	Props.cylinder(bell_cap, 0.024, 0.05, Vector3(0,0.15,0), Color("f1d29a"))
	Props.cylinder(bell_cap, 0.06, 0.015, Vector3(0,0.18,0), Color("e5c58c"))

func bell_hit(camera: Camera3D) -> bool:
	var origin := bell.to_local(camera.global_position)
	var ray := bell.global_basis.inverse() * -camera.global_basis.z
	var hit = AABB(Vector3(-0.2,-0.02,-0.2),Vector3(0.4,0.25,0.4)).intersects_ray(origin,ray)
	return hit != null and origin.distance_to(hit) < 3.2

func ring(role: int) -> void:
	if type_id == "counter": model.presentation.bell += 1
	else:
		var raw = model.poses[role].get("presentation", {"book": false, "page": "index", "bell": 0})
		var appearance: Dictionary = raw.duplicate() if raw is Dictionary else {"book": false, "page": "index", "bell": 0}
		appearance.bell = int(appearance.get("bell", 0)) + 1
		model.poses[role].presentation = appearance
	bell_flash = 0.35
	_stamp_bell(role)

func _stamp_bell(role: int) -> void:
	if training.phase != "recording" or role < 0 or training.pending_tracks.size() <= role: return
	var track: Dictionary = training.pending_tracks[role]
	if track.is_empty() or track.get("frames", []).is_empty(): return
	if type_id == "counter":
		track.frames.back()["presentation"] = model.presentation.duplicate(true)
	elif track.frames.back() is Dictionary:
		track.frames.back()["pose"] = model.poses[role].duplicate(true)

func bell_count() -> int:
	if type_id == "counter": return int(model.presentation.get("bell",0))
	var count := 0
	for pose in model.poses: count += int(pose.get("presentation",{}).get("bell",0))
	return count

func pulse_at(point: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.16
	mesh.outer_radius = 0.19
	var pulse := Props.shape(self, mesh, point, Color("f5d48e"))
	pulse.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tween := create_tween().set_parallel(true)
	tween.tween_property(pulse,"scale",Vector3(2.8,1,2.8),0.55)
	tween.tween_property(pulse,"position:y",point.y+0.15,0.55)
	tween.tween_property(pulse.material_override,"albedo_color:a",0.0,0.55)
	tween.chain().tween_callback(pulse.queue_free)


func apply_upgrades() -> void:
	if type_id != "counter": return
	model.sauce_ramp = "sauce_ramp" in upgrades
	if not model.sauce_ramp:
		if is_instance_valid(upgrade_view):
			remove_child(upgrade_view)
			upgrade_view.queue_free()
			upgrade_view = null
		return
	if is_instance_valid(upgrade_view): return
	upgrade_view = Node3D.new()
	upgrade_view.name = "SauceRamp"
	add_child(upgrade_view)
	var length := Model.RAMP_END - Model.RAMP_START
	var slope := atan2(0.65, length)
	var chute := Node3D.new()
	upgrade_view.add_child(chute)
	chute.position = Vector3(Model.RAMP_X, 0.975, (Model.RAMP_START + Model.RAMP_END) / 2)
	chute.rotation.x = slope
	var size := sqrt(length * length + 0.65 * 0.65)
	Props.box(chute, Vector3(0.56, 0.07, size + 0.1), Vector3(0,-0.045,0), Color("b7c7bb"))
	Props.box(chute, Vector3(0.45, 0.015, size), Vector3.ZERO, Color("c45b47"))
	for x in [-0.27, 0.27]: Props.box(chute, Vector3(0.035, 0.16, size + 0.1), Vector3(x,0.04,0), Color("d5cbb2"))
	for z in [Model.RAMP_START, Model.RAMP_END]:
		var height := Model.ramp_height(z) - 0.10
		Props.box(upgrade_view, Vector3(0.08,height,0.08), Vector3(Model.RAMP_X,height/2,z), Color("728779"))
	# An improvised spring spoon visibly explains the launch at the end.
	var spoon := Props.box(upgrade_view, Vector3(0.48,0.045,0.42), Vector3(Model.RAMP_X,0.70,Model.RAMP_END), Color("e4b668"))
	spoon.rotation.x = -0.55
	for i in range(4): Props.box(upgrade_view, Vector3(0.28,0.025,0.24), Vector3(Model.RAMP_X,0.45+i*0.045,Model.RAMP_END), Color("728779"))
	var label := Props.text(upgrade_view, "СОУСНЫЙ ТРАМПЛИН", Vector3(Model.RAMP_X,1.60,Model.RAMP_START), 18, Color("efcc8e"))
	label.pixel_size = 0.003
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
