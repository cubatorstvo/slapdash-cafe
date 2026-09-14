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
