extends Node3D
const P = preload("res://scripts/props.gd")
var hat: MeshInstance3D
var book: Node3D
var caption: Label3D
var head: Node3D
var notebook: Node3D
var pencil: Node3D
var arms: Array = []
var legs: Array = []
var phase := 0.0
var tint := Color("6cac9b")

func _ready() -> void:
	for side in [-1, 1]:
		var leg := Node3D.new()
		add_child(leg)
		leg.position = Vector3(side * 0.14, 0.65, 0)
		P.box(leg, Vector3(0.18, 0.58, 0.2), Vector3(0, -0.25, 0), Color("293d4b"))
		P.box(leg, Vector3(0.22, 0.13, 0.34), Vector3(0, -0.56, -0.06), Color("24323b"))
		legs.append(leg)
		arms.append(P.line(self, Vector3(side * 0.3, 1.2, 0), Vector3(side * 0.36, 0.8, -0.2), 0.075, tint))
	P.box(self, Vector3(0.59, 0.61, 0.33), Vector3(0, 0.96, 0), tint)
	P.box(self, Vector3(0.38, 0.5, 0.04), Vector3(0, 0.91, -0.185), Color("f3deb1"))
	head = Node3D.new()
	add_child(head)
	head.position.y = 1.51
	P.ball(head, 0.24, Vector3.ZERO, Color("e8b893"))
	for side in [-1, 1]: P.ball(head, 0.027, Vector3(side * 0.08, 0.04, -0.22), Color("203c40"))
	hat=P.cylinder(head, 0.26, 0.22, Vector3(0, 0.27, 0), Color("fff0cb"))
	notebook = Node3D.new()
	add_child(notebook)
	notebook.position = Vector3(0, 1.02, -0.35)
	notebook.rotation.x = -0.7
	P.box(notebook, Vector3(0.32, 0.025, 0.4), Vector3.ZERO, Color("795746"))
	P.box(notebook, Vector3(0.28, 0.008, 0.36), Vector3(0, 0.018, 0), Color("fff1c9"))
	for n in range(5): P.box(notebook, Vector3(0.21, 0.003, 0.008), Vector3(0, 0.024, -0.13 + n * 0.055), Color("8a9690"))
	pencil = Node3D.new()
	notebook.add_child(pencil)
	P.line(pencil, Vector3(0, 0.04, 0), Vector3(0.12, 0.20, 0), 0.012, Color("e5b455"))
	caption = P.text(self, "", Vector3(0, 2.1, 0), 19)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.pixel_size = 0.005
	notebook.hide()
	book = preload("res://scripts/book_prop.gd").new()
	add_child(book)
	book.pose_in_hands(false)

func walk_to(target: Vector3, delta: float) -> bool:
	var offset := target - position
	phase += delta * 8
	if offset.length() < 0.04:
		for leg in legs: leg.rotation.x = 0
		return true
	rotation.y = atan2(-offset.x, -offset.z)
	position = position.move_toward(target, delta * 2.2)
	legs[0].rotation.x = sin(phase) * 0.3
	legs[1].rotation.x = -sin(phase) * 0.3
	return false

func observe(target: Vector3, neighbor: Vector3, delta: float, index: int) -> void:
	phase += delta
	notebook.show()
	book.set_reading(false)
	var look := target
	if fmod(phase + index * 1.7, 11) > 9: look = neighbor
	var local := to_local(look)
	head.rotation.y = clampf(atan2(-local.x, -local.z), -1.1, 1.1)
	head.rotation.x = sin(phase * 3.5) * 0.13 if fmod(phase, 6) < 1.8 else -0.1
	pencil.position = Vector3(sin(phase * 8) * 0.065, 0, cos(phase * 5) * 0.05)
	P.align_line(arms[0], Vector3(-0.3, 1.2, 0), Vector3(-0.15, 1.02, -0.35))
	P.align_line(arms[1], Vector3(0.3, 1.2, 0), Vector3(0.1, 1.15, -0.36) + pencil.position)

func perform(pose: Dictionary, target: Vector3, holding: bool) -> void:
	reset_lounge_accessories()
	rotation=Vector3.ZERO
	hat.show()
	notebook.hide()
	var appearance: Dictionary = pose.get("presentation", {}) if pose.get("presentation", {}) is Dictionary else {}
	position = Vector3(pose.position[0], pose.position[1], pose.position[2])
	rotation.y = pose.yaw
	head.rotation = Vector3(pose.pitch, 0, 0)
	book.pose_for_gaze(head.rotation.x, true, head.position.y)
	book.set_reading(appearance.get("book", false) == true, str(appearance.get("page", "index")))
	var hand := to_local(get_parent().to_global(target)) if holding else Vector3(0.35, 0.78, -0.2)
	P.align_line(arms[0], Vector3(-0.3, 1.2, 0), hand + Vector3(-0.18, 0, 0) if holding else Vector3(-0.35, 0.78, -0.2))
	P.align_line(arms[1], Vector3(0.3, 1.2, 0), hand)
	if book.visible:
		P.align_line(arms[0], Vector3(-0.3, 1.2, 0), to_local(book.cover_grip(-1)))
		P.align_line(arms[1], Vector3(0.3, 1.2, 0), to_local(book.cover_grip(1)))

# Ambient poses never modify the recorded cooking model.
func idle(home: Vector3, delta: float, clock: float, identity: int, aisle: float) -> void:
	notebook.hide()
	book.set_reading(false)
	var beat := fposmod(clock + identity * 3.73, 23.0)
	var destination := home
	if beat > 8.0 and beat < 14.0:
		destination.x += 0.42 if identity % 2 == 0 else -0.42
		destination.z += 0.16
	if position.z < 1.4:
		var side := -1.0 if position.x < 0.0 else 1.0
		destination = Vector3(side * aisle, 0, position.z) if absf(position.x) < aisle - 0.08 else Vector3(side * aisle, 0, home.z)
	var walking := not walk_to(destination, delta)
	if not walking: rotation.y = lerp_angle(rotation.y, 0.0, 1.0 - exp(-delta * 4.0))
	var glance := sin(clock * 0.65 + identity) * 0.38
	head.rotation.y = lerp_angle(head.rotation.y, glance, 1.0 - exp(-delta * 3.0))
	head.rotation.x = lerp_angle(head.rotation.x, 0.24 if beat > 15.0 and beat < 19.0 else 0.02, 1.0 - exp(-delta * 3.0))
	var left := Vector3(-0.35, 0.78, -0.12)
	var right := Vector3(0.35, 0.78, -0.12)
	if walking:
		left.z += sin(phase) * 0.13
		right.z -= sin(phase) * 0.13
	elif beat > 3.0 and beat < 6.0:
		var gesture := sin((beat - 3.0) / 3.0 * PI)
		right = right.lerp(Vector3(0.23, 1.83, -0.04), gesture)
	elif beat > 15.0 and beat < 19.0:
		var gesture := sin((beat - 15.0) / 4.0 * PI)
		left = left.lerp(Vector3(-0.16, 1.08, -0.35), gesture)
		right = right.lerp(Vector3(0.16, 1.08, -0.35), gesture)
	P.align_line(arms[0], Vector3(-0.3, 1.2, 0), left)
	P.align_line(arms[1], Vector3(0.3, 1.2, 0), right)

func celebrate(clock: float, variant: int, throwing: bool) -> void:
	notebook.hide(); book.set_reading(false)
	var beat:=clock*(13 if variant==1 else 9)
	position.y+=absf(sin(beat))*0.16 if variant==0 or throwing else sin(beat)*0.025
	rotation.z=sin(beat*0.6)*0.12 if variant==2 else 0.0
	if variant==2 and not throwing: rotation.y+=sin(beat*0.35)*0.6
	for i in range(legs.size()): legs[i].rotation.x=sin(beat+i*PI)*(0.75 if variant==1 else 0.45)
	head.rotation=Vector3(-0.12,sin(beat*0.35)*0.2,0)
	for i in range(arms.size()):
		var side: float=-1 if i==0 else 1
		var high: bool=throwing or variant!=1
		P.align_line(arms[i],Vector3(side*0.3,1.2,0),Vector3(side*(0.6 if high else 0.35),1.8+sin(beat+i)*0.12 if high else 0.9,-0.2+sin(beat+i*PI)*0.24))

var lounge_legs: Node3D
var lounge_floor_legs: Node3D
var lounge_cup: Node3D
var lounge_paddle: Node3D
var lounge_snack: Node3D

func build_lounge_accessories() -> void:
	lounge_legs=Node3D.new()
	add_child(lounge_legs)
	for side in [-1,1]:
		P.line(lounge_legs,Vector3(side*0.14,0.65,0),Vector3(side*0.17,0.62,-0.43),0.095,Color("293d4b"))
		P.line(lounge_legs,Vector3(side*0.17,0.62,-0.43),Vector3(side*0.17,0.18,-0.44),0.085,Color("293d4b"))
		P.box(lounge_legs,Vector3(0.22,0.13,0.32),Vector3(side*0.17,0.145,-0.52),Color("24323b"))
	lounge_floor_legs=Node3D.new()
	add_child(lounge_floor_legs)
	for side in [-1,1]:
		P.line(lounge_floor_legs,Vector3(side*0.14,0.65,0),Vector3(side*0.36,0.57,-0.28),0.095,Color("293d4b"))
		P.line(lounge_floor_legs,Vector3(side*0.36,0.57,-0.28),Vector3(-side*0.12,0.57,-0.43),0.085,Color("293d4b"))
		P.box(lounge_floor_legs,Vector3(0.22,0.13,0.28),Vector3(-side*0.12,0.565,-0.46),Color("24323b"))
	lounge_cup=Node3D.new()
	add_child(lounge_cup)
	P.cylinder(lounge_cup,0.066,0.13,Vector3.ZERO,Color("f1d9ae"))
	P.cylinder(lounge_cup,0.052,0.008,Vector3(0,0.069,0),Color("584438"))
	lounge_paddle=Node3D.new()
	add_child(lounge_paddle)
	var face:=P.ball(lounge_paddle,0.13,Vector3.ZERO,Color("bb7565"))
	face.scale=Vector3(0.85,1.0,0.16)
	P.line(lounge_paddle,Vector3(0,-0.10,0),Vector3(0,-0.25,0),0.025,Color("976c4f"))
	lounge_snack=Node3D.new()
	add_child(lounge_snack)
	P.box(lounge_snack,Vector3(0.15,0.22,0.09),Vector3.ZERO,Color("dca458"))
	P.box(lounge_snack,Vector3(0.11,0.07,0.012),Vector3(0,0,-0.05),Color("f1d9ae"))

func lounge_pose(spot: Dictionary, clock: float, identity: int) -> void:
	if not is_instance_valid(lounge_legs): build_lounge_accessories()
	var pose:=str(spot.pose)
	var seated: bool=pose in ["watch","chat","rock","tea","board","relax","floor"]
	position=spot.position
	rotation=Vector3(0,float(spot.get("yaw",0)),0)
	head.rotation=Vector3(sin(clock*0.75+identity)*0.025,sin(clock*0.3+identity)*0.055,0)
	hat.hide()
	notebook.hide()
	book.set_reading(pose=="read")
	lounge_legs.visible=seated and pose!="floor"
	lounge_floor_legs.visible=pose=="floor"
	for leg in legs:
		leg.visible=not seated
		leg.rotation=Vector3.ZERO
	lounge_cup.visible=pose=="tea"
	lounge_paddle.visible=pose=="pingpong"
	lounge_snack.visible=pose=="snack"
	var left:=Vector3(-0.34,0.83,-0.15)
	var right:=Vector3(0.34,0.83,-0.15)
	if seated:
		left=Vector3(-0.30,0.78,-0.43)
		right=Vector3(0.30,0.78,-0.43)
	var beat:=sin(clock*1.4+identity)
	match pose:
		"watch":
			head.rotation.y=sin(clock*0.25+identity)*0.09
		"chat":
			var talk:=fposmod(clock+identity*1.37,6.4)
			var side: float=-1.0 if str(spot.id)=="sofa_right" else 1.0 if str(spot.id)=="sofa_left" else sin(clock*0.43+identity)
			head.rotation.y=side*(0.52+sin(clock*0.8+identity)*0.16)
			head.rotation.x=sin(clock*2.4+identity)*0.06
			if talk<2.35:
				var gesture:=sin(talk/2.35*PI)
				right=right.lerp(Vector3(0.52,1.18,-0.28),gesture)
				left=left.lerp(Vector3(-0.40,1.04,-0.33),gesture*0.55)
			elif talk>4.35 and talk<5.45:
				var laugh:=sin((talk-4.35)/1.10*PI)
				rotation.z=sin(clock*8.0+identity)*0.035*laugh
				head.rotation.x=-0.12*clampf(laugh,0,1)
				left.y-=0.08*clampf(laugh,0,1)
				right.y-=0.08*clampf(laugh,0,1)
		"rock":
			rotation.x=sin(clock*1.7)*0.065
		"tea":
			var sip:=maxf(0.0,sin(clock*0.8+identity))
			right=Vector3(0.29,0.92,-0.35).lerp(Vector3(0.10,1.45,-0.29),sip)
			lounge_cup.position=right
		"board":
			head.rotation.x=0.28
			right=Vector3(0.27,0.92,-0.54-0.14*maxf(0,beat))
		"relax":
			head.rotation.x=-0.1
			left=Vector3(-0.48,0.89,0.02)
			right=Vector3(0.48,0.89,0.02)
		"foosball":
			head.rotation.x=0.20
			left=Vector3(-0.28,1.10,-0.41+sin(clock*4.4)*0.025)
			right=Vector3(0.28,1.10,-0.41-sin(clock*4.4)*0.025)
		"arcade":
			head.rotation.x=0.10
			left=Vector3(-0.23,1.08,-0.43)
			right=Vector3(0.23,1.08+maxf(0,sin(clock*5))*0.04,-0.43)
		"pingpong":
			right=Vector3(0.29+sin(clock*2.6)*0.18,0.98,-0.40-maxf(0,beat)*0.20)
			lounge_paddle.position=right+Vector3(0,0.17,0)
			lounge_paddle.rotation.y=sin(clock*2.6)*0.5
		"read":
			head.rotation.x=0.23
			left=Vector3(-0.18,1.05,-0.38)
			right=Vector3(0.18,1.05,-0.38)
		"music":
			head.rotation.x=sin(clock*2.6)*0.11
			rotation.z=sin(clock*1.3)*0.035
		"fish":
			head.rotation.y=sin(clock*0.33)*0.22
		"snack":
			right=Vector3(0.29,1.14,-0.32)
			lounge_snack.position=right
		"floor":
			position.y-=0.50
			var floor_beat:=fposmod(clock*0.78+identity*1.11,7.0)
			head.rotation.x=-0.08+sin(clock*1.7+identity)*0.05
			head.rotation.y=sin(clock*0.62+identity)*0.48
			if floor_beat<2.2:
				var story:=sin(floor_beat/2.2*PI)
				right=right.lerp(Vector3(0.50,1.03,-0.28),story)
			elif floor_beat>4.6 and floor_beat<5.8:
				var laugh:=sin((floor_beat-4.6)/1.2*PI)
				rotation.z=sin(clock*9.0+identity)*0.045*laugh
				left.y-=0.10*laugh
				right.y-=0.10*laugh
	P.align_line(arms[0],Vector3(-0.3,1.2,0),left)
	P.align_line(arms[1],Vector3(0.3,1.2,0),right)

func lounge_ball_react(target: Vector3, pass_phase: float, throwing: bool) -> void:
	var local_target: Vector3=to_local(target)
	head.rotation.y=clampf(atan2(-local_target.x,-local_target.z),-1.0,1.0)
	head.rotation.x=clampf(-atan2(local_target.y-1.45,maxf(0.2,Vector2(local_target.x,local_target.z).length())),-0.35,0.35)
	var reach: float=sin(clampf(pass_phase,0.0,1.0)*PI)
	var right:=Vector3(0.30,0.82,-0.43)
	var left:=Vector3(-0.30,0.82,-0.43)
	if throwing:
		right=right.lerp(Vector3(0.48,1.34,-0.30),clampf(1.2-pass_phase,0.0,1.0))
	else:
		var catch: float=smoothstep(0.55,1.0,pass_phase)
		right=right.lerp(Vector3(0.20,1.24,-0.38),catch)
		left=left.lerp(Vector3(-0.20,1.24,-0.38),catch)
	P.align_line(arms[0],Vector3(-0.3,1.2,0),left)
	P.align_line(arms[1],Vector3(0.3,1.2,0),right+Vector3(0,reach*0.04,0))

func morning_wake_pose(at: Vector3, yaw: float, rise: float, identity: int) -> void:
	reset_lounge_accessories()
	hat.hide(); notebook.hide(); book.set_reading(false)
	var eased: float=smoothstep(0.0,1.0,clampf(rise,0.0,1.0))
	position=at-Vector3.UP*(1.0-eased)*0.28
	rotation=Vector3(0,yaw,0)
	head.rotation=Vector3(-0.34*(1.0-eased)+sin(identity*1.7+eased*PI)*0.06,0,0)
	for i in range(legs.size()): legs[i].rotation.x=(1.0-eased)*(0.75 if i==0 else -0.55)
	for i in range(arms.size()):
		var side: float=-1.0 if i==0 else 1.0
		var sleepy:=Vector3(side*0.33,0.84,-0.18)
		var stretch:=Vector3(side*0.48,1.92,-0.04)
		var hand:=stretch.lerp(sleepy,eased)
		P.align_line(arms[i],Vector3(side*0.3,1.2,0),hand)

func morning_run(clock: float, variant: int) -> void:
	reset_lounge_accessories()
	hat.hide(); notebook.hide(); book.set_reading(false)
	var kind: int=posmod(variant,5)
	var beat: float=clock*float([11.0,9.0,14.0,10.5,12.0][kind])
	var bounce: float=float([0.08,0.20,0.045,0.11,0.14][kind])
	position.y+=absf(sin(beat))*bounce
	rotation.x=-0.10 if kind==2 else 0.0
	rotation.z=sin(beat*0.5)*0.07 if kind in [1,4] else 0.0
	for i in range(legs.size()): legs[i].rotation.x=sin(beat+i*PI)*float([0.62,0.82,0.95,0.70,0.78][kind])
	head.rotation=Vector3(-0.06,sin(beat*0.22+kind)*0.17,0)
	for i in range(arms.size()):
		var side: float=-1.0 if i==0 else 1.0
		var hand:=Vector3(side*0.38,0.90,-0.12+sin(beat+i*PI)*0.28)
		if kind==1 and i==1: hand=Vector3(0.62,1.72,-0.05+sin(beat)*0.12)
		elif kind==3: hand=Vector3(side*0.72,1.30,-0.12+sin(beat+i)*0.08)
		elif kind==4 and i==0: hand=Vector3(-0.54,1.55,-0.10)
		P.align_line(arms[i],Vector3(side*0.3,1.2,0),hand)

func reset_lounge_accessories() -> void:
	for node in [lounge_legs,lounge_floor_legs,lounge_cup,lounge_paddle,lounge_snack]:
		if is_instance_valid(node): node.hide()
	for leg in legs:
		leg.show()
		leg.rotation=Vector3.ZERO

func sleep_pose(spot: Dictionary, clock: float, identity: int) -> void:
	reset_lounge_accessories()
	hat.hide()
	notebook.hide()
	book.set_reading(false)
	position=spot.position
	rotation=spot.sleep_rotation
	var seated: bool=str(spot.sleep_kind)=="seated"
	if seated:
		if not is_instance_valid(lounge_legs): build_lounge_accessories(); reset_lounge_accessories()
		lounge_legs.show()
		for leg in legs: leg.hide()
		rotation.y=float(spot.get("yaw",0))
	head.rotation=Vector3(0.26 if seated else 0.08,0,sin(clock*1.3+identity)*0.025)
	position.y+=sin(clock*1.3+identity)*0.008
	for i in range(arms.size()):
		var side: float=-1.0 if i==0 else 1.0
		var hand:=Vector3(side*0.18,0.92,-0.26)
		if identity%3==1: hand=Vector3(side*0.38,1.52,0.08)
		P.align_line(arms[i],Vector3(side*0.3,1.2,0),hand)
