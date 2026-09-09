extends "res://scripts/station_model.gd"
## Deterministic food simulation: live input is simulated, employees replay snapshots.

const DISHES := {"wine": "Вино тяп-ляп", "potato": "Картошка на дырявой сковороде", "sausage": "Непослушная сосиска"}
const PAN_CENTER := Vector2(-0.55, 0)
const PAN_LIFT := 0.20
const PAN_HALF := Vector2(0.75, 0.60)
const HOLES := [Vector2(-0.30, -0.15), Vector2(0.30, 0.15)]
const FACES := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
const FACE_NAMES := ["правый", "левый", "верх", "низ", "перед", "зад"]
const SAUCE_CENTER := Vector2(1.45, -0.50)
const PLATE_CENTER := Vector2(1.35, 0.40)

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
var fall_speed := 0.0
var falls := 0
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
	jug = Vector2(-1.65, -0.65)
	cup = Vector2(0.65, -0.65)
	rag = Vector2(1.85, 0.65)
	tomato = Vector2(1.85, -0.1)
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
	falls = 0
	sausage_angle = 0
	sausage_phase = 0
	sausage_coating = 0
	sausage_slip = 0
	sausage_state = "table"
	sausage_velocity = Vector2.ZERO
	previous_sausage = sausage
	elevations.merge({"pan": PAN_LIFT, "potato": PAN_LIFT, "sausage": 0.0, "tomato": 0.0})

func pick_up(item: String) -> void:
	if item == "tomato":
		put_down()
		held = item
		elevations.tomato = 0.4
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
		elevations.potato = 0.4
	elif item == "sausage":
		sausage_state = "held"
		elevations.sausage = 0.22
		sausage_velocity = Vector2.ZERO
		previous_sausage = sausage
		sausage_slip = 0

func put_down() -> void:
	if held == "tomato":
		elevations.tomato = 0.0
		held = ""
		return
	if held in ["jug", "cup", "rag"]:
		super.put_down()
		return
	if held == "potato":
		var offset := potato - PAN_CENTER
		if absf(offset.x) < PAN_HALF.x - 0.10 and absf(offset.y) < PAN_HALF.y - 0.10:
			potato_state = "pan"
			elevations.potato = PAN_LIFT
		else:
			potato_state = "plate" if potato.distance_to(PLATE_CENTER) < 0.40 else "table"
			elevations.potato = 0.045 if potato_state == "plate" else 0.0
	elif held == "sausage":
		sausage_state = "plate" if sausage.distance_to(PLATE_CENTER) < 0.40 else "table"
		elevations.sausage = 0.045 if sausage_state == "plate" else 0.0
		sausage_angle = 0
		sausage_slip = 0
	pan_tilt = Vector2.ZERO
	held = ""

func lift_held(amount: float) -> void:
	if held == "pan": return
	super.lift_held(amount)

func move_item(item: String, point: Vector2) -> void:
	if item == "pan": return
	point = point.clamp(-BOUNDS, BOUNDS)
	if item == "tomato": tomato = point
	elif item == "potato": potato = point
	elif item == "sausage": sausage = point
	else: super.move_item(item, point)

func tilt_pan(motion: Vector2) -> void:
	pan_tilt = (pan_tilt + motion * 0.003).limit_length(0.18)

func step(delta: float, use_item: bool, straighten: bool, squeeze: bool) -> void:
	super.step(delta, use_item and held == "jug", straighten, squeeze and held == "rag")
	_step_potato(delta, use_item)
	_step_sausage(delta, use_item)
	_step_tomato(delta, use_item)

func _step_potato(delta: float, use_item: bool) -> void:
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
				potato_velocity = Vector2(0, 0.9)
				falls += 1
		if potato_state == "pan":
			var bottom := potato_orientation.inverse() * Vector3.DOWN
			var face := 0
			for index in range(1, 6):
				if FACES[index].dot(bottom) > FACES[face].dot(bottom): face = index
			potato_heat[face] = minf(1.0, float(potato_heat[face]) + delta * 0.55)
	elif potato_state == "falling":
		fall_speed += 3.5 * delta
		elevations.potato = maxf(0, float(elevations.potato) - fall_speed * delta)
		if elevations.potato <= 0: potato_state = "table"
	elif potato_state == "table" and potato_velocity.length() > 0:
		var before := potato.y
		potato.y = minf(0.78, potato.y + potato_velocity.y * delta)
		potato_orientation = (Quaternion(Vector3.RIGHT, (potato.y - before) / 0.14) * potato_orientation).normalized()
		if potato.y >= 0.78: potato_velocity = Vector2.ZERO

func _step_sausage(delta: float, use_item: bool) -> void:
	var motion := (sausage - previous_sausage) / maxf(delta, 0.001)
	sausage_phase += delta * 5.5 + motion.length() * delta * 3
	if held == "sausage":
		sausage_angle = move_toward(sausage_angle, PI * 0.5 if use_item else 0.0, 2.8 * delta)
		var upright := sin(sausage_angle)
		if float(elevations.sausage) <= 0.08:
			sausage_slip = maxf(0, sausage_slip - delta * 2)
		else:
			sausage_slip += delta * (0.12 + maxf(0, motion.length() - 0.35) * 0.8) * pow(1.0 - upright, 2)
			sausage_slip = maxf(0, sausage_slip - upright * delta * 1.5)
		if sausage_slip >= 1:
			held = ""
			sausage_state = "falling"
			sausage_velocity = motion * 0.45 + Vector2(cos(sausage_phase), sin(sausage_phase)) * 0.65
			fall_speed = -0.5
			falls += 1
	elif sausage_state == "falling":
		fall_speed += delta * 4
		elevations.sausage = clampf(float(elevations.sausage) - fall_speed * delta, 0, MAX_LIFT)
		sausage = (sausage + sausage_velocity * delta).clamp(-BOUNDS, BOUNDS)
		sausage_velocity *= exp(-2 * delta)
		sausage_angle = move_toward(sausage_angle, 0, delta * 3)
		if elevations.sausage <= 0:
			sausage_state = "plate" if sausage.distance_to(PLATE_CENTER) < 0.4 else "table"
			sausage_slip = 0
	if sausage.distance_to(SAUCE_CENTER) < 0.34 and float(elevations.sausage) <= 0.13:
		sausage_coating = minf(1, sausage_coating + delta * 1.4)
	previous_sausage = sausage

func cooked_faces() -> int:
	var count := 0
	for heat in potato_heat:
		if heat >= 0.999: count += 1
	return count

func success() -> bool:
	if dish == "potato": return cooked_faces() == 6 and potato_state == "plate" and held != "potato"
	if dish == "sausage": return sausage_coating >= 0.90 and sausage_state == "plate" and held != "sausage"
	return super.success()

func goal_text() -> String:
	match dish:
		"potato": return "КАРТОШКА: %d / 6 сторон + тарелка" % cooked_faces()
		"sausage": return "СОСИСКА: соус %d%% + тарелка" % roundi(sausage_coating * 100)
	return "ВИНО: %d / 225 мл" % roundi(filled)

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
	data.tomato = {"position": [tomato.x, tomato.y], "velocity": [tomato_velocity.x, tomato_velocity.y, tomato_velocity.z], "flying": tomato_flying, "hit": tomato_hit, "reaction": customer_reaction}
	data.food = {"pan_tilt": [pan_tilt.x, pan_tilt.y], "potato": [potato.x, potato.y],
			"potato_velocity": [potato_velocity.x, potato_velocity.y], "potato_orientation": [potato_orientation.x, potato_orientation.y, potato_orientation.z, potato_orientation.w],
			"potato_heat": potato_heat.duplicate(), "potato_state": potato_state, "fall_speed": fall_speed, "falls": falls,
			"sausage": [sausage.x, sausage.y], "sausage_angle": sausage_angle, "sausage_phase": sausage_phase,
			"sausage_coating": sausage_coating, "sausage_slip": sausage_slip, "sausage_state": sausage_state,
			"sausage_velocity": [sausage_velocity.x, sausage_velocity.y]}
	return data

func restore(data: Dictionary) -> void:
	super.restore(data)
	dish = str(data.get("dish", "wine"))
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
	previous_sausage = sausage

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
