extends RefCounted
## Shared geometry and activity anchors for the fully furnished lounge preview.
## Expansion stages are catalogue metadata; the current playtest uses the largest shell.
const ROOM_STAGES := [
	{"id":"small","back_z":18.5},
	{"id":"medium","back_z":22.0},
	{"id":"large","back_z":27.0}
]
const MAX_BACK_Z := 27.0
const AISLE_X := 10.4
const ENTRANCE := Vector3(10.4,0,11.45)
const BEDS_Z := 25.7
const GRID_STEP := 0.40
const WALK_MARGIN := 0.34

static func catalogue() -> Array:
	return [
		{"id":"sofa","title":"Диван на троих","stage":"small","position":Vector3(6.5,0,14.7),"yaw":0.0},
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

static func activity_slots() -> Array:
	# Interleave areas so even a small crew makes several corners feel inhabited.
	return [
		slot("sofa_left","sofa",Vector3(5.62,-0.10,14.45),Vector3(5.62,0,13.65),0,"watch","Смотрит телевизор"),
		slot("football_left","foosball",Vector3(12.85,0,13.9),Vector3(12.85,0,13.9),-PI/2,"foosball","Играет в настольный футбол"),
		slot("football_right","foosball",Vector3(15.15,0,13.9),Vector3(15.15,0,13.9),PI/2,"foosball","Играет в настольный футбол"),
		slot("rocker","rocking_chair",Vector3(4.55,-0.10,18.5),Vector3(5.6,0,18.5),-PI/2,"rock","Качается в кресле"),
		slot("tea_left","tea_station",Vector3(12.8,0.10,21.55),Vector3(12.8,0,20.95),PI,"tea","Пьёт чай"),
		slot("arcade_player","arcade",Vector3(16.6,0,12.85),Vector3(16.6,0,12.85),0,"arcade","Проходит ещё один уровень"),
		slot("board_left","board_games",Vector3(5.5,-0.14,21.0),Vector3(4.8,0,21.0),-PI/2,"board","Играет в настолку"),
		slot("board_right","board_games",Vector3(7.9,-0.14,21.0),Vector3(8.65,0,21.0),PI/2,"board","Обдумывает ход"),
		slot("ping_front","table_tennis",Vector3(14,0,16.82),Vector3(14,0,16.82),PI,"pingpong","Играет в пинг-понг"),
		slot("ping_back","table_tennis",Vector3(14,0,20.78),Vector3(14,0,20.78),0,"pingpong","Играет в пинг-понг"),
		slot("sofa_middle","sofa",Vector3(6.5,-0.10,14.45),Vector3(6.5,0,13.65),0,"watch","Смотрит телевизор"),
		slot("beanbag_seat","beanbag",Vector3(8.2,-0.10,18.6),Vector3(8.2,0,19.5),PI,"relax","Отдыхает в кресле-мешке"),
		slot("aquarium_viewer","aquarium",Vector3(4.65,0,16.6),Vector3(4.65,0,16.6),PI/2,"fish","Наблюдает за рыбками"),
		slot("book_reader","bookcase",Vector3(4.25,0,22.3),Vector3(4.25,0,22.3),PI/2,"read","Листает книгу"),
		slot("music_listener","jukebox",Vector3(16,0,16.2),Vector3(16,0,16.2),-PI/2,"music","Слушает музыку"),
		slot("tea_right","tea_station",Vector3(14.2,0.10,21.55),Vector3(14.2,0,20.95),PI,"tea","Пьёт чай"),
		slot("sofa_right","sofa",Vector3(7.38,-0.10,14.45),Vector3(7.38,0,13.65),0,"watch","Смотрит телевизор"),
		slot("board_front","board_games",Vector3(6.7,-0.14,19.8),Vector3(6.7,0,19.1),PI,"board","Играет в настолку"),
		slot("board_back","board_games",Vector3(6.7,-0.14,22.2),Vector3(6.7,0,22.9),0,"board","Обдумывает ход"),
		slot("snack_break","snack_fridge",Vector3(16.8,0,21.5),Vector3(16.8,0,21.5),PI,"snack","Выбирает перекус")
	]

static func obstacles() -> Array:
	# Footprints also generate the furniture collision proxies.
	var result: Array = [
		Rect2(4.87,14.10,3.26,1.22), Rect2(5.12,10.92,2.76,0.74),
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
	result.append(Rect2(3.15,23.48,6.10,0.14))
	result.append(Rect2(11.55,23.48,6.00,0.14))
	result.append(Rect2(8.56,11.26,0.48,0.48))
	result.append(Rect2(16.81,25.46,0.48,0.48))
	for x in [4.7,7.95,11.2,14.45]:
		result.append(Rect2(x-1.175,BEDS_Z-0.525,2.35,1.05))
	return result

static func walkable(point: Vector3, blockers: Array) -> bool:
	if point.x<3.34 or point.x>17.36 or point.z<11.18 or point.z>26.52: return false
	for rect: Rect2 in blockers:
		if rect.grow(WALK_MARGIN).has_point(Vector2(point.x,point.z)): return false
	return true

static func grid_point(cell: Vector2i) -> Vector3:
	return Vector3(3.4+cell.x*GRID_STEP,0,11.25+cell.y*GRID_STEP)

static func nearest_cell(point: Vector3, blockers: Array) -> Vector2i:
	var best := Vector2i(-1,-1)
	var distance := INF
	for x in range(35):
		for z in range(39):
			var cell := Vector2i(x,z)
			var candidate := grid_point(cell)
			var next_distance := point.distance_squared_to(candidate)
			if next_distance<distance and walkable(candidate,blockers):
				best=cell
				distance=next_distance
	return best

static func approach_path(target: Vector3) -> Array:
	var blockers := obstacles()
	var start := nearest_cell(ENTRANCE,blockers)
	var goal := nearest_cell(target,blockers)
	var frontier: Array[Vector2i] = [start]
	var previous := {start:start}
	var cursor := 0
	while cursor<frontier.size() and not previous.has(goal):
		var cell: Vector2i=frontier[cursor]
		cursor+=1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+offset
			if next.x<0 or next.x>=35 or next.y<0 or next.y>=39 or previous.has(next): continue
			if not walkable(grid_point(next),blockers): continue
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
	var result: Array = [ENTRANCE]
	for i in range(reverse_path.size()):
		if i==0 or i==reverse_path.size()-1:
			result.append(reverse_path[i])
		else:
			var before: Vector3=reverse_path[i]-reverse_path[i-1]
			var after: Vector3=reverse_path[i+1]-reverse_path[i]
			if before.normalized().dot(after.normalized())<0.999: result.append(reverse_path[i])
	return result

static func overflow_slot(index: int) -> Dictionary:
	var blockers := obstacles()
	var candidates: Array = []
	for z in range(12,24):
		for x in [9.1,11.5,16.4]:
			var point:=Vector3(x,0,float(z)+0.25)
			if walkable(point,blockers): candidates.append(point)
	if index>=candidates.size():
		# Unlimited crews share roomy floor perches in distinct vertical layers.
		var base: Vector3=candidates[index%candidates.size()]
		return slot("overflow_%d"%index,"floor",base+Vector3(0,(index/candidates.size())*0.34,0),base,0,"floor","Устроился на ковре")
	var point: Vector3=candidates[index]
	return slot("overflow_%d"%index,"floor",point,point,0,"floor","Устроился на ковре")

static func rest_spot(index: int) -> Dictionary:
	var slots:=activity_slots()
	return slots[index].duplicate(true) if index<slots.size() else overflow_slot(index-slots.size())
