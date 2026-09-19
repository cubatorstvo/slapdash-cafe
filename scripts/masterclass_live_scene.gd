extends Node3D
## Physical comedy around a live chef master-class. Cinematic angles are intentionally unrelated.
const Person=preload("res://scripts/customer_view.gd")
const Props=preload("res://scripts/props.gd")
var station: Node3D
var operator: Node3D
var audience: Array=[]
var waypoints: Array=[]
var waypoint_index:=0
var age:=0.0
var crouch_clock:=0.0

func setup(owner_station: Node3D)->void:
	station=owner_station
	name="MasterclassLiveScene"
	_build_operator()
	_build_audience()

func _build_operator()->void:
	operator=Person.new()
	operator.color=Color("527988")
	add_child(operator)
	operator.caption.text="Оператор · очень важная съёмка"
	var rig:=Node3D.new()
	operator.add_child(rig)
	rig.position=Vector3(0.34,1.42,-0.20)
	Props.box(rig,Vector3(0.34,0.22,0.40),Vector3.ZERO,Color("273c45"))
	Props.box(rig,Vector3(0.16,0.12,0.23),Vector3(0,0, -0.29),Color("17282f"))
	Props.cylinder(rig,0.055,0.26,Vector3(0,0,-0.48),Color("1d3038"))
	var half: float=float(station.Definition.TYPES[station.type_id].width)*0.5
	waypoints=[
		station.position+Vector3(-half-0.72,0,-1.10),
		station.position+Vector3(half+0.72,0,-0.20),
		station.position+Vector3(half+0.66,0,1.65),
		station.position+Vector3(-half-0.68,0,1.45)
	]
	operator.position=waypoints[0]

func _build_audience()->void:
	var half: float=float(station.Definition.TYPES[station.type_id].width)*0.5
	var points: Array=[
		Vector3(-mini(half-0.5,2.0),0,-3.25),
		Vector3(-0.65,0,-3.45),
		Vector3(0.65,0,-3.45),
		Vector3(mini(half-0.5,2.0),0,-3.25)
	]
	for i in range(points.size()):
		var viewer:=Person.new()
		add_child(viewer)
		viewer.position=station.position+points[i]
		viewer.rotation.y=PI
		viewer.caption.text="Зритель" if i>0 else "Зритель · пришёл на мастер-класс"
		viewer.watching=true
		viewer.cook_target=station.position+Vector3(0,1.55,0.7)
		viewer.food_target=station.position+Vector3(0,1.0,0.1)
		audience.append(viewer)

func advance(delta: float)->void:
	if not is_instance_valid(station) or not is_instance_valid(operator): return
	age+=delta
	crouch_clock=maxf(0.0,crouch_clock-delta)
	var target: Vector3=waypoints[waypoint_index]
	if operator.walk_to(target,delta*1.45):
		waypoint_index=(waypoint_index+1)%waypoints.size()
		if waypoint_index%2==1: crouch_clock=0.55
	operator.scale.y=lerpf(operator.scale.y,0.72 if crouch_clock>0 else 1.0,1.0-exp(-delta*8.0))
	operator.watching=true
	operator.cook_target=station.position+Vector3(0,1.45,0.35)
	operator.food_target=station.position+Vector3(0,1.0,0.1)
	for i in range(audience.size()):
		var viewer: Node3D=audience[i]
		viewer.watching=true
		viewer.cook_target=station.position+Vector3(station.role_home_x(i%station.role_count()),1.45,0.6)
		viewer.food_target=station.position+Vector3(0,1.0,0.1)

func _process(delta: float)->void:
	advance(delta)
