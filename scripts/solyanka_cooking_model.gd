extends RefCounted
## Three-role late kitchen: everyone throws ingredients (and optionally tools) into one shared cauldron.
const Quality = preload("res://scripts/dish_quality.gd")
const BOUNDS := Vector2(3.05, 2.70)
const BASE_Y := 1.015
const POT := Vector2(0.0, -0.10)
const GUEST_MOUTH := Vector3(0, 1.5, -1.61)
const MIN_CONTENTS := 13
const ITEMS := [
	"lighter", "potato", "onion", "tomato", "carrot", "garlic", "boot",
	"paddle", "cabbage", "cucumber", "beet", "pepper", "zucchini", "mug",
	"salt", "pickle", "lemon", "sausage", "mushroom", "eggplant", "bolt"
]
const NAMES := {
	"lighter":"зажигалка", "potato":"картошка", "onion":"лук", "tomato":"помидор", "carrot":"морковь", "garlic":"чеснок", "boot":"ботинок",
	"paddle":"лопатка-мешалка", "cabbage":"капуста", "cucumber":"огурец", "beet":"свёкла", "pepper":"перец", "zucchini":"кабачок", "mug":"кружка",
	"salt":"соль", "pickle":"солёный огурец", "lemon":"лимон", "sausage":"сосиска", "mushroom":"гриб", "eggplant":"баклажан", "bolt":"болт"
}
const ZONE_ITEMS := [
	["lighter", "potato", "onion", "tomato", "carrot", "garlic", "boot"],
	["paddle", "cabbage", "cucumber", "beet", "pepper", "zucchini", "mug"],
	["salt", "pickle", "lemon", "sausage", "mushroom", "eggplant", "bolt"]
]
const STRANGE_ITEMS := ["boot", "mug", "bolt", "lighter", "paddle"]
var equipment: Array = ["fire_kit", "stir_kit", "salt_kit"]
var dish := "solyanka"
var guest_active := false
var guest_roles: Array = []
var live_roles: Array = [0, 1, 2]
var positions: Dictionary
var heights: Dictionary
var owners: Dictionary
var dumped: Dictionary
var hands: Array
var poses: Array
var using: Array
var fire_started := false
var stir_progress := 0.0
var salt_amount := 0.0
var served := false
var elapsed := 0.0

func _init() -> void: reset()

func reset(recipe := "solyanka") -> void:
	dish = "solyanka" if str(recipe) != "solyanka" else str(recipe)
	guest_active = false
	guest_roles = []
	for _role in range(3): guest_roles.append({"drunk":0.0,"swallowed":[],"chew":0.0})
	positions = {
		"lighter":Vector2(-2.52,-0.72), "potato":Vector2(-2.56,0.10), "onion":Vector2(-2.08,0.10), "tomato":Vector2(-1.60,0.10), "carrot":Vector2(-2.10,0.72), "garlic":Vector2(-1.60,0.72), "boot":Vector2(-2.58,0.76),
		"paddle":Vector2(-0.34,-1.56), "cabbage":Vector2(-0.96,1.20), "cucumber":Vector2(-0.50,1.25), "beet":Vector2(0.0,1.25), "pepper":Vector2(0.50,1.25), "zucchini":Vector2(0.96,1.20), "mug":Vector2(0.42,-1.58),
		"salt":Vector2(2.52,-0.72), "pickle":Vector2(1.58,0.10), "lemon":Vector2(2.06,0.10), "sausage":Vector2(2.54,0.10), "mushroom":Vector2(2.10,0.72), "eggplant":Vector2(1.60,0.72), "bolt":Vector2(2.58,0.76)
	}
	heights = {}; owners = {}; dumped = {}
	for item in ITEMS:
		heights[item] = 0.0
		owners[item] = -1
		dumped[item] = false
	hands = ["", "", ""]
	poses = [default_pose(0), default_pose(1), default_pose(2)]
	using = [false, false, false]
	fire_started = false
	stir_progress = 0.0
	salt_amount = 0.0
	served = false
	elapsed = 0.0

static func default_pose(role: int) -> Dictionary:
	var xs := [-1.85, 0.0, 1.85]
	return {"position":[xs[clampi(role,0,2)],0.0,1.95],"yaw":0.0,"pitch":-0.2,"presentation":{"book":false,"page":"index","bell":0}}

func role_kit(role: int) -> String:
	return ["fire_kit", "stir_kit", "salt_kit"][clampi(role,0,2)]

func item_role(item: String) -> int:
	for role in range(ZONE_ITEMS.size()):
		if item in ZONE_ITEMS[role]: return role
	return -1

func item_available(item: String) -> bool:
	if item not in ITEMS or bool(dumped.get(item,false)): return false
	var role := item_role(item)
	return role >= 0 and role_kit(role) in equipment

func can_touch(role: int, item: String) -> bool:
	if role not in live_roles: return false
	var owner_role := item_role(item)
	return owner_role >= 0 and owner_role in live_roles

func grab(role: int, item: String) -> bool:
	if role < 0 or role >= 3 or not item_available(item) or not can_touch(role,item) or not hands[role].is_empty() or int(owners[item]) != -1: return false
	owners[item] = role
	hands[role] = item
	heights[item] = maxf(float(heights[item]), 0.12)
	return true

func drop(role: int) -> void:
	if role < 0 or role >= 3: return
	var item: String = hands[role]
	if item.is_empty(): return
	owners[item] = -1
	hands[role] = ""
	using[role] = false
	heights[item] = 0.0

func can_dump(role: int) -> bool:
	if role < 0 or role >= 3: return false
	var item: String = hands[role]
	if item.is_empty() or bool(dumped.get(item,false)): return false
	return positions[item].distance_to(POT) <= 0.92 and float(heights[item]) >= 0.20

func dump_into_pot(role: int) -> bool:
	if not can_dump(role): return false
	var item: String = hands[role]
	dumped[item] = true
	positions[item] = POT
	heights[item] = 0.0
	owners[item] = -1
	hands[role] = ""
	using[role] = false
	if item == "salt": salt_amount = maxf(salt_amount, 1.0)
	return true

func step(commands: Array, delta: float) -> void:
	for info in guest_roles: info.chew = maxf(0.0, float(info.chew) - delta)
	for role in range(3):
		var command: Dictionary = commands[role] if role < commands.size() else {}
		if command.has("pose"):
			var bells := int(poses[role].get("presentation",{}).get("bell",0))
			poses[role] = command.pose.duplicate(true)
			if not poses[role].has("presentation"): poses[role].presentation = {"book":false,"page":"index","bell":bells}
			else: poses[role].presentation.bell = bells
		if command.get("feed",false): feed(role)
		if command.get("dump",false): dump_into_pot(role)
		if command.get("drop",false): drop(role)
		var wanted := str(command.get("grab",""))
		if not wanted.is_empty(): grab(role,wanted)
		var item: String = hands[role]
		var use_item := bool(command.get("use",false))
		if not item.is_empty():
			if command.has("target"):
				var target := Vector2(float(command.target[0]),float(command.target[1])).clamp(-BOUNDS,BOUNDS)
				positions[item] = positions[item].move_toward(target,delta*5.5)
			if command.has("height"): heights[item] = clampf(float(command.height),0.0,1.1)
			if use_item: _use(role,item,not using[role],delta)
		using[role] = use_item
	stir_progress = clampf(stir_progress,0.0,1.0)
	salt_amount = clampf(salt_amount,0.0,3.0)
	elapsed += delta

func _use(_role: int, item: String, pressed: bool, delta: float) -> void:
	var near_pot: bool = positions[item].distance_to(POT) <= 0.95
	match item:
		"lighter":
			if pressed and near_pot: fire_started = true
		"paddle":
			if near_pot: stir_progress = minf(1.0,stir_progress + delta / 1.8)
		"salt":
			if near_pot and float(heights[item]) >= 0.18: salt_amount = minf(3.0,salt_amount + delta * 1.8)

func pot_count() -> int:
	var count := 0
	for item in ITEMS:
		if bool(dumped.get(item,false)): count += 1
	return count

func strange_count() -> int:
	var count := 0
	for item in STRANGE_ITEMS:
		if bool(dumped.get(item,false)): count += 1
	return count

func quality() -> Dictionary:
	var count := pot_count()
	var enough_contents := count >= MIN_CONTENTS
	var criteria := [
		{"label":"В котле минимум 13","value":minf(1.0,float(count)/MIN_CONTENTS)},
		{"label":"Огонь","value":1.0 if fire_started else 0.0},
		{"label":"Перемешать","value":stir_progress},
		{"label":"Соль","value":minf(1.0,salt_amount)}
	]
	var report := Quality.result(criteria,true,[])
	report.components = [
		{"id":"fire","name":"Огонь","role":0,"served":fire_started,"location":"под котлом" if fire_started else "не зажжён","lines":["Разжечь: "+("✓" if fire_started else "×")],"details":["Поднеси зажигалку к котлу и используй её."]},
		{"id":"stir","name":"Мешалка","role":1,"served":stir_progress>=0.999,"location":"в котле" if stir_progress>0 else "не использована","lines":["Перемешано: %d%%"%roundi(stir_progress*100)],"details":["Поднеси лопатку к котлу и мешай до 100%."]},
		{"id":"salt","name":"Соль","role":2,"served":salt_amount>=1.0,"location":"в солянке" if salt_amount>=1 else "не добавлена","lines":["Посолено: "+("✓" if salt_amount>=1 else "×")],"details":["Поднеси соль к котлу и используй её. Если утопить солонку целиком, это тоже считается."]},
		{"id":"pot","name":"Общий котёл","role":-1,"served":enough_contents,"location":"готов" if enough_contents else "наполняется","lines":["В котле: %d / %d"%[count,MIN_CONTENTS],"Странных предметов: %d"%strange_count()],"details":["Закинь не меньше 13 вещей. Еда и случайные предметы считаются одинаково честно.","Странные предметы не штрафуют качество — это солянка."]}
	]
	return report

func success() -> bool: return quality().grade == "S"

func take_serving() -> Array:
	if served: return []
	served = true
	for info in guest_roles: info.chew = 0.8
	return [{"kind":"solyanka","dish":"solyanka","from":Vector3(POT.x,BASE_Y+0.55,POT.y)},{"kind":"plate","dish":"solyanka","from":Vector3(POT.x,BASE_Y+0.05,POT.y)}]

func held_center(role: int) -> Vector3:
	if role < 0 or role >= hands.size(): return Vector3(100,100,100)
	var item: String = hands[role]
	return Vector3(100,100,100) if item.is_empty() else Vector3(positions[item].x,BASE_Y+float(heights[item])+0.12,positions[item].y)

func mouth_opening() -> float:
	if not guest_active: return 0.0
	var result := 0.0
	for role in range(3): result = maxf(result,clampf(1.0-held_center(role).distance_to(GUEST_MOUTH)/1.5,0,1))
	return result

func can_feed(_role := 0) -> bool: return false
func feed(_role: int) -> bool: return false
func guest_drunk() -> float: return 0.0
func guest_chewing() -> float:
	var result := 0.0
	for info in guest_roles: result = maxf(result,float(info.chew))
	return result
func surface_at(_point: Vector2) -> float: return BASE_Y

func snapshot() -> Dictionary:
	var points := {}
	for item in ITEMS: points[item] = [positions[item].x,positions[item].y]
	return {"equipment":equipment.duplicate(),"dish":dish,"guest_active":guest_active,"guest_roles":guest_roles.duplicate(true),"layout":"solyanka-cauldron","positions":points,"heights":heights.duplicate(),"owners":owners.duplicate(),"dumped":dumped.duplicate(),"hands":hands.duplicate(),"poses":poses.duplicate(true),"using":using.duplicate(),"fire_started":fire_started,"stir_progress":stir_progress,"salt_amount":salt_amount,"served":served,"elapsed":elapsed}

func restore(data: Dictionary) -> void:
	equipment = data.get("equipment",equipment).duplicate(); dish = str(data.get("dish",dish)); guest_active = bool(data.get("guest_active",false)); guest_roles = data.get("guest_roles",guest_roles).duplicate(true)
	for item in ITEMS: positions[item] = Vector2(float(data.positions[item][0]),float(data.positions[item][1]))
	for key in ["heights","owners","dumped","hands","poses","using"]: set(key,data[key].duplicate(true))
	for key in ["fire_started","stir_progress","salt_amount","served","elapsed"]: set(key,data[key])

func zone_snapshot(role: int) -> Dictionary:
	var result := {"dish":dish,"guest_active":guest_active,"guest_zone":guest_roles[role].duplicate(true),"positions":{},"heights":{},"owners":{},"dumped":{},"hand":hands[role],"pose":poses[role].duplicate(true),"using":using[role]}
	for item in ZONE_ITEMS[role]:
		result.positions[item] = [positions[item].x,positions[item].y]
		result.heights[item] = heights[item]
		result.owners[item] = owners[item]
		result.dumped[item] = dumped[item]
	if role == 0: result.fire_started = fire_started
	elif role == 1: result.stir_progress = stir_progress
	else: result.salt_amount = salt_amount
	return result.duplicate(true)

func restore_zone(role: int, data: Dictionary) -> void:
	dish = str(data.get("dish",dish)); guest_active = guest_active or bool(data.get("guest_active",false))
	if data.has("guest_zone"): guest_roles[role] = data.guest_zone.duplicate(true)
	for item in ZONE_ITEMS[role]:
		positions[item] = Vector2(float(data.positions[item][0]),float(data.positions[item][1]))
		heights[item] = data.heights[item]
		owners[item] = int(data.owners[item])
		dumped[item] = bool(data.dumped[item])
	hands[role] = str(data.hand); poses[role] = data.pose.duplicate(true); using[role] = bool(data.using)
	if role == 0: fire_started = bool(data.get("fire_started",false))
	elif role == 1: stir_progress = float(data.get("stir_progress",0.0))
	else: salt_amount = float(data.get("salt_amount",0.0))

static func valid_pose(data: Variant) -> bool: return data is Dictionary and numbers(data.get("position"),3) and finite(data.get("yaw")) and finite(data.get("pitch"))
static func numbers(data: Variant, count: int) -> bool:
	if not data is Array or data.size() != count: return false
	for value in data:
		if not finite(value): return false
	return true
static func finite(value: Variant) -> bool: return (value is float or value is int) and is_finite(float(value))
