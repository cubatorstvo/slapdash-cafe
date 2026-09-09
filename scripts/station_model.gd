extends RefCounted
## The bounded workstation's liquid rules. Positions use tabletop-local X/Z.
## This model is shared by live input and tests; replay uses recorded snapshots.

const CUP_CAPACITY := 250.0
const TARGET := 225.0
const JUG_CAPACITY := 1000.0
const RAG_CAPACITY := 300.0
const CUP_RADIUS := 0.24
const BOUNDS := Vector2(2.05, 0.85)
const SURFACE_Y := 1.0
const BASE_Y := 1.015
const MAX_LIFT := 1.10

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
var actor_position := Vector3(0, 0, 1.8)
var actor_yaw := 0.0
var actor_pitch := 0.0

func reset() -> void:
	jug = Vector2(-1.05, -0.1)
	cup = Vector2(0.50, 0.18)
	rag = Vector2(1.22, 0.40)
	tilt = 0.0
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
	actor_position = Vector3(0, 0, 1.8)
	actor_yaw = 0.0
	actor_pitch = 0.0

func pick_up(item: String) -> void:
	put_down()
	held = item
	elevations[item] = 0.50 if item == "jug" else 0.04

func put_down() -> void:
	if held.is_empty(): return
	elevations[held] = 0.0
	held = ""
	tilt = 0.0
	flowing = false
	squeezing = false

func lift_held(amount: float) -> void:
	if held.is_empty(): return
	var floor_limit := minimum_jug_lift() if held == "jug" else 0.0
	elevations[held] = clampf(float(elevations[held]) + amount, floor_limit, MAX_LIFT)

func minimum_jug_lift() -> float:
	var angle := deg_to_rad(tilt)
	return maxf(0.0, 0.46 * sin(angle) + 0.40 * absf(cos(angle)) - 0.48)

func spout_position() -> Vector3:
	var angle := deg_to_rad(tilt)
	return Vector3(jug.x + 0.40 * cos(angle) + 0.30 * sin(angle),
		BASE_Y + float(elevations.jug) + 0.48 - 0.40 * sin(angle) + 0.30 * cos(angle), jug.y)

func source_height() -> float:
	return BASE_Y + float(elevations.rag) + 0.04 if held == "rag" else spout_position().y

func can_fill_at(point: Vector2, height: float) -> bool:
	return point.distance_to(cup) <= CUP_RADIUS and height >= BASE_Y + float(elevations.cup) + 0.50

func move_item(item: String, point: Vector2) -> void:
	point = point.clamp(-BOUNDS, BOUNDS)
	match item:
		"jug": jug = point
		"cup": cup = point
		"rag": rag = point

func spout_target() -> Vector2:
	var mouth := spout_position()
	return Vector2(mouth.x, mouth.z)

func step(delta: float, tip: bool, straighten: bool, squeeze: bool) -> void:
	if tip:
		tilt = minf(tilt + 45.0 * delta, 95.0)
	elif straighten or held != "jug":
		tilt = maxf(tilt - 95.0 * delta, 0.0)
	elevations.jug = maxf(float(elevations.jug), minimum_jug_lift())
	flowing = tilt > 28.0 and wine > 0.0
	squeezing = held == "rag" and squeeze and soaked > 0.0
	if flowing:
		landing = spout_target()
		var amount := minf(wine, (tilt - 28.0) * 2.2 * delta)
		wine -= amount
		_deliver(landing, amount, spout_position().y)
	if held == "rag":
		if squeezing:
			landing = rag
			var amount := minf(soaked, 110.0 * delta)
			soaked -= amount
			squeezed_total += amount
			_deliver(rag, amount, source_height())
		elif float(elevations.rag) <= 0.10:
			_absorb(delta)

func _deliver(point: Vector2, amount: float, height: float) -> void:
	if can_fill_at(point, height):
		var accepted := minf(amount, CUP_CAPACITY - filled)
		filled += accepted
		amount -= accepted
	if amount <= 0.0001:
		return
	if absf(point.x) > 2.0 or absf(point.y) > 1.03:
		lost += amount
		return
	# A bounded grid merges spills, keeping recordings small and wiping local.
	var cell := (point / 0.23).round() * 0.23
	for puddle in puddles:
		if Vector2(puddle[0], puddle[1]).distance_to(cell) < 0.05:
			puddle[2] += amount
			return
	puddles.append([cell.x, cell.y, amount])

func _absorb(delta: float) -> void:
	var budget := minf(160.0 * delta, RAG_CAPACITY - soaked)
	for index in range(puddles.size() - 1, -1, -1):
		var puddle: Array = puddles[index]
		if rag.distance_to(Vector2(puddle[0], puddle[1])) > 0.42:
			continue
		var amount := minf(float(puddle[2]), budget)
		puddle[2] -= amount
		soaked += amount
		budget -= amount
		if puddle[2] < 0.001:
			puddles.remove_at(index)

func success() -> bool:
	return filled >= TARGET - 0.001

func spilled() -> float:
	var total := 0.0
	for puddle in puddles:
		total += float(puddle[2])
	return total

func snapshot() -> Dictionary:
	return {"jug": [jug.x, jug.y], "cup": [cup.x, cup.y], "rag": [rag.x, rag.y],
		"tilt": tilt, "wine": wine, "filled": filled, "soaked": soaked,
		"lost": lost, "squeezed_total": squeezed_total,
		"puddles": puddles.duplicate(true), "held": held,
		"flowing": flowing, "squeezing": squeezing,
		"landing": [landing.x, landing.y], "elevations": elevations.duplicate(),
		"actor_position": [actor_position.x, actor_position.y, actor_position.z],
		"actor_yaw": actor_yaw, "actor_pitch": actor_pitch}

func restore(data: Dictionary) -> void:
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
