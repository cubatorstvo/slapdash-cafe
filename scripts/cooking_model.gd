extends "res://scripts/station_model.gd"
## Deterministic food simulation: live input is simulated, employees replay snapshots.

const Quality = preload("res://scripts/dish_quality.gd")
const DISHES := {"wine": "Вино тяп-ляп", "potato": "Картошка на дырявой сковороде", "sausage": "Непослушная сосиска"}
const PAN_CENTER := Vector2(-1.05, -0.10)
const PAN_LIFT := 0.20
const PAN_HALF := Vector2(0.75, 0.60)
const HOLES := [Vector2(-0.30, 0.15), Vector2(0.30, -0.15)]
const FACES := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
const FACE_NAMES := ["правый", "левый", "верх", "низ", "перед", "зад"]
const SAUCE_CENTER := Vector2(0.30, -0.70)
const PLATE_CENTER := Layout.TRAY

const RAMP_X := 2.65
const RAMP_START := -0.65
const RAMP_END := 0.85
var equipment: Array = ["jug","cup","plates","pan","sauce","rag"]
var chef_order := {}
const GUEST_MOUTH := Vector3(0,1.50,-1.61)
var guest_serving := {"active":false,"drunk":0.0,"eaten":[],"swallowed":[],"chew":0.0}
var guest_pour := false
var ramp_velocity := Vector2(-0.7,-0.12)
var sauce_ramp := false
var plates: Array = []
var tray_wine := 0.0
const PLATE_RADIUS := 0.39
var potato_index := 0
var sausage_index := 0
var potato_plate_offset := Vector2.ZERO
var sausage_plate_offset := Vector2.ZERO
var potatoes: Array = []
var sausages: Array = []
const POTATO_FIELDS := ["potato_plate_offset","potato", "potato_velocity", "potato_orientation", "potato_heat", "potato_state", "fall_speed"]
const SAUSAGE_FIELDS := ["sausage_launched", "sausage_high", "sausage_showy", "sausage_plate_offset","sausage", "sausage_angle", "sausage_phase", "sausage_coating", "sausage_slip", "sausage_state", "sausage_velocity", "previous_sausage", "sausage_fall_speed"]
var tomato := Vector2(1.85, -0.1)
var tomato_velocity := Vector3.ZERO
var tomato_flying := false
var tomato_hit := false
var customer_reaction := 0.0
var throw_direction := Vector3(0, 0.1, -1)
var dish := "wine"
var pan := PAN_CENTER
var potato := PAN_CENTER + Vector2(-0.05, 0.28)
var sausage := Vector2(0.8, 0.65)
var pan_tilt := Vector2.ZERO
var potato_velocity := Vector2.ZERO
var potato_orientation := Quaternion.IDENTITY
var potato_heat: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var potato_state := "pan"
var sausage_fall_speed := 0.0
var fall_speed := 0.0
var falls := 0
var sausage_launched := false
var sausage_high := false
var sausage_showy := false
var sausage_angle := 0.0
var sausage_phase := 0.0
var sausage_coating := 0.0
var sausage_slip := 0.0
var sausage_state := "table"
var sausage_velocity := Vector2.ZERO
var previous_sausage := sausage

func _init() -> void:
	reset("wine")

func reset(recipe := "") -> void:
	if not recipe.is_empty(): dish = recipe
	super.reset()
	chef_order = {}
	guest_serving = {"active":false,"drunk":0.0,"eaten":[],"swallowed":[],"chew":0.0}
	guest_pour = false
	ramp_velocity=Vector2(randf_range(-1.25,-0.45),randf_range(-0.60,0.08))
	jug = Layout.shelf_point(Vector2(-0.1, 0.0))
	cup = Vector2(1.93, Layout.CROCKERY_Z)
	rag = Layout.RAG_HOME
	tomato = Layout.shelf_point(Vector2(0.33, 0.10))
	tomato_velocity = Vector3.ZERO
	tomato_flying = false
	tomato_hit = false
	customer_reaction = 0
	throw_direction = Vector3(0, 0.1, -1)
	pan = PAN_CENTER
	potato = PAN_CENTER + Vector2(-0.05, 0.28)
	sausage = Vector2(0.8, 0.65)
	pan_tilt = Vector2.ZERO
	potato_velocity = Vector2.ZERO
	potato_orientation = Quaternion.IDENTITY
	potato_heat = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	potato_state = "pan"
	fall_speed = 0
	sausage_fall_speed = 0
	falls = 0
	sausage_launched = false
	sausage_high = false
	sausage_showy = false
	sausage_angle = 0
	sausage_phase = 0
	sausage_coating = 0
	sausage_slip = 0
	sausage_state = "table"
	sausage_velocity = Vector2.ZERO
	previous_sausage = sausage
	elevations.merge({"pan": PAN_LIFT, "potato": PAN_LIFT, "sausage": 0.0, "tomato": 0.0})
	elevations.rag = Layout.RAG_Y - BASE_Y
	elevations.jug = Layout.LEVELS[2] - BASE_Y
	elevations.tomato = Layout.LEVELS[2] - BASE_Y
	elevations.cup = Layout.CROCKERY_Y - BASE_Y
	plates.clear()
	tray_wine = 0.0
	potato_plate_offset = Vector2.ZERO
	sausage_plate_offset = Vector2.ZERO
	for i in range(3):
		plates.append({"point": Vector2(1.30, Layout.CROCKERY_Z), "tilt": 0.0})
		elevations["plate_%d" % i] = Layout.CROCKERY_Y + i * 0.045 - BASE_Y
	potato_index = 0
	sausage_index = 0
	potatoes.clear()
	sausages.clear()
	for i in range(3):
		potato = Layout.shelf_point(Vector2(-0.30 + i * 0.30, 0.08))
		potato_state = "table"
		elevations.potato = Layout.LEVELS[0] - BASE_Y
		potatoes.append(_capture_food("potato"))
		sausage = Layout.shelf_point(Vector2(-0.38 + i * 0.38, 0.04))
		previous_sausage = sausage
		elevations.sausage = Layout.LEVELS[1] - BASE_Y
		sausages.append(_capture_food("sausage"))
	_load_food("potato", 0)
	_load_food("sausage", 0)


func pick_up(item: String) -> void:
	if not item_available(item): return
	if item.begins_with("potato_") or item.begins_with("sausage_"):
		put_down()
		var kind := item.get_slice("_", 0)
		_store_food(kind)
		_load_food(kind, clampi(int(item.get_slice("_", 1)), 0, 2))
		item = kind
	if item.begins_with("plate_"):
		super.pick_up(item)
		_sync_carried_food()
		return
	if item == "tomato":
		put_down()
		held = item
		elevations.tomato += 0.12
		tomato_flying = false
		tomato_hit = false
		return
	if item in ["jug", "cup", "rag"]:
		super.pick_up(item)
		return
	if not item in ["pan", "potato", "sausage"]: return
	put_down()
	held = item
	if item == "potato":
		potato_state = "held"
		potato_velocity = Vector2.ZERO
		elevations.potato += 0.12
	elif item == "sausage":
		sausage_state = "held"
		sausage_launched = false
		elevations.sausage += 0.55
		sausage_velocity = Vector2.ZERO
		previous_sausage = sausage
		sausage_slip = 0

func put_down() -> void:
	if held.begins_with("plate_"):
		plates[int(held.get_slice("_", 1))].tilt = 0.0
		super.put_down()
		_sync_carried_food()
		return
	if held == "tomato":
		elevations.tomato = surface_at(tomato) - BASE_Y
		held = ""
		return
	if held in ["jug", "cup", "rag"]:
		super.put_down()
		return
	if held == "potato":
		var offset := potato - PAN_CENTER
		if item_available("pan") and absf(offset.x) < PAN_HALF.x - 0.10 and absf(offset.y) < PAN_HALF.y - 0.10:
			potato_state = "pan"
			elevations.potato = PAN_LIFT
		else:
			potato_state = _food_rest("potato", potato)
			elevations.potato = _food_height(potato_state, potato, "potato") - BASE_Y
	elif held == "sausage":
		if sauce_ramp and absf(sausage.x - RAMP_X) < 0.24 and sausage.y >= RAMP_START - 0.1 and sausage.y < RAMP_END and BASE_Y + float(elevations.sausage) >= ramp_height(sausage.y) - 0.12:
			ramp_velocity=Vector2(randf_range(-1.25,-0.45),randf_range(-0.60,0.08))
			sausage_state = "ramp"
			sausage.x = RAMP_X
			elevations.sausage = ramp_height(sausage.y) - BASE_Y
			held = ""
			_store_food("sausage")
			return
		sausage_state = _food_rest("sausage", sausage)
		elevations.sausage = _food_height(sausage_state, sausage, "sausage") - BASE_Y
		sausage_angle = 0
		sausage_slip = 0
	_store_food("potato")
	_store_food("sausage")
	pan_tilt = Vector2.ZERO
	held = ""

func lift_held(amount: float) -> void:
	if held == "pan": return
	super.lift_held(amount)
	if held.begins_with("plate_"): _sync_carried_food()

func move_item(item: String, point: Vector2) -> void:
	if item == "pan": return
	point = point.clamp(-BOUNDS, BOUNDS)
	if item.begins_with("plate_"): plates[int(item.get_slice("_", 1))].point = point
	elif item == "tomato": tomato = point
	elif item == "potato": potato = point
	elif item == "sausage": sausage = point
	else: super.move_item(item, point)
	if item in elevations: elevations[item] = maxf(float(elevations[item]), support_at(point, BASE_Y + float(elevations[item])) - BASE_Y)

func tilt_pan(motion: Vector2) -> void:
	pan_tilt = (pan_tilt + motion * 0.003).limit_length(0.18)

func step(delta: float, use_item: bool, straighten: bool, squeeze: bool) -> void:
	guest_pour = false
	guest_serving.chew = maxf(0, float(guest_serving.chew)-delta)
	super.step(delta, use_item and held in ["jug", "cup"], straighten, squeeze and held == "rag")
	_store_food("potato")
	_store_food("sausage")
	var pi := potato_index
	var si := sausage_index
	var original_held := held
	for i in range(3):
		_load_food("potato", i)
		_load_food("sausage", i)
		held = "" if (original_held == "potato" and i != pi) or (original_held == "sausage" and i != si) else original_held
		_step_potato(delta, use_item)
		_step_sausage(delta, use_item)
		if i == si and original_held == "sausage" and held.is_empty(): original_held = ""
		_store_food("potato")
		_store_food("sausage")
	held = original_held
	_load_food("potato", pi)
	_load_food("sausage", si)
	_step_tomato(delta, use_item)
	for i in range(plates.size()):
		plates[i].tilt = move_toward(float(plates[i].tilt), 0.95 if held == "plate_%d" % i and use_item else 0.0, delta * 1.8)
	_sync_carried_food()

func _step_potato(delta: float, use_item: bool) -> void:
	if potato_state == "eaten": return
	if held != "pan" or not use_item: pan_tilt = pan_tilt.move_toward(Vector2.ZERO, 1.5 * delta)
	if potato_state == "pan":
		potato_velocity += Vector2(sin(pan_tilt.x), sin(pan_tilt.y)) * 6.0 * delta
		potato_velocity *= exp(-1.1 * delta)
		var travel := potato_velocity * delta
		potato += travel
		var edge := PAN_HALF - Vector2(0.16, 0.15)
		var offset := potato - PAN_CENTER
		if absf(offset.x) > edge.x:
			offset.x = clampf(offset.x, -edge.x, edge.x)
			potato_velocity.x *= -0.45
		if absf(offset.y) > edge.y:
			offset.y = clampf(offset.y, -edge.y, edge.y)
			potato_velocity.y *= -0.45
		potato = PAN_CENTER + offset
		if travel.length() > 0.00001:
			var axis := Vector3(travel.y, 0, -travel.x).normalized()
			potato_orientation = (Quaternion(axis, travel.length() / 0.14) * potato_orientation).normalized()
		elevations.potato = PAN_LIFT - sin(pan_tilt.x) * offset.x - sin(pan_tilt.y) * offset.y
		for hole in HOLES:
			if absf(offset.x - hole.x) < 0.11 and absf(offset.y - hole.y) < 0.11:
				potato_state = "falling"
				fall_speed = 0
				potato_velocity *= 0.92
				falls += 1
		if potato_state == "pan":
			var bottom := potato_orientation.inverse() * Vector3.DOWN
			var face := 0
			for index in range(1, 6):
				if FACES[index].dot(bottom) > FACES[face].dot(bottom): face = index
			potato_heat[face] = minf(1.0, float(potato_heat[face]) + delta * 0.55)
	elif potato_state == "falling":
		fall_speed += 3.5 * delta
		var resting_support := support_at(potato, BASE_Y + float(elevations.potato)) - BASE_Y
		elevations.potato = maxf(resting_support, float(elevations.potato) - fall_speed * delta)
		if elevations.potato <= resting_support:
			potato_state = "table"
	elif potato_state == "table":
		if Layout.broken_corner_contains(potato):
			potato_velocity += Layout.broken_corner_roll_acceleration() * delta
			potato_velocity *= exp(-0.75 * delta)
		else:
			potato_velocity *= exp(-2.8 * delta)
		var travel := potato_velocity * delta
		potato += travel
		if travel.length() > 0.00001:
			var axis := Vector3(travel.y, 0, -travel.x).normalized()
			potato_orientation = (Quaternion(axis, travel.length() / 0.14) * potato_orientation).normalized()
		if Layout.table_contains(potato):
			elevations.potato = Layout.table_height(potato) - BASE_Y
		elif Layout.shelf_contains(potato):
			elevations.potato = support_at(potato, BASE_Y + float(elevations.potato)) - BASE_Y
		else:
			potato_state = "falling"
			fall_speed = 0.0
		if potato_velocity.length() < 0.015:
			potato_velocity = Vector2.ZERO

func _step_sausage(delta: float, use_item: bool) -> void:
	if sausage_state == "eaten": return
	var motion := (sausage - previous_sausage) / maxf(delta, 0.001)
	sausage_phase += delta * 5.5 + motion.length() * delta * 3
	if held == "sausage":
		sausage_angle = move_toward(sausage_angle, PI * 0.5 if use_item else 0.0, 2.8 * delta)
		var upright := sin(sausage_angle)
		if BASE_Y + float(elevations.sausage) <= food_surface("sausage", sausage) + 0.08:
			sausage_slip = maxf(0, sausage_slip - delta * 2)
		else:
			sausage_slip += delta * (0.12 + maxf(0, motion.length() - 0.35) * 0.8) * pow(1.0 - upright, 2)
			sausage_slip = maxf(0, sausage_slip - upright * delta * 1.5)
		if sausage_slip >= 1:
			held = ""
			sausage_state = "falling"
			sausage_velocity = motion * 0.45 + Vector2(cos(sausage_phase), sin(sausage_phase)) * 0.65
			sausage_fall_speed = -0.5
			falls += 1
	elif sausage_state == "ramp" and sauce_ramp:
		sausage.y = minf(RAMP_END, sausage.y + delta * (1.4 + (sausage.y - RAMP_START) * 1.8))
		sausage.x = RAMP_X
		elevations.sausage = ramp_height(sausage.y) - BASE_Y
		sausage_coating = minf(1, sausage_coating + delta * 3.0)
		if sausage.y >= RAMP_END:
			sausage_state = "falling"
			sausage_fall_speed = -6.6
			sausage_velocity = ramp_velocity
			sausage_launched = true
			sausage_high = false
	elif sausage_state == "falling":
		for i in range(plates.size()):
			if not item_available("plate_%d" % i): continue
			if sausage_fall_speed >= 0 and sausage.distance_to(plates[i].point) < PLATE_RADIUS - 0.08 and absf(float(elevations.sausage) - float(elevations["plate_%d" % i])) < 0.16:
				if held == "plate_%d"%i and sausage_fall_speed>=1.0: sausage_showy = true
				sausage_launched = false
				sausage_state = "plate_%d" % i
				sausage_plate_offset = sausage - plates[i].point
				elevations.sausage = float(elevations[sausage_state]) + 0.035
				sausage_velocity = Vector2.ZERO
				previous_sausage = sausage
				return
		sausage_fall_speed += delta * (7.2 if sausage_launched else 4.0)
		elevations.sausage = clampf(float(elevations.sausage) - sausage_fall_speed * delta, support_at(sausage, BASE_Y + float(elevations.sausage)) - BASE_Y, 4.0 - BASE_Y if sausage_launched else MAX_LIFT)
		sausage = (sausage + sausage_velocity * delta).clamp(-BOUNDS, BOUNDS)
		if sausage_launched:
			if BASE_Y + float(elevations.sausage) >= 2.8: sausage_high = true
		else: sausage_velocity *= exp(-2 * delta)
		sausage_angle = move_toward(sausage_angle, 0, delta * 3)
		if elevations.sausage <= support_at(sausage, BASE_Y + float(elevations.sausage)) - BASE_Y:
			sausage_state = _food_rest("sausage", sausage)
			elevations.sausage = _food_height(sausage_state, sausage, "sausage") - BASE_Y
			sausage_slip = 0
			sausage_launched = false
	if "sauce" in equipment and sausage.distance_to(SAUCE_CENTER) < 0.34 and float(elevations.sausage) <= 0.13:
		sausage_coating = minf(1, sausage_coating + delta * 1.4)
	previous_sausage = sausage

func cooked_faces() -> int:
	var count := 0
	for heat in potato_heat:
		if heat >= 0.999: count += 1
	return count

func success() -> bool:
	return quality().grade == "S"

func quality() -> Dictionary:
	_store_food("potato")
	_store_food("sausage")
	return preload("res://scripts/chef_orders.gd").evaluate(self)

func goal_text() -> String:
	match dish:
		"potato": return "КАРТОШКА: %d / 6 сторон + тарелка" % cooked_faces()
		"sausage": return "СОСИСКА: соус %d%% + тарелка" % roundi(sausage_coating * 100)
	return "ВИНО: %d мл · нужно 200–250 мл" % roundi(filled)

func progress_value() -> float:
	if dish == "potato":
		var total := 0.0
		for heat in potato_heat: total += float(heat)
		return total / 6.0 * 100
	if dish == "sausage": return sausage_coating * 100
	return filled / TARGET * 100

func snapshot() -> Dictionary:
	var data := super.snapshot()
	data.dish = dish
	data.guest_serving = guest_serving.duplicate(true)
	data.chef_order = chef_order.duplicate(true)
	data.ramp_velocity=[ramp_velocity.x,ramp_velocity.y]
	data.guest_pour = guest_pour
	data.equipment = equipment.duplicate()
	data.plates = plates.map(func(p): return {"point": [p.point.x, p.point.y], "tilt": p.tilt})
	data.tray_wine = tray_wine
	data.tomato = {"position": [tomato.x, tomato.y], "velocity": [tomato_velocity.x, tomato_velocity.y, tomato_velocity.z], "flying": tomato_flying, "hit": tomato_hit, "reaction": customer_reaction}
	_store_food("potato")
	_store_food("sausage")
	data.stock = {"potatoes": encode_stock(potatoes), "sausages": encode_stock(sausages), "potato_index": potato_index, "sausage_index": sausage_index}
	data.food = {"pan_tilt": [pan_tilt.x, pan_tilt.y], "potato": [potato.x, potato.y],
			"potato_velocity": [potato_velocity.x, potato_velocity.y], "potato_orientation": [potato_orientation.x, potato_orientation.y, potato_orientation.z, potato_orientation.w],
			"potato_heat": potato_heat.duplicate(), "potato_state": potato_state, "fall_speed": fall_speed, "falls": falls,
			"sausage": [sausage.x, sausage.y], "sausage_angle": sausage_angle, "sausage_phase": sausage_phase,
			"sausage_coating": sausage_coating, "sausage_slip": sausage_slip, "sausage_state": sausage_state,
			"sausage_velocity": [sausage_velocity.x, sausage_velocity.y], "sausage_fall_speed": sausage_fall_speed}
	return data

func restore(data: Dictionary) -> void:
	super.restore(data)
	guest_serving = data.get("guest_serving", {"active":false,"drunk":0.0,"eaten":[],"swallowed":[],"chew":0.0}).duplicate(true)
	chef_order = data.get("chef_order",{}).duplicate(true)
	var recorded: Array=data.get("ramp_velocity",[-0.7,-0.12])
	ramp_velocity=Vector2(recorded[0],recorded[1])
	guest_pour = data.get("guest_pour",false)
	equipment = data.get("equipment",equipment).duplicate()
	dish = str(data.get("dish", "wine"))
	tray_wine = float(data.get("tray_wine", 0.0))
	if data.has("plates"):
		plates = data.plates.map(func(p): return {"point": Vector2(p.point[0], p.point[1]), "tilt": float(p.tilt)})
	tomato = Vector2(data.tomato.position[0], data.tomato.position[1])
	tomato_velocity = Vector3(data.tomato.velocity[0], data.tomato.velocity[1], data.tomato.velocity[2])
	tomato_flying = data.tomato.flying
	tomato_hit = data.tomato.hit
	customer_reaction = data.tomato.reaction
	var food: Dictionary = data.food
	pan_tilt = Vector2(food.pan_tilt[0], food.pan_tilt[1])
	potato = Vector2(food.potato[0], food.potato[1])
	potato_velocity = Vector2(food.potato_velocity[0], food.potato_velocity[1])
	potato_orientation = Quaternion(food.potato_orientation[0], food.potato_orientation[1], food.potato_orientation[2], food.potato_orientation[3])
	potato_heat = food.potato_heat.duplicate()
	potato_state = str(food.potato_state)
	fall_speed = float(food.fall_speed)
	falls = int(food.falls)
	sausage = Vector2(food.sausage[0], food.sausage[1])
	sausage_angle = float(food.sausage_angle)
	sausage_phase = float(food.sausage_phase)
	sausage_coating = float(food.sausage_coating)
	sausage_slip = float(food.sausage_slip)
	sausage_state = str(food.sausage_state)
	sausage_velocity = Vector2(food.sausage_velocity[0], food.sausage_velocity[1])
	sausage_fall_speed = food.sausage_fall_speed
	previous_sausage = sausage
	potatoes = decode_stock(data.stock.potatoes)
	sausages = decode_stock(data.stock.sausages)
	potato_index = int(data.stock.potato_index)
	sausage_index = int(data.stock.sausage_index)
	_load_food("potato", potato_index)
	_load_food("sausage", sausage_index)

func _step_tomato(delta: float, use_item: bool) -> void:
	customer_reaction = maxf(0, customer_reaction - delta)
	if held == "tomato" and use_item:
		held = ""
		tomato_flying = true
		tomato_velocity = throw_direction.normalized() * 6.5
	if not tomato_flying: return
	var point := Vector3(tomato.x, BASE_Y + float(elevations.tomato) + 0.12, tomato.y)
	var next := point + tomato_velocity * delta
	var receiver := Vector3(0, 1.5, -1.85)
	if Geometry3D.get_closest_point_to_segment(receiver, point, next).distance_to(receiver) < 0.38:
		tomato_hit = true
		tomato_flying = false
		customer_reaction = 1.8
		next = receiver
	tomato_velocity.y -= delta * 6
	var floor_y := BASE_Y + 0.12 if absf(next.x) < 2.15 and absf(next.z) < 1.12 else 0.12
	if next.y <= floor_y:
		next.y = floor_y
		tomato_flying = false
	tomato = Vector2(next.x, next.z)
	elevations.tomato = next.y - BASE_Y - 0.12

func _capture_food(kind: String) -> Dictionary:
	var data := {"elevation": elevations[kind]}
	for key in POTATO_FIELDS if kind == "potato" else SAUSAGE_FIELDS:
		var value = get(key)
		data[key] = value.duplicate(true) if value is Array else value
	return data

func _store_food(kind: String) -> void:
	var stock := potatoes if kind == "potato" else sausages
	if stock.size() == 3: stock[potato_index if kind == "potato" else sausage_index] = _capture_food(kind)

func _load_food(kind: String, index: int) -> void:
	var stock := potatoes if kind == "potato" else sausages
	if kind == "potato": potato_index = index
	else:
		sausage_index = index
		sausage_launched = false
		sausage_high = false
		sausage_showy = false
	for key in stock[index]:
		if key == "elevation": elevations[kind] = stock[index][key]
		else: set(key, stock[index][key].duplicate(true) if stock[index][key] is Array else stock[index][key])

static func food_surface(kind: String, point: Vector2) -> float:
	if Layout.shelf_contains(point): return Layout.LEVELS[0] if kind == "potato" else Layout.LEVELS[1]
	return surface_at(point)

func _get(property: StringName):
	if str(property).begins_with("plate_"):
		var index := int(str(property).get_slice("_", 1))
		if index >= 0 and index < plates.size(): return plates[index].point
	return null

func _food_rest(kind: String, point: Vector2) -> String:
	for i in range(plates.size()):
		var key := "plate_%d" % i
		if not item_available(key): continue
		if point.distance_to(plates[i].point) <= PLATE_RADIUS - 0.10 and float(elevations[kind]) >= float(elevations[key]) - 0.06:
			set(kind + "_plate_offset", point - plates[i].point)
			return key
	return "tray" if Layout.on_tray(point, 0.1) else "table"

func _food_height(state: String, point: Vector2, kind: String) -> float:
	if state.begins_with("plate_"): return BASE_Y + float(elevations[state]) + 0.035
	return support_at(point, BASE_Y + float(elevations[kind]))

func _sync_carried_food() -> void:
	_store_food("potato")
	_store_food("sausage")
	for kind in ["potato", "sausage"]:
		for food in potatoes if kind == "potato" else sausages:
			var state: String = food[kind + "_state"]
			if not state.begins_with("plate_"): continue
			var carrier: Dictionary = plates[int(state.get_slice("_", 1))]
			food[kind] = carrier.point + food.get(kind + "_plate_offset", Vector2.ZERO)
			food.elevation = float(elevations[state]) + 0.035
			if kind == "sausage": food.previous_sausage = food[kind]
			if float(carrier.tilt) > 0.60:
				food[kind] += Vector2(0.46, 0)
				food[kind + "_state"] = "falling"
				food["fall_speed" if kind == "potato" else "sausage_fall_speed"] = 0.0
	_load_food("potato", potato_index)
	_load_food("sausage", sausage_index)

func food_is_served(kind: String, index: int) -> bool:
	var food: Dictionary = (potatoes if kind == "potato" else sausages)[index]
	if food[kind + "_state"] == "eaten": return false
	if held == kind and index == (potato_index if kind == "potato" else sausage_index): return false
	var state: String = food[kind + "_state"]
	if state.begins_with("plate_") and held == state: return false
	if not Layout.on_tray(food[kind], 0.08) or absf(BASE_Y + float(food.elevation) - Layout.TRAY_Y) >= 0.12: return false
	return state in ["tray", "table"] or state.begins_with("plate_")

func served_index(kind: String) -> int:
	for i in range(3):
		if food_is_served(kind, i): return i
	return -1

func served_in_dish(kind: String) -> bool:
	if kind == "wine": return cup_on_tray() and filled > 0 and tray_wine <= 0.01
	var index := served_index(kind)
	return index >= 0 and str((potatoes if kind == "potato" else sausages)[index][kind + "_state"]).begins_with("plate_")

func cup_on_tray() -> bool:
	return item_available("cup") and Layout.on_tray(cup, 0.24) and held != "cup" and absf(BASE_Y + float(elevations.cup) - Layout.TRAY_Y) < 0.08

func served_wine() -> float:
	return tray_wine + (filled if cup_on_tray() else 0.0)

func _deliver(point: Vector2, amount: float, height: float) -> void:
	if guest_serving.active and height >= GUEST_MOUTH.y:
		var hit: Vector2 = vessels[source].landing(vessel_base(source), GUEST_MOUTH.y) if held in vessels else point
		if hit.distance_to(Vector2(GUEST_MOUTH.x,GUEST_MOUTH.z)) < 0.24:
			guest_serving.drunk += amount
			guest_pour = true
			landing = hit
			return
	var receiver := receiver_at(point, height)
	if not receiver.is_empty():
		var accepted := Pourable.accepted(amount, filled if receiver == "cup" else wine, CUP_CAPACITY if receiver == "cup" else JUG_CAPACITY)
		if receiver == "cup": filled += accepted
		else: wine += accepted
		amount -= accepted
	if amount <= 0.0001: return
	if Layout.on_tray(point) and height >= Layout.TRAY_Y:
		var accepted := minf(amount, maxf(0, 350.0 - tray_wine))
		tray_wine += accepted
		if amount > accepted: super._deliver(Layout.TRAY + Vector2(Layout.TRAY_HALF.x + 0.15, 0), amount - accepted, height)
	else: super._deliver(point, amount, height)

func _absorb(delta: float) -> void:
	super._absorb(delta)
	if Layout.on_tray(rag) and tray_wine > 0:
		var amount := minf(tray_wine, minf(160 * delta, RAG_CAPACITY - soaked))
		tray_wine -= amount
		soaked += amount

static func encode_stock(stock: Array) -> Array:
	var result: Array = []
	for entry in stock:
		var data := {}
		for key in entry:
			var value = entry[key]
			if value is Vector2: value = [value.x, value.y]
			elif value is Quaternion: value = [value.x, value.y, value.z, value.w]
			data[key] = value
		result.append(data)
	return result

static func decode_stock(stock: Array) -> Array:
	var result: Array = stock.duplicate(true)
	for data in result:
		for key in data:
			var value = data[key]
			if value is Array and value.size() == 2: data[key] = Vector2(value[0], value[1])
			elif key == "potato_orientation": data[key] = Quaternion(value[0], value[1], value[2], value[3])
	return result

func _utensil_grade(report: Dictionary) -> Dictionary:
	if dish == "sausage":
		var served := served_index("sausage")
		if served >= 0 and sausages[served].get("sausage_showy", false):
			report.style_count = 1
			report.style_multiplier = Quality.style_multiplier(1)
			report.style_tricks = ["Ловкая подача"]
	var correct := served_in_dish(dish)
	report.criteria.append({"label": "Подходящая посуда: " + ("✓" if correct else "×"), "value": 1.0 if correct else 0.0})
	if report.present and not correct:
		var grades := ["D", "C", "B", "A", "S"]
		report.grade = grades[maxi(0, grades.find(report.grade) - 1)]
		report.price_factor = Quality.PRICE_FACTORS[report.grade]
	return report


static func ramp_height(z: float) -> float:
	return lerpf(1.30, 0.65, clampf((z - RAMP_START) / (RAMP_END - RAMP_START), 0, 1))

func item_available(item: String) -> bool:
	if item in guest_serving.swallowed: return false
	if item.begins_with("plate_"): return "plates" in equipment
	if item in ["jug","cup","rag","pan"]: return item in equipment
	if item.begins_with("potato_") or item.begins_with("sausage_"):
		var kind := item.get_slice("_",0)
		var stock: Array = potatoes if kind == "potato" else sausages
		return stock[int(item.get_slice("_",1))][kind+"_state"] != "eaten"
	if item in ["potato","sausage"]: return get(item+"_state") != "eaten"
	return true

func receiver_at(point: Vector2, height: float) -> String:
	for item in ["cup","jug"]:
		if not item_available(item) or item == held or (item == source and flowing): continue
		var base := vessel_base(item)
		if point.distance_to(get(item)) <= vessels[item].radius and height >= base.y + vessels[item].rim_height and vessels[item].angle < 15: return item
	return ""

func held_center() -> Vector3:
	if held.is_empty(): return Vector3(100,100,100)
	if held == "pan": return Vector3(pan.x, BASE_Y+PAN_LIFT, pan.y)
	var point: Vector2 = get(held)
	return Vector3(point.x,BASE_Y+float(elevations[held])+(0.35 if held in vessels else 0.1),point.y)

func mouth_opening() -> float:
	if not guest_serving.active: return 0
	return clampf(1.0-held_center().distance_to(GUEST_MOUTH)/1.5,0,1)

func can_feed() -> bool:
	return guest_serving.active and not held.is_empty() and held_center().distance_to(GUEST_MOUTH) <= 0.95

func food_candidate(kind: String, index: int, location: String, utensil: bool) -> Dictionary:
	var entry: Dictionary = (potatoes if kind == "potato" else sausages)[index]
	var candidate := {"kind":kind,"present":true,"utensil":utensil,"location":location,"id":kind+str(index)}
	if kind == "potato":
		var faces := 0
		for heat in entry.potato_heat:
			if heat >= 0.999: faces += 1
		candidate.faces = faces
	else: candidate.coat = entry.sausage_coating; candidate.showy = entry.get("sausage_showy",false)
	return candidate

func feed() -> bool:
	if not can_feed(): return false
	_store_food("potato")
	_store_food("sausage")
	var item := held
	for kind in ["potato","sausage"]:
		var stock: Array = potatoes if kind == "potato" else sausages
		for i in range(stock.size()):
			var state: String = stock[i][kind+"_state"]
			var selected: bool = item == kind and i == (potato_index if kind == "potato" else sausage_index)
			if selected or (item.begins_with("plate_") and state == item) or (item == "pan" and kind == "potato" and state == "pan"):
				guest_serving.eaten.append(food_candidate(kind,i,"у гостя",item.begins_with("plate_") or item == "pan"))
				stock[i][kind+"_state"] = "eaten"
	if item == "cup": guest_serving.drunk += filled; filled = 0
	elif item == "jug": guest_serving.drunk += wine; wine = 0
	elif item == "rag": guest_serving.drunk += soaked; soaked = 0
	if item not in ["potato","sausage"]: guest_serving.swallowed.append(item)
	_load_food("potato",potato_index)
	_load_food("sausage",sausage_index)
	held = ""
	guest_serving.chew = 0.8
	return true

func serving_candidates(kind: String) -> Array:
	var result: Array = []
	if kind == "wine":
		if cup_on_tray() and filled > 0: result.append({"present":true,"ml":filled,"utensil":true,"location":"в бокале на подносе"})
		if tray_wine > 0: result.append({"present":true,"ml":tray_wine,"utensil":false,"location":"на подносе"})
		if guest_serving.drunk > 0: result.append({"present":true,"ml":guest_serving.drunk,"utensil":true,"location":"выпито гостем"})
	else:
		for i in range(3):
			if food_is_served(kind,i): result.append(food_candidate(kind,i,"на подносе",str((potatoes if kind == "potato" else sausages)[i][kind+"_state"]).begins_with("plate_")))
		for entry in guest_serving.eaten:
			if entry.kind == kind: result.append(entry.duplicate(true))
	return result

func preview_candidate(kind: String) -> Dictionary:
	if kind == "wine": return {"present":true,"ml":filled,"utensil":item_available("cup")}
	return food_candidate(kind,potato_index if kind == "potato" else sausage_index,"в работе",false)

func ramp_landing() -> Vector2:
	# Predicted crossing of table height. Fixed simulation steps match the flight integrator.
	var point := Vector2(RAMP_X,RAMP_END)
	var height := ramp_height(RAMP_END)
	var speed := -6.6
	if sausage_launched and sausage_state=="falling":
		point=sausage; height=BASE_Y+float(elevations.sausage); speed=sausage_fall_speed
	var velocity := sausage_velocity if sausage_launched else ramp_velocity
	for i in range(240):
		speed+=7.2/60.0
		height-=speed/60.0
		point+=velocity/60.0
		if speed>0 and height<=BASE_Y+0.035: break
	return point.clamp(-BOUNDS,BOUNDS)

# Transfer everything resting on the serving tray after the order has been evaluated.
# Recorded snapshots remain untouched; this belongs to customer service, not the recipe.
func take_serving() -> Array:
	_store_food("potato"); _store_food("sausage")
	var result: Array=[]
	for kind in ["potato","sausage"]:
		var stock: Array=potatoes if kind=="potato" else sausages
		for i in range(stock.size()):
			if not food_is_served(kind,i): continue
			var p: Vector2=stock[i][kind]
			result.append({"kind":kind,"from":Vector3(p.x,BASE_Y+stock[i].elevation+0.08,p.y)})
			guest_serving.eaten.append(food_candidate(kind,i,"у гостя",str(stock[i][kind+"_state"]).begins_with("plate_")))
			stock[i][kind+"_state"]="eaten"
	for item in ["plate_0","plate_1","plate_2","cup","jug","rag","tomato"]:
		if not item_available(item) or held==item: continue
		var p: Vector2=plates[int(item.get_slice("_",1))].point if item.begins_with("plate_") else get(item)
		var height: float=BASE_Y+float(elevations.get(item,0))
		if not Layout.on_tray(p,0.15) or absf(height-Layout.TRAY_Y)>0.18: continue
		result.append({"kind":"plate" if item.begins_with("plate_") else item,"from":Vector3(p.x,height,p.y),"ml":filled if item=="cup" else wine if item=="jug" else 0})
		guest_serving.swallowed.append(item)
		if item=="cup": guest_serving.drunk+=filled; filled=0
		elif item=="jug": guest_serving.drunk+=wine; wine=0
		elif item=="rag": guest_serving.drunk+=soaked; soaked=0
	if tray_wine>0:
		result.append({"kind":"wine","from":Vector3(Layout.TRAY.x,Layout.TRAY_Y,Layout.TRAY.y),"ml":tray_wine})
		guest_serving.drunk+=tray_wine; tray_wine=0
	_load_food("potato",potato_index); _load_food("sausage",sausage_index)
	guest_serving.chew=0.8
	return result
