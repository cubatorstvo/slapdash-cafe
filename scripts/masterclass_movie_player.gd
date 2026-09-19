extends Node
## Replays accepted master-class frames into the lounge TV SubViewport.
const Station=preload("res://scripts/work_station.gd")
const Highlights=preload("res://scripts/masterclass_highlights.gd")
const Definition=preload("res://scripts/station_definition.gd")
var viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var stage: Node3D
var screen: MeshInstance3D
var idle_material: Material
var movie_material: StandardMaterial3D
var record: Dictionary={}
var record_id:=0
var active:=false
var last_camera:=-1

func setup(target_screen: MeshInstance3D)->void:
	screen=target_screen
	idle_material=screen.material_override.duplicate() if screen.material_override!=null else null
	viewport=SubViewport.new()
	viewport.name="MasterclassMovieViewport"
	viewport.size=Vector2i(640,360)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.world_3d=World3D.new()
	add_child(viewport)
	world_root=Node3D.new()
	viewport.add_child(world_root)
	camera=Camera3D.new()
	world_root.add_child(camera)
	camera.current=true
	camera.fov=57.0
	camera.near=0.05
	var light:=DirectionalLight3D.new()
	world_root.add_child(light)
	light.rotation_degrees=Vector3(-55,-25,0)
	light.light_energy=1.4
	var fill:=OmniLight3D.new()
	world_root.add_child(fill)
	fill.position=Vector3(0,4,-2)
	fill.omni_range=10
	fill.light_energy=1.8
	movie_material=StandardMaterial3D.new()
	movie_material.albedo_texture=viewport.get_texture()
	movie_material.emission_enabled=true
	movie_material.emission_texture=viewport.get_texture()
	movie_material.emission_energy_multiplier=0.8
	movie_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED

func _load_record(value: Dictionary)->void:
	if is_instance_valid(stage):
		stage.queue_free()
		stage=null
	record=value.duplicate(true)
	record_id=int(record.get("id",0))
	last_camera=-1
	stage=Station.new()
	stage.manual_station=true
	stage.masterclass_station=true
	stage.station_id=1
	stage.slot_index=0
	stage.type_id=str(record.get("source_type","counter"))
	var config: Dictionary=record.get("scene_config",{}) if record.get("scene_config",{}) is Dictionary else {}
	stage.equipment=config.get("equipment",Definition.DISH_EQUIPMENT.get(str(record.get("dish","")),[])).duplicate()
	stage.upgrades=config.get("upgrades",[]).duplicate()
	world_root.add_child(stage)
	stage.position=Vector3.ZERO
	stage.rotation=Vector3.ZERO
	stage.apply_equipment()
	stage.apply_upgrades()
	if is_instance_valid(stage.view.station_label): stage.view.station_label.hide()
	for node in stage.students: node.hide()

func _camera(index: int)->void:
	if index==last_camera: return
	last_camera=index
	var pose: Dictionary=Highlights.camera_pose(str(record.get("source_type","counter")),index)
	camera.position=pose.position
	camera.look_at(pose.target,Vector3.UP)

func sync(state: Dictionary,value: Dictionary)->void:
	var playing: bool=bool(state.get("playing",false))
	var id: int=int(state.get("id",0))
	if not playing or id<=0 or value.is_empty() or int(value.get("id",0))!=id or not value.get("tracks",[]) is Array or value.get("tracks",[]).is_empty():
		if active:
			active=false
			screen.material_override=idle_material
		return
	if id!=record_id: _load_record(value)
	if record.is_empty() or not is_instance_valid(stage): return
	active=true
	screen.material_override=movie_material
	var segments: Array=record.get("highlight_segments",[])
	if segments.is_empty(): return
	var film_tick:=clampi(floori(float(state.get("elapsed",0.0))*60.0),0,maxi(0,roundi(float(state.get("duration",0.0))*60.0)-1))
	var frame: Dictionary=Highlights.source_tick(segments,film_tick)
	if frame.is_empty(): return
	_camera(int(frame.camera))
	stage.show_tracks(record.tracks,int(frame.tick))
	stage.view.update_view(stage.model,float(frame.tick)/60.0,false)
	if stage.type_id=="counter": stage.view._update_worker(stage.model,float(frame.tick)/60.0,false)
	var brightness:=0.35+0.65*clampf(float(film_tick%6)/5.0,0.0,1.0) if bool(frame.get("transition",false)) else 1.0
	movie_material.albedo_color=Color(brightness,brightness,brightness,1.0)
	movie_material.emission_energy_multiplier=0.35+brightness*0.55
