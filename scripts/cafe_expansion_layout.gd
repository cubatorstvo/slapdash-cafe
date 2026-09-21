extends RefCounted
## Gameplay-scale implementation of the accepted Zone A-D cafe blockout.
## The design scene uses compact placeholder tables; gameplay stations are larger, so the courts
## are scaled while preserving their topology: visitors inside, cooks outside, Chef as the rear
## centre anchor, and the main flow visible from the central hall.
const SLOT_COUNT:=20
const BASE_SLOT_COUNT:=6
const TILE:=2.0
const HALL_X_MIN:=-40.0
const HALL_X_MAX:=40.0
const HALL_BACK_Z:=14.0
# Early stages keep a compact front door; the final expansion moves it forward between C/D.
const EARLY_ENTRANCE_Z:=-8.0
const FINAL_ENTRANCE_Z:=-32.0
const CHEF_POSITION:=Vector3(0.0,0.0,5.1)
const CHEF_FLOW_POINT:=Vector3(0.0,0.0,2.4)
const FRONT_FLOW_POINT:=Vector3(0.0,0.0,-18.0)
const REAR_SPINE_POINT:=Vector3(0.0,0.0,11.2)
# Compatibility aliases for systems that need a coarse central routing spine.
const AISLE_XS: Array[float]=[-6.0,0.0,6.0]
const LEFT_AISLE_X:=-6.0
const RIGHT_AISLE_X:=6.0
const MARKET_POSITION:=Vector3(6.0,0.0,11.0)
const DECOR_SIGN_POSITION:=Vector3(1.5,2.8,13.84)
const DECOR_PLANT_POINTS: Array[Vector2]=[Vector2(-4.0,12.0),Vector2(4.0,12.0)]
const STAGE_NAMES:=['Красный','Синий','Зелёный','Жёлтый']
const SECTION_ROWS: Array=[
	{"name":"Zone B","slots":[6,7,8,9,10,11,12]},
	{"name":"Zone C","slots":[13,14,15]},
	{"name":"Zone D","slots":[16,17,18,19]}
]

const TABLE_SKEWS: Array[float]=[-0.09,0.07,-0.04,0.11,-0.06]
# A/B are pulled toward the entrance compared with the first gameplay-scale pass: their rear-most
# tables now begin roughly on the Chef's row, so both courts are visible from behind his counter.
const ZONE_A_CENTER:=Vector3(20.0,0.0,1.0)
const ZONE_B_CENTER:=Vector3(-20.0,0.0,1.0)
const ZONE_C_CENTER:=Vector3(-17.0,0.0,-18.0)
const ZONE_D_CENTER:=Vector3(17.0,0.0,-18.0)

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
# The current 20-slot game occupies only part of the larger documented late-game C/D courts.
# These positions leave the public pockets open for later capacity growth.
const ZONE_C_POSITIONS: Array[Vector3]=[
	Vector3(-24.0,0.0,-13.0),Vector3(-27.0,0.0,-21.0),Vector3(-18.0,0.0,-27.0)
]
const ZONE_D_POSITIONS: Array[Vector3]=[
	Vector3(8.0,0.0,-25.0),Vector3(17.0,0.0,-27.0),Vector3(27.0,0.0,-22.0),Vector3(26.0,0.0,-13.0)
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

static func installer_spawn(stage: int,id: int)->Vector3:
	return Vector3(-3.7,0.0,entrance_z(stage)+0.65+float(posmod(id,4))*0.30)

static func installer_exit(stage: int,id: int)->Vector3:
	return Vector3(-4.9,0.0,entrance_z(stage)-0.55+float(posmod(id,4))*0.28)

static func zone_for_slot(slot_index: int)->String:
	if slot_index==0: return "Шеф"
	if slot_index<=5: return "Zone A"
	if slot_index<=12: return "Zone B"
	if slot_index<=15: return "Zone C"
	return "Zone D"

static func unlock_stage_for_slot(slot_index: int)->int:
	if slot_index==0: return 1
	if slot_index<=5: return 2
	if slot_index<=12: return 3
	return 4

static func zone_center(slot_index: int)->Vector3:
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
	if slot_index<=15: return ZONE_C_POSITIONS[slot_index-13]
	return ZONE_D_POSITIONS[slot_index-16]

static func rotation_y(slot_index: int)->float:
	if slot_index==0: return 0.0
	var point:=position(slot_index)
	var inward:=(zone_center(slot_index)-point).normalized()
	var skew:=TABLE_SKEWS[(slot_index-1)%TABLE_SKEWS.size()]
	# WorkStation customers stand on local -Z; cooks therefore occupy the outside of each court.
	return atan2(-inward.x,-inward.z)+skew

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

static func _append_unique(route: Array,point: Vector3)->void:
	if route.is_empty() or Vector3(route.back()).distance_to(point)>0.2: route.append(point)

static func route_from_entrance(target: Vector3,stage: int)->Array:
	var result: Array=[customer_spawn(stage)]
	var zone:=zone_for_point(target)
	if stage>=4 and zone in ["Zone C","Zone D"]: _append_unique(result,FRONT_FLOW_POINT)
	else: _append_unique(result,CHEF_FLOW_POINT)
	if not zone.is_empty(): _append_unique(result,zone_center_named(zone))
	_append_unique(result,target)
	return result

static func route_to_exit(start: Vector3,stage: int)->Array:
	var result: Array=[start]
	var zone:=zone_for_point(start)
	if not zone.is_empty(): _append_unique(result,zone_center_named(zone))
	if stage>=4 and zone in ["Zone C","Zone D"]: _append_unique(result,FRONT_FLOW_POINT)
	else: _append_unique(result,CHEF_FLOW_POINT)
	_append_unique(result,customer_exit(stage))
	return result

static func route_to_rear(start: Vector3,target: Vector3)->Array:
	var result: Array=[start]
	var zone:=zone_for_point(start)
	if zone in ["Zone C","Zone D"]:
		_append_unique(result,zone_center_named(zone))
		_append_unique(result,FRONT_FLOW_POINT)
		_append_unique(result,CHEF_FLOW_POINT)
	elif zone in ["Zone A","Zone B"]:
		if start.z>8.5: _append_unique(result,REAR_SPINE_POINT)
		else:
			_append_unique(result,zone_center_named(zone))
			_append_unique(result,CHEF_FLOW_POINT)
	else:
		if start.z<EARLY_ENTRANCE_Z: _append_unique(result,FRONT_FLOW_POINT)
		_append_unique(result,CHEF_FLOW_POINT)
	_append_unique(result,REAR_SPINE_POINT)
	_append_unique(result,target)
	return result

static func cafe_route(start: Vector3,target: Vector3,stage: int,via_chef := true)->Array:
	var result: Array=[]
	var start_zone:=zone_for_point(start)
	var target_zone:=zone_for_point(target)
	# Short movements inside the entrance apron should remain local.
	if start_zone.is_empty() and target_zone.is_empty() and start.distance_to(target)<=8.0:
		_append_unique(result,target)
		return result
	if not start_zone.is_empty(): _append_unique(result,zone_center_named(start_zone))
	if stage>=4 and start_zone in ["Zone C","Zone D"]: _append_unique(result,FRONT_FLOW_POINT)
	if via_chef: _append_unique(result,CHEF_FLOW_POINT)
	if stage>=4 and target_zone in ["Zone C","Zone D"]: _append_unique(result,FRONT_FLOW_POINT)
	if not target_zone.is_empty(): _append_unique(result,zone_center_named(target_zone))
	_append_unique(result,target)
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
	_mark_rect(plan,Rect2i(-3,-16,6,12),4)
	_mark_rect(plan,Rect2i(-17,-16,14,12),4)
	_mark_rect(plan,Rect2i(3,-16,14,12),4)
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
