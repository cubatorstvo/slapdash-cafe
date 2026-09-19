extends Node3D
## Physical courier/assembler. Authoritative lifecycle state lives in progress.installer_jobs.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Props=preload("res://scripts/props.gd")
var actor: Node3D
var parcel_box: Node3D
var clock:=0.0

func setup(index: int)->void:
	actor=Avatar.new()
	actor.tint=[Color("d58c5c"),Color("7b9fc0"),Color("a889ba"),Color("78a47e")][index%4]
	add_child(actor)
	actor.add_to_group("automatic_door_actor")
	actor.hat.hide()
	actor.notebook.hide()
	parcel_box=Node3D.new()
	actor.add_child(parcel_box)
	Props.box(parcel_box,Vector3(0.52,0.46,0.44),Vector3.ZERO,Color("b28a59"))
	Props.box(parcel_box,Vector3(0.09,0.47,0.45),Vector3.ZERO,Color("d4be91"))

func apply(job: Dictionary,install_target: Vector3,cook_target: Vector3,exit_target: Vector3,delta: float)->void:
	if actor==null: return
	clock+=delta
	var raw: Array=job.get("position",[0.0,0.0,0.0])
	var base: Vector3=Vector3(float(raw[0]),0.0,float(raw[2])) if raw.size()==3 else Vector3.ZERO
	actor.global_position=base
	actor.rotation=Vector3(0,float(job.get("yaw",0.0)),0)
	actor.head.rotation=Vector3.ZERO
	actor.book.set_reading(false)
	actor.notebook.hide()
	for i in range(actor.legs.size()):
		actor.legs[i].position.x=(-0.14 if i==0 else 0.14)
		actor.legs[i].rotation=Vector3.ZERO
	actor.rotation.z=0.0
	var state: String=str(job.get("phase","waiting_delivery"))
	if bool(job.get("blocked_path",false)) and state in ["approaching_box","carrying"]:
		actor.caption.text="Сборщик · Ждёт свободного прохода"
		parcel_box.visible=state=="carrying"
		_idle_arms()
		return
	match state:
		"waiting_delivery":
			actor.caption.text="Сборщик · ждёт доставку"
			parcel_box.hide()
			_idle_arms()
		"approaching_box":
			actor.caption.text="Сборщик · идёт к коробке"
			parcel_box.hide()
			_walk_pose(false)
		"carrying":
			actor.caption.text="Сборщик · несёт коробку"
			parcel_box.show()
			parcel_box.position=Vector3(0,0.94,-0.46)
			_walk_pose(true)
		"waiting":
			parcel_box.show()
			parcel_box.position=Vector3(0.54,0.25,0.10)
			var wait_variant: int=posmod(int(job.get("variant",0)),4)
			var wait_age: float=float(job.get("phase_age",0.0))
			if wait_variant==0: actor.global_position+=Vector3(sin(wait_age*1.7)*0.20,0,cos(wait_age*1.1)*0.06)
			elif wait_variant==1: actor.global_position+=Vector3(sin(wait_age*2.4)*0.09,0,cos(wait_age*1.8)*0.05)
			_wait_pose(wait_variant,wait_age,cook_target,exit_target)
		"installing":
			actor.caption.text="Сборщик · устанавливает"
			parcel_box.show()
			var local_target: Vector3=actor.to_local(install_target)
			parcel_box.position=local_target
			var reach: Vector3=local_target+Vector3(0,0.18,0)
			Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),reach+Vector3(-0.18,0,0))
			Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),reach+Vector3(0.18,0,0))
			actor.rotation.x=0.10+sin(clock*5.0)*0.035
			actor.head.rotation.x=0.22
			for leg in actor.legs: leg.rotation.x=0.08
		"leaving":
			actor.caption.text="Сборщик · домой"
			parcel_box.hide()
			_walk_pose(false)
		"finished":
			actor.caption.text="Сборщик · готово"
			parcel_box.hide()
			_idle_arms()
		_:
			parcel_box.hide()
			_idle_arms()

func _walk_pose(carrying: bool)->void:
	for i in range(actor.legs.size()): actor.legs[i].rotation.x=sin(clock*8.0+i*PI)*0.31
	if carrying:
		Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.22,1.02,-0.49))
		Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.22,1.02,-0.49))
	else:
		Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.36,0.82,-0.18+sin(clock*8.0)*0.16))
		Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.36,0.82,-0.18-sin(clock*8.0)*0.16))
	actor.head.rotation.y=sin(clock*1.5)*0.10

func _idle_arms()->void:
	Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),Vector3(-0.35,0.82,-0.18))
	Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),Vector3(0.35,0.82,-0.18))

func _wait_pose(variant: int,age: float,cook_target: Vector3,exit_target: Vector3)->void:
	var cycle: float=fposmod(age,6.0)
	var left: Vector3=Vector3(-0.35,0.82,-0.18)
	var right: Vector3=Vector3(0.35,0.82,-0.18)
	match posmod(variant,4):
		0:
			actor.caption.text="Сборщик · смотрит на часы"
			var watch: float=smoothstep(0.2,0.8,cycle)*smoothstep(2.4,1.6,cycle)
			left=left.lerp(Vector3(-0.10,1.43,-0.33),clampf(watch,0.0,1.0))
			right=right.lerp(Vector3(0.05,1.30,-0.39),clampf(watch,0.0,1.0))
			actor.head.rotation=Vector3(0.18,-0.28*clampf(watch,0.0,1.0),0)
			actor.legs[1].rotation.x=sin(age*10.0)*0.18
			actor.rotation.z=sin(age*2.2)*0.025
		1:
			actor.caption.text="Сборщик · очень хочет в туалет"
			actor.legs[0].position.x=-0.075
			actor.legs[1].position.x=0.075
			actor.legs[0].rotation.x=0.12+sin(age*5.0)*0.10
			actor.legs[1].rotation.x=-0.12-sin(age*5.0)*0.10
			actor.rotation.x=0.14
			actor.rotation.z=sin(age*3.2)*0.055
			left=Vector3(-0.18,0.86,-0.28)
			right=Vector3(0.18,0.86,-0.28)
			actor.head.rotation.x=0.20
		2:
			actor.caption.text="Сборщик · очень хочет домой"
			var toward: Vector3=exit_target-base_position()
			toward.y=0
			var step: float=sin(clampf(cycle/2.4,0.0,1.0)*PI) if cycle<2.4 else 0.0
			if toward.length()>0.05:
				toward=toward.normalized()
				actor.global_position+=toward*0.42*step
				var desired: float=atan2(-toward.x,-toward.z)
				actor.rotation.y=lerp_angle(actor.rotation.y,desired,0.75*step)
				actor.head.rotation.y=0.18*sin(age*1.7)
			for i in range(actor.legs.size()): actor.legs[i].rotation.x=sin(age*7.0+i*PI)*0.22*step
		3:
			actor.caption.text="Сборщик · сверлит повара взглядом"
			if cook_target.is_finite():
				var flat: Vector3=cook_target-actor.global_position
				flat.y=0
				if flat.length()>0.05:
					var desired:=atan2(-flat.x,-flat.z)
					actor.rotation.y=lerp_angle(actor.rotation.y,desired,0.18)
					var local: Vector3=actor.to_local(cook_target)
					actor.head.rotation.y=clampf(atan2(-local.x,-local.z),-1.05,1.05)
					actor.head.rotation.x=clampf(-atan2(local.y-1.5,maxf(0.2,Vector2(local.x,local.z).length())),-0.30,0.30)
					left=Vector3(-0.40,0.90,-0.12)
					right=Vector3(0.40,0.90,-0.12)
	Props.align_line(actor.arms[0],Vector3(-0.3,1.2,0),left)
	Props.align_line(actor.arms[1],Vector3(0.3,1.2,0),right)

func base_position()->Vector3:
	return actor.global_position
