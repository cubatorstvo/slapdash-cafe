extends RefCounted
## Product-scale physical plan for the production cafe.
## Stations use a regular four-row layout with generous aisles instead of the old debug clumps.
const SLOT_COUNT:=20
const BASE_SLOT_COUNT:=6
const TILE:=2.0
const HALL_X_MIN:=-24.0
const HALL_X_MAX:=24.0
const HALL_BACK_Z:=14.0
const STAGE_ENTRANCE_Z: Array[float]=[-6.0,-6.0,-14.0,-24.0]
const CHEF_POSITION:=Vector3(0.0,0.0,8.0)
# Legacy name used by route callers: this is now the central transverse aisle, not a point at the Chef table.
const CHEF_FLOW_POINT:=Vector3(0.0,0.0,-4.0)
const REAR_SPINE_POINT:=Vector3(0.0,0.0,12.2)
const AISLE_XS: Array[float]=[-13.5,-4.5,4.5,13.5]
const LEFT_AISLE_X:=-4.5
const RIGHT_AISLE_X:=4.5
const MARKET_POSITION:=Vector3(-7.0,0.0,13.1)
const DECOR_SIGN_POSITION:=Vector3(1.5,2.8,13.84)
const DECOR_PLANT_POINTS: Array[Vector2]=[Vector2(-6.8,11.9),Vector2(6.8,11.9),Vector2(22.2,-4.2)]
const STAGE_NAMES:=['Красный','Синий','Зелёный','Жёлтый']
const SECTION_ROWS: Array=[
	{"name":"Основной зал · ★3","slots":[6,7,8,9,10,11,12]},
	{"name":"Передний зал · ★4","slots":[13,14,15,16,17,18,19]}
]

# Slot 1 is the Chef. The remaining positions open symmetrically as the room grows.
# Rows are 8 m apart; columns are 9 m apart. With a 6.6 x 5.72 m station training
# footprint this leaves >=2.28 m between rows and >=2.4 m between columns.
const SLOT_POSITIONS: Array[Vector3]=[
	Vector3(0.0,0.0,8.0),
	Vector3(-18.0,0.0,8.0),Vector3(-9.0,0.0,8.0),Vector3(9.0,0.0,8.0),Vector3(18.0,0.0,8.0),
	Vector3(0.0,0.0,0.0),
	Vector3(-18.0,0.0,0.0),Vector3(-9.0,0.0,0.0),Vector3(9.0,0.0,0.0),Vector3(18.0,0.0,0.0),
	Vector3(-9.0,0.0,-8.0),Vector3(0.0,0.0,-8.0),Vector3(9.0,0.0,-8.0),
	Vector3(-18.0,0.0,-8.0),Vector3(18.0,0.0,-8.0),
	Vector3(-18.0,0.0,-16.0),Vector3(-9.0,0.0,-16.0),Vector3(0.0,0.0,-16.0),Vector3(9.0,0.0,-16.0),Vector3(18.0,0.0,-16.0)
]

static func stage_for_progress(p)->int:
	if p==null or int(p.stars)<1: return 1
	if not bool(p.expanded): return 2
	if not bool(p.orchestration_expanded): return 3
	return 4

static func entrance_z(stage: int)->float:
	return STAGE_ENTRANCE_Z[clampi(stage,1,4)-1]

static func player_spawn(stage: int)->Vector3:
	return Vector3(0.0,0.02,entrance_z(stage)+1.4)

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
	if slot_index<=5: return "Задний зал"
	if slot_index<=12: return "Основной зал"
	return "Передний зал"

static func unlock_stage_for_slot(slot_index: int)->int:
	if slot_index==0: return 1
	if slot_index<=5: return 2
	if slot_index<=12: return 3
	return 4

static func position(slot_index: int)->Vector3:
	return SLOT_POSITIONS[clampi(slot_index,0,SLOT_POSITIONS.size()-1)]

static func rotation_y(_slot_index: int)->float:
	# Every table faces the entrance. Customer side is local -Z; worker/service side is local +Z.
	return 0.0

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

static func aisle_x(point_x: float)->float:
	var best: float=AISLE_XS[0]
	var distance:=absf(point_x-best)
	for candidate in AISLE_XS:
		var candidate_distance:=absf(point_x-candidate)
		if candidate_distance<distance:
			best=candidate
			distance=candidate_distance
	return best

static func aisle_gate(point: Vector3)->Vector3:
	return Vector3(aisle_x(point.x),0.0,point.z)

static func transfer_gate(point: Vector3)->Vector3:
	return Vector3(aisle_x(point.x),0.0,CHEF_FLOW_POINT.z)

static func zone_gate(point: Vector3)->Vector3:
	return aisle_gate(point)

static func route_from_entrance(target: Vector3,stage: int)->Array:
	var spawn:=customer_spawn(stage)
	var result: Array=[spawn]
	# Enter through the left longitudinal aisle before moving toward a station. Going straight
	# to the room centre would cut through the central production row.
	var entrance_gate:=Vector3(LEFT_AISLE_X,0.0,spawn.z)
	if entrance_gate.distance_to(spawn)>0.2: result.append(entrance_gate)
	var left_transfer:=Vector3(LEFT_AISLE_X,0.0,CHEF_FLOW_POINT.z)
	if left_transfer.distance_to(Vector3(result.back()))>0.2: result.append(left_transfer)
	var transfer:=transfer_gate(target)
	if transfer.distance_to(left_transfer)>0.2: result.append(transfer)
	var gate:=aisle_gate(target)
	if gate.distance_to(transfer)>0.2: result.append(gate)
	result.append(target)
	return result

static func route_to_exit(start: Vector3,stage: int)->Array:
	var result: Array=[start]
	var gate:=aisle_gate(start)
	if gate.distance_to(start)>0.2: result.append(gate)
	var transfer:=transfer_gate(start)
	if transfer.distance_to(gate)>0.2: result.append(transfer)
	var right_transfer:=Vector3(RIGHT_AISLE_X,0.0,CHEF_FLOW_POINT.z)
	if right_transfer.distance_to(transfer)>0.2: result.append(right_transfer)
	var exit:=customer_exit(stage)
	var exit_gate:=Vector3(RIGHT_AISLE_X,0.0,exit.z)
	if exit_gate.distance_to(Vector3(result.back()))>0.2: result.append(exit_gate)
	result.append(exit)
	return result

static func route_to_rear(start: Vector3,target: Vector3)->Array:
	var result: Array=[start]
	var gate:=aisle_gate(start)
	if gate.distance_to(start)>0.2: result.append(gate)
	var rear_gate:=Vector3(gate.x,0.0,REAR_SPINE_POINT.z)
	if rear_gate.distance_to(Vector3(result.back()))>0.2: result.append(rear_gate)
	if rear_gate.distance_to(REAR_SPINE_POINT)>0.2: result.append(REAR_SPINE_POINT)
	result.append(target)
	return result

static func cafe_route(start: Vector3,target: Vector3,_stage: int,via_chef := true)->Array:
	var result: Array=[]
	var start_gate:=aisle_gate(start)
	if start.distance_to(start_gate)>0.2: result.append(start_gate)
	var start_transfer:=transfer_gate(start)
	if start_transfer.distance_to(start_gate)>0.2: result.append(start_transfer)
	if via_chef:
		var cross_start:=Vector3(aisle_x(start.x),0.0,CHEF_FLOW_POINT.z)
		if result.is_empty() or Vector3(result.back()).distance_to(cross_start)>0.2: result.append(cross_start)
	var target_transfer:=transfer_gate(target)
	if result.is_empty() or Vector3(result.back()).distance_to(target_transfer)>0.2: result.append(target_transfer)
	var target_gate:=aisle_gate(target)
	if target_gate.distance_to(target_transfer)>0.2: result.append(target_gate)
	result.append(target)
	return result

static func hall_cells_for_stage(stage: int)->Dictionary:
	var plan: Dictionary={}
	# Stage 1: intimate Chef room and entry corridor.
	_mark_rect(plan,Rect2i(-4,-3,8,10),1)
	# Stage 2: full-width rear hall for the first production row.
	_mark_rect(plan,Rect2i(-12,-3,24,10),2)
	# Stage 3: extend toward the street for the second production bank.
	_mark_rect(plan,Rect2i(-12,-7,24,14),3)
	# Stage 4: final front hall, lobby and last production row.
	_mark_rect(plan,Rect2i(-12,-12,24,19),4)
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
