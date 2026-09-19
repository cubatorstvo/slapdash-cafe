extends Node3D
## Cosmetic courier/assembler. Authoritative state lives in the delivery parcel.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Props=preload("res://scripts/props.gd")
var actor: Node3D
var parcel_box: Node3D
var clock:=0.0

func setup(index: int)->void:
	actor=Avatar.new()
	actor.tint=[Color("d58c5c"),Color("7b9fc0"),Color("a889ba"),Color("78a47e")][index%4]
	add_child(actor)
	actor.hat.hide()
	actor.notebook.hide()
	parcel_box=Node3D.new()
	actor.add_child(parcel_box)
	parcel_box.position=Vector3(0,0.95,-0.48)
	Props.box(parcel_box,Vector3(0.52,0.46,0.44),Vector3.ZERO,Color("b28a59"))
	Props.box(parcel_box,Vector3(0.09,0.47,0.45),Vector3.ZERO,Color("d4be91"))

func apply(parcel: Dictionary,target: Vector3,delta: float)->void:
	if actor==null: return
	clock+=delta
	var raw: Array=parcel.get("installer_position",parcel.get("position",[0,0,0]))
	if raw.size()==3: actor.global_position=Vector3(raw[0],raw[1],raw[2])
	var state:=str(parcel.get("installer_state","waiting_delivery"))
	parcel_box.visible=state in ["walking","waiting"]
	actor.caption.text=match state:
		"walking": "Сборщик · тащит коробку"
		"waiting": ["Сборщик · ну когда уже?","Сборщик · смотрит на часы","Сборщик · очень хочет домой","Сборщик · сверлит повара взглядом"][int(parcel.get("installer_variant",0)+floor(clock/2.8))%4]
		"installing": "Сборщик · собирает"
		_: "Сборщик"
	if state=="waiting":
		var phase:=clock+float(parcel.get("id",0))*0.73
		var base:=target+Vector3(0,0,2.55)
		actor.global_position=base+Vector3(sin(phase*1.7)*0.55,0,cos(phase*1.2)*0.22)
		actor.rotation.y=atan2(-(target.x-actor.global_position.x),-(target.z-actor.global_position.z))
		actor.head.rotation.y=sin(phase*0.55)*0.55
		for leg in actor.legs: leg.rotation.x=sin(phase*5.0)*0.09
	elif state=="installing":
		actor.rotation.y=atan2(-(target.x-actor.global_position.x),-(target.z-actor.global_position.z))
		for leg in actor.legs: leg.rotation.x=0
