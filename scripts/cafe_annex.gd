extends Node3D
## Laboratory and expanded rest room live behind the cafe, opposite the cooking stations.
const Props = preload("res://scripts/props.gd")
const LoungeLayout = preload("res://scripts/lounge_layout.gd")
const LabLayout = preload("res://scripts/laboratory_layout.gd")
const LoungeFurniture = preload("res://scripts/lounge_furniture.gd")
const Expansion = preload("res://scripts/cafe_expansion_layout.gd")

const CAFE_X_MIN := Expansion.HALL_X_MIN
const CAFE_X_MAX := Expansion.HALL_X_MAX
const CAFE_BACK_Z := Expansion.HALL_BACK_Z
const DIVIDER_X := 0.0
const LAB_X_MIN := -14.7
const LAB_X_MAX := DIVIDER_X
const LAB_BACK_Z := 30.4
const REST_X_MIN := DIVIDER_X
const REST_X_MAX := 14.9
const REST_BACK_Z := LoungeLayout.MAX_BACK_Z
const LAB_DOOR_X := -4.0
const REST_DOOR_X := LoungeLayout.ENTRANCE.x
const DOOR_WIDTH := 1.8
const DOOR_HEIGHT := 2.55
const DOOR_TRIGGER_RADIUS := 2.35
const WALL_HEIGHT := 4.7
const WALL_Y := 2.3
const WALL_THICKNESS := 0.18
const LAB_ORIGIN := Vector3(-4.0, 0.0, 8.4)
const LAB_ROTATION_Y := 0.0
const LAB_DOOR_CAFE := Vector3(LAB_DOOR_X, 0.0, 13.15)
const LAB_DOOR_ROOM := Vector3(LAB_DOOR_X, 0.0, 14.85)
const REST_DOOR_CAFE := Vector3(REST_DOOR_X, 0.0, 13.15)
const REST_DOOR_ROOM := Vector3(REST_DOOR_X, 0.0, 14.85)
const REST_AREA := (REST_X_MAX - REST_X_MIN) * (REST_BACK_Z - CAFE_BACK_Z)
const PLAYER_BED_COUNT := 1
const LoungeProgress = preload("res://scripts/lounge_progression.gd")

var game: Node3D
var doors := {}
var layout_stamp := ""
var refresh_pending := false

static func lab_world(local_point: Vector3) -> Vector3:
	return Transform3D(Basis(Vector3.UP, LAB_ROTATION_Y), LAB_ORIGIN) * local_point

static func place_lab(node: Node3D) -> void:
	node.position = LAB_ORIGIN
	node.rotation.y = LAB_ROTATION_Y

static func player_bed_center(_index: int, tier := 0) -> Vector3:
	return LoungeLayout.bed_center(tier)

static func player_sleep_position(layer: int, tier := 0) -> Vector3:
	return player_bed_center(0,tier)+Vector3(-0.95,0.20+layer*0.34,0)

static func player_sleep_yaw(_index: int) -> float:
	return 0.0

static func player_bed_exit(layer: int, tier := 0) -> Vector3:
	var center := player_bed_center(0,tier)
	return Vector3(center.x+(layer-1.5)*0.55,0.02,center.z-1.6)

static func rest_spot(index: int) -> Dictionary:
	return LoungeLayout.rest_spot(index)

static func back_wall_left(p) -> float:
	var lab_tier: int=int(p.lab_tier) if p!=null else 0
	return floorf(LabLayout.left(lab_tier)/Expansion.TILE)*Expansion.TILE

static func back_wall_right(p) -> float:
	if p==null or Expansion.stage_for_progress(p)<2: return DIVIDER_X
	var tier: int=int(p.lounge_tier)
	return ceilf(LoungeLayout.right_x(tier)/Expansion.TILE)*Expansion.TILE

static func build_shell(owner_game: Node3D) -> void:
	var parent := Node3D.new()
	parent.name="CafeAnnexShell"
	owner_game.add_child(parent)
	var p = owner_game.service.progress if is_instance_valid(owner_game.service) else null
	var building_stage: int=Expansion.stage_for_progress(p)
	var tier: int=int(p.lounge_tier) if p!=null else 0
	var wall_color := Color("2e5355")
	var lab_tier: int=int(p.lab_tier) if p!=null else 0
	var lab_left:=LabLayout.left(lab_tier)
	var lab_back:=LabLayout.back(lab_tier)
	var lab_width:=LAB_X_MAX-lab_left
	var lab_depth:=lab_back-CAFE_BACK_Z
	Props.box(parent,Vector3(lab_width,0.09,lab_depth),Vector3((lab_left+LAB_X_MAX)*0.5,-0.05,(CAFE_BACK_Z+lab_back)*0.5),Color("60756f"))
	Props.collision_box(parent,Vector3(lab_width,0.2,lab_depth),Vector3((lab_left+LAB_X_MAX)*0.5,-0.10,(CAFE_BACK_Z+lab_back)*0.5))
	var rest_right: float=LoungeLayout.right_x(tier)
	var rest_back: float=LoungeLayout.back_z(tier)
	var rest_width:=rest_right-REST_X_MIN
	var rest_depth:=rest_back-CAFE_BACK_Z
	if building_stage>=2:
		Props.box(parent,Vector3(rest_width,0.09,rest_depth),Vector3((REST_X_MIN+rest_right)*0.5,-0.05,(CAFE_BACK_Z+rest_back)*0.5),Color("776f60"))
		Props.collision_box(parent,Vector3(rest_width,0.2,rest_depth),Vector3((REST_X_MIN+rest_right)*0.5,-0.10,(CAFE_BACK_Z+rest_back)*0.5))
	_build_cafe_back_wall(parent,wall_color,building_stage,p)
	# Laboratory keeps its existing internal footprint; its current outside edges become expansion partitions.
	_add_room_edge(parent,Vector3(WALL_THICKNESS,WALL_HEIGHT,lab_depth),Vector3(lab_left,WALL_Y,(CAFE_BACK_Z+lab_back)*0.5),wall_color,lab_tier<2,Vector3.RIGHT)
	_add_room_edge(parent,Vector3(lab_width,WALL_HEIGHT,WALL_THICKNESS),Vector3((lab_left+LAB_X_MAX)*0.5,WALL_Y,lab_back),wall_color,lab_tier<2,Vector3.BACK)
	var shared_depth:=maxf(lab_back,rest_back if building_stage>=2 else lab_back)-CAFE_BACK_Z
	Props.solid_box(parent,Vector3(WALL_THICKNESS,WALL_HEIGHT,shared_depth),Vector3(DIVIDER_X,WALL_Y,CAFE_BACK_Z+shared_depth*0.5),wall_color)
	if building_stage>=2:
		_add_room_edge(parent,Vector3(WALL_THICKNESS,WALL_HEIGHT,rest_depth),Vector3(rest_right,WALL_Y,(CAFE_BACK_Z+rest_back)*0.5),wall_color,tier<2,Vector3.LEFT)
		Props.solid_box(parent,Vector3(rest_width,WALL_HEIGHT,WALL_THICKNESS),Vector3((REST_X_MIN+rest_right)*0.5,WALL_Y,rest_back),wall_color)
	var lab_sign := Props.text(parent,"ЛАБОРАТОРИЯ",Vector3(LAB_DOOR_X,3.12,CAFE_BACK_Z-0.24),24,Color("edd09d"))
	lab_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab_sign.pixel_size = 0.005
	if building_stage>=2:
		var rest_sign := Props.text(parent,"КОМНАТА ОТДЫХА",Vector3(REST_DOOR_X,3.12,CAFE_BACK_Z-0.24),22,Color("e7c891"))
		rest_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rest_sign.pixel_size = 0.005
		_build_rest_furniture(parent,owner_game,tier,p)
	for spec in [[Vector3((lab_left+LAB_X_MAX)*0.5,3.25,CAFE_BACK_Z+2.75),Color("b7e0cb")]]:
		var light := OmniLight3D.new()
		parent.add_child(light)
		light.position = Vector3(spec[0])
		light.light_color = Color(spec[1])
		light.light_energy = 0.85
		light.omni_range = 6.5

static func _add_room_edge(parent: Node3D,size: Vector3,center: Vector3,color: Color,temporary: bool,inward: Vector3) -> void:
	if not temporary:
		Props.solid_box(parent,size,center,color)
		return
	Props.solid_box(parent,size,center,Color("9b815d"))
	var along_x:=size.x>size.z
	var length:=size.x if along_x else size.z
	var frame_offset:=inward*0.16
	var rail:=Vector3(length,0.12,0.08) if along_x else Vector3(0.08,0.12,length)
	Props.box(parent,rail,center+frame_offset+Vector3(0,2.10,0),Color("3f4747"))
	Props.box(parent,rail,center+frame_offset-Vector3(0,2.10,0),Color("3f4747"))
	var band:=Vector3(maxf(0.4,length-0.2),0.24,0.06) if along_x else Vector3(0.06,0.24,maxf(0.4,length-0.2))
	Props.box(parent,band,center+inward*0.19+Vector3(0,-1.7,0),Color("e3bd36"))
	var label:=Props.text(parent,"РАСШИРЕНИЕ",center+inward*0.23+Vector3(0,-0.35,0),20,Color("fff2b0"))
	label.rotation.y=atan2(inward.x,inward.z)

static func _build_cafe_back_wall(parent: Node3D, color: Color, building_stage: int, p) -> void:
	var openings := [Vector2(LAB_DOOR_X-DOOR_WIDTH*0.5,LAB_DOOR_X+DOOR_WIDTH*0.5)]
	if building_stage>=2: openings.append(Vector2(REST_DOOR_X-DOOR_WIDTH*0.5,REST_DOOR_X+DOOR_WIDTH*0.5))
	openings.sort_custom(func(a,b): return a.x<b.x)
	var left_edge: float=back_wall_left(p)
	var right_edge: float=back_wall_right(p)
	var cursor: float=left_edge
	for opening in openings:
		if opening.x > cursor:
			Props.solid_box(parent,Vector3(opening.x-cursor,WALL_HEIGHT,WALL_THICKNESS),Vector3((cursor+opening.x)*0.5,WALL_Y,CAFE_BACK_Z),color)
		cursor = opening.y
	if cursor < right_edge:
		Props.solid_box(parent,Vector3(right_edge-cursor,WALL_HEIGHT,WALL_THICKNESS),Vector3((cursor+right_edge)*0.5,WALL_Y,CAFE_BACK_Z),color)
	var door_xs: Array=[LAB_DOOR_X]
	if building_stage>=2: door_xs.append(REST_DOOR_X)
	for door_x in door_xs:
		var lintel_height := WALL_HEIGHT-DOOR_HEIGHT
		Props.solid_box(parent,Vector3(DOOR_WIDTH,lintel_height,WALL_THICKNESS),Vector3(door_x,DOOR_HEIGHT+lintel_height*0.5-0.05,CAFE_BACK_Z),color)
		for side in [-1.0,1.0]:
			Props.box(parent,Vector3(0.13,DOOR_HEIGHT+0.20,0.28),Vector3(door_x+float(side)*(DOOR_WIDTH*0.5+0.05),(DOOR_HEIGHT+0.20)*0.5,CAFE_BACK_Z-0.04),Color("bd9667"))

static func _build_rest_furniture(parent: Node3D, owner_game: Node3D, tier: int, p) -> void:
	var lounge := LoungeFurniture.new()
	parent.add_child(lounge)
	lounge.setup(owner_game,tier,p.lounge_items if p!=null else ["sofa"],p.lounge_upgrades if p!=null else [])
	var center := player_bed_center(0,tier)
	Props.solid_box(parent,Vector3(2.65,0.28,1.25),Vector3(center.x,0.26,center.z),Color("80634f"))
	Props.box(parent,Vector3(2.45,0.18,1.07),Vector3(center.x,0.47,center.z),Color("c1ae82"))
	Props.box(parent,Vector3(0.62,0.13,0.98),Vector3(center.x+0.82,0.61,center.z),Color("e7dcc0"))
	Props.box(parent,Vector3(1.12,0.035,1.07),Vector3(center.x-0.45,0.59,center.z),Color("528d82"))
	var sign:=Props.text(parent,"ШЕФ-КРОВАТЬ\nВсем хватит места",center+Vector3(0,1.7,0.65),23,Color("f1d9ae"))
	sign.rotation.y=PI

func setup(owner_game: Node3D) -> void:
	game = owner_game
	layout_stamp=_layout_stamp()
	_sync_doors()

func _layout_stamp() -> String:
	return "%d:%s:%s"%[Expansion.stage_for_progress(game.service.progress),LoungeProgress.stamp(game.service.progress),LabLayout.stamp(game.service.progress)]

func _sync_doors() -> void:
	for data in doors.values():
		var root: Node3D=data.get("root")
		if is_instance_valid(root): root.queue_free()
	doors.clear()
	_build_door("lab",LAB_DOOR_X,Color("87a99f"))
	if Expansion.stage_for_progress(game.service.progress)>=2:
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
		Props.moving_solid_box(leaf,Vector3(DOOR_WIDTH*0.46,DOOR_HEIGHT,0.11),Vector3.ZERO,color)
		var inset := Props.box(leaf,Vector3(DOOR_WIDTH*0.32,0.72,0.025),Vector3(0,0.18,-0.065),Color("b8d0c7"))
		inset.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inset.material_override.albedo_color.a = 0.45
		leaves.append({"node":leaf,"closed":closed_x,"open":open_x})
	doors[id] = {"root":root,"leaves":leaves,"amount":0.0,"hold":0.0}

func _physics_process(delta: float) -> void:
	if game==null: return
	if _layout_stamp()!=layout_stamp and not refresh_pending:
		refresh_pending=true
		refresh_shell.call_deferred()
	advance_doors(delta)

func refresh_shell() -> void:
	refresh_pending=false
	if game==null: return
	var p=game.service.progress
	layout_stamp=_layout_stamp()
	_sync_doors()
	var shell:=game.get_node_or_null("CafeAnnexShell")
	if shell!=null: shell.free()
	build_shell(game)
	# Furniture appears around an awake player without moving them; they can simply walk out of the new footprint.
	var point: Vector3=game.player.global_position
	if point.z>CAFE_BACK_Z and not game.session.local_sleeping():
		if point.x<REST_X_MIN and not LabLayout.walkable(point,p):
			game.player.global_position=LAB_DOOR_ROOM
			game.player.velocity=Vector3.ZERO
		elif point.x>=REST_X_MIN and Expansion.stage_for_progress(p)>=2:
			var blockers:=LoungeLayout.obstacles(p.lounge_tier,p.lounge_items)
			if not LoungeLayout.walkable(point,blockers,p.lounge_tier):
				game.player.global_position=REST_DOOR_ROOM
				game.player.velocity=Vector3.ZERO

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

func sleep_target(camera: Camera3D, _peer: int) -> Dictionary:
	if game == null or game.service.progress.shift != "night" or game.session.local_sleeping(): return {}
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	for index in range(PLAYER_BED_COUNT):
		var center := player_bed_center(index,game.service.progress.lounge_tier)
		var box := AABB(center-Vector3(1.34,0.45,0.64),Vector3(2.68,0.90,1.28))
		var hit = box.intersects_ray(origin,direction)
		if hit == null or origin.distance_to(hit)>4.2: continue
		return {"action":"sleep","bed":index,"hint":"(E) В Шеф-кровать · "+game.session.sleep_status_text()}
	return {}

func settle_player_avatar(actor: Node3D, bed_index: int) -> void:
	actor.global_position = player_sleep_position(bed_index,game.service.progress.lounge_tier)
	actor.rotation = Vector3.ZERO
	actor.rotation.y = player_sleep_yaw(bed_index)
	actor.rotation.z = -PI/2
	actor.book.set_reading(false)
	actor.notebook.hide()
	actor.head.rotation=Vector3.ZERO
	actor.hat.hide()
	actor.reset_lounge_accessories()
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
