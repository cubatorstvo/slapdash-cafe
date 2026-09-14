extends Node3D
## Purchased low-poly furnishings, staged interiors and ambient motion.
const P = preload("res://scripts/props.gd")
const Layout = preload("res://scripts/lounge_layout.gd")
const WOOD := Color("976c4f")
const DARK_WOOD := Color("503e35")
const CREAM := Color("f1d9ae")
const TEAL := Color("528d82")
const GOLD := Color("dca458")
const INK := Color("263d45")
var tier := 0
var owned: Array = ["sofa"]
var improved: Array = []
var game: Node3D
var fixtures := {}
var rods: Array = []
var fishes: Array = []
var rocking_root: Node3D
var television_ball: Node3D
var pong_ball: Node3D
var arcade_sprite: Node3D
var ambient_clock := 0.0

func setup(owner_game: Node3D, room_tier := 0, items: Array = ["sofa"], upgrades: Array = []) -> void:
	game=owner_game
	tier=room_tier
	owned=items.duplicate()
	improved=upgrades.duplicate()
	name="StaffLounge"
	add_to_group("staff_lounge")
	for spec in Layout.catalogue(tier,owned):
		var item:=Node3D.new()
		item.name=str(spec.id).to_pascal_case()
		add_child(item)
		item.position=spec.position
		item.rotation.y=float(spec.yaw)
		item.set_meta("lounge_item",spec.id)
		item.set_meta("future_stage",spec.stage)
		fixtures[spec.id]=item
		match str(spec.id):
			"sofa": build_sofa(item)
			"television": build_tv(item)
			"rocking_chair": build_rocker(item)
			"foosball": build_foosball(item)
			"arcade": build_arcade(item)
			"table_tennis": build_pingpong(item)
			"board_games": build_board_games(item)
			"bookcase": build_bookcase(item)
			"beanbag": build_beanbag(item)
			"tea_station": build_tea(item)
			"jukebox": build_jukebox(item)
			"aquarium": build_aquarium(item)
			"plants": build_plant(item,1.0)
			"floor_lamp": build_lamp(item)
			"snack_fridge": build_fridge(item)
		if spec.id in improved:
			# A visible brass badge and fresh upholstery identify improved furnishings.
			var badge:=label(item,"★",Vector3(0,1.55,0),30)
			badge.modulate=GOLD
			badge.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			box(item,Vector3(0.42,0.035,0.28),Vector3(0,0.12,-0.48),GOLD)
	build_interior()
	# Shared footprint proxies keep walking and clone routes consistent.
	var blockers:=Layout.obstacles(tier,owned)
	var heights:=Layout.obstacle_heights(tier,owned)
	for i in range(blockers.size()-1):
		var rect: Rect2=blockers[i]
		var height: float=heights[i]
		P.collision_box(self,Vector3(rect.size.x,height,rect.size.y),Vector3(rect.get_center().x,height*0.5,rect.get_center().y))

func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	return P.box(parent,size,at,color)

func glow(node: MeshInstance3D, strength := 0.4) -> void:
	var material: StandardMaterial3D=node.material_override
	material.emission_enabled=true
	material.emission=material.albedo_color
	material.emission_energy_multiplier=strength

func label(parent: Node3D, value: String, point: Vector3, size := 22) -> Label3D:
	var text:=P.text(parent,value,point,size,CREAM)
	text.pixel_size=0.003
	return text

func legs(parent: Node3D, width: float, depth: float, height: float) -> void:
	for x in [-width*0.5,width*0.5]:
		for z in [-depth*0.5,depth*0.5]:
			box(parent,Vector3(0.09,height,0.09),Vector3(x,height*0.5,z),DARK_WOOD)

func stool(parent: Node3D, point: Vector3, high := false) -> void:
	var height:=0.70 if high else 0.44
	var root:=Node3D.new()
	parent.add_child(root)
	root.position=point
	legs(root,0.32,0.32,height-0.07)
	P.cylinder(root,0.29,0.12,Vector3(0,height,0),GOLD)

func build_sofa(parent: Node3D) -> void:
	legs(parent,1.90,0.7,0.18)
	box(parent,Vector3(2.40,0.34,1.12),Vector3(0,0.34,0),TEAL)
	box(parent,Vector3(2.45,0.72,0.23),Vector3(0,0.85,0.46),Color("3f756e"))
	for x in [-1.12,1.12]:
		box(parent,Vector3(0.24,0.57,1.12),Vector3(x,0.68,0),TEAL)
	for x in [-0.55,0.55]:
		box(parent,Vector3(0.98,0.18,0.91),Vector3(x,0.56,-0.12),Color("6eaa96"))
		box(parent,Vector3(0.97,0.51,0.17),Vector3(x,0.89,0.29),Color("68a18f"))
	for x in [-0.72,0.72]:
		var cushion:=box(parent,Vector3(0.32,0.31,0.13),Vector3(x,0.83,0.10),GOLD if x<0 else Color("bf8071"))
		cushion.rotation.z=x*0.20
	box(parent,Vector3(0.42,0.035,0.72),Vector3(0.70,0.67,-0.14),Color("e3caa0"))
	var table:=Node3D.new()
	parent.add_child(table)
	table.position=Vector3(0,0,-1.95)
	legs(table,1.52,0.6,0.35)
	box(table,Vector3(1.8,0.09,0.8),Vector3(0,0.39,0),WOOD)
	box(table,Vector3(0.22,0.025,0.09),Vector3(0.35,0.46,0.06),INK)
	P.cylinder(table,0.17,0.14,Vector3(-0.45,0.49,0.02),CREAM)
	for i in range(9): P.ball(table,0.035,Vector3(-0.53+(i%3)*0.07,0.56,-0.05+(i/3)*0.055),Color("f7dfa1"))

func build_tv(parent: Node3D) -> void:
	legs(parent,2.40,0.46,0.18)
	box(parent,Vector3(2.75,0.52,0.72),Vector3(0,0.46,0),WOOD)
	for x in [-0.88,0.0,0.88]:
		box(parent,Vector3(0.77,0.28,0.025),Vector3(x,0.44,-0.373),DARK_WOOD)
	box(parent,Vector3(0.7,0.05,0.30),Vector3(0,0.76,0),INK)
	box(parent,Vector3(0.12,0.25,0.12),Vector3(0,0.87,0),INK)
	box(parent,Vector3(2.30,1.35,0.16),Vector3(0,1.57,0),INK)
	glow(box(parent,Vector3(2.12,1.16,0.015),Vector3(0,1.57,-0.087),Color("345f71")),0.65)
	# A tiny original silent space programme: moving moon, stars, horizon.
	for i in range(16):
		P.ball(parent,0.013,Vector3(-0.93+fmod(i*0.327,1.84),1.14+fmod(i*0.197,0.88),-0.107),CREAM)
	box(parent,Vector3(2.1,0.28,0.014),Vector3(0,1.12,-0.109),Color("658a8b"))
	television_ball=P.ball(parent,0.15,Vector3(-0.3,1.75,-0.115),GOLD)
	label(parent,"ПОСЛЕ СМЕНЫ",Vector3(0,2.43,0),30).rotation.y=PI

func build_rocker(parent: Node3D) -> void:
	rocking_root=Node3D.new()
	parent.add_child(rocking_root)
	for x in [-0.46,0.46]:
		for i in range(9):
			var a: float=-0.70+i*0.155
			var b: float=a+0.155
			P.line(rocking_root,Vector3(x,0.06+a*a*0.23,a),Vector3(x,0.06+b*b*0.23,b),0.047,WOOD)
		box(rocking_root,Vector3(0.085,0.50,0.085),Vector3(x,0.35,0.20),WOOD)
		box(rocking_root,Vector3(0.10,0.08,0.82),Vector3(x,0.79,0),WOOD)
	box(rocking_root,Vector3(0.88,0.16,0.90),Vector3(0,0.53,0),GOLD)
	var back:=box(rocking_root,Vector3(0.86,0.75,0.15),Vector3(0,0.98,0.40),Color("cc995d"))
	back.rotation.x=-0.14
	box(rocking_root,Vector3(0.45,0.035,0.75),Vector3(-0.1,0.635,-0.04),CREAM)

func build_foosball(parent: Node3D) -> void:
	legs(parent,0.90,1.62,0.80)
	box(parent,Vector3(1.08,0.27,1.90),Vector3(0,0.84,0),WOOD)
	box(parent,Vector3(0.91,0.025,1.70),Vector3(0,0.99,0),Color("4d8b6b"))
	for x in [-0.51,0.51]: box(parent,Vector3(0.065,0.14,1.87),Vector3(x,1.03,0),GOLD)
	for z in [-0.91,0.91]: box(parent,Vector3(1.02,0.14,0.065),Vector3(0,1.03,z),GOLD)
	for z in [-0.75,0.0,0.75]: box(parent,Vector3(0.84,0.006,0.02),Vector3(0,1.007,z),CREAM)
	for i in range(6):
		var rod:=Node3D.new()
		parent.add_child(rod)
		rod.position=Vector3(0,1.10,-0.65+i*0.26)
		P.line(rod,Vector3(-0.92,0,0),Vector3(0.92,0,0),0.018,INK)
		var side: float=-1 if i%2==0 else 1
		P.line(rod,Vector3(side*0.70,0,0),Vector3(side*0.91,0,0),0.052,Color("bf735a"))
		for x in [-0.28,0,0.28]:
			box(rod,Vector3(0.10,0.18,0.07),Vector3(x,-0.05,0),Color("dca458") if i%2==0 else TEAL)
			P.ball(rod,0.055,Vector3(x,0.085,0),CREAM)
		rods.append(rod)
	P.ball(parent,0.04,Vector3(0.12,1.025,0.30),CREAM)

func build_arcade(parent: Node3D) -> void:
	box(parent,Vector3(0.94,1.84,0.89),Vector3(0,0.92,0),Color("ad665d"))
	box(parent,Vector3(0.78,0.7,0.04),Vector3(0,1.36,-0.47),INK)
	glow(box(parent,Vector3(0.64,0.52,0.015),Vector3(0,1.36,-0.498),Color("396375")),0.5)
	box(parent,Vector3(0.98,0.12,0.48),Vector3(0,0.99,-0.36),GOLD)
	P.line(parent,Vector3(-0.24,1.06,-0.39),Vector3(-0.24,1.19,-0.39),0.025,INK)
	P.ball(parent,0.055,Vector3(-0.24,1.20,-0.39),Color("cf795f"))
	for x in [0.10,0.25]: P.cylinder(parent,0.055,0.025,Vector3(x,1.065,-0.43),TEAL)
	box(parent,Vector3(0.89,0.22,0.07),Vector3(0,1.93,-0.43),INK)
	label(parent,"КЛОНТРИС",Vector3(0,1.93,-0.475),19).rotation.y=PI
	arcade_sprite=box(parent,Vector3(0.11,0.11,0.02),Vector3(0,1.42,-0.52),GOLD)
	for i in range(5): box(parent,Vector3(0.105,0.105,0.02),Vector3(-0.24+i*0.115,1.14,-0.52),TEAL)

func build_pingpong(parent: Node3D) -> void:
	legs(parent,1.24,2.25,0.72)
	box(parent,Vector3(1.52,0.065,2.74),Vector3(0,0.76,0),TEAL)
	for x in [-0.74,0.74]: box(parent,Vector3(0.025,0.008,2.68),Vector3(x,0.797,0),CREAM)
	for z in [-1.35,1.35,0.0]: box(parent,Vector3(1.48,0.008,0.025),Vector3(0,0.797,z),CREAM)
	for x in [-0.8,0.8]: P.line(parent,Vector3(x,0.76,0),Vector3(x,0.99,0),0.025,INK)
	for i in range(8): P.line(parent,Vector3(-0.79+i*0.225,0.79,0),Vector3(-0.79+i*0.225,0.97,0),0.006,CREAM)
	for y in [0.83,0.90,0.97]: P.line(parent,Vector3(-0.79,y,0),Vector3(0.79,y,0),0.006,CREAM)
	pong_ball=P.ball(parent,0.035,Vector3(0,1.02,0),CREAM)

func build_board_games(parent: Node3D) -> void:
	legs(parent,0.90,0.90,0.70)
	box(parent,Vector3(1.16,0.08,1.16),Vector3(0,0.74,0),WOOD)
	for x in range(8):
		for z in range(8):
			box(parent,Vector3(0.075,0.012,0.075),Vector3(-0.263+x*0.075,0.791,-0.263+z*0.075),CREAM if (x+z)%2==0 else INK)
	for side in [-1,1]:
		for i in range(5):
			P.cylinder(parent,0.022,0.065,Vector3(-0.22+i*0.105,0.83,side*0.20),GOLD if side<0 else TEAL)
	for point in [Vector3(-1.2,0,0),Vector3(1.2,0,0),Vector3(0,0,-1.2),Vector3(0,0,1.2)]: stool(parent,point)
	box(parent,Vector3(0.20,0.025,0.29),Vector3(0.40,0.80,0.19),Color("b96958"))

func build_bookcase(parent: Node3D) -> void:
	box(parent,Vector3(1.94,2.2,0.38),Vector3(0,1.1,0),DARK_WOOD)
	for y in [0.18,0.77,1.36,1.95]:
		box(parent,Vector3(1.90,0.055,0.40),Vector3(0,y,-0.05),WOOD)
	for row in range(3):
		for i in range(13):
			var height: float=0.29+fmod(i*0.11+row*0.07,0.20)
			var volume:=box(parent,Vector3(0.095,height,0.22),Vector3(-0.83+i*0.132,0.22+row*0.59+height*0.5,-0.14),[TEAL,GOLD,CREAM,Color("bc776d")][(i+row)%4])
			if i%6==0: volume.rotation.z=0.10
	label(parent,"ПОЧТИ ВСЁ ОБО ВСЁМ",Vector3(0,2.37,-0.04),18).rotation.y=PI

func build_beanbag(parent: Node3D) -> void:
	var base:=P.ball(parent,0.59,Vector3(0,0.30,0),Color("bd806d"))
	base.scale=Vector3(1.0,0.55,0.92)
	var back:=P.ball(parent,0.42,Vector3(0,0.57,0.27),Color("c88c78"))
	back.scale=Vector3(1.0,0.95,0.70)
	P.ball(parent,0.19,Vector3(0.25,0.49,-0.14),GOLD)

func cup(parent: Node3D, point: Vector3, color: Color) -> void:
	P.cylinder(parent,0.065,0.13,point,color)
	P.cylinder(parent,0.053,0.009,point+Vector3(0,0.068,0),Color("584438"))
	var handle:=P.ball(parent,0.044,point+Vector3(0.078,0,0),color)
	handle.scale=Vector3(0.55,1.0,1.0)

func build_tea(parent: Node3D) -> void:
	box(parent,Vector3(3.2,0.86,0.78),Vector3(0,0.43,0),TEAL)
	box(parent,Vector3(3.30,0.08,0.86),Vector3(0,0.9,0),WOOD)
	for x in [-1.05,0,1.05]:
		box(parent,Vector3(0.96,0.61,0.025),Vector3(x,0.47,-0.405),Color("437c71"))
		box(parent,Vector3(0.21,0.035,0.04),Vector3(x,0.65,-0.44),GOLD)
	P.cylinder(parent,0.16,0.28,Vector3(-1.0,1.08,0),CREAM,0.11)
	P.line(parent,Vector3(-0.9,1.06,0),Vector3(-0.71,1.18,0),0.035,CREAM)
	for x in [-0.35,0.1,0.55]: cup(parent,Vector3(x,1.01,-0.18),CREAM)
	P.cylinder(parent,0.23,0.04,Vector3(1.08,0.97,0),GOLD)
	for i in range(5): P.ball(parent,0.052,Vector3(0.94+i*0.06,1.02,0),Color("b98350"))
	for x in [-0.7,0.7]: stool(parent,Vector3(x,0,-1.05),true)

func build_jukebox(parent: Node3D) -> void:
	box(parent,Vector3(0.87,1.51,0.64),Vector3(0,0.76,0),WOOD)
	var dome:=P.ball(parent,0.44,Vector3(0,1.47,0),WOOD)
	dome.scale.z=0.7
	glow(box(parent,Vector3(0.63,0.40,0.025),Vector3(0,1.41,-0.34),Color("cf9060")))
	for x in [-0.36,0.36]:
		glow(box(parent,Vector3(0.055,1.07,0.06),Vector3(x,0.84,-0.37),GOLD))
	box(parent,Vector3(0.60,0.62,0.025),Vector3(0,0.53,-0.34),INK)
	for i in range(7): box(parent,Vector3(0.52,0.024,0.028),Vector3(0,0.27+i*0.08,-0.36),GOLD)
	label(parent,"ТИШЕ, Я ОТДЫХАЮ",Vector3(0,1.36,-0.38),13).rotation.y=PI

func build_aquarium(parent: Node3D) -> void:
	box(parent,Vector3(1.8,0.70,0.70),Vector3(0,0.35,0),WOOD)
	box(parent,Vector3(1.78,0.06,0.69),Vector3(0,0.73,0),INK)
	box(parent,Vector3(1.72,0.75,0.02),Vector3(0,1.14,0.31),Color("3c7378"))
	box(parent,Vector3(1.72,0.03,0.62),Vector3(0,0.78,0),GOLD)
	for x in [-0.86,0.86]:
		box(parent,Vector3(0.035,0.82,0.63),Vector3(x,1.15,0),INK)
		for i in range(3): P.line(parent,Vector3(x*0.75,0.80,0.1),Vector3(x*0.75+i*0.03,1.08+i*0.06,0.1),0.025,TEAL)
	box(parent,Vector3(1.81,0.07,0.70),Vector3(0,1.56,0),INK)
	for i in range(4):
		var fish:=Node3D.new()
		parent.add_child(fish)
		var body:=P.ball(fish,0.095,Vector3.ZERO,GOLD if i%2==0 else Color("d78f7f"))
		body.scale=Vector3(1.65,0.72,0.50)
		var tail:=box(fish,Vector3(0.06,0.16,0.03),Vector3(-0.17,0,0),GOLD)
		tail.rotation.z=PI/4
		P.ball(fish,0.014,Vector3(0.10,0.022,-0.046),INK)
		fishes.append(fish)
	var glass:=box(parent,Vector3(1.71,0.73,0.018),Vector3(0,1.15,-0.322),Color("90d4c7"))
	glass.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override.albedo_color.a=0.12

func build_plant(parent: Node3D, scale_factor: float) -> void:
	P.cylinder(parent,0.32*scale_factor,0.48*scale_factor,Vector3(0,0.24*scale_factor,0),Color("c48662"),0.39*scale_factor)
	for i in range(7):
		var at:=Vector3(sin(i*2.4)*0.27,0.68+i*0.115,cos(i*2.4)*0.25)*scale_factor
		P.line(parent,Vector3(0,0.40,0)*scale_factor,at,0.018,Color("577955"))
		var leaf:=P.ball(parent,0.19*scale_factor,at,Color("739b70") if i%2==0 else Color("8aaa79"))
		leaf.scale=Vector3(0.65,1.65,0.75)
		leaf.rotation.z=sin(i)*0.5

func build_lamp(parent: Node3D) -> void:
	P.cylinder(parent,0.24,0.05,Vector3(0,0.035,0),INK)
	P.line(parent,Vector3(0,0.05,0),Vector3(0,1.62,0),0.025,GOLD)
	glow(P.cylinder(parent,0.36,0.44,Vector3(0,1.67,0),CREAM,0.22),0.30)
	add_light(parent,Vector3(0,1.44,0),Color("ffd295"),0.85,4.0)

func build_fridge(parent: Node3D) -> void:
	box(parent,Vector3(0.9,1.73,0.87),Vector3(0,0.865,0),CREAM)
	box(parent,Vector3(0.77,1.30,0.026),Vector3(0,0.97,-0.45),INK)
	glow(box(parent,Vector3(0.65,1.14,0.024),Vector3(0,0.99,-0.47),Color("719c9e")),0.22)
	for row in range(3):
		for col in range(4):
			P.cylinder(parent,0.047,0.18,Vector3(-0.23+col*0.15,0.59+row*0.33,-0.49),[GOLD,TEAL,Color("b97061"),CREAM][col])
	box(parent,Vector3(0.04,0.56,0.08),Vector3(0.39,1.0,-0.48),WOOD)

func add_light(parent: Node3D, at: Vector3, color: Color, energy: float, radius: float) -> void:
	var light:=OmniLight3D.new()
	parent.add_child(light)
	light.position=at
	light.light_color=color
	light.light_energy=energy
	light.omni_range=radius
	light.shadow_enabled=false

func rug(at: Vector3, size: Vector2, color: Color) -> void:
	box(self,Vector3(size.x,0.012,size.y),at,color)
	box(self,Vector3(size.x-0.16,0.007,size.y-0.16),at+Vector3(0,0.01,0),color.lightened(0.09))
	for end in [-1,1]:
		for i in range(12): box(self,Vector3(0.022,0.01,0.16),at+Vector3(-size.x*0.45+i*size.x*0.9/11.0,0,end*(size.y*0.5+0.045)),CREAM)

func build_interior() -> void:
	var back:=Layout.back_z(tier)
	var depth:=back-10.6
	var middle: float=(10.6+back)*0.5
	# The starter room already has warm light; purchases add visible layers.
	rug(Vector3(6.45,0.016,13.60),Vector2(5.35,5.0),Color("a86f59"))
	if "textiles" in owned:
		rug(Vector3(14.15,0.016,middle),Vector2(5.30,depth-2.0),Color("667a79"))
		rug(Vector3(10.4,0.016,middle-0.5),Vector2(1.25,depth-3.5),Color("b39870"))
		if tier==2: rug(Vector3(6.45,0.016,20.55),Vector2(5.40,5.0),Color("7b8966"))
	if tier==2:
		for side in [Vector2(3.15,9.25),Vector2(11.55,17.55)]:
			box(self,Vector3(side.y-side.x,0.28,0.14),Vector3((side.x+side.y)*0.5,2.05,23.55),WOOD)
			for i in range(int((side.y-side.x)/0.50)):
				box(self,Vector3(0.055,1.95,0.07),Vector3(side.x+0.14+i*0.50,1.03,23.55),WOOD)
	box(self,Vector3(14.55,0.10,depth-0.3),Vector3(10.35,4.60,middle),Color("c1b69a"))
	for z in [11.0,middle,back-0.30]:
		box(self,Vector3(14.5,0.16,0.16),Vector3(10.35,4.40,z),WOOD)
	for x in [3.02,17.68]:
		box(self,Vector3(0.07,1.00,depth-0.4),Vector3(x,0.50,middle),Color("8c7357"))
		box(self,Vector3(0.10,0.055,depth-0.4),Vector3(x,1.02,middle),GOLD)
	for z in [13.0,back-3.0]:
		for x in [6.6,13.7]:
			P.line(self,Vector3(x,4.55,z),Vector3(x,3.65,z),0.015,INK)
			glow(P.cylinder(self,0.42,0.25,Vector3(x,3.58,z),CREAM,0.27),0.28)
			add_light(self,Vector3(x,3.35,z),Color("ffdeb0"),0.75,6.0)
	add_light(self,Vector3(10.4,3.25,back-1.4),Color("f6d0a0"),0.65,7.0)
	if "ambient" in owned:
		for i in range(25):
			var z:=11.3+i*(depth-2.3)/24.0
			var y:=3.95-sin(i*PI/24)*0.28
			if i>0: P.line(self,Vector3(10.4,3.95-sin((i-1)*PI/24)*0.28,z-(depth-2.3)/24.0),Vector3(10.4,y,z),0.012,DARK_WOOD)
			if i%2==0: glow(P.ball(self,0.048,Vector3(10.4,y-0.055,z),GOLD),0.6)
		add_light(self,Vector3(6.5,2.8,middle),Color("ffbf84"),0.5,7.0)
	for z in [13.0,18.2,21.2]:
		if z>back-2.0: continue
		box(self,Vector3(0.12,1.30,1.66),Vector3(17.64,2.65,z),WOOD)
		glow(box(self,Vector3(0.025,1.12,1.47),Vector3(17.56,2.65,z),Color("496e80")),0.15)
		if "textiles" in owned:
			for edge in [-1,1]:
				box(self,Vector3(0.15,1.62,0.30),Vector3(17.45,2.54,z+edge*0.82),Color("c68b71"))
	if "plants" in owned:
		for point in [Vector3(8.8,0,11.5),Vector3(17.05,0,back-1.3)]:
			var plant:=Node3D.new()
			add_child(plant)
			plant.position=point
			build_plant(plant,0.72)
	var sign:=label(self,"ЗДЕСЬ МОЖНО НИЧЕГО НЕ УСПЕВАТЬ",Vector3(10.4,3.10,back-0.23),32)
	sign.rotation.y=PI

func _process(delta: float) -> void:
	if game==null or not is_instance_valid(game.service): return
	if game.session_paused and not game.session.online(): return
	ambient_clock+=delta
	var night: bool=game.service.progress.shift=="night"
	var clock: float=game.service.progress.night_elapsed if night else ambient_clock
	if is_instance_valid(television_ball): television_ball.position.x=sin(clock*0.13)*0.67
	if is_instance_valid(arcade_sprite):
		arcade_sprite.position.x=snappedf(sin(clock*0.37)*0.22,0.11)
		arcade_sprite.position.y=1.54-fposmod(clock*0.07,0.32)
	for i in range(fishes.size()):
		fishes[i].position=Vector3(sin(clock*0.33+i*1.9)*0.61,0.98+fmod(i*0.13,0.39)+sin(clock+i)*0.02,-0.08)
		fishes[i].rotation.y=0.0 if cos(clock*0.33+i*1.9)>0 else PI
	var occupied: Dictionary={}
	if night and is_instance_valid(game.evening):
		for entry in game.evening.performers.values():
			if entry.get("settled",false): occupied[str(entry.get("item",""))]=true
	if is_instance_valid(rocking_root): rocking_root.rotation.x=sin(clock*1.7)*0.065 if occupied.has("rocking_chair") else 0.0
	for i in range(rods.size()):
		rods[i].rotation.x=sin(clock*4.4+i)*0.65 if occupied.has("foosball") else 0.0
	if is_instance_valid(pong_ball): pong_ball.position=Vector3(sin(clock*1.3)*0.35,0.88+absf(sin(clock*2.6))*0.43,sin(clock*2.6)*1.19) if occupied.has("table_tennis") else Vector3(0.52,0.82,1.0)
