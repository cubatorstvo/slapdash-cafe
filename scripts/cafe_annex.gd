extends Node3D
## Laboratory and rest room live in one continuous world, in an annex west of the cafe.
const Props = preload("res://scripts/props.gd")

const CAFE_WEST_X := -11.8
const ANNEX_WEST_X := -17.4
const ANNEX_CENTER_X := (CAFE_WEST_X + ANNEX_WEST_X) * 0.5
const ANNEX_WIDTH := CAFE_WEST_X - ANNEX_WEST_X
const REST_Z_MIN := -2.8
const DIVIDER_Z := 3.4
const LAB_Z_MAX := 10.4
const REST_DOOR_Z := 0.3
const LAB_DOOR_Z := 6.9
const DOOR_WIDTH := 1.8
const DOOR_HEIGHT := 2.55
const DOOR_TRIGGER_RADIUS := 2.35
const WALL_HEIGHT := 4.7
const WALL_Y := 2.3
const WALL_THICKNESS := 0.18
const LAB_ORIGIN := Vector3(-7.0, 0.0, LAB_DOOR_Z)
const LAB_ROTATION_Y := -PI / 2.0
const REST_DOOR_CAFE := Vector3(-10.95, 0.0, REST_DOOR_Z)
const REST_DOOR_ROOM := Vector3(-12.65, 0.0, REST_DOOR_Z)
const LAB_DOOR_CAFE := Vector3(-10.95, 0.0, LAB_DOOR_Z)
const LAB_DOOR_ROOM := Vector3(-12.65, 0.0, LAB_DOOR_Z)
const PLAYER_SLEEP_POINT := Vector3(-16.65, 0.82, 2.35)

var game: Node3D
var doors := {}

static func lab_world(local_point: Vector3) -> Vector3:
	return Transform3D(Basis(Vector3.UP, LAB_ROTATION_Y), LAB_ORIGIN) * local_point

static func place_lab(node: Node3D) -> void:
	node.position = LAB_ORIGIN
	node.rotation.y = LAB_ROTATION_Y

static func rest_spot(index: int) -> Dictionary:
	var spots := [
		{"position":Vector3(-16.15,0.62,-1.65),"quality":1.10,"pose":"bed"},
		{"position":Vector3(-13.55,0.62,-1.65),"quality":1.08,"pose":"bed"},
		{"position":Vector3(-16.10,0.72,0.70),"quality":1.03,"pose":"bench"},
		{"position":Vector3(-13.30,0.80,1.05),"quality":1.00,"pose":"table"},
		{"position":Vector3(-15.55,0.06,0.05),"quality":0.96,"pose":"floor"},
		{"position":Vector3(-13.75,0.06,-0.05),"quality":0.94,"pose":"floor"},
		{"position":Vector3(-16.15,0.92,-1.65),"quality":0.92,"pose":"stack"},
		{"position":Vector3(-12.55,0.0,2.35),"quality":0.90,"pose":"stand"}
	]
	if index < spots.size(): return spots[index].duplicate(true)
	var layer := 1 + int((index - spots.size()) / 2)
	var side := -1.0 if index % 2 == 0 else 1.0
	return {"position":Vector3(-16.15 + side * 0.18,0.92 + layer * 0.28,-1.65),"quality":0.90,"pose":"stack"}

static func build_shell(parent: Node3D) -> void:
	var wall_color := Color("2e5355")
	Props.box(parent,Vector3(ANNEX_WIDTH,0.09,DIVIDER_Z-REST_Z_MIN),Vector3(ANNEX_CENTER_X,-0.05,(REST_Z_MIN+DIVIDER_Z)*0.5),Color("776f60"))
	Props.box(parent,Vector3(ANNEX_WIDTH,0.09,LAB_Z_MAX-DIVIDER_Z),Vector3(ANNEX_CENTER_X,-0.05,(DIVIDER_Z+LAB_Z_MAX)*0.5),Color("60756f"))
	Props.collision_box(parent,Vector3(ANNEX_WIDTH,0.2,LAB_Z_MAX-REST_Z_MIN),Vector3(ANNEX_CENTER_X,-0.10,(REST_Z_MIN+LAB_Z_MAX)*0.5))
	Props.solid_box(parent,Vector3(WALL_THICKNESS,WALL_HEIGHT,LAB_Z_MAX-REST_Z_MIN),Vector3(ANNEX_WEST_X,WALL_Y,(REST_Z_MIN+LAB_Z_MAX)*0.5),wall_color)
	for z in [REST_Z_MIN,DIVIDER_Z,LAB_Z_MAX]:
		Props.solid_box(parent,Vector3(ANNEX_WIDTH,WALL_HEIGHT,WALL_THICKNESS),Vector3(ANNEX_CENTER_X,WALL_Y,z),wall_color)
	var openings := [Vector2(REST_DOOR_Z-DOOR_WIDTH*0.5,REST_DOOR_Z+DOOR_WIDTH*0.5),Vector2(LAB_DOOR_Z-DOOR_WIDTH*0.5,LAB_DOOR_Z+DOOR_WIDTH*0.5)]
	var cursor := -7.6
	for opening in openings:
		if opening.x > cursor:
			Props.solid_box(parent,Vector3(WALL_THICKNESS,WALL_HEIGHT,opening.x-cursor),Vector3(CAFE_WEST_X,WALL_Y,(cursor+opening.x)*0.5),wall_color)
		cursor = opening.y
	if cursor < 10.6:
		Props.solid_box(parent,Vector3(WALL_THICKNESS,WALL_HEIGHT,10.6-cursor),Vector3(CAFE_WEST_X,WALL_Y,(cursor+10.6)*0.5),wall_color)
	for door_z in [REST_DOOR_Z,LAB_DOOR_Z]:
		var lintel_height := WALL_HEIGHT-DOOR_HEIGHT
		Props.solid_box(parent,Vector3(WALL_THICKNESS,lintel_height,DOOR_WIDTH),Vector3(CAFE_WEST_X,DOOR_HEIGHT+lintel_height*0.5-0.05,door_z),wall_color)
		for side in [-1.0,1.0]:
			Props.box(parent,Vector3(0.28,DOOR_HEIGHT+0.20,0.13),Vector3(CAFE_WEST_X+0.04,(DOOR_HEIGHT+0.20)*0.5,door_z+side*(DOOR_WIDTH*0.5+0.05)),Color("bd9667"))
	var lab_sign := Props.text(parent,"ЛАБОРАТОРИЯ",Vector3(CAFE_WEST_X+0.32,3.12,LAB_DOOR_Z),24,Color("edd09d"))
	lab_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab_sign.pixel_size = 0.005
	var rest_sign := Props.text(parent,"КОМНАТА ОТДЫХА",Vector3(CAFE_WEST_X+0.32,3.12,REST_DOOR_Z),22,Color("e7c891"))
	rest_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rest_sign.pixel_size = 0.005
	_build_rest_furniture(parent)
	for spec in [[Vector3(ANNEX_CENTER_X,3.25,REST_DOOR_Z),Color("ffd29a")],[Vector3(ANNEX_CENTER_X,3.25,LAB_DOOR_Z),Color("b7e0cb")]]:
		var light := OmniLight3D.new()
		parent.add_child(light)
		light.position = spec[0]
		light.light_color = spec[1]
		light.light_energy = 0.85
		light.omni_range = 6.0

static func _build_rest_furniture(parent: Node3D) -> void:
	for x in [-16.15,-13.55]:
		Props.solid_box(parent,Vector3(2.15,0.24,0.88),Vector3(x,0.28,-1.65),Color("80634f"))
		Props.box(parent,Vector3(1.75,0.16,0.72),Vector3(x,0.46,-1.65),Color("b9a477"))
		Props.box(parent,Vector3(0.48,0.12,0.65),Vector3(x-0.62,0.58,-1.65),Color("e5d9b8"))
	Props.solid_box(parent,Vector3(2.0,0.42,0.62),Vector3(-16.10,0.25,0.70),Color("637b70"))
	Props.solid_box(parent,Vector3(1.1,0.78,0.72),Vector3(-13.30,0.39,1.05),Color("8d6b50"))
	Props.box(parent,Vector3(0.58,0.18,0.42),PLAYER_SLEEP_POINT,Color("d8c998"))

func setup(owner_game: Node3D) -> void:
	game = owner_game
	_build_door("rest",REST_DOOR_Z,Color("8bb0a4"))
	_build_door("lab",LAB_DOOR_Z,Color("87a99f"))

func _build_door(id: String, door_z: float, color: Color) -> void:
	var root := Node3D.new()
	root.name = "%sDoor" % id.capitalize()
	add_child(root)
	root.position = Vector3(CAFE_WEST_X+0.015,0,door_z)
	var leaves: Array = []
	for side in [-1.0,1.0]:
		var leaf := Node3D.new()
		root.add_child(leaf)
		var closed_z := side * DOOR_WIDTH * 0.25
		var open_z := side * DOOR_WIDTH * 0.69
		leaf.position = Vector3(0,DOOR_HEIGHT*0.5,closed_z)
		Props.solid_box(leaf,Vector3(0.11,DOOR_HEIGHT,DOOR_WIDTH*0.46),Vector3.ZERO,color)
		var inset := Props.box(leaf,Vector3(0.025,0.72,DOOR_WIDTH*0.32),Vector3(0.065,0.18,0),Color("b8d0c7"))
		inset.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inset.material_override.albedo_color.a = 0.45
		leaves.append({"node":leaf,"closed":closed_z,"open":open_z})
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
		var target := 1.0 if float(door.hold)>0.0 else 0.0
		door.amount = move_toward(float(door.amount),target,delta*4.2)
		for leaf_data in door.leaves:
			var leaf: Node3D = leaf_data.node
			leaf.position.z = lerpf(float(leaf_data.closed),float(leaf_data.open),float(door.amount))

func door_openness(id: String) -> float:
	return float(doors.get(id,{}).get("amount",0.0))

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
