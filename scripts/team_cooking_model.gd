extends RefCounted
## Two commands act on one shared kitchen. Completed orders replay joint snapshots.
const BOUNDS := Vector2(2.75, 0.90)
const BASE_Y := 1.015
const GRILL := Vector2(-1.4, -0.15)
const STOVE := Vector2(1.4, -0.15)
const PLATE := Vector2(0, 0.65)
const ITEMS := ["steak", "pot", "water", "pasta_bag", "salt", "spatula"]
const NAMES := {"steak": "стейк", "pot": "кастрюля", "water": "кувшин воды", "pasta_bag": "мешок макарон", "salt": "солонка", "spatula": "лопатка"}
var positions: Dictionary
var heights: Dictionary
var owners: Dictionary
var hands: Array
var poses: Array
var using: Array
var meat_sides: Array
var meat_face := 0
var meat_state := "raw"
var meat_salt := 0.0
var flip_time := 0.0
var water := 0.0
var pasta := 0.0
var bag := 300.0
var temperature := 20.0
var cooked := 0.0
var stirred := 0.0
var pasta_salt := 0.0
var served_pasta := 0.0
var conflicts: Array = []
var pouring := [false, false]
var elapsed := 0.0

func _init() -> void: reset()

func reset() -> void:
	positions = {"steak": Vector2(-2.25, 0.45), "pot": STOVE, "water": Vector2(2.3, 0.45), "pasta_bag": Vector2(2.25, -0.55), "salt": Vector2(0, -0.48), "spatula": Vector2(0, 0.02)}
	heights = {}
	owners = {}
	for item in ITEMS:
		heights[item] = 0.0
		owners[item] = -1
	hands = ["", ""]
	poses = [default_pose(0), default_pose(1)]
	using = [false, false]
	meat_sides = [0.0, 0.0]
	meat_face = 0
	meat_state = "raw"
	meat_salt = 0
	flip_time = 0
	water = 0
	pasta = 0
	bag = 300
	temperature = 20
	cooked = 0
	stirred = 0
	pasta_salt = 0
	served_pasta = 0
	conflicts = []
	pouring = [false, false]
	elapsed = 0

static func default_pose(role: int) -> Dictionary:
	return {"position": [-1.35 if role == 0 else 1.35, 0.0, 1.85], "yaw": 0.0, "pitch": -0.2}

func grab(role: int, item: String) -> bool:
	if not item in ITEMS or not hands[role].is_empty(): return false
	if owners[item] != -1:
		conflicts.append("Роль %d: %s занята другим участником" % [role + 1, NAMES[item]])
		return false
	owners[item] = role
	hands[role] = item
	heights[item] = 0.50 if item in ["water", "pasta_bag", "salt"] else 0.30
	if item == "steak": meat_state = "held"
	return true

func drop(role: int) -> void:
	var item: String = hands[role]
	if item.is_empty(): return
	owners[item] = -1
	heights[item] = 0.0
	hands[role] = ""
	using[role] = false
	if item == "steak":
		if positions.steak.distance_to(GRILL) < 0.65: meat_state = "grill"
		elif positions.steak.distance_to(PLATE) < 0.48: meat_state = "plate"
		else: meat_state = "raw"

func step(commands: Array, delta: float) -> void:
	conflicts.clear()
	pouring = [false, false]
	for role in range(2):
		var command: Dictionary = commands[role] if role < commands.size() else {}
		if command.has("pose"): poses[role] = command.pose.duplicate(true)
		if command.get("drop", false): drop(role)
		var item_to_grab: String = str(command.get("grab", ""))
		if not item_to_grab.is_empty(): grab(role, item_to_grab)
		var item: String = hands[role]
		var use_item: bool = command.get("use", false)
		if not item.is_empty():
			if command.has("target"):
				var target := Vector2(command.target[0], command.target[1]).clamp(-BOUNDS, BOUNDS)
				positions[item] = positions[item].move_toward(target, delta * 5.0)
			if command.has("height"): heights[item] = clampf(float(command.height), 0, 1.1)
			if use_item: _use(role, item, not using[role], delta)
		using[role] = use_item
	if meat_state == "grill" and hands.find("steak") < 0:
		meat_sides[meat_face] = minf(1, float(meat_sides[meat_face]) + delta / 6.0)
	if positions.pot.distance_to(STOVE) < 0.45 and heights.pot < 0.10 and water > 0:
		temperature = minf(100, temperature + delta * 22)
		if water >= 500 and pasta >= 100 and temperature >= 99:
			cooked = minf(1, cooked + delta / 12.0)
	else: temperature = maxf(20, temperature - delta * 2)
	flip_time = maxf(0, flip_time - delta)
	elapsed += delta

func _use(role: int, item: String, pressed: bool, delta: float) -> void:
	var point: Vector2 = positions[item]
	var over_pot := point.distance_to(positions.pot) < 0.48
	var above_pot: bool = heights[item] >= float(heights.pot) + 0.44
	match item:
		"water":
			pouring[role] = true
			if over_pot and above_pot: water = minf(800, water + delta * 200)
		"pasta_bag":
			pouring[role] = bag > 0
			if over_pot and above_pot:
				var amount := minf(bag, delta * 50)
				bag -= amount
				pasta += amount
		"salt":
			pouring[role] = true
			if point.distance_to(positions.steak) < 0.40 and heights.salt > float(heights.steak) + 0.18: meat_salt = minf(9, meat_salt + delta * 2)
			if over_pot and above_pot: pasta_salt = minf(9, pasta_salt + delta * 2)
			elif point.distance_to(PLATE) < 0.45 and served_pasta > 0 and heights.salt > 0.20: pasta_salt = minf(9, pasta_salt + delta * 2)
		"spatula":
			if over_pot and heights.spatula < float(heights.pot) + 0.65:
				if pasta > 0 and water > 0: stirred = minf(1, stirred + delta / 2.0)
			elif pressed and meat_state == "grill" and point.distance_to(positions.steak) < 0.48 and heights.spatula < 0.60:
				meat_face = 1 - meat_face
				flip_time = 0.35
		"pot":
			if point.distance_to(PLATE) < 0.55 and heights.pot > 0.2 and cooked >= 0.999 and stirred >= 0.999:
				pouring[role] = true
				var amount := minf(pasta, delta * 160)
				pasta -= amount
				served_pasta += amount

func success() -> bool:
	return meat_state == "plate" and float(meat_sides[0]) >= 0.999 and float(meat_sides[1]) >= 0.999 and meat_salt >= 1 and served_pasta >= 99.9 and pasta_salt >= 1 and cooked >= 0.999 and stirred >= 0.999

static func pace(seconds: float) -> String:
	return "Fast" if seconds < 15 else ("Medium" if seconds <= 60 else "Slow")

func snapshot() -> Dictionary:
	var points := {}
	for item in ITEMS: points[item] = [positions[item].x, positions[item].y]
	return {"layout": "meal-table", "positions": points, "heights": heights.duplicate(), "owners": owners.duplicate(), "hands": hands.duplicate(), "poses": poses.duplicate(true), "using": using.duplicate(),
		"meat_sides": meat_sides.duplicate(), "meat_face": meat_face, "meat_state": meat_state, "meat_salt": meat_salt, "flip_time": flip_time,
		"water": water, "pasta": pasta, "bag": bag, "temperature": temperature, "cooked": cooked, "stirred": stirred, "pasta_salt": pasta_salt, "served_pasta": served_pasta, "pouring": pouring.duplicate(), "elapsed": elapsed}

func restore(data: Dictionary) -> void:
	for item in ITEMS: positions[item] = Vector2(data.positions[item][0], data.positions[item][1])
	for key in ["heights", "owners", "hands", "poses", "using", "meat_sides", "pouring"]: set(key, data[key].duplicate(true))
	for key in ["meat_face", "meat_state", "meat_salt", "flip_time", "water", "pasta", "bag", "temperature", "cooked", "stirred", "pasta_salt", "served_pasta", "elapsed"]: set(key, data[key])

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("layout") != "meal-table": return false
	for key in ["positions", "heights", "owners"]:
		if not data.get(key) is Dictionary: return false
	for item in ITEMS:
		var point = data.positions.get(item)
		if not numbers(point, 2) or not finite(data.heights.get(item)) or not finite(data.owners.get(item)) or data.owners[item] != int(data.owners[item]) or not int(data.owners[item]) in [-1, 0, 1]: return false
		if data.heights[item] < 0 or data.heights[item] > 1.1: return false
	for key in ["hands", "poses", "using", "pouring"]:
		if not data.get(key) is Array or data[key].size() != 2: return false
	for role in range(2):
		if not data.hands[role] in ITEMS + [""] or not valid_pose(data.poses[role]): return false
		if not data.using[role] is bool or not data.pouring[role] is bool: return false
		if not data.hands[role].is_empty() and data.owners[data.hands[role]] != role: return false
	if not numbers(data.get("meat_sides"), 2) or not finite(data.get("meat_face")) or data.meat_face != int(data.meat_face) or not int(data.meat_face) in [0, 1] or not data.get("meat_state") in ["raw", "held", "grill", "plate"]: return false
	for key in ["meat_salt", "flip_time", "water", "pasta", "bag", "temperature", "cooked", "stirred", "pasta_salt", "served_pasta", "elapsed"]:
		if not finite(data.get(key)): return false
	return true

static func valid_pose(data: Variant) -> bool:
	return data is Dictionary and numbers(data.get("position"), 3) and finite(data.get("yaw")) and finite(data.get("pitch"))

static func numbers(data: Variant, count: int) -> bool:
	if not data is Array or data.size() != count: return false
	for value in data:
		if not finite(value): return false
	return true

static func finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
