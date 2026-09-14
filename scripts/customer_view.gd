extends Node3D
const Props = preload("res://scripts/props.gd")
var playback_speed := 1.0
var mouth_amount := 0.0
var drinking := false
var drunk_ml := 0.0
var chewing := 0.0
var mouth_shape: MeshInstance3D
var drink_label: Label3D
var stain: MeshInstance3D
var caption: Label3D
var legs: Array[Node3D] = []
var color := Color("a66c76")
var chef := false
var phase := 0.0
var head: Node3D
var shoulders: Array[Node3D] = []
var watching := false
var food_target := Vector3.ZERO
var cook_target := Vector3.ZERO
var following_food := false
var personality := 0.0

func _ready() -> void:
	personality = float(get_instance_id() % 97) * 0.37
	for side in [-1, 1]:
		var leg := Node3D.new()
		add_child(leg)
		leg.position = Vector3(side * 0.14, 0.65, 0)
		Props.box(leg, Vector3(0.18, 0.58, 0.2), Vector3(0, -0.23, 0), Color("293d4b"))
		Props.box(leg, Vector3(0.21, 0.13, 0.34), Vector3(0, -0.56, -0.06), Color("24323b"))
		legs.append(leg)
	Props.box(self, Vector3(0.59, 0.61, 0.33), Vector3(0, 0.96, 0), color)
	for side in [-1, 1]:
		var shoulder := Node3D.new()
		add_child(shoulder)
		shoulder.position = Vector3(side * 0.36, 1.16, 0)
		Props.box(shoulder, Vector3(0.14, 0.50, 0.18), Vector3(0, -0.22, 0), color)
		Props.ball(shoulder, 0.085, Vector3(0, -0.49, 0), Color("e8b893"))
		shoulders.append(shoulder)
	head = Node3D.new()
	add_child(head)
	head.position.y = 1.51
	Props.ball(head, 0.24, Vector3.ZERO, Color("e8b893"))
	for side in [-1, 1]: Props.ball(head, 0.027, Vector3(side * 0.08, 0.04, -0.22), Color("203c40"))
	if chef:
		Props.cylinder(head, 0.26, 0.22, Vector3(0, 0.27, 0), Color("fff0cb"))
		Props.box(self, Vector3(0.38, 0.5, 0.04), Vector3(0, 0.91, -0.185), Color("f3deb1"))
	else: Props.ball(head, 0.25, Vector3(0, 0.13, 0.025), color.darkened(0.3)).scale.y = 0.48
	mouth_shape = Props.ball(head,0.205,Vector3(0,-0.035,-0.248),Color("341c25"))
	mouth_shape.scale = Vector3(0.2,0.06,0.12)
	drink_label = Props.text(self,"",Vector3(0,2.32,0),17,Color("eacb86"))
	drink_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	drink_label.pixel_size = 0.005
	stain = Props.ball(head, 0.13, Vector3(0, -0.01, -0.235), Color("d9483b"))
	stain.scale.z = 0.15
	stain.hide()
	caption = Props.text(self, "", Vector3(0, 2.05, 0), 19, Color("f6dfa9"))
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.pixel_size = 0.005

func walk_to(target: Vector3, delta: float) -> bool:
	watching = false
	playback_speed = 1.0
	mouth_amount = 0
	drinking = false
	chewing = maxf(0,chewing-delta)
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

func _process(delta: float) -> void:
	delta *= playback_speed
	personality += delta
	var blend := 1.0 - exp(-delta * 4.5)
	var yaw := 0.0
	var pitch := 0.0
	if watching:
		var beat := fposmod(personality, 12.0)
		var target := food_target if following_food or beat < 5.5 else cook_target
		var direction := to_local(target) - head.position
		yaw = clampf(atan2(-direction.x, -direction.z), -0.95, 0.95)
		pitch = clampf(atan2(direction.y, Vector2(direction.x, direction.z).length()), -0.55, 0.4)
		if beat > 10.2:
			yaw = sin(personality * 0.8) * 0.75
			pitch = 0.02
		for leg in legs: leg.rotation.x = lerpf(leg.rotation.x, 0.0, blend)
	if drinking and mouth_amount>0.05: pitch = maxf(pitch,mouth_amount*0.95)
	var opening := maxf(mouth_amount,absf(sin(chewing*20))*0.5 if chewing>0 else 0.0)
	mouth_shape.scale = mouth_shape.scale.lerp(Vector3(0.2+opening*0.95,0.05+opening*1.05,0.12),blend)
	drink_label.visible = drunk_ml>0
	drink_label.text = "Выпито: %.0f мл" % drunk_ml
	head.rotation.y = lerp_angle(head.rotation.y, yaw, blend)
	head.rotation.x = lerp_angle(head.rotation.x, pitch, blend)
	head.position.y = 1.51 + sin(personality * 1.7) * 0.008
	for index in range(shoulders.size()):
		var gesture := 0.0
		if watching and index == 1:
			var beat := fposmod(personality + 2.0, 17.0)
			if beat < 2.8: gesture = -0.55 * sin(beat / 2.8 * PI)
		shoulders[index].rotation.x = lerpf(shoulders[index].rotation.x, gesture, blend)
