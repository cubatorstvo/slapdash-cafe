extends Node3D
## Laboratory and expanded rest room live behind the cafe, opposite the cooking stations.
const Props = preload("res://scripts/props.gd")

const CAFE_X_MIN := -11.8
const CAFE_X_MAX := 17.8
const CAFE_BACK_Z := 10.6
const DIVIDER_X := 2.9
const LAB_X_MIN := -5.0
const LAB_X_MAX := DIVIDER_X
const LAB_BACK_Z := 16.2
const REST_X_MIN := DIVIDER_X
const REST_X_MAX := CAFE_X_MAX
const REST_BACK_Z := 18.5
const LAB_DOOR_X := -1.1
const REST_DOOR_X := 10.4
const DOOR_WIDTH := 1.8
const DOOR_HEIGHT := 2.55
const DOOR_TRIGGER_RADIUS := 2.35
const WALL_HEIGHT := 4.7
const WALL_Y := 2.3
const WALL_THICKNESS := 0.18
const LAB_ORIGIN := Vector3(-1.1, 0.0, 5.0)
const LAB_ROTATION_Y := 0.0
const LAB_DOOR_CAFE := Vector3(LAB_DOOR_X, 0.0, 9.75)
const LAB_DOOR_ROOM := Vector3(LAB_DOOR_X, 0.0, 11.45)
const REST_DOOR_CAFE := Vector3(REST_DOOR_X, 0.0, 9.75)
const REST_DOOR_ROOM := Vector3(REST_DOOR_X, 0.0, 11.45)
const REST_AREA := (REST_X_MAX - REST_X_MIN) * (REST_BACK_Z - CAFE_BACK_Z)
const PLAYER_BED_COUNT := 4

var game: Node3D
var doors := {}

static func lab_world(local_point: Vector3) -> Vector3:
	return Transform3D(Basis(Vector3.UP, LAB_ROTATION_Y), LAB_ORIGIN) * local_point

static func place_lab(node: Node3D) -> void:
	node.position = LAB_ORIGIN
	node.rotation.y = LAB_ROTATION_Y

static func player_bed_center(index: int) -> Vector3:
	var centers := [Vector3(4.7,0.48,17.15),Vector3(7.95,0.48,17.15),Vector3(11.20,0.48,17.15),Vector3(14.45,0.48,17.15)]
	return centers[clampi(index,0,centers.size()-1)]

static func player_sleep_position(index: int) -> Vector3:
	var center := player_bed_center(index)
	return Vector3(center.x,0.66,center.z)

static func player_sleep_yaw(_index: int) -> float:
	return PI / 2.0

static func player_bed_exit(index: int) -> Vector3:
	var center := player_bed_center(index)
	return Vector3(center.x,0.02,15.65)

static func rest_spot(index: int) -> Dictionary:
	var spots := [
		{"position":Vector3(4.65,0.62,12.75),"quality":1.10,"pose":"bed"},
		{"position":Vector3(7.35,0.62,12.75),"quality":1.08,"pose":"bed"},
		{"position":Vector3(10.10,0.72,12.80),"quality":1.03,"pose":"bench"},
		{"position":Vector3(13.05,0.80,12.85),"quality":1.00,"pose":"table"},
		{"position":Vector3(5.25,0.06,14.45),"quality":0.96,"pose":"floor"},
		{"position":Vector3(8.05,0.06,14.45),"quality":0.94,"pose":"floor"},
		{"position":Vector3(4.65,0.92,12.75),"quality":0.92,"pose":"stack"},
		{"position":Vector3(15.55,0.0,13.25),"quality":0.90,"pose":"stand"}
	]
	if index < spots.size(): return spots[index].duplicate(true)
	var layer := 1 + int((index - spots.size()) / 2)
	var side: float = -1.0 if index % 2 == 0 else 1.0
	return {"position":Vector3(4.65 + side * 0.18,0.92 + layer * 0.28,12.75),"quality":0.90,"pose":"stack"}

static func build_shell(parent: Node3D) -> void:
	var wall_color := Color("2e5355")
	var lab_width := LAB_X_MAX-LAB_X_MIN
	var lab_depth := LAB_BACK_Z-CAFE_BACK_Z
	var rest_width := REST_X_MAX-REST_X_MIN
	var rest_depth := REST_BACK_Z-CAFE_BACK_Z
	Props.box(parent,Vector3(lab_width,0.09,lab_depth),Vector3((LAB_X_MIN+LAB_X_MAX)*0.5,-0.05,(CAFE_BACK_Z+LAB_BACK_Z)*0.5),Color("60756f"))
	Props.box(parent,Vector3(rest_width,0.09,rest_depth),Vector3((REST_X_MIN+REST_X_MAX)*0.5,-0.05,(CAFE_BACK_Z+REST_BACK_Z)*0.5),Color("776f60"))
	Props.collision_box(parent,Vector3(lab_width,0.2,lab_depth),Vector3((LAB_X_MIN+LAB_X_MAX)*0.5,-0.10,(CAFE_BACK_Z+LAB_BACK_Z)*0.5))
	Props.collision_box(parent,Vector3(rest_width,0.2,rest_depth),Vector3((REST_X_MIN+REST_X_MAX)*0.5,-0.10,(CAFE_BACK_Z+REST_BACK_Z)*0.5))
	_build_cafe_back_wall(parent,wall_color)
	Props.solid_box(parent,Vector3(WALL_THICKNESS,WALL_HEIGHT,lab_depth),Vector3(LAB_X_MIN,WALL_Y,(CAFE_BACK_Z+LAB_BACK_Z)*0.5),wall_color)
	Props.solid_box(parent,Vector3(lab_width,WALL_HEIGHT,WALL_THICKNESS),Vector3((LAB_X_MIN+LAB_X_MAX)*0.5,WALL_Y,LAB_BACK_Z),wall_color)
	Props.solid_box(parent,Vector3(WALL_THICKNESS,WALL_HEIGHT,REST_BACK_Z-CAFE_BACK_Z),Vector3(DIVIDER_X,WALL_Y,(CAFE_BACK_Z+REST_BACK_Z)*0.5),wall_color)
	Props.solid_box(parent,Vector3(WALL_THICKNESS,WALL_HEIGHT,rest_depth),Vector3(REST_X_MAX,WALL_Y,(CAFE_BACK_Z+REST_BACK_Z)*0.5),wall_color)
	Props.solid_box(parent,Vector3(rest_width,WALL_HEIGHT,WALL_THICKNESS),Vector3((REST_X_MIN+REST_X_MAX)*0.5,WALL_Y,REST_BACK_Z),wall_color)
	var lab_sign := Props.text(parent,"ЛАБОРАТОРИЯ",Vector3(LAB_DOOR_X,3.12,CAFE_BACK_Z-0.24),24,Color("edd09d"))
	lab_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab_sign.pixel_size = 0.005
	var rest_sign := Props.text(parent,"КОМНАТА ОТДЫХА",Vector3(REST_DOOR_X,3.12,CAFE_BACK_Z-0.24),22,Color("e7c891"))
	rest_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rest_sign.pixel_size = 0.005
	_build_rest_furniture(parent)
	for spec in [[Vector3((LAB_X_MIN+LAB_X_MAX)*0.5,3.25,13.35),Color("b7e0cb")],[Vector3(7.0,3.25,13.6),Color("ffd29a")],[Vector3(13.5,3.25,16.0),Color("ffd29a")]]:
		var light := OmniLight3D.new()
		parent.add_child(light)
		light.position = Vector3(spec[0])
		light.light_color = Color(spec[1])
		light.light_energy = 0.85
		light.omni_range = 6.5

static func _build_cafe_back_wall(parent: Node3D, color: Color) -> void:
	var openings := [Vector2(LAB_DOOR_X-DOOR_WIDTH*0.5,LAB_DOOR_X+DOOR_WIDTH*0.5),Vector2(REST_DOOR_X-DOOR_WIDTH*0.5,REST_DOOR_X+DOOR_WIDTH*0.5)]
	var cursor: float = CAFE_X_MIN
	for opening in openings:
		if opening.x > cursor:
			Props.solid_box(parent,Vector3(opening.x-cursor,WALL_HEIGHT,WALL_THICKNESS),Vector3((cursor+opening.x)*0.5,WALL_Y,CAFE_BACK_Z),color)
		cursor = opening.y
	if cursor < CAFE_X_MAX:
		Props.solid_box(parent,Vector3(CAFE_X_MAX-cursor,WALL_HEIGHT,WALL_THICKNESS),Vector3((cursor+CAFE_X_MAX)*0.5,WALL_Y,CAFE_BACK_Z),color)
	for door_x in [LAB_DOOR_X,REST_DOOR_X]:
		var lintel_height := WALL_HEIGHT-DOOR_HEIGHT
		Props.solid_box(parent,Vector3(DOOR_WIDTH,lintel_height,WALL_THICKNESS),Vector3(door_x,DOOR_HEIGHT+lintel_height*0.5-0.05,CAFE_BACK_Z),color)
		for side in [-1.0,1.0]:
			Props.box(parent,Vector3(0.13,DOOR_HEIGHT+0.20,0.28),Vector3(door_x+float(side)*(DOOR_WIDTH*0.5+0.05),(DOOR_HEIGHT+0.20)*0.5,CAFE_BACK_Z-0.04),Color("bd9667"))

static func _build_rest_furniture(parent: Node3D) -> void:
	for x in [4.65,7.35]:
		Props.solid_box(parent,Vector3(2.15,0.24,0.88),Vector3(x,0.28,12.75),Color("80634f"))
		Props.box(parent,Vector3(1.75,0.16,0.72),Vector3(x,0.46,12.75),Color("b9a477"))
		Props.box(parent,Vector3(0.48,0.12,0.65),Vector3(x-0.62,0.58,12.75),Color("e5d9b8"))
	Props.solid_box(parent,Vector3(2.0,0.42,0.62),Vector3(10.10,0.25,12.80),Color("637b70"))
	Props.solid_box(parent,Vector3(1.1,0.78,0.72),Vector3(13.05,0.39,12.85),Color("8d6b50"))
	for index in range(PLAYER_BED_COUNT):
		var center := player_bed_center(index)
		Props.solid_box(parent,Vector3(2.35,0.28,1.05),Vector3(center.x,0.26,center.z),Color("80634f"))
		Props.box(parent,Vector3(2.05,0.18,0.87),Vector3(center.x,0.47,center.z),Color("c1ae82"))
		Props.box(parent,Vector3(0.62,0.13,0.78),Vector3(center.x-0.68,0.61,center.z),Color("e7dcc0"))

func setup(owner_game: Node3D) -> void:
	game = owner_game
	_build_door("lab",LAB_DOOR_X,Color("87a99f"))
	_build_door("rest",REST_DOOR_X,Color("8bb0a4"))

func _build_door(id: String, door_x: float, color: Color) -> void:
	var root := Node3D.new()
	root.name = "%sDoor" % id.capitalize()
	add_child(root)
	root.position = Vector3(door_x,0,CAFE_BACK_Z-0.015)
	var leaves: Array = []
	for side in [-1.0,1.0]:
		var leaf := Node3D.new()
		root.add_child(leaf)
		var closed_x: float = float(side) * DOOR_WIDTH * 0.25
		var open_x: float = float(side) * DOOR_WIDTH * 0.69
		leaf.position = Vector3(closed_x,DOOR_HEIGHT*0.5,0)
		Props.solid_box(leaf,Vector3(DOOR_WIDTH*0.46,DOOR_HEIGHT,0.11),Vector3.ZERO,color)
		var inset := Props.box(leaf,Vector3(DOOR_WIDTH*0.32,0.72,0.025),Vector3(0,0.18,-0.065),Color("b8d0c7"))
		inset.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inset.material_override.albedo_color.a = 0.45
		leaves.append({"node":leaf,"closed":closed_x,"open":open_x})
	doors[id] = {"root":root,"leaves":leaves,"amount":0.0,"hold":0.0}

func _physics_process(delta: float) -> void:
	advance_doors(delta)

func advance_doors(delta: float) -> void:
	if game == null: return
	for id in doors:
		var door: Dictionary = doors[id]
		var root: Node3D = door.root
		if _someone_near(root.global_position): door.hold = 0.85
		else: door.hold = maxf(0.0,float(door.hold)-delta)
		var target: float = 1.0 if float(door.hold)>0.0 else 0.0
		door.amount = move_toward(float(door.amount),target,delta*4.2)
		for leaf_data in door.leaves:
			var leaf: Node3D = leaf_data.node
			leaf.position.x = lerpf(float(leaf_data.closed),float(leaf_data.open),float(door.amount))

func door_openness(id: String) -> float:
	return float(doors.get(id,{}).get("amount",0.0))

func sleep_target(camera: Camera3D, peer: int) -> Dictionary:
	if game == null or game.service.progress.shift != "night" or game.session.local_sleeping(): return {}
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	for index in range(PLAYER_BED_COUNT):
		var center := player_bed_center(index)
		var box := AABB(center-Vector3(1.20,0.45,0.58),Vector3(2.40,0.90,1.16))
		var hit = box.intersects_ray(origin,direction)
		if hit == null or origin.distance_to(hit)>4.2: continue
		var occupant: int = int(game.session.sleeping_peer_for_bed(index))
		if occupant > 0 and occupant != peer: return {"hint":"Кровать занята"}
		return {"action":"sleep","bed":index,"hint":"(E) Лечь спать · "+game.session.sleep_status_text()}
	return {}

func settle_player_avatar(actor: Node3D, bed_index: int) -> void:
	actor.global_position = player_sleep_position(bed_index)
	actor.rotation = Vector3.ZERO
	actor.rotation.y = player_sleep_yaw(bed_index)
	actor.rotation.z = PI/2
	actor.book.set_reading(false)
	actor.notebook.hide()
	actor.head.rotation=Vector3.ZERO
	for leg in actor.legs: leg.rotation.x=0

func _someone_near(point: Vector3) -> bool:
	if is_instance_valid(game.player) and _flat_distance(game.player.global_position,point) < DOOR_TRIGGER_RADIUS: return true
	if is_instance_valid(game.session):
		for pose in game.session.player_poses.values():
			var raw: Array = pose.get("position",[])
			if raw.size()==3 and _flat_distance(Vector3(raw[0],raw[1],raw[2]),point) < DOOR_TRIGGER_RADIUS: return true
	for actor in get_tree().get_nodes_in_group("automatic_door_actor"):
		if actor is Node3D and is_instance_valid(actor) and _flat_distance(actor.global_position,point) < DOOR_TRIGGER_RADIUS: return true
	return false

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
