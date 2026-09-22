extends RefCounted
## Shared staged geometry: meshes, collisions, leisure anchors and routes use the same layout.
const SHIFT := Vector3(-2.9,0,3.4)
const ROOM_STAGES := [
	{"id":"small","right_x":6.3},
	{"id":"medium","right_x":12.3},
	{"id":"large","right_x":14.9}
]
const MAX_BACK_Z := 30.4
const AISLE_X := 5.0
const ENTRANCE := Vector3(5.0,0,14.85)
const BEDS_Z := 29.1
const GRID_STEP := 0.40
const WALK_MARGIN := 0.34
const LEFT_X := 0.0
const FRONT_Z := 14.0

static func back_z(_tier: int) -> float:
	return MAX_BACK_Z

static func right_x(tier: int) -> float:
	return float(ROOM_STAGES[clampi(tier,0,2)].right_x)

static func bed_center(tier: int) -> Vector3:
	return Vector3(minf(7.5,right_x(tier)-1.5),0.48,back_z(tier)-1.3)

static func offsets(tier: int) -> Dictionary:
	if tier==0:
		return {"television":Vector3(-0.8,0,1.2),"rocking_chair":Vector3(0,0,-2),"beanbag":Vector3(0,0,-2.1),"bookcase":Vector3(0,0,-8),"floor_lamp":Vector3(0,0,-2.1)}
	if tier==1:
		return {"television":Vector3(-0.8,0,1.2),"bookcase":Vector3(0,0,-8),"board_games":Vector3(6.8,0,-2.5),"tea_station":Vector3(-7.2,0,-2),"arcade":Vector3(-2.5,0,0),"snack_fridge":Vector3(-2.5,0,-2.05)}
	return {"television":Vector3(-0.8,0,1.2)}

static func catalogue(tier := 2, owned: Array = []) -> Array:
	var result: Array=[]
	var shifts:=offsets(tier)
	for spec in _base_catalogue():
		var required: int=["small","medium","large"].find(spec.stage)
		if required>tier or (not owned.is_empty() and spec.id not in owned): continue
		spec.position+=SHIFT+Vector3(shifts.get(spec.id,Vector3.ZERO))
		result.append(spec)
	return result

static func item_position(id: String, tier: int) -> Vector3:
	for spec in catalogue(tier):
		if spec.id==id: return spec.position
	return Vector3(AISLE_X,0,FRONT_Z+1.4)

static func _base_catalogue() -> Array:
	return [
		{"id":"sofa","title":"Диван на двоих","stage":"small","position":Vector3(6.5,0,14.7),"yaw":0.0},
		{"id":"television","title":"Телевизор с тумбой","stage":"small","position":Vector3(6.5,0,11.3),"yaw":PI},
		{"id":"rocking_chair","title":"Кресло-качалка","stage":"small","position":Vector3(4.55,0,18.5),"yaw":-PI/2},
		{"id":"foosball","title":"Настольный футбол","stage":"medium","position":Vector3(14.0,0,13.9),"yaw":0.0},
		{"id":"arcade","title":"Аркадный автомат","stage":"medium","position":Vector3(16.6,0,11.8),"yaw":PI},
		{"id":"table_tennis","title":"Настольный теннис","stage":"large","position":Vector3(14.0,0,18.8),"yaw":0.0},
		{"id":"board_games","title":"Стол настольных игр","stage":"medium","position":Vector3(6.7,0,21.0),"yaw":0.0},
		{"id":"bookcase","title":"Книжный стеллаж","stage":"small","position":Vector3(3.3,0,21.0),"yaw":-PI/2},
		{"id":"beanbag","title":"Кресло-мешок","stage":"small","position":Vector3(8.2,0,18.6),"yaw":PI},
		{"id":"tea_station","title":"Чайный уголок","stage":"medium","position":Vector3(13.5,0,22.6),"yaw":0.0},
		{"id":"jukebox","title":"Музыкальный автомат","stage":"large","position":Vector3(17.1,0,16.2),"yaw":PI/2},
		{"id":"aquarium","title":"Аквариум","stage":"large","position":Vector3(3.6,0,16.6),"yaw":-PI/2},
		{"id":"plants","title":"Крупные растения","stage":"small","position":Vector3(3.7,0,11.5),"yaw":0.0},
		{"id":"floor_lamp","title":"Торшер","stage":"small","position":Vector3(4.2,0,19.8),"yaw":0.0},
		{"id":"snack_fridge","title":"Холодильник с перекусами","stage":"medium","position":Vector3(16.8,0,22.65),"yaw":0.0}
	]

static func slot(id: String, item: String, point: Vector3, approach: Vector3, yaw: float, pose: String, activity: String) -> Dictionary:
	return {"id":id,"item":item,"position":point,"approach":approach,"yaw":yaw,"pose":pose,"activity":activity,"quality":1.0}

static func activity_slots(tier := 2, owned: Array = []) -> Array:
	var result: Array=[]
	var installed: Array=[]
	for spec in catalogue(tier,owned): installed.append(spec.id)
	var shifts:=offsets(tier)
	for spot in _base_slots():
		if spot.item not in installed: continue
		var shift: Vector3=shifts.get(spot.item,Vector3.ZERO)
		spot.position+=SHIFT+shift
		spot.approach+=SHIFT+shift
		result.append(spot)
	return result

static func _base_slots() -> Array:
	# Interleave areas so even a small crew makes several corners feel inhabited.
	return [
		slot("sofa_left","sofa",Vector3(5.95,0.0,14.45),Vector3(5.95,0,13.65),0,"chat","Болтает на диване"),
		slot("football_left","foosball",Vector3(12.85,0,13.9),Vector3(12.85,0,13.9),-PI/2,"foosball","Играет в настольный футбол"),
		slot("football_right","foosball",Vector3(15.15,0,13.9),Vector3(15.15,0,13.9),PI/2,"foosball","Играет в настольный футбол"),
		slot("rocker","rocking_chair",Vector3(4.55,-0.10,18.5),Vector3(5.6,0,18.5),-PI/2,"rock","Качается в кресле"),
		slot("tea_left","tea_station",Vector3(12.8,0.10,21.55),Vector3(12.8,0,20.95),PI,"tea","Пьёт чай"),
		slot("arcade_player","arcade",Vector3(16.6,0,12.85),Vector3(16.6,0,12.85),0,"arcade","Проходит ещё один уровень"),
		slot("board_left","board_games",Vector3(5.5,-0.14,21.0),Vector3(4.8,0,21.0),-PI/2,"board","Играет в настолку"),
		slot("board_right","board_games",Vector3(7.9,-0.14,21.0),Vector3(8.65,0,21.0),PI/2,"board","Обдумывает ход"),
		slot("ping_front","table_tennis",Vector3(14,0,16.82),Vector3(14,0,16.82),PI,"pingpong","Играет в пинг-понг"),
		slot("ping_back","table_tennis",Vector3(14,0,20.78),Vector3(14,0,20.78),0,"pingpong","Играет в пинг-понг"),
		slot("beanbag_seat","beanbag",Vector3(8.2,-0.10,18.6),Vector3(8.2,0,19.5),PI,"relax","Отдыхает в кресле-мешке"),
		slot("aquarium_viewer","aquarium",Vector3(4.65,0,16.6),Vector3(4.65,0,16.6),PI/2,"fish","Наблюдает за рыбками"),
		slot("book_reader","bookcase",Vector3(4.25,0,22.3),Vector3(4.25,0,22.3),PI/2,"read","Листает книгу"),
		slot("music_listener","jukebox",Vector3(16,0,16.2),Vector3(16,0,16.2),-PI/2,"music","Слушает музыку"),
		slot("tea_right","tea_station",Vector3(14.2,0.10,21.55),Vector3(14.2,0,20.95),PI,"tea","Пьёт чай"),
		slot("sofa_right","sofa",Vector3(7.05,0.0,14.45),Vector3(7.05,0,13.65),0,"chat","Смеётся с соседом"),
		slot("board_front","board_games",Vector3(6.7,-0.14,19.8),Vector3(6.7,0,19.1),PI,"board","Играет в настолку"),
		slot("board_back","board_games",Vector3(6.7,-0.14,22.2),Vector3(6.7,0,22.9),0,"board","Обдумывает ход"),
		slot("snack_break","snack_fridge",Vector3(16.8,0,21.5),Vector3(16.8,0,21.5),PI,"snack","Выбирает перекус")
	]

static func obstacles(tier := 2, owned: Array = []) -> Array:
	# Footprints also generate the furniture collision proxies.
	var result: Array = [
		Rect2(5.25,14.10,2.50,1.22), Rect2(5.12,10.92,2.76,0.74),
		Rect2(5.60,12.35,1.80,0.80), Rect2(4.00,17.94,1.10,1.12),
		Rect2(13.46,12.95,1.08,1.90), Rect2(16.12,11.33,0.96,0.94),
		Rect2(13.24,17.43,1.52,2.74), Rect2(6.12,20.42,1.16,1.16),
		Rect2(3.10,20.02,0.40,1.96), Rect2(7.60,18.04,1.20,1.12),
		Rect2(11.90,22.20,3.20,0.80), Rect2(16.72,15.72,0.76,0.96),
		Rect2(3.20,15.70,0.72,1.80), Rect2(3.37,11.17,0.66,0.66),
		Rect2(3.95,19.55,0.50,0.50), Rect2(16.34,22.20,0.92,0.90)
	]
	for point in [Vector2(5.5,21.0),Vector2(7.9,21.0),Vector2(6.7,19.8),Vector2(6.7,22.2),Vector2(12.8,21.55),Vector2(14.2,21.55)]:
		result.append(Rect2(point-Vector2(0.25,0.25),Vector2(0.50,0.50)))
	var ids:=obstacle_items()
	var installed: Array=[]
	for spec in catalogue(tier,owned): installed.append(spec.id)
	var shifted: Array=[]
	var shifts:=offsets(tier)
	for i in range(result.size()):
		if ids[i] not in installed: continue
		var shift: Vector3=shifts.get(ids[i],Vector3.ZERO)
		var rect: Rect2=result[i]
		rect.position+=Vector2(SHIFT.x+shift.x,SHIFT.z+shift.z)
		shifted.append(rect)
	if "plants" in installed:
		shifted.append(Rect2(8.56+SHIFT.x,11.26+SHIFT.z,0.48,0.48))
		shifted.append(Rect2(minf(16.81+SHIFT.x,right_x(tier)-0.55),back_z(tier)-1.54,0.48,0.48))
	var bed:=bed_center(tier)
	shifted.append(Rect2(bed.x-1.325,bed.z-0.625,2.65,1.25))
	return shifted

static func obstacle_items() -> Array:
	return ["sofa","television","sofa","rocking_chair","foosball","arcade","table_tennis","board_games","bookcase","beanbag","tea_station","jukebox","aquarium","plants","floor_lamp","snack_fridge","board_games","board_games","board_games","board_games","tea_station","tea_station"]

static func obstacle_heights(tier: int, owned: Array) -> Array:
	var installed: Array=[]
	for spec in catalogue(tier,owned): installed.append(spec.id)
	var result: Array=[]
	var ids:=obstacle_items()
	for i in range(ids.size()):
		if ids[i] not in installed: continue
		result.append(2.0 if i in [5,8,11,15] else 0.44 if i in [16,17,18,19] else 0.70 if i in [20,21] else 0.85)
	if "plants" in installed: result.append(0.85); result.append(0.85)
	result.append(0.54)
	return result

static func walkable(point: Vector3, blockers: Array, tier := 2) -> bool:
	if point.x<LEFT_X+0.44 or point.x>right_x(tier)-0.44 or point.z<FRONT_Z+0.48 or point.z>back_z(tier)-0.48: return false
	for rect: Rect2 in blockers:
		if rect.grow(WALK_MARGIN).has_point(Vector2(point.x,point.z)): return false
	return true

static func grid_point(cell: Vector2i) -> Vector3:
	return Vector3(LEFT_X+0.50+cell.x*GRID_STEP,0,FRONT_Z+0.65+cell.y*GRID_STEP)

static func nearest_cell(point: Vector3, blockers: Array, tier := 2) -> Vector2i:
	var best := Vector2i(-1,-1)
	var distance := INF
	for x in range(38):
		for z in range(42):
			var cell := Vector2i(x,z)
			var candidate := grid_point(cell)
			var next_distance := point.distance_squared_to(candidate)
			if next_distance<distance and walkable(candidate,blockers,tier):
				best=cell
				distance=next_distance
	return best

static func path_between(start_point: Vector3, target: Vector3, tier := 2, owned: Array = []) -> Array:
	var blockers := obstacles(tier,owned)
	var start := nearest_cell(start_point,blockers,tier)
	var goal := nearest_cell(target,blockers,tier)
	if start.x<0 or goal.x<0: return []
	var frontier: Array[Vector2i] = [start]
	var previous := {start:start}
	var cursor := 0
	while cursor<frontier.size() and not previous.has(goal):
		var cell: Vector2i=frontier[cursor]
		cursor+=1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+offset
			if next.x<0 or next.x>=38 or next.y<0 or next.y>=42 or previous.has(next): continue
			if not walkable(grid_point(next),blockers,tier): continue
			previous[next]=cell
			frontier.append(next)
	if not previous.has(goal): return []
	var reverse_path: Array = [target]
	var cell := goal
	while cell!=start:
		reverse_path.append(grid_point(cell))
		cell=previous[cell]
	reverse_path.append(grid_point(start))
	reverse_path.reverse()
	# Keep corners; avoid a turn at every grid sample.
	var result: Array = [start_point]
	for i in range(reverse_path.size()):
		if Vector3(result.back()).distance_to(reverse_path[i])<0.01: continue
		if i==0 or i==reverse_path.size()-1:
			result.append(reverse_path[i])
		else:
			var before: Vector3=reverse_path[i]-reverse_path[i-1]
			var after: Vector3=reverse_path[i+1]-reverse_path[i]
			if before.normalized().dot(after.normalized())<0.999: result.append(reverse_path[i])
	return result

static func approach_path(target: Vector3, tier := 2, owned: Array = []) -> Array:
	return path_between(ENTRANCE,target,tier,owned)

static func training_viewer_spots(count: int, tier := 2, owned: Array = []) -> Array:
	var wanted:=maxi(0,count)
	if wanted==0: return []
	var blockers:=obstacles(tier,owned)
	var candidates: Array=[]
	var television:=item_position("television",tier)
	var z:=FRONT_Z+0.75
	while z<=back_z(tier)-0.55:
		var x:=LEFT_X+0.85
		while x<=right_x(tier)-0.55:
			var point:=Vector3(x,0,z)
			if point.distance_to(ENTRANCE)>1.25 and walkable(point,blockers,tier):
				candidates.append(point)
			x+=0.55
		z+=0.55
	candidates.sort_custom(func(a,b):
		var a_score: float=Vector3(a).distance_squared_to(television)+absf(float(a.x)-television.x)*0.08
		var b_score: float=Vector3(b).distance_squared_to(television)+absf(float(b.x)-television.x)*0.08
		return a_score<b_score)
	var result: Array=[]
	for raw in candidates:
		var point:=Vector3(raw)
		var separated:=true
		for chosen in result:
			if point.distance_to(Vector3(chosen))<0.72:
				separated=false
				break
		if not separated: continue
		result.append(point)
		if result.size()>=wanted: break
	if result.size()<wanted:
		for index in range(wanted*3):
			var fallback: Dictionary=overflow_slot(index,tier,owned)
			var point:=Vector3(fallback.approach)
			var separated:=true
			for chosen in result:
				if point.distance_to(Vector3(chosen))<0.55:
					separated=false
					break
			if separated: result.append(point)
			if result.size()>=wanted: break
	return result

static func overflow_slot(index: int, tier := 2, owned: Array = []) -> Dictionary:
	var blockers:=obstacles(tier,owned)
	var ring: Array=[]
	for center_z in [17.4,20.0,22.6,25.2,27.7]:
		if center_z>back_z(tier)-1.25: continue
		var center:=Vector3(AISLE_X,0,center_z)
		for spoke in range(6):
			var angle:=TAU*float(spoke)/6.0
			var point:=center+Vector3(cos(angle)*1.08,0,sin(angle)*0.82)
			if walkable(point,blockers,tier): ring.append({"point":point,"center":center})
	if not ring.is_empty():
		var chosen: Dictionary=ring[index%ring.size()]
		var base: Vector3=chosen.point
		var layer: int=int(index/ring.size())
		var point:=base+Vector3(0,layer*0.34,0)
		var toward: Vector3=Vector3(chosen.center)-base
		var yaw: float=atan2(-toward.x,-toward.z)
		var activity: String=["Перекидывается мячиком","Болтает на ковре","Смеётся в кружке","Слушает байку"][index%4]
		return slot("overflow_%d"%index,"floor",point,base,yaw,"floor",activity)
	var candidates: Array=[]
	for z in range(15,30):
		for x in [maxf(LEFT_X+0.9,AISLE_X-1.3),AISLE_X,minf(right_x(tier)-0.7,AISLE_X+3.1)]:
			var point:=Vector3(x,0,float(z)+0.25)
			if walkable(point,blockers,tier): candidates.append(point)
	if candidates.is_empty(): candidates.append(ENTRANCE)
	var base: Vector3=candidates[index%candidates.size()]
	var layer: int=int(index/candidates.size())
	var point:=base+Vector3(0,layer*0.34,0)
	var toward:=Vector3(minf(AISLE_X,right_x(tier)-1.0),0,clampf(base.z,FRONT_Z+1.0,back_z(tier)-1.3))-base
	var yaw: float=atan2(-toward.x,-toward.z) if toward.length()>0.05 else float(index%4)*PI/2.0
	return slot("overflow_%d"%index,"floor",point,base,yaw,"floor","Болтает на ковре")

static func rest_spot(index: int, tier := 2, owned: Array = []) -> Dictionary:
	var slots:=activity_slots(tier,owned)
	return slots[index].duplicate(true) if index<slots.size() else overflow_slot(index-slots.size(),tier,owned)

static func sleep_spot(leisure: Dictionary, identity: int, tier: int) -> Dictionary:
	var spot: Dictionary=leisure.duplicate(true)
	spot.sleep_rotation=Vector3.ZERO
	spot.sleep_kind="standing"
	spot.activity="Спит стоя"
	if str(leisure.item)!="sofa" and posmod(identity,5)==2:
		spot.position=Vector3(leisure.approach)+Vector3(0,1.72,0)
		spot.sleep_kind="headstand"
		spot.activity="Спит на голове"
		return spot
	match str(leisure.item):
		"sofa":
			var layer: int=["sofa_left","sofa_right"].find(leisure.id)
			spot.position=item_position("sofa",tier)+Vector3(-0.86,0.72+maxi(0,layer)*0.31,-0.10)
			spot.sleep_kind="back"
			spot.activity="Спит на спине поверх соседа" if layer>0 else "Спит на спине на диване"
		"board_games", "tea_station":
			var layer: int=0
			for other in _base_slots():
				if other.id==leisure.id: break
				if other.item==leisure.item: layer+=1
			spot.position=item_position(leisure.item,tier)+Vector3(-0.6,1.03+layer*0.30,0)
			spot.sleep_rotation=Vector3(0,0,-PI/2)
			spot.sleep_kind="lying"
			spot.activity="Спит на столе"
		"rocking_chair","beanbag":
			spot.sleep_kind="seated"
			spot.activity="Задремал в кресле"
		"arcade","bookcase","aquarium","snack_fridge":
			spot.sleep_rotation=Vector3(-0.12,float(leisure.yaw),0.06)
			spot.activity="Спит, уткнувшись носом"
		_:
			if identity%2==0:
				spot.position=Vector3(leisure.approach)+Vector3(0,0.17,0)
				spot.sleep_rotation=Vector3(PI/2,PI/2,0)
				spot.sleep_kind="lying"
				spot.activity="Спит на полу"
			else:
				spot.sleep_rotation=Vector3(0,float(leisure.yaw),0.08)
	return spot
