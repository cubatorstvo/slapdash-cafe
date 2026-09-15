extends RefCounted
const Policy=preload("res://scripts/laboratory_progression.gd")
const FRONT := 10.6
const RIGHT := 2.9
const ENTRY := Vector3(-1.1,0,11.45)
const MICROSCOPE := Vector3(1.45,0,11.55)
const CHAIR := Vector3(-3.6,0,15.8)
const SUPPLY_X := 2.14
const POTS := [
	Vector3(-1.25,0,17.1),Vector3(1.25,0,17.1),
	Vector3(-6.3,0,16.5),Vector3(-6.3,0,19.5),Vector3(1.25,0,20.3),Vector3(-1.25,0,20.3),
	Vector3(-9.8,0,14.5),Vector3(-9.8,0,18.0),Vector3(-9.8,0,22.0),
	Vector3(-6.2,0,24.5),Vector3(-2.8,0,24.5),Vector3(1.0,0,24.5)
]
static func left(tier: int) -> float: return float(Policy.STAGES[clampi(tier,0,2)].left)
static func back(tier: int) -> float: return float(Policy.STAGES[clampi(tier,0,2)].back)
static func stamp(p) -> String: return "%d:%d:%s"%[p.lab_tier,p.lab_stage,str(p.lab_upgrades)]
static func tool_point(tool: String) -> Vector3:
	return Vector3(SUPPLY_X,1.03,{"soil":13.85,"liquid":14.5,"water":15.15,"fertilizer":15.8}.get(tool,13.85))
static func waiting_point(index: int) -> Vector3:
	return Vector3(-0.75+(index%3)*0.62,float(index/9)*0.35,14.7+float((index/3)%3)*0.55)

static func pot_point(id: int) -> Vector3: return POTS[clampi(id,0,POTS.size()-1)]
static func fixture(id: String) -> Vector3:
	return {
		"lab_power":Vector3(-2.50,1.25,13.5),"lab_power_2":Vector3(0.32,1.25,13.5),
		"lab_power_3":Vector3(-4.1,0,12.0),"lab_valve":Vector3(-1.75,1.25,13.6),"lab_damper":Vector3(-0.55,1.25,13.6),
		"lab_feeder":Vector3(0,2.35,17.1),"lab_irrigation":Vector3(-4.0,0,17.35),
		"lab_planter":Vector3(-7.1,0,12.0),"lab_extractor":Vector3(-7.1,0,14.0),
		"lab_production":Vector3(-4.6,0,23.0),"lab_lamps":Vector3(0,3.3,17.1),
		"lab_nutrients":Vector3(-7.4,0,20.7),"lab_climate":Vector3(-10.65,0,25.4),
		"lab_rack":Vector3(-6.3,0,18.0),"lab_rack_2":Vector3(-9.8,0,20.0),
		"lab_chair":CHAIR,"lab_cal_focus":CHAIR+Vector3(-0.55,1.4,0.4),
		"lab_cal_slow":CHAIR+Vector3(0.55,1.4,0.4),"lab_cal_auto":CHAIR+Vector3(-0.65,0.9,-0.75),
		"lab_cal_speed":CHAIR+Vector3(0.6,0.9,0.4)
	}.get(id,ENTRY+Vector3.UP)

static func obstacles(p) -> Array:
	var result: Array=[Rect2(-2.96,12.75,3.72,1.14),Rect2(0.9,11.13,1.1,0.85),Rect2(1.93,13.5,0.42,2.65)]
	for i in range(Policy.pot_count(p)):
		var point:=pot_point(i)
		result.append(Rect2(point.x-0.59,point.z-0.59,1.18,1.18))
	for id in ["lab_chair","lab_irrigation","lab_planter","lab_extractor","lab_production","lab_nutrients","lab_climate","lab_power_3"]:
		if id in p.lab_upgrades:
			var point:=fixture(id)
			result.append(Rect2(point.x-0.58,point.z-0.5,1.16,1.0))
	return result

static func walkable(point: Vector3, p) -> bool:
	if point.x<left(p.lab_tier)+0.4 or point.x>RIGHT-0.4 or point.z<FRONT+0.4 or point.z>back(p.lab_tier)-0.4: return false
	for rect: Rect2 in obstacles(p):
		if rect.grow(0.27).has_point(Vector2(point.x,point.z)): return false
	return true

static func cell_point(cell: Vector2i, p) -> Vector3:
	return Vector3(left(p.lab_tier)+0.45+cell.x*0.4,0,11.1+cell.y*0.4)

static func nearest(point: Vector3, p, blockers: Array) -> Vector2i:
	var result:=Vector2i.ZERO
	var distance:=INF
	for x in range(37):
		for z in range(40):
			var cell:=Vector2i(x,z)
			var candidate:=cell_point(cell,p)
			if candidate.x>RIGHT-0.4 or candidate.z>back(p.lab_tier)-0.4: continue
			var blocked:=false
			for rect: Rect2 in blockers:
				if rect.grow(0.27).has_point(Vector2(candidate.x,candidate.z)): blocked=true; break
			if not blocked and point.distance_squared_to(candidate)<distance:
				distance=point.distance_squared_to(candidate); result=cell
	return result

static func path(from: Vector3, to: Vector3, p) -> Array:
	var blockers:=obstacles(p)
	var start:=nearest(from,p,blockers)
	var goal:=nearest(to,p,blockers)
	var frontier: Array=[start]
	var previous: Dictionary={start:start}
	var cursor:=0
	while cursor<frontier.size() and not previous.has(goal):
		var cell: Vector2i=frontier[cursor]; cursor+=1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+offset
			if previous.has(next) or next.x<0 or next.y<0 or next.x>=37 or next.y>=40: continue
			var point:=cell_point(next,p)
			if point.x>RIGHT-0.4 or point.z>back(p.lab_tier)-0.4: continue
			var blocked:=false
			for rect: Rect2 in blockers:
				if rect.grow(0.27).has_point(Vector2(point.x,point.z)): blocked=true; break
			if blocked: continue
			previous[next]=cell; frontier.append(next)
	if not previous.has(goal): return [from]
	var reverse: Array=[to]
	var cell:=goal
	while cell!=start:
		reverse.append(cell_point(cell,p)); cell=previous[cell]
	reverse.append(cell_point(start,p)); reverse.append(from); reverse.reverse()
	return reverse
