extends RefCounted
## The bounded workstation's liquid rules. Positions use tabletop-local X/Z.
## This model is shared by live input and tests; replay uses recorded snapshots.

const Layout = preload("res://scripts/counter_layout.gd")
const Pourable = preload("res://scripts/pourable.gd")
const CUP_CAPACITY := 300.0
const TARGET := 225.0
const JUG_CAPACITY := 1000.0
const RAG_CAPACITY := 300.0
const CUP_RADIUS := 0.24
const BOUNDS := Vector2(3.35, 2.65) * 1.5
const SERVE := Layout.TRAY
const SURFACE_Y := 1.0
const BASE_Y := 1.015
const MAX_LIFT := 1.10

var vessels := {"jug": Pourable.new(0.40, 0.78, 1050.0), "cup": Pourable.new(0.24, 0.50, 500.0)}
var source := "jug"
var jug := Vector2(-1.05, -0.1)
var cup := Vector2(0.50, 0.18)
var rag := Vector2(1.22, 0.40)
var tilt := 0.0
var wine := JUG_CAPACITY
var filled := 0.0
var soaked := 0.0
var lost := 0.0
var squeezed_total := 0.0
var puddles: Array = []
var held := ""
var flowing := false
var squeezing := false
var landing := Vector2.ZERO
var elevations := {"jug": 0.0, "cup": 0.0, "rag": 0.0}
var presentation := {"book": false, "page": "index", "bell": 0}
var actor_position := Vector3(0, 0, 1.8)
var actor_yaw := 0.0
var actor_pitch := 0.0

func reset() -> void:
	jug = Vector2(-1.05, -0.1)
	cup = Vector2(0.50, 0.18)
	rag = Vector2(1.22, 0.40)
	tilt = 0.0
	for vessel in vessels.values(): vessel.angle = 0.0
	vessels.jug.pivot_height = 0.48
	source = "jug"
	wine = JUG_CAPACITY
	filled = 0.0
	soaked = 0.0
	lost = 0.0
	squeezed_total = 0.0
	puddles.clear()
	held = ""
	flowing = false
	squeezing = false
	landing = Vector2.ZERO
	elevations = {"jug": 0.0, "cup": 0.0, "rag": 0.0}
	presentation = {"book": false, "page": "index", "bell": 0}
	actor_position = Vector3(0, 0, 1.8)
	actor_yaw = 0.0
	actor_pitch = 0.0

func pick_up(item: String) -> void:
	put_down()
	held = item
	elevations[item] = maxf(float(elevations[item]), support_at(get(item), BASE_Y + float(elevations[item])) - BASE_Y) + 0.12

func put_down() -> void:
	if held.is_empty(): return
	elevations[held] = support_at(get(held), BASE_Y + float(elevations[held])) - BASE_Y
	if held in vessels: vessels[held].angle = 0.0
	held = ""
	tilt = 0.0
	flowing = false
	squeezing = false

func lift_held(amount: float) -> void:
	if held.is_empty(): return
	var floor_limit := support_at(get(held), BASE_Y + float(elevations[held])) - BASE_Y
	elevations[held] = clampf(float(elevations[held]) + amount, floor_limit, MAX_LIFT)

static func surface_at(point: Vector2) -> float:
	return Layout.support(point)

static func support_at(point: Vector2, height: float) -> float:
	return Layout.support(point, height)

func vessel_base(item: String) -> Vector3:
	var point: Vector2 = get(item)
	return Vector3(point.x, BASE_Y + float(elevations[item]), point.y)

func receiver_at(point: Vector2, height: float) -> String:
	for item in ["cup", "jug"]:
		if item == source and flowing: continue
		if item == held: continue
		var base := vessel_base(item)
		if point.distance_to(get(item)) <= vessels[item].radius and height >= base.y + vessels[item].rim_height and vessels[item].angle < 15: return item
	return ""

func minimum_jug_lift() -> float:
	var angle := deg_to_rad(tilt)
	return maxf(0.0, 0.46 * sin(angle) + 0.40 * absf(cos(angle)) - 0.48)

func spout_position() -> Vector3:
	return vessels[source].mouth(vessel_base(source))

func source_height() -> float:
	return BASE_Y + float(elevations.rag) + 0.04 if held == "rag" else spout_position().y

func can_fill_at(point: Vector2, height: float) -> bool:
	return receiver_at(point, height) == "cup"

func move_item(item: String, point: Vector2) -> void:
	point = point.clamp(-BOUNDS, BOUNDS)
	match item:
		"jug": jug = point
		"cup": cup = point
		"rag": rag = point
	if item in elevations: elevations[item] = maxf(float(elevations[item]), support_at(point, BASE_Y + float(elevations[item])) - BASE_Y)

func spout_target() -> Vector2:
	return vessels[source].landing(vessel_base(source), support_at(get(source), spout_position().y))

func step(delta: float, tip: bool, _straighten: bool, squeeze: bool) -> void:
	for item in vessels: vessels[item].advance(delta, tip and held == item)
	if held in vessels: source = held
	tilt = vessels.jug.angle
	flowing = held in vessels and vessels[held].rate() > 0 and (wine if held == "jug" else filled) > 0
	squeezing = held == "rag" and squeeze and soaked > 0
	if flowing:
		landing = spout_target()
		var amount: float = vessels[held].take(wine if held == "jug" else filled, delta)
		if held == "jug": wine -= amount
		else: filled -= amount
		_deliver(landing, amount, spout_position().y)
	if held == "rag":
		if squeezing:
			landing = rag
			var amount := minf(soaked, 110.0 * delta)
			soaked -= amount
			squeezed_total += amount
			_deliver(rag, amount, source_height())
		elif BASE_Y + float(elevations.rag) <= support_at(rag, BASE_Y + float(elevations.rag)) + 0.10:
			_absorb(delta)

func _deliver(point: Vector2, amount: float, height: float) -> void:
	var receiver := receiver_at(point, height)
	if not receiver.is_empty():
		var accepted := Pourable.accepted(amount, filled if receiver == "cup" else wine, CUP_CAPACITY if receiver == "cup" else JUG_CAPACITY)
		if receiver == "cup": filled += accepted
		else: wine += accepted
		amount -= accepted
	if amount <= 0.0001: return
	# Floor spills remain recoverable; the station boundary retains every drop.
	point = point.clamp(-BOUNDS, BOUNDS)
	var cell := (point / 0.15).round() * 0.15
	for puddle in puddles:
		if Vector2(puddle[0], puddle[1]).distance_to(cell) < 0.05:
			puddle[2] += amount
			return
	puddles.append([cell.x, cell.y, amount])

func _absorb(delta: float) -> void:
	var budget := minf(160.0 * delta, RAG_CAPACITY - soaked)
	for index in range(puddles.size() - 1, -1, -1):
		var puddle: Array = puddles[index]
		if rag.distance_to(Vector2(puddle[0], puddle[1])) > 0.42 or absf(surface_at(rag) - surface_at(Vector2(puddle[0], puddle[1]))) > 0.1:
			continue
		var amount := minf(float(puddle[2]), budget)
		puddle[2] -= amount
		soaked += amount
		budget -= amount
		if puddle[2] < 0.001:
			puddles.remove_at(index)

func success() -> bool:
	return filled >= 200 and filled <= 250 and spilled() + lost + soaked <= 5 and cup.distance_to(SERVE) < 0.4 and held != "cup"

func spilled() -> float:
	var total := 0.0
	for puddle in puddles:
		total += float(puddle[2])
	return total

func snapshot() -> Dictionary:
	return {"presentation": presentation.duplicate(), "vessel_angles": {"jug": vessels.jug.angle, "cup": vessels.cup.angle}, "source": source, "jug": [jug.x, jug.y], "cup": [cup.x, cup.y], "rag": [rag.x, rag.y],
		"tilt": tilt, "wine": wine, "filled": filled, "soaked": soaked,
		"lost": lost, "squeezed_total": squeezed_total,
		"puddles": puddles.duplicate(true), "held": held,
		"flowing": flowing, "squeezing": squeezing,
		"landing": [landing.x, landing.y], "elevations": elevations.duplicate(),
		"actor_position": [actor_position.x, actor_position.y, actor_position.z],
		"actor_yaw": actor_yaw, "actor_pitch": actor_pitch}

func restore(data: Dictionary) -> void:
	presentation = preload("res://scripts/cookbook_data.gd").presentation(data.get("presentation", {}))
	for item in vessels: vessels[item].angle = float(data.vessel_angles[item])
	source = data.source
	jug = Vector2(data.jug[0], data.jug[1])
	cup = Vector2(data.cup[0], data.cup[1])
	rag = Vector2(data.rag[0], data.rag[1])
	tilt = float(data.tilt)
	wine = float(data.wine)
	filled = float(data.filled)
	soaked = float(data.soaked)
	lost = float(data.lost)
	squeezed_total = float(data.squeezed_total)
	puddles = data.puddles.duplicate(true)
	held = str(data.held)
	flowing = bool(data.flowing)
	squeezing = bool(data.squeezing)
	landing = Vector2(data.landing[0], data.landing[1])
	elevations = data.elevations.duplicate()
	actor_position = Vector3(data.actor_position[0], data.actor_position[1], data.actor_position[2])
	actor_yaw = float(data.actor_yaw)
	actor_pitch = float(data.actor_pitch)
