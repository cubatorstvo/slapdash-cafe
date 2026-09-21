extends Node3D
## Physical comedy around a live chef master-class. Cinematic angles are intentionally unrelated.
const Person=preload("res://scripts/customer_view.gd")
const Props=preload("res://scripts/props.gd")
const SceneRuntime=preload("res://scripts/scene_runtime.gd")
var station: Node3D
var operator: Node3D
var audience: Array=[]
var anchors: Node3D
var waypoints: Array=[]
var waypoint_index:=0
var age:=0.0
var crouch_clock:=0.0

func point(local: Vector3)->Vector3:
	return station.position+station.basis*local

func setup(owner_station: Node3D)->void:
	station=owner_station
	name="MasterclassLiveScene"
	anchors=SceneRuntime.instantiate("res://scenes/presentation/presentation_accessory_anchors.tscn") as Node3D
	add_child(anchors)
	_build_operator()
	_build_audience()

func _build_operator()->void:
	operator=SceneRuntime.instantiate("res://scenes/actors/customer.tscn",Person) as Node3D
	operator.color=Color("527988"); add_child(operator); operator.caption.text="Оператор · очень важная съёмка"
	var rig:=SceneRuntime.instantiate("res://scenes/presentation/masterclass_camera_rig.tscn") as Node3D
	operator.add_child(rig); rig.position=Vector3(0.34,1.42,-0.20)
	var half: float=float(station.Definition.TYPES[station.type_id].width)*0.5
	var local_points=[Vector3(-half-0.72,0,-1.10),Vector3(half+0.72,0,-0.20),Vector3(half+0.66,0,1.65),Vector3(-half-0.68,0,1.45)]
	var marker_names=["OperatorStart","OperatorRightFront","OperatorRightBack","OperatorLeftBack"]
	waypoints.clear()
	for i in range(marker_names.size()):
		var marker:=anchors.get_node(marker_names[i]) as Marker3D; marker.position=local_points[i]; waypoints.append(point(marker.position))
	operator.position=waypoints[0]

func _build_audience()->void:
	var half: float=float(station.Definition.TYPES[station.type_id].width)*0.5
	var points: Array=[Vector3(-mini(half-0.5,2.0),0,-3.25),Vector3(-0.65,0,-3.45),Vector3(0.65,0,-3.45),Vector3(mini(half-0.5,2.0),0,-3.25)]
	var audience_names=["AudienceLeft","AudienceMidLeft","AudienceMidRight","AudienceRight"]
	for i in range(points.size()):
		var marker:=anchors.get_node(audience_names[i]) as Marker3D; marker.position=points[i]
		var viewer:=SceneRuntime.instantiate("res://scenes/actors/customer.tscn",Person) as Node3D
		add_child(viewer)
		viewer.position=point(marker.position)
		viewer.rotation.y=PI
		viewer.caption.text="Зритель" if i>0 else "Зритель · пришёл на мастер-класс"
		viewer.watching=true
		viewer.cook_target=point(Vector3(0,1.55,0.7))
		viewer.food_target=point(Vector3(0,1.0,0.1))
		audience.append(viewer)

func advance(delta: float)->void:
	if not is_instance_valid(station) or not is_instance_valid(operator): return
	age+=delta
	crouch_clock=maxf(0.0,crouch_clock-delta)
	var target: Vector3=waypoints[waypoint_index]
	if operator.walk_to(target,delta*1.45):
		waypoint_index=(waypoint_index+1)%waypoints.size()
		if waypoint_index%2==1: crouch_clock=0.55
		operator.walk_to(waypoints[waypoint_index],delta*1.45)
	operator.scale.y=lerpf(operator.scale.y,0.72 if crouch_clock>0 else 1.0,1.0-exp(-delta*8.0))
	operator.watching=true
	operator.cook_target=point(Vector3(0,1.45,0.35))
	operator.food_target=point(Vector3(0,1.0,0.1))
	for i in range(audience.size()):
		var viewer: Node3D=audience[i]
		viewer.watching=true
		viewer.cook_target=point(Vector3(station.role_home_x(i%station.role_count()),1.45,0.6))
		viewer.food_target=point(Vector3(0,1.0,0.1))

func _process(delta: float)->void:
	advance(delta)
