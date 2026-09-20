extends RefCounted
## Shared physical plan for the production cafe. The layout mirrors the accepted debug prototype
## so the existing lab/lounge interiors can keep their current orientation behind the Chef.
const SLOT_COUNT:=20
const BASE_SLOT_COUNT:=6
const TILE:=2.0
const HALL_X_MIN:=-20.0
const HALL_X_MAX:=20.0
const HALL_BACK_Z:=14.0
const EARLY_ENTRANCE_Z:=-2.0
const FINAL_ENTRANCE_Z:=-16.0
const CHEF_POSITION:=Vector3(0.0,0.0,5.1)
const CHEF_FLOW_POINT:=Vector3(0.0,0.0,2.4)
const REAR_SPINE_POINT:=Vector3(0.0,0.0,11.2)
const STAGE_NAMES:=['Красный','Синий','Зелёный','Жёлтый']
const SECTION_ROWS: Array=[
	{"name":"Zone B","slots":[6,7,8,9,10,11,12]},
	{"name":"Zone C","slots":[13,14,15]},
	{"name":"Zone D","slots":[16,17,18,19]}
]

const TABLE_SKEWS: Array[float]=[-0.09,0.07,-0.04,0.11,-0.06]
const ZONE_A_OFFSETS: Array[Vector3]=[
	Vector3(-1.6,0,3.6),Vector3(2.0,0,3.4),Vector3(4.1,0,-0.1),
	Vector3(2.1,0,-3.6),Vector3(-1.6,0,-3.5)
]
const ZONE_B_OFFSETS: Array[Vector3]=[
	Vector3(2.4,0,3.6),Vector3(-0.8,0,3.8),Vector3(-3.7,0,2.6),
	Vector3(-4.4,0,-0.5),Vector3(-3.0,0,-3.4),Vector3(0.2,0,-3.9),Vector3(3.4,0,-3.0)
]
const ZONE_C_OFFSETS: Array[Vector3]=[
	Vector3(-3.5,0,3.7),Vector3(-0.2,0,4.0),Vector3(-4.4,0,0.6)
]
const ZONE_D_OFFSETS: Array[Vector3]=[
	Vector3(-2.5,0,3.8),Vector3(0.6,0,4.0),Vector3(3.7,0,3.2),Vector3(4.5,0,0.1)
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
	return Vector3(-3.15+col*0.72,0.30,entrance_z(stage)+1.05+row*0.72)

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

static func _zone_center(slot_index: int)->Vector3:
	var zone:=zone_for_slot(slot_index)
	if zone=="Zone A": return Vector3(13,0,4)
	if zone=="Zone B": return Vector3(-13,0,4)
	if zone=="Zone C": return Vector3(-13,0,-8)
	if zone=="Zone D": return Vector3(13,0,-8)
	return CHEF_POSITION

static func _zone_offset(slot_index: int)->Vector3:
	if slot_index<=5: return ZONE_A_OFFSETS[slot_index-1]
	if slot_index<=12: return ZONE_B_OFFSETS[slot_index-6]
	if slot_index<=15: return ZONE_C_OFFSETS[slot_index-13]
	return ZONE_D_OFFSETS[slot_index-16]

static func position(slot_index: int)->Vector3:
	if slot_index==0: return CHEF_POSITION
	return _zone_center(slot_index)+_zone_offset(slot_index)

static func rotation_y(slot_index: int)->float:
	if slot_index==0: return 0.0
	var point:=position(slot_index)
	var inward:=(_zone_center(slot_index)-point).normalized()
	var skew:=TABLE_SKEWS[(slot_index-1)%TABLE_SKEWS.size()]
	# WorkStation customers stand on local -Z, cooks on local +Z.
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
	if point.x>6.0: return Vector3(5.2,0.0,-3.0 if point.z<-2.0 else 2.4)
	if point.x<-6.0: return Vector3(-5.2,0.0,-3.0 if point.z<-2.0 else 2.4)
	return Vector3(0.0,0.0,clampf(point.z,-3.0,3.0))

static func route_from_entrance(target: Vector3,stage: int)->Array:
	var result: Array=[customer_spawn(stage)]
	if stage>=4: result.append(Vector3(0,0,-3.0))
	result.append(CHEF_FLOW_POINT)
	var gate:=zone_gate(target)
	if gate.distance_to(CHEF_FLOW_POINT)>0.2: result.append(gate)
	result.append(target)
	return result

static func route_to_exit(start: Vector3,stage: int)->Array:
	var result: Array=[start]
	var gate:=zone_gate(start)
	if gate.distance_to(start)>0.2: result.append(gate)
	result.append(CHEF_FLOW_POINT)
	if stage>=4: result.append(Vector3(0,0,-3.0))
	result.append(customer_exit(stage))
	return result

static func route_to_rear(start: Vector3,target: Vector3)->Array:
	var result: Array=[start]
	var gate:=zone_gate(start)
	if gate.distance_to(start)>0.2: result.append(gate)
	if Vector3(result.back()).distance_to(CHEF_FLOW_POINT)>0.2: result.append(CHEF_FLOW_POINT)
	result.append(REAR_SPINE_POINT)
	result.append(target)
	return result

static func cafe_route(start: Vector3,target: Vector3,stage: int,via_chef := true)->Array:
	var result: Array=[]
	var start_gate:=zone_gate(start)
	if start.distance_to(start_gate)>0.2: result.append(start_gate)
	if via_chef and (result.is_empty() or Vector3(result.back()).distance_to(CHEF_FLOW_POINT)>0.2): result.append(CHEF_FLOW_POINT)
	var target_gate:=zone_gate(target)
	if target_gate.distance_to(CHEF_FLOW_POINT)>0.2: result.append(target_gate)
	result.append(target)
	return result

static func hall_cells_for_stage(stage: int)->Dictionary:
	var debug_map: Dictionary={}
	_mark_rect(debug_map,Rect2i(-3,-7,6,6),1)
	_mark_rect(debug_map,Rect2i(-2,-1,4,2),1)
	_mark_rect(debug_map,Rect2i(-2,1,4,7),4)
	_mark_rect(debug_map,Rect2i(3,-5,7,6),2)
	_mark_rect(debug_map,Rect2i(2,-1,1,2),2)
	_mark_rect(debug_map,Rect2i(-10,-5,7,6),3)
	_mark_rect(debug_map,Rect2i(-3,-1,1,2),3)
	_mark_rect(debug_map,Rect2i(-6,-7,3,2),3)
	_mark_rect(debug_map,Rect2i(3,-7,3,2),3)
	_mark_rect(debug_map,Rect2i(-10,1,8,6),4)
	_mark_rect(debug_map,Rect2i(2,1,8,6),4)
	_mark_rect(debug_map,Rect2i(-9,-7,3,2),4)
	_mark_rect(debug_map,Rect2i(6,-7,3,2),4)
	var cells: Dictionary={}
	for debug_cell in debug_map:
		var unlock:=int(debug_map[debug_cell])
		if unlock>stage: continue
		var c: Vector2i=debug_cell
		var mirrored:=Vector2i(c.x,-c.y-1)
		if cell_center(mirrored).z>=HALL_BACK_Z: continue
		cells[mirrored]=unlock
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
