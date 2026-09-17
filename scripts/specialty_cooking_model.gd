extends RefCounted
## Two-role burger kitchen with one genuinely shared bottleneck: the griddle.
## Patty and bun belong to different role snapshots, but both need the same physical surface.
const Quality = preload("res://scripts/dish_quality.gd")
const BOUNDS := Vector2(3.05, 2.65)
const BASE_Y := 1.015
const GRIDDLE := Vector2(0.0, -0.28)
const ASSEMBLY := Vector2(0.0, 0.72)
const GUEST_MOUTH := Vector3(0, 1.5, -1.61)
const ITEMS := ["patty", "patty_spatula", "seasoning", "bun", "cheese", "sauce_bottle", "chili_bottle"]
const NAMES := {"patty":"котлета","patty_spatula":"лопатка","seasoning":"приправа","bun":"булка","cheese":"сыр","sauce_bottle":"соус","chili_bottle":"острый соус"}
const ZONE_ITEMS := [["patty", "patty_spatula", "seasoning"],["bun", "cheese", "sauce_bottle", "chili_bottle"]]
const ZONE_VALUES := [["patty_sides", "patty_face", "patty_state", "patty_season", "flip_time"],["bun_toast", "cheese_applied", "sauce_amount", "chili_amount", "served"]]
var equipment: Array = ["grill_kit", "assembly_kit"]
var dish := "burger"
var guest_active := false
var guest_roles: Array = []
var live_roles: Array = [0, 1]
var positions: Dictionary
var heights: Dictionary
var owners: Dictionary
var hands: Array
var poses: Array
var using: Array
var pouring: Array
var patty_sides: Array
var patty_face := 0
var patty_state := "raw"
var patty_season := 0.0
var bun_toast := 0.0
var cheese_applied := false
var sauce_amount := 0.0
var chili_amount := 0.0
var flip_time := 0.0
var griddle_conflict := false
var griddle_wait := 0.0
var served := false
var elapsed := 0.0

func _init() -> void: reset()

func reset(recipe := "burger") -> void:
	dish = str(recipe) if str(recipe) in ["burger","cheeseburger","spicy_burger"] else "burger"
	guest_active = false
	guest_roles = [{"drunk":0.0,"swallowed":[],"chew":0.0},{"drunk":0.0,"swallowed":[],"chew":0.0}]
	positions = {"patty":Vector2(-2.20,0.22),"patty_spatula":Vector2(-1.55,-0.62),"seasoning":Vector2(-2.38,-0.68),"bun":Vector2(2.15,0.18),"cheese":Vector2(1.38,-0.68),"sauce_bottle":Vector2(2.18,-0.68),"chili_bottle":Vector2(2.60,-0.68)}
	heights = {}; owners = {}
	for item in ITEMS: heights[item]=0.0; owners[item]=-1
	hands=["",""]; poses=[default_pose(0),default_pose(1)]; using=[false,false]; pouring=[false,false]
	patty_sides=[0.0,0.0]; patty_face=0; patty_state="raw"; patty_season=0.0; bun_toast=0.0; cheese_applied=false; sauce_amount=0.0; chili_amount=0.0; flip_time=0.0; griddle_conflict=false; griddle_wait=0.0; served=false; elapsed=0.0

static func default_pose(role: int) -> Dictionary:
	return {"position":[-1.35 if role==0 else 1.35,0.0,1.85],"yaw":0.0,"pitch":-0.2,"presentation":{"book":false,"page":"index","bell":0}}

func item_available(item: String) -> bool:
	if item not in ITEMS: return false
	return "grill_kit" in equipment if item in ZONE_ITEMS[0] else "assembly_kit" in equipment

func can_touch(role: int, item: String) -> bool:
	if role not in live_roles: return false
	for zone in range(ZONE_ITEMS.size()):
		if item in ZONE_ITEMS[zone]: return zone in live_roles
	return false

func grab(role: int, item: String) -> bool:
	if role<0 or role>=2 or not item_available(item) or not can_touch(role,item) or not hands[role].is_empty() or owners[item]!=-1: return false
	owners[item]=role; hands[role]=item; heights[item]=maxf(float(heights[item]),0.12)
	if item=="patty": patty_state="held"
	return true

func drop(role: int) -> void:
	if role<0 or role>=2: return
	var item:String=hands[role]
	if item.is_empty(): return
	owners[item]=-1; heights[item]=0.0; hands[role]=""; using[role]=false; pouring[role]=false
	if item=="patty":
		if positions.patty.distance_to(GRIDDLE)<0.52: patty_state="griddle"
		elif positions.patty.distance_to(ASSEMBLY)<0.46: patty_state="assembly"
		else: patty_state="raw"

func step(commands: Array, delta: float) -> void:
	for info in guest_roles: info.chew=maxf(0.0,float(info.chew)-delta)
	pouring=[false,false]
	for role in range(2):
		var command:Dictionary=commands[role] if role<commands.size() else {}
		if command.has("pose"):
			var bells:=int(poses[role].get("presentation",{}).get("bell",0))
			poses[role]=command.pose.duplicate(true)
			if not poses[role].has("presentation"): poses[role].presentation={"book":false,"page":"index","bell":bells}
			else: poses[role].presentation.bell=bells
		if command.get("feed",false): feed(role)
		if command.get("drop",false): drop(role)
		var wanted:=str(command.get("grab",""))
		if not wanted.is_empty(): grab(role,wanted)
		var item:String=hands[role]
		var use_item:=bool(command.get("use",false))
		if not item.is_empty():
			if command.has("target"):
				var target:=Vector2(float(command.target[0]),float(command.target[1])).clamp(-BOUNDS,BOUNDS)
				if live_roles.size()==1: target.x=clampf(target.x,-BOUNDS.x if role==0 else 0.12,-0.12 if role==0 else BOUNDS.x)
				positions[item]=positions[item].move_toward(target,delta*5.0)
			if command.has("height"): heights[item]=clampf(float(command.height),0.0,1.1)
			if use_item: _use(role,item,not using[role],delta)
		using[role]=use_item
	_update_griddle(delta)
	flip_time=maxf(0.0,flip_time-delta); elapsed+=delta

func _update_griddle(delta: float) -> void:
	var patty_on:=hands.find("patty")<0 and positions.patty.distance_to(GRIDDLE)<0.52
	var bun_on:=hands.find("bun")<0 and positions.bun.distance_to(GRIDDLE)<0.52
	griddle_conflict=patty_on and bun_on
	if griddle_conflict: griddle_wait+=delta; return
	if patty_on:
		patty_state="griddle"; patty_sides[patty_face]=minf(1.0,float(patty_sides[patty_face])+delta/5.5)
	elif hands.find("patty")<0 and positions.patty.distance_to(ASSEMBLY)<0.46: patty_state="assembly"
	if bun_on: bun_toast=minf(1.0,bun_toast+delta/4.0)

func _use(role: int, item: String, pressed: bool, delta: float) -> void:
	var point:Vector2=positions[item]
	match item:
		"patty_spatula":
			if pressed and patty_state=="griddle" and point.distance_to(positions.patty)<0.50: patty_face=1-patty_face; flip_time=0.35
		"seasoning":
			pouring[role]=true
			if point.distance_to(positions.patty)<0.42 and float(heights[item])>0.18: patty_season=minf(3.0,patty_season+delta*2.0)
		"cheese":
			if pressed and _assembly_ready(false) and point.distance_to(ASSEMBLY)<0.48: cheese_applied=true
		"sauce_bottle":
			pouring[role]=true
			if _assembly_ready(false) and point.distance_to(ASSEMBLY)<0.48 and float(heights[item])>0.16: sauce_amount=minf(3.0,sauce_amount+delta*2.0)
		"chili_bottle":
			pouring[role]=true
			if _assembly_ready(false) and point.distance_to(ASSEMBLY)<0.48 and float(heights[item])>0.16: chili_amount=minf(3.0,chili_amount+delta*2.0)

func _assembly_ready(require_bun := true) -> bool:
	var patty_here:=patty_state=="assembly" and hands.find("patty")<0
	var bun_here:=positions.bun.distance_to(ASSEMBLY)<0.46 and hands.find("bun")<0
	return patty_here and (bun_here if require_bun else true)

func quality() -> Dictionary:
	var present:=_assembly_ready() or served
	var criteria:=[{"label":"Котлета: две стороны","value":(float(patty_sides[0])+float(patty_sides[1]))/2.0},{"label":"Приправа котлеты","value":minf(1.0,patty_season)},{"label":"Булка: поджарить","value":bun_toast},{"label":"Соус","value":minf(1.0,sauce_amount)}]
	if dish=="cheeseburger": criteria.append({"label":"Сыр","value":1.0 if cheese_applied else 0.0})
	elif dish=="spicy_burger": criteria.append({"label":"Острый соус","value":minf(1.0,chili_amount)})
	var report:=Quality.result(criteria,present,[])
	report.components=[
		{"id":"patty","name":"Котлета","role":0,"served":patty_state=="assembly" or served,"location":"в бургере" if present else "в работе","lines":["Две стороны: %d%% / %d%%"%[roundi(patty_sides[0]*100),roundi(patty_sides[1]*100)],"Приправа: "+("✓" if patty_season>=1 else "×")],"details":["Обе стороны котлеты должны дойти до 100%.","Приправь котлету до сборки."]},
		{"id":"assembly","name":"Сборка","role":1,"served":present,"location":"на подаче" if present else "в работе","lines":["Булка: %d%%"%roundi(bun_toast*100),"Соус: "+("✓" if sauce_amount>=1 else "×"),("Сыр: "+("✓" if cheese_applied else "—")) if dish=="cheeseburger" else ("Острый соус: "+("✓" if chili_amount>=1 else "×")) if dish=="spicy_burger" else "Сборка: бургер"],"details":["Поджарь булку на общей поверхности.","Добавь соус после передачи котлеты.","Добавь нужную добавку и собери бургер."]}
	]
	return report

func success() -> bool: return quality().grade=="S"

func take_serving() -> Array:
	if not _assembly_ready() or served: return []
	served=true; guest_roles[1].chew=0.8
	return [{"kind":"burger","from":Vector3(ASSEMBLY.x,BASE_Y+0.15,ASSEMBLY.y)},{"kind":"plate","from":Vector3(ASSEMBLY.x,BASE_Y+0.03,ASSEMBLY.y)}]

func held_center(role: int) -> Vector3:
	var item:String=hands[role]
	return Vector3(100,100,100) if item.is_empty() else Vector3(positions[item].x,BASE_Y+float(heights[item])+0.12,positions[item].y)
func mouth_opening() -> float:
	if not guest_active: return 0.0
	return maxf(clampf(1.0-held_center(0).distance_to(GUEST_MOUTH)/1.5,0,1),clampf(1.0-held_center(1).distance_to(GUEST_MOUTH)/1.5,0,1))
func feed(role: int) -> bool:
	if not guest_active or role<0 or role>=2: return false
	if _assembly_ready() and held_center(role).distance_to(GUEST_MOUTH)<=0.95: served=true; guest_roles[role].chew=0.8; return true
	return false
func guest_drunk() -> float: return 0.0
func guest_chewing() -> float: return maxf(float(guest_roles[0].chew),float(guest_roles[1].chew))
func surface_at(_point: Vector2) -> float: return BASE_Y

func snapshot() -> Dictionary:
	var points:={}
	for item in ITEMS: points[item]=[positions[item].x,positions[item].y]
	return {"equipment":equipment.duplicate(),"dish":dish,"guest_active":guest_active,"guest_roles":guest_roles.duplicate(true),"layout":"burger-griddle","positions":points,"heights":heights.duplicate(),"owners":owners.duplicate(),"hands":hands.duplicate(),"poses":poses.duplicate(true),"using":using.duplicate(),"pouring":pouring.duplicate(),"patty_sides":patty_sides.duplicate(),"patty_face":patty_face,"patty_state":patty_state,"patty_season":patty_season,"bun_toast":bun_toast,"cheese_applied":cheese_applied,"sauce_amount":sauce_amount,"chili_amount":chili_amount,"flip_time":flip_time,"griddle_conflict":griddle_conflict,"griddle_wait":griddle_wait,"served":served,"elapsed":elapsed}

func restore(data: Dictionary) -> void:
	equipment=data.get("equipment",equipment).duplicate(); dish=str(data.get("dish",dish)); guest_active=bool(data.get("guest_active",false)); guest_roles=data.get("guest_roles",guest_roles).duplicate(true)
	for item in ITEMS: positions[item]=Vector2(float(data.positions[item][0]),float(data.positions[item][1]))
	for key in ["heights","owners","hands","poses","using","pouring","patty_sides"]: set(key,data[key].duplicate(true))
	for key in ["patty_face","patty_state","patty_season","bun_toast","cheese_applied","sauce_amount","chili_amount","flip_time","griddle_conflict","griddle_wait","served","elapsed"]: set(key,data[key])

func zone_snapshot(role: int) -> Dictionary:
	var data:=snapshot()
	var result:={"dish":dish,"guest_active":guest_active,"guest_zone":guest_roles[role].duplicate(true),"positions":{},"heights":{},"owners":{},"hand":hands[role],"pose":poses[role].duplicate(true),"using":using[role],"pouring":pouring[role]}
	for item in ZONE_ITEMS[role]:
		for key in ["positions","heights","owners"]: result[key][item]=data[key][item]
	for key in ZONE_VALUES[role]: result[key]=data[key].duplicate(true) if data[key] is Array else data[key]
	return result.duplicate(true)

func restore_zone(role: int, data: Dictionary) -> void:
	dish=str(data.get("dish",dish)); guest_active=guest_active or bool(data.get("guest_active",false))
	if data.has("guest_zone"): guest_roles[role]=data.guest_zone.duplicate(true)
	for item in ZONE_ITEMS[role]:
		positions[item]=Vector2(float(data.positions[item][0]),float(data.positions[item][1])); heights[item]=data.heights[item]; owners[item]=int(data.owners[item])
	hands[role]=str(data.hand); poses[role]=data.pose.duplicate(true); using[role]=bool(data.using); pouring[role]=bool(data.pouring)
	for key in ZONE_VALUES[role]: set(key,data[key].duplicate(true) if data[key] is Array else data[key])
	griddle_conflict=hands.find("patty")<0 and hands.find("bun")<0 and positions.patty.distance_to(GRIDDLE)<0.52 and positions.bun.distance_to(GRIDDLE)<0.52

static func valid_pose(data: Variant) -> bool: return data is Dictionary and numbers(data.get("position"),3) and finite(data.get("yaw")) and finite(data.get("pitch"))
static func numbers(data: Variant, count: int) -> bool:
	if not data is Array or data.size()!=count: return false
	for value in data:
		if not finite(value): return false
	return true
static func finite(value: Variant) -> bool: return (value is float or value is int) and is_finite(float(value))
