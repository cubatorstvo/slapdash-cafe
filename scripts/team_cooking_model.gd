extends RefCounted
## Two commands act on one shared kitchen. Completed orders replay joint snapshots.
const Pourable = preload("res://scripts/pourable.gd")
const Quality = preload("res://scripts/dish_quality.gd")
const BOUNDS := Vector2(3.05, 2.65)
const BASE_Y := 1.015
const GRILL := Vector2(-1.4, -0.15)
const STOVE := Vector2(1.4, -0.15)
const PLATE := Vector2(-0.5, 0.65)
const PASTA_PLATE := Vector2(0.5, 0.65)
const ITEMS := ["steak", "pot", "water", "pasta_bag", "salt", "spatula", "pasta_salt_tool", "pasta_spatula"]
const NAMES := {"steak": "стейк", "pot": "кастрюля", "water": "кувшин воды", "pasta_bag": "мешок макарон", "salt": "солонка", "spatula": "лопатка для мяса", "pasta_salt_tool": "соль для макарон", "pasta_spatula": "лопатка для макарон"}
const ZONE_ITEMS := [["steak", "salt", "spatula"], ["pot", "water", "pasta_bag", "pasta_salt_tool", "pasta_spatula"]]
const ZONE_VALUES := [["meat_sides", "meat_face", "meat_state", "meat_salt", "flip_time"], ["water", "pasta", "bag", "temperature", "cooked", "stirred", "pasta_salt", "served_pasta", "served_cooked", "served_stirred", "served_salt", "pitcher_water", "water_angle", "pot_angle", "spills"]]
var vessels := {"water": Pourable.new(0.23, 0.44, 700.0), "pot": Pourable.new(0.36, 0.36, 900.0)}
var water_angle := 0.0
var pot_angle := 0.0
var pitcher_water := 1600.0
var served_cooked := 0.0
var served_stirred := 0.0
var served_salt := 0.0
var spills: Array = []
var live_roles: Array = [0, 1]
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
	positions = {"steak": Vector2(-2.25, 0.45), "pot": STOVE, "water": Vector2(2.3, 0.45), "pasta_bag": Vector2(2.25, -0.55), "salt": Vector2(-0.48, -0.48), "spatula": Vector2(-0.45, 0.02), "pasta_salt_tool": Vector2(0.48, -0.48), "pasta_spatula": Vector2(0.45, 0.02)}
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
	served_cooked = 0
	served_stirred = 0
	served_salt = 0
	pitcher_water = 1600
	water_angle = 0
	pot_angle = 0
	spills.clear()
	for vessel in vessels.values(): vessel.angle = 0
	conflicts = []
	pouring = [false, false]
	elapsed = 0

static func default_pose(role: int) -> Dictionary:
	return {"position": [-1.35 if role == 0 else 1.35, 0.0, 1.85], "yaw": 0.0, "pitch": -0.2}

func grab(role: int, item: String) -> bool:
	if not item in ITEMS or not hands[role].is_empty() or not can_touch(role, item): return false
	if owners[item] != -1:
		conflicts.append("Роль %d: %s занята другим участником" % [role + 1, NAMES[item]])
		return false
	owners[item] = role
	hands[role] = item
	heights[item] = maxf(float(heights[item]), surface_at(positions[item]) - BASE_Y) + 0.12
	if item == "steak": meat_state = "held"
	return true

func drop(role: int) -> void:
	var item: String = hands[role]
	if item.is_empty(): return
	owners[item] = -1
	heights[item] = surface_at(positions[item]) - BASE_Y
	if item in vessels: vessels[item].angle = 0.0
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
				if live_roles.size() == 1: target.x = clampf(target.x, -BOUNDS.x if role == 0 else 0.12, -0.12 if role == 0 else BOUNDS.x)
				positions[item] = positions[item].move_toward(target, delta * 5.0)
			if command.has("height"): heights[item] = clampf(float(command.height), surface_at(positions[item]) - BASE_Y, 1.1)
			heights[item] = maxf(float(heights[item]), surface_at(positions[item]) - BASE_Y)
			if item in vessels:
				vessels[item].advance(delta, use_item)
				_pour(role, item, delta)
			if use_item: _use(role, item, not using[role], delta)
		using[role] = use_item
	water_angle = vessels.water.angle
	pot_angle = vessels.pot.angle
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
		"pasta_bag":
			pouring[role] = bag > 0
			if over_pot and above_pot:
				var amount := minf(bag, delta * 50)
				bag -= amount
				pasta += amount
		"salt", "pasta_salt_tool":
			pouring[role] = true
			if point.distance_to(positions.steak) < 0.40 and heights[item] > float(heights.steak) + 0.18: meat_salt = minf(9, meat_salt + delta * 2)
			if over_pot and above_pot: pasta_salt = minf(9, pasta_salt + delta * 2)
			elif point.distance_to(PASTA_PLATE) < 0.45 and served_pasta > 0 and heights[item] > 0.20: served_salt = minf(9, served_salt + delta * 2)
		"spatula", "pasta_spatula":
			if over_pot and heights[item] < float(heights.pot) + 0.65:
				if pasta > 0 and water > 0: stirred = minf(1, stirred + delta / 2.0)
			elif pressed and meat_state == "grill" and point.distance_to(positions.steak) < 0.48 and heights[item] < 0.60:
				meat_face = 1 - meat_face
				flip_time = 0.35

func success() -> bool: return quality().grade == "S"

func quality() -> Dictionary:
	var meat_on := meat_state == "plate" and hands.find("steak") < 0
	var pasta_on := served_pasta > 0
	var sides := (float(meat_sides[0]) + float(meat_sides[1])) / 2 if meat_on else 0.0
	return Quality.result([
		{"label": "Мясо: %s · стороны %.0f%% / %.0f%%" % ["на подаче" if meat_on else "нет", float(meat_sides[0]) * 100 if meat_on else 0, float(meat_sides[1]) * 100 if meat_on else 0], "value": sides},
		{"label": "Соль мяса ≥1 г: " + ("✓" if meat_on and meat_salt >= 1 else "×"), "value": minf(1, meat_salt) if meat_on else 0},
		{"label": "Макароны: %.0f / 100 г" % served_pasta, "value": minf(1, served_pasta / 100)},
		{"label": "Порция сварена: %.0f%%" % (served_cooked * 100), "value": served_cooked if pasta_on else 0},
		{"label": "Порция перемешана: %.0f%%" % (served_stirred * 100), "value": served_stirred if pasta_on else 0},
		{"label": "Соль макарон ≥1 г: " + ("✓" if pasta_on and served_salt >= 1 else "×"), "value": minf(1, served_salt) if pasta_on else 0}
	], meat_on or pasta_on, ["Стейк: 2 стороны 100% · соль ≥1 г", "Макароны: ≥100 г · сварить · перемешать", "Варить в ≥500 мл воды · соль ≥1 г", "В работе мясо: %.0f%% / %.0f%%" % [float(meat_sides[0]) * 100, float(meat_sides[1]) * 100], "Кастрюля: %.0f мл · %.0f г · варка %.0f%%" % [water, pasta, cooked * 100]])

static func surface_at(point: Vector2) -> float:
	return BASE_Y if absf(point.x) <= 3.05 and absf(point.y) <= 1.125 else 0.015

func mouth(item: String) -> Vector3:
	return vessels[item].mouth(Vector3(positions[item].x, BASE_Y + heights[item], positions[item].y))

func pour_target(item: String) -> Vector2:
	return vessels[item].landing(Vector3(positions[item].x, BASE_Y + heights[item], positions[item].y), surface_at(positions[item]))

func _spill(point: Vector2, amount: float) -> void:
	if amount <= 0.001: return
	var cell := (point.clamp(-BOUNDS, BOUNDS) / 0.2).round() * 0.2
	for entry in spills:
		if Vector2(entry[0], entry[1]).distance_to(cell) < 0.05: entry[2] += amount; return
	spills.append([cell.x, cell.y, amount])

func _pour(role: int, item: String, delta: float) -> void:
	var volume := pitcher_water if item == "water" else water + pasta
	var amount: float = vessels[item].take(volume, delta)
	pouring[role] = amount > 0
	if amount <= 0: return
	var target := pour_target(item)
	var start := mouth(item)
	if item == "water":
		pitcher_water -= amount
		if target.distance_to(positions.pot) < 0.34 and start.y > BASE_Y + heights.pot + 0.36 and vessels.pot.angle < 15:
			var received := Pourable.accepted(amount, water, 800)
			water += received
			amount -= received
		_spill(target, amount)
	else:
		var fraction := amount / maxf(0.001, volume)
		var food := pasta * fraction
		var liquid := water * fraction
		var salt_amount := pasta_salt * fraction
		pasta -= food
		water -= liquid
		pasta_salt -= salt_amount
		if target.distance_to(PASTA_PLATE) < 0.44 and start.y > BASE_Y + 0.04:
			var total := served_pasta + food
			if total > 0:
				served_cooked = (served_cooked * served_pasta + cooked * food) / total
				served_stirred = (served_stirred * served_pasta + stirred * food) / total
			served_pasta = total
			served_salt += salt_amount
			# Pasta stays on the plate; poured cooking water spills around it.
			_spill(target, liquid)
		elif target.distance_to(positions.water) < 0.23 and start.y > BASE_Y + heights.water + 0.44 and vessels.water.angle < 15:
			var received := Pourable.accepted(liquid, pitcher_water, 1600)
			pitcher_water += received
			_spill(target, amount - received)
		else: _spill(target, amount)

func snapshot() -> Dictionary:
	var points := {}
	for item in ITEMS: points[item] = [positions[item].x, positions[item].y]
	return {"served_cooked": served_cooked, "served_stirred": served_stirred, "served_salt": served_salt, "pitcher_water": pitcher_water, "water_angle": water_angle, "pot_angle": pot_angle, "spills": spills.duplicate(true), "layout": "meal-table", "positions": points, "heights": heights.duplicate(), "owners": owners.duplicate(), "hands": hands.duplicate(), "poses": poses.duplicate(true), "using": using.duplicate(),
		"meat_sides": meat_sides.duplicate(), "meat_face": meat_face, "meat_state": meat_state, "meat_salt": meat_salt, "flip_time": flip_time,
		"water": water, "pasta": pasta, "bag": bag, "temperature": temperature, "cooked": cooked, "stirred": stirred, "pasta_salt": pasta_salt, "served_pasta": served_pasta, "pouring": pouring.duplicate(), "elapsed": elapsed}

func restore(data: Dictionary) -> void:
	for item in ITEMS: positions[item] = Vector2(data.positions[item][0], data.positions[item][1])
	for key in ["heights", "owners", "hands", "poses", "using", "meat_sides", "pouring"]: set(key, data[key].duplicate(true))
	for key in ["meat_face", "meat_state", "meat_salt", "flip_time", "water", "pasta", "bag", "temperature", "cooked", "stirred", "pasta_salt", "served_pasta", "elapsed", "served_cooked", "served_stirred", "served_salt", "pitcher_water", "water_angle", "pot_angle", "spills"]: set(key, data[key])
	vessels.water.angle = water_angle
	vessels.pot.angle = pot_angle

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("layout") != "meal-table": return false
	for key in ["positions", "heights", "owners"]:
		if not data.get(key) is Dictionary: return false
	for item in ITEMS:
		var point = data.positions.get(item)
		if not numbers(point, 2) or not finite(data.heights.get(item)) or not finite(data.owners.get(item)) or data.owners[item] != int(data.owners[item]) or not int(data.owners[item]) in [-1, 0, 1]: return false
		if data.heights[item] < -1 or data.heights[item] > 1.1: return false
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

func can_touch(role: int, item: String) -> bool:
	if not role in live_roles: return false
	for zone in range(ZONE_ITEMS.size()):
		if item in ZONE_ITEMS[zone]: return zone in live_roles
	return false

func zone_snapshot(role: int) -> Dictionary:
	var data := snapshot()
	var result := {"positions": {}, "heights": {}, "owners": {}, "hand": hands[role], "pose": poses[role].duplicate(true), "using": using[role], "pouring": pouring[role]}
	for item in ZONE_ITEMS[role]:
		for key in ["positions", "heights", "owners"]: result[key][item] = data[key][item]
	for key in ZONE_VALUES[role]: result[key] = data[key]
	return result.duplicate(true)

func restore_zone(role: int, data: Dictionary) -> void:
	for item in ZONE_ITEMS[role]:
		positions[item] = Vector2(data.positions[item][0], data.positions[item][1])
		heights[item] = data.heights[item]
		owners[item] = int(data.owners[item])
	hands[role] = data.hand
	poses[role] = data.pose.duplicate(true)
	using[role] = data.using
	pouring[role] = data.pouring
	for key in ZONE_VALUES[role]: set(key, data[key].duplicate(true) if data[key] is Array else data[key])
	vessels.water.angle = water_angle
	vessels.pot.angle = pot_angle
