extends RefCounted
## Gameplay-scale implementation of the accepted Zone A-D cafe blockout.
## The design scene uses compact placeholder tables; gameplay stations are larger, so the courts
## are scaled while preserving their topology: visitors inside, cooks outside, Chef as the rear
## centre anchor, and the main flow visible from the central hall.
const SLOT_COUNT:=31
const BASE_SLOT_COUNT:=6
const TILE:=2.0
const HALL_X_MIN:=-40.0
const HALL_X_MAX:=40.0
const HALL_BACK_Z:=14.0
# Early stages keep a compact front door; the final expansion moves it forward between C/D.
const EARLY_ENTRANCE_Z:=-8.0
const FINAL_ENTRANCE_Z:=-48.0
const CHEF_POSITION:=Vector3(0.0,0.0,5.1)
const CHEF_FLOW_POINT:=Vector3(0.0,0.0,0.0)
const FRONT_FLOW_POINT:=Vector3(0.0,0.0,-23.0)
const REAR_SPINE_POINT:=Vector3(0.0,0.0,11.2)
# Compatibility aliases for systems that need a coarse central routing spine.
const AISLE_XS: Array[float]=[-6.0,0.0,6.0]
const LEFT_AISLE_X:=-6.0
const RIGHT_AISLE_X:=6.0
const MARKET_POSITION:=Vector3(-4.5,0.0,8.8)
const DECOR_SIGN_POSITION:=Vector3(1.5,2.8,13.84)
const DECOR_PLANT_POINTS: Array[Vector2]=[Vector2(-4.0,12.0),Vector2(4.0,12.0)]
const STAGE_NAMES:=['Красный','Синий','Зелёный','Жёлтый']
const SECTION_ROWS: Array=[
	{"name":"Zone B","slots":[6,7,8,9,10,11,12]},
	{"name":"Zone C","slots":[13,14,15,20,21,22,23,24]},
	{"name":"Zone D","slots":[16,17,18,19,25,26,27,28,29,30]}
]

const TABLE_SKEWS: Array[float]=[-0.09,0.07,-0.04,0.11,-0.06]
# A/B are pulled toward the entrance compared with the first gameplay-scale pass: their rear-most
# tables now begin roughly on the Chef's row, so both courts are visible from behind his counter.
const ZONE_A_CENTER:=Vector3(20.0,0.0,1.0)
const ZONE_B_CENTER:=Vector3(-20.0,0.0,1.0)
const ZONE_C_CENTER:=Vector3(-21.0,0.0,-27.0)
const ZONE_D_CENTER:=Vector3(12.0,0.0,-29.0)
const ZONE_D_NORTH:=Vector3(22.0,0.0,-21.0)
const ZONE_D_SOUTH:=Vector3(24.0,0.0,-39.0)
# Keep IDs 1-20 compatible with existing saves; additional places extend the two front courts.
const C_SLOTS: Array[int]=[13,14,15,20,21,22,23,24]
const D_SLOTS: Array[int]=[16,17,18,19,25,26,27,28,29,30]

# Zone A: five-table crooked horseshoe, open on the west side toward Chef and the central plaza.
const ZONE_A_POSITIONS: Array[Vector3]=[
	Vector3(13.0,0.0,-4.0),Vector3(24.0,0.0,-4.0),Vector3(31.0,0.0,1.0),
	Vector3(24.0,0.0,6.0),Vector3(13.0,0.0,6.0)
]
# Zone B: seven-table elongated irregular oval.  The east side stays visibly open to Chef.
const ZONE_B_POSITIONS: Array[Vector3]=[
	Vector3(-10.0,0.0,6.0),Vector3(-19.0,0.0,6.0),Vector3(-28.0,0.0,6.0),
	Vector3(-36.0,0.0,0.0),Vector3(-28.0,0.0,-5.0),Vector3(-19.0,0.0,-5.0),Vector3(-10.0,0.0,-5.0)
]
# C is an angular square with its upper-right corner open to the central promenade.
const ZONE_C_POSITIONS: Array[Vector3]=[
	Vector3(-21,0,-16),Vector3(-32,0,-26),Vector3(-20,0,-39),
	Vector3(-30,0,-17),Vector3(-29,0,-36),Vector3(-10,0,-37),
	Vector3(-7.5,0,-27),Vector3(-12,0,-16)
]
# D has a perimeter and two back-to-back central kitchens separating connected guest pockets.
const ZONE_D_POSITIONS: Array[Vector3]=[
	Vector3(12,0,-42),Vector3(23,0,-43),Vector3(34,0,-42),Vector3(36,0,-26),
	Vector3(10,0,-16),Vector3(20,0,-16),Vector3(31,0,-17),Vector3(7,0,-29),
	Vector3(22,0,-26),Vector3(24,0,-34)
]

static func stage_for_progress(p)->int:
	if p==null or int(p.stars)<1: return 1
	if not bool(p.expanded): return 2
	if not bool(p.orchestration_expanded): return 3
	return 4

static func entrance_z(stage: int)->float:
	return FINAL_ENTRANCE_Z if stage>=4 else EARLY_ENTRANCE_Z

static func player_spawn(stage: int)->Vector3:
	return Vector3(0.0,0.02,entrance_z(stage)+2.6)

static func customer_spawn(stage: int)->Vector3:
	return Vector3(-1.25,0.0,entrance_z(stage)+0.85)

static func customer_exit(stage: int)->Vector3:
	return Vector3(1.25,0.0,entrance_z(stage)-1.0)

static func delivery_position(stage: int,id: int)->Vector3:
	var row:=int(posmod(id,9)/3)
	var col:=posmod(id,3)
	return Vector3(-3.15+col*0.72,0.25,entrance_z(stage)+1.05+row*0.72)

static func delivery_vehicle_spawn(stage: int)->Vector3:
	return Vector3(-3.7,0.0,entrance_z(stage)+0.65)

static func zone_for_slot(slot_index: int)->String:
	if slot_index==0: return "Шеф"
	if slot_index<=5: return "Zone A"
	if slot_index<=12: return "Zone B"
	if slot_index in C_SLOTS: return "Zone C"
	return "Zone D"

static func unlock_stage_for_slot(slot_index: int)->int:
	if slot_index==0: return 1
	if slot_index<=5: return 2
	if slot_index<=12: return 3
	return 4

static func zone_center(slot_index: int)->Vector3:
	if slot_index in D_SLOTS:
		if slot_index==28: return ZONE_D_CENTER
		return ZONE_D_NORTH if slot_index in [19,25,26,27,29] else ZONE_D_SOUTH
	return zone_center_named(zone_for_slot(slot_index))

static func zone_center_named(zone: String)->Vector3:
	match zone:
		"Zone A": return ZONE_A_CENTER
		"Zone B": return ZONE_B_CENTER
		"Zone C": return ZONE_C_CENTER
		"Zone D": return ZONE_D_CENTER
	return CHEF_POSITION

static func zone_for_point(point: Vector3)->String:
	# Workers stand outside the visitor ring, so choose the nearest court rather than splitting only
	# by Z; otherwise a cook on the front edge of A/B can be mistaken for C/D.
	if point.x>7.0:
		return "Zone A" if point.distance_squared_to(ZONE_A_CENTER)<=point.distance_squared_to(ZONE_D_CENTER) else "Zone D"
	if point.x<-7.0:
		return "Zone B" if point.distance_squared_to(ZONE_B_CENTER)<=point.distance_squared_to(ZONE_C_CENTER) else "Zone C"
	return ""

static func position(slot_index: int)->Vector3:
	if slot_index==0: return CHEF_POSITION
	if slot_index<=5: return ZONE_A_POSITIONS[slot_index-1]
	if slot_index<=12: return ZONE_B_POSITIONS[slot_index-6]
	if slot_index in C_SLOTS: return ZONE_C_POSITIONS[C_SLOTS.find(slot_index)]
	return ZONE_D_POSITIONS[D_SLOTS.find(slot_index)]

static func rotation_y(slot_index: int)->float:
	if slot_index==0: return 0.0
	# Long runs face across the court instead of converging on one point: this keeps each
	# customer's approach in front of its own kitchen, including the wider three-person model.
	if slot_index in [6,7,8,13,20,24,25,26,27,30]: return 0.0
	if slot_index in [10,11,12,15,21,22,16,17,18,29]: return PI
	if slot_index in [9,14,28]: return -PI*0.5
	if slot_index in [23,19]: return PI*0.5
	var inward:=(zone_center(slot_index)-position(slot_index)).normalized()
	return atan2(-inward.x,-inward.z)+TABLE_SKEWS[(slot_index-1)%TABLE_SKEWS.size()]

static func section_for(slot_index: int)->String:
	return zone_for_slot(slot_index)

static func slot_available(slot_index: int,stage: int)->bool:
	return unlock_stage_for_slot(slot_index)<=stage

static func free_slot_ids(service: Node)->Array:
	var result: Array=[]
	var stage:=stage_for_progress(service.progress)
	for slot in range(BASE_SLOT_COUNT,SLOT_COUNT):
		if slot_available(slot,stage) and service.by_id(slot+1)==null: result.append(slot+1)
	return result

static func slot_label(station_id: int)->String:
	var slot:=station_id-1
	return "%s · место %d"%[section_for(slot),station_id]

static func zone_gate(point: Vector3)->Vector3:
	var side:=6.0 if point.x>0.0 else -6.0
	var zone:=zone_for_point(point)
	return Vector3(side,0.0,FRONT_FLOW_POINT.z if zone in ["Zone C","Zone D"] else CHEF_FLOW_POINT.z)

static func visitor_focus(point: Vector3)->Vector3:
	var zone:=zone_for_point(point)
	if zone=="Zone D":
		# The westmost counter faces the passage connecting both pockets.
		if point.x<11.0 and point.z<-23.0 and point.z>-34.0: return ZONE_D_CENTER
		return ZONE_D_NORTH if point.z>-30.0 else ZONE_D_SOUTH
	return zone_center_named(zone)

static func _append_unique(route: Array,point: Vector3)->void:
	if route.is_empty() or Vector3(route.back()).distance_to(point)>0.2: route.append(point)

static func _court_entry(target: Vector3)->Array:
	var zone:=zone_for_point(target)
	if zone=="Zone C": return [Vector3(-5,0,-21),Vector3(-16,0,-23),ZONE_C_CENTER]
	if zone=="Zone D":
		var focus:=visitor_focus(target)
		var route: Array=[Vector3(5,0,-22),Vector3(14,0,-22)]
		if focus==ZONE_D_NORTH: route.append(focus)
		else:
			route.append(Vector3(14,0,-29))
			if focus==ZONE_D_SOUTH: route.append(Vector3(16,0,-39))
			route.append(focus)
		return route
	return [zone_center_named(zone)] if not zone.is_empty() else []

static func route_from_entrance(target: Vector3,stage: int)->Array:
	var result: Array=[customer_spawn(stage)]
	var zone:=zone_for_point(target)
	_append_unique(result,FRONT_FLOW_POINT if stage>=4 and zone in ["Zone C","Zone D"] else CHEF_FLOW_POINT)
	for point in _court_entry(target): _append_unique(result,point)
	_append_unique(result,target)
	return result

static func route_to_exit(start: Vector3,stage: int)->Array:
	var result:=route_from_entrance(start,stage)
	result.reverse()
	result[result.size()-1]=customer_exit(stage)
	return result

static func _court_approach(point: Vector3)->Array:
	var result:=_court_entry(point)
	# Staff and delivery runners approach from the back. Go around a table end before crossing
	# between its public and working sides; all models fit the same reserved slot.
	var nearest:=-1
	var distance:=INF
	for slot in range(SLOT_COUNT):
		var d:=point.distance_squared_to(position(slot))
		if d<distance:
			distance=d
			nearest=slot
	if nearest>=0 and distance<25.0:
		var center:=position(nearest)
		var yaw:=rotation_y(nearest)
		var local:=(point-center).rotated(Vector3.UP,-yaw)
		if local.z>0.4:
			var approach:=Vector3(result.back()) if not result.is_empty() else CHEF_FLOW_POINT
			var side:=1.0 if (approach-center).rotated(Vector3.UP,-yaw).x>=0.0 else -1.0
			for corner in [Vector3(side*4.2,0,-3.6),Vector3(side*4.2,0,maxf(local.z,3.6))]:
				_append_unique(result,center+corner.rotated(Vector3.UP,yaw))
	_append_unique(result,point)
	return result

static func route_to_rear(start: Vector3,target: Vector3)->Array:
	var result:=_court_approach(start)
	result.reverse()
	var zone:=zone_for_point(start)
	if zone in ["Zone C","Zone D"]: _append_unique(result,FRONT_FLOW_POINT)
	if start.z<9.0:
		_append_unique(result,CHEF_FLOW_POINT)
		_append_unique(result,Vector3(4.8,0,CHEF_FLOW_POINT.z))
		_append_unique(result,Vector3(4.8,0,REAR_SPINE_POINT.z))
	_append_unique(result,REAR_SPINE_POINT)
	_append_unique(result,target)
	return result

static func cafe_route(start: Vector3,target: Vector3,stage: int,via_chef := true)->Array:
	var result: Array=[]
	var start_zone:=zone_for_point(start)
	var target_zone:=zone_for_point(target)
	if start_zone.is_empty() and target_zone.is_empty() and start.distance_to(target)<=8.0:
		return [target]
	if not start_zone.is_empty():
		var departure:=_court_approach(start)
		departure.reverse()
		for point in departure.slice(1): _append_unique(result,point)
	if stage>=4 and start_zone in ["Zone C","Zone D"]: _append_unique(result,FRONT_FLOW_POINT)
	if start.z>=9.0 and start_zone.is_empty():
		_append_unique(result,Vector3(4.8,0,REAR_SPINE_POINT.z))
		_append_unique(result,Vector3(4.8,0,CHEF_FLOW_POINT.z))
	if via_chef: _append_unique(result,CHEF_FLOW_POINT)
	if stage>=4 and target_zone in ["Zone C","Zone D"]: _append_unique(result,FRONT_FLOW_POINT)
	if target.z>=9.0 and target_zone.is_empty():
		_append_unique(result,Vector3(4.8,0,CHEF_FLOW_POINT.z))
		_append_unique(result,Vector3(4.8,0,REAR_SPINE_POINT.z))
	for point in _court_approach(target): _append_unique(result,point)
	return result

static func hall_cells_for_stage(stage: int)->Dictionary:
	var plan: Dictionary={}
	# Stage 1: compact Chef plaza and its front approach.
	_mark_rect(plan,Rect2i(-3,-4,6,11),1)
	# Stage 2: Zone A opens as a recognisable right-hand court.
	_mark_rect(plan,Rect2i(3,-5,17,12),2)
	# Stage 3: Zone B opens on the left without moving Chef or Zone A.
	_mark_rect(plan,Rect2i(-20,-5,17,12),3)
	# Stage 4: two separate front courts around the same central promenade.
	_mark_rect(plan,Rect2i(-3,-24,6,20),4)
	_mark_rect(plan,Rect2i(-19,-23,16,19),4)
	_mark_rect(plan,Rect2i(3,-24,17,20),4)
	var cells: Dictionary={}
	for cell in plan:
		var unlock:=int(plan[cell])
		if unlock<=stage: cells[cell]=unlock
	return cells

static func final_hall_cells()->Dictionary:
	return hall_cells_for_stage(4)

static func _mark_rect(map: Dictionary,rect: Rect2i,stage: int)->void:
	for x in range(rect.position.x,rect.end.x):
		for z in range(rect.position.y,rect.end.y):
			var cell:=Vector2i(x,z)
			if not map.has(cell): map[cell]=stage

static func cell_center(cell: Vector2i)->Vector3:
	return Vector3((float(cell.x)+0.5)*TILE,0.0,(float(cell.y)+0.5)*TILE)
