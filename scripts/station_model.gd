extends RefCounted
## The bounded workstation's liquid rules. Positions use tabletop-local X/Z.
## This model is shared by live input and tests; replay uses recorded snapshots.

const CUP_CAPACITY := 250.0
const TARGET := 225.0
const JUG_CAPACITY := 1000.0
const RAG_CAPACITY := 300.0
const CUP_RADIUS := 0.24
const BOUNDS := Vector2(1.75, 0.8)

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

func move_item(item: String, point: Vector2) -> void:
	point = point.clamp(-BOUNDS, BOUNDS)
	match item:
		"jug": jug = point
		"cup": cup = point
		"rag": rag = point

func spout_target() -> Vector2:
	return jug + Vector2(0.23 + tilt * 0.005, 0.0)

func step(delta: float, tip: bool, straighten: bool, squeeze: bool) -> void:
	if tip:
		tilt = minf(tilt + 45.0 * delta, 95.0)
	elif straighten or held != "jug":
		tilt = maxf(tilt - 95.0 * delta, 0.0)
	flowing = tilt > 28.0 and wine > 0.0
	squeezing = held == "rag" and squeeze and soaked > 0.0
	if flowing:
		landing = spout_target()
		var amount := minf(wine, (tilt - 28.0) * 2.2 * delta)
		wine -= amount
		_deliver(landing, amount)
	if held == "rag":
		if squeezing:
			landing = rag
			var amount := minf(soaked, 110.0 * delta)
			soaked -= amount
			squeezed_total += amount
			_deliver(rag, amount)
		else:
			_absorb(delta)

func _deliver(point: Vector2, amount: float) -> void:
	if point.distance_to(cup) <= CUP_RADIUS:
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

static func pace(seconds: float) -> String:
	if seconds < 15.0:
		return "Fast"
	if seconds <= 60.0:
		return "Medium"
	return "Slow"

static func efficiency(seconds: float) -> float:
	match pace(seconds):
		"Fast": return 1.1
		"Slow": return 0.9
	return 1.0

func snapshot() -> Dictionary:
	return {"jug": [jug.x, jug.y], "cup": [cup.x, cup.y], "rag": [rag.x, rag.y],
		"tilt": tilt, "wine": wine, "filled": filled, "soaked": soaked,
		"lost": lost, "squeezed_total": squeezed_total,
		"puddles": puddles.duplicate(true), "held": held,
		"flowing": flowing, "squeezing": squeezing,
		"landing": [landing.x, landing.y]}

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
