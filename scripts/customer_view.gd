extends Node3D
const Props = preload("res://scripts/props.gd")
var stain: MeshInstance3D
var caption: Label3D
var legs: Array[Node3D] = []
var color := Color("a66c76")
var chef := false
var phase := 0.0

func _ready() -> void:
	for side in [-1, 1]:
		var leg := Node3D.new()
		add_child(leg)
		leg.position = Vector3(side * 0.14, 0.65, 0)
		Props.box(leg, Vector3(0.18, 0.58, 0.2), Vector3(0, -0.23, 0), Color("293d4b"))
		Props.box(leg, Vector3(0.21, 0.13, 0.34), Vector3(0, -0.56, -0.06), Color("24323b"))
		legs.append(leg)
	Props.box(self, Vector3(0.59, 0.61, 0.33), Vector3(0, 0.96, 0), color)
	for side in [-1, 1]:
		Props.box(self, Vector3(0.14, 0.50, 0.18), Vector3(side * 0.36, 0.94, 0), color)
		Props.ball(self, 0.085, Vector3(side * 0.36, 0.67, 0), Color("e8b893"))
	Props.ball(self, 0.24, Vector3(0, 1.51, 0), Color("e8b893"))
	for side in [-1, 1]: Props.ball(self, 0.027, Vector3(side * 0.08, 1.55, -0.22), Color("203c40"))
	if chef:
		Props.cylinder(self, 0.26, 0.22, Vector3(0, 1.78, 0), Color("fff0cb"))
		Props.box(self, Vector3(0.38, 0.5, 0.04), Vector3(0, 0.91, -0.185), Color("f3deb1"))
	else: Props.ball(self, 0.25, Vector3(0, 1.64, 0.025), color.darkened(0.3)).scale.y = 0.48
	stain = Props.ball(self, 0.13, Vector3(0, 1.5, -0.235), Color("d9483b"))
	stain.scale.z = 0.15
	stain.hide()
	caption = Props.text(self, "", Vector3(0, 2.05, 0), 19, Color("f6dfa9"))
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.pixel_size = 0.005

func walk_to(target: Vector3, delta: float) -> bool:
	var offset := target - position
	if offset.length() < 0.04:
		for leg in legs: leg.rotation.x = 0
		return true
	rotation.y = atan2(-offset.x, -offset.z)
	position = position.move_toward(target, 1.65 * delta)
	phase += delta * 8
	legs[0].rotation.x = sin(phase) * 0.32
	legs[1].rotation.x = -sin(phase) * 0.32
	return false

func react(time_left: float) -> void:
	stain.visible = time_left > 0
	rotation.z = sin(time_left * 10) * 0.12 if time_left > 0 else 0.0
