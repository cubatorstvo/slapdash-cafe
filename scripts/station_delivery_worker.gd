extends Node3D
## Temporary visual double of a station worker while the real crew abandons work for a delivery.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Props=preload("res://scripts/props.gd")
var actor: Node3D
var parcel_box: Node3D
var clock:=0.0
var base_y:=0.0

func setup(name: String,tint: Color)->void:
	actor=get_node("Actor") as Node3D
	if actor.get_script()!=Avatar:
		actor.set_script(Avatar)
		if actor.is_inside_tree(): actor._ready()
	actor.tint=tint
	actor.caption.text=name
	actor.add_to_group("automatic_door_actor")
	actor.hat.hide()
	actor.notebook.hide()
	parcel_box=get_node("Actor/ParcelBox") as Node3D
	parcel_box.hide()

func apply(state: Dictionary,delta: float)->void:
	if actor==null: return
	clock+=delta
	var raw: Array=state.get("position",[0.0,0.0,0.0])
	var at:=Vector3(float(raw[0]),float(raw[1]),float(raw[2])) if raw.size()==3 else Vector3.ZERO
	actor.global_position=at
	base_y=at.y
	actor.rotation=Vector3(0,float(state.get("yaw",0.0)),0)
	actor.head.rotation=Vector3.ZERO
	actor.rotation.z=0.0
	actor.book.set_reading(false)
	actor.notebook.hide()
	for i in range(actor.legs.size()):
		actor.legs[i].position.x=-0.14 if i==0 else 0.14
		actor.legs[i].rotation=Vector3.ZERO
	var phase:=str(state.get("phase","cheering"))
	var name:=str(state.get("name","Клон"))
	match phase:
		"approaching_box":
			actor.caption.text=name+" · КОРОБКА!"
			parcel_box.hide()
			_run_pose(1.12,false)
		"carrying":
			actor.caption.text=name+" · НЕСЁТ СОКРОВИЩЕ"
			parcel_box.show()
			parcel_box.position=Vector3(0,0.94,-0.46)
			_run_pose(0.96,true)
		"installing":
			actor.caption.text=name+" · САМ ПОСТАВЛЮ!"
			parcel_box.show()
			parcel_box.position=Vector3(0.0,0.42,-0.58)
			_install_pose()
		"cheering":
			parcel_box.hide()
			_cheer_pose(name,int(state.get("variant",0)),float(state.get("age",0.0)))
		_:
			parcel_box.hide()
			_idle_pose()

func _run_pose(multiplier: float,carrying: bool)->void:
	var beat:=clock*11.0*multiplier
	for i in range(actor.legs.size()): actor.legs[i].rotation.x=sin(beat+i*PI)*0.46
	if carrying:
		Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.24,1.03,-0.48))
		Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.24,1.03,-0.48))
		actor.rotation.z=sin(beat*0.5)*0.035
	else:
		Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.40,0.84,-0.18+sin(beat)*0.20))
		Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.40,0.84,-0.18-sin(beat)*0.20))
	actor.head.rotation.y=sin(clock*2.3)*0.12

func _install_pose()->void:
	var bounce:=0.5+0.5*sin(clock*8.5)
	actor.rotation.x=0.12+0.08*bounce
	actor.head.rotation.x=0.24
	for i in range(actor.legs.size()): actor.legs[i].rotation.x=0.10+sin(clock*7.0+i*PI)*0.08
	Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.28,0.62,-0.62))
	Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.28,0.62,-0.62))

func _cheer_pose(name: String,variant: int,age: float)->void:
	var mode:=posmod(variant,4)
	var beat:=age*8.0
	match mode:
		0:
			actor.caption.text=name+" · ДАВАЙ-ДАВАЙ!"
			actor.position.y=absf(sin(beat))*0.11
			Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.48,1.65,-0.10))
			Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.48,1.65,-0.10))
		1:
			actor.caption.text=name+" · ОЧЕНЬ ПОМОГАЕТ"
			actor.rotation.z=sin(beat*0.55)*0.10
			Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.58,1.05,-0.28))
			Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.58,1.05,-0.28))
		2:
			actor.caption.text=name+" · КОНТРОЛИРУЕТ"
			actor.head.rotation.y=sin(beat*0.4)*0.55
			Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.18,0.92,-0.34))
			Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.18,0.92,-0.34))
		_:
			actor.caption.text=name+" · УРА, ОБНОВКА!"
			actor.position.y=absf(sin(beat*1.2))*0.07
			for i in range(actor.legs.size()): actor.legs[i].rotation.x=sin(beat+i*PI)*0.24
			Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.38,1.50,-0.22))
			Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.38,1.50,-0.22))

func _idle_pose()->void:
	Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.35,0.82,-0.18))
	Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.35,0.82,-0.18))
