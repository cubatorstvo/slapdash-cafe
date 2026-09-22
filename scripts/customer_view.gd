extends Node3D
const Props = preload("res://scripts/props.gd")
const SceneRuntime = preload("res://scripts/scene_runtime.gd")
var meal_items: Array = []
var meal_age := 0.0
var meal_root: Node3D
var meal_hand: MeshInstance3D
var meal_arm: MeshInstance3D
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
	preload("res://scripts/scene_runtime.gd").ensure_children(self, "res://scenes/actors/customer.tscn")
	personality = float(get_instance_id() % 97) * 0.37
	legs = [get_node("LeftLeg"), get_node("RightLeg")]
	shoulders = [get_node("LeftShoulder"), get_node("RightShoulder")]
	head = get_node("Head")
	mouth_shape = get_node("Head/Mouth") as MeshInstance3D
	drink_label = get_node("DrinkLabel") as Label3D
	stain = get_node("Head/Stain") as MeshInstance3D
	caption = get_node("Caption") as Label3D
	var runtime = preload("res://scripts/scene_runtime.gd")
	runtime.colorize(get_node("Body") as MeshInstance3D, color)
	runtime.colorize(get_node("LeftShoulder/Arm") as MeshInstance3D, color)
	runtime.colorize(get_node("RightShoulder/Arm") as MeshInstance3D, color)
	runtime.colorize(get_node("Head/Hair") as MeshInstance3D, color.darkened(0.3))
	get_node("Head/Hair").visible = not chef
	get_node("ChefVariant").visible = chef
	stain.hide()

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
	# X is the lip width, Y opens the mouth, Z stays the thin face normal. A thicker Z reads as a tongue.
	mouth_shape.scale = mouth_shape.scale.lerp(Vector3(0.1+opening*0.475,0.025+opening*0.525,0.02),blend)
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
	animate_meal()

func serving_scene(items: Array) -> String:
	if items.is_empty(): return ""
	var dish:=str(items[0].get("dish",""))
	var kinds: Array=[]
	for entry in items: kinds.append(str(entry.kind))
	if dish=="wine" and "cup" in kinds and "plate" in kinds and "wine" not in kinds: return "res://scenes/food/wine_serving.tscn"
	if dish=="potato" and "potato" in kinds and "plate" in kinds: return "res://scenes/food/fried_potato_serving.tscn"
	if dish=="sausage" and "sausage" in kinds and "plate" in kinds: return "res://scenes/food/sausage_serving.tscn"
	if dish=="meal" and "steak" in kinds and "pasta" in kinds and "plate" in kinds: return "res://scenes/food/steak_pasta_serving.tscn"
	if dish=="burger" and "burger" in kinds and "plate" in kinds: return "res://scenes/food/burger_serving.tscn"
	if dish=="cheeseburger" and "burger" in kinds and "plate" in kinds: return "res://scenes/food/cheeseburger_serving.tscn"
	if dish=="spicy_burger" and "burger" in kinds and "plate" in kinds: return "res://scenes/food/spicy_burger_serving.tscn"
	if dish=="solyanka" and "solyanka" in kinds and "plate" in kinds: return "res://scenes/food/solyanka_serving.tscn"
	return ""

func begin_meal(items: Array) -> void:
	if not meal_items.is_empty(): return
	meal_items=items.duplicate(true)
	meal_age=0.0
	meal_root=Node3D.new(); add_child(meal_root)
	var plated_scene:=serving_scene(meal_items)
	for item_index in range(meal_items.size()):
		var entry: Dictionary=meal_items[item_index]
		var node:=SceneRuntime.instantiate(plated_scene) as Node3D if item_index==0 and not plated_scene.is_empty() else Node3D.new()
		meal_root.add_child(node)
		if not plated_scene.is_empty(): continue
		match str(entry.kind):
			"plate": Props.cylinder(node,0.32,0.035,Vector3.ZERO,Color("ecdfb5"))
			"cup", "jug":
				var big: bool=entry.kind=="jug"
				Props.cylinder(node,0.28 if big else 0.22,0.5 if big else 0.4,Vector3(0,0.2,0),Color("c78251") if big else Color("a9d2cd"))
				if float(entry.get("ml",0))>0: Props.cylinder(node,0.2,0.03,Vector3(0,0.39,0),Color("b44761"))
			"rag": Props.box(node,Vector3(0.25,0.06,0.18),Vector3.ZERO,Color("d1b26a"))
			"wine": Props.ball(node,0.16,Vector3.ZERO,Color("b44761")).scale=Vector3(1.3,0.18,1)
			"pasta":
				for i in range(10): Props.cylinder(node,0.023,0.17,Vector3(sin(i)*0.13,0.025*(i%3),cos(i)*0.13),Color("dfbd65")).rotation.z=PI/2
			_:
				var food:=Props.ball(node,0.18,Vector3.ZERO,{"potato":Color("c79c55"),"sausage":Color("c78561"),"steak":Color("a96b4e"),"tomato":Color("da6250")}.get(entry.kind,Color("d0ac74")))
				food.scale=Vector3(0.6,0.6,2.4) if entry.kind=="sausage" else Vector3(1.25,0.4,1.0) if entry.kind=="steak" else Vector3(0.85,1,1.25)
	meal_hand=Props.ball(self,0.1,Vector3.ZERO,Color("e8b893"))
	meal_arm=Props.line(self,Vector3(0.36,1.16,0),Vector3(0.36,0.7,-0.2),0.065,color)

func animate_meal() -> void:
	if meal_items.is_empty() or not is_instance_valid(meal_root): return
	var t:=clampf(meal_age/0.85,0,1)
	var mouth:=head.global_position-global_basis.z*0.28
	mouth_shape.scale=Vector3(0.56,0.55,0.04) if t<1 else Vector3(0.25,0.175+absf(sin(meal_age*24))*0.1,0.03)
	for i in range(meal_items.size()):
		var node: Node3D=meal_root.get_child(i)
		var origin: Vector3=meal_items[i].from
		node.global_position=origin.lerp(mouth,smoothstep(0,1,t))+Vector3.UP*sin(t*PI)*0.22
		node.scale=Vector3.ONE*(1.0-smoothstep(0.75,1.0,t))
		node.visible=t<1
	var hand_at: Vector3=meal_items[0].from.lerp(mouth,t)
	meal_hand.global_position=hand_at
	Props.align_line(meal_arm,Vector3(0.36,1.16,0),to_local(hand_at))
	meal_hand.visible=meal_age<1.1; meal_arm.visible=meal_age<1.1
	if meal_age>=1.1:
		for entry in meal_items: drunk_ml+=float(entry.get("ml",0))
		meal_items.clear(); meal_root.queue_free(); meal_hand.queue_free(); meal_arm.queue_free()
