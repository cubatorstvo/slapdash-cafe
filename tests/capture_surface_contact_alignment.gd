extends SceneTree

const SceneRuntime = preload("res://scripts/scene_runtime.gd")
const StationView = preload("res://scripts/station_view.gd")
const Model = preload("res://scripts/cooking_model.gd")
const CookAvatar = preload("res://scripts/cook_avatar.gd")
const Props = preload("res://scripts/props.gd")

var world: Node3D
var camera: Camera3D

func _initialize() -> void:
	run.call_deferred()

func setup_world() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("26343b")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("dbe7df")
	e.ambient_light_energy = 0.65
	env.environment = e
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -35, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	world.add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 50
	world.add_child(camera)

func clear_scene() -> void:
	for child in world.get_children().duplicate():
		if child == camera or child is WorldEnvironment or child is DirectionalLight3D: continue
		child.free()

func save(path: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	assert(error == OK)
	print("CAPTURED: ", path)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	setup_world()
	await capture_food()
	clear_scene()
	await capture_sofa()
	quit()

func capture_food() -> void:
	var station := StationView.new()
	world.add_child(station)
	station.build(false)
	var model := Model.new()
	model.reset("potato")
	model._load_food("potato", 0)
	model.potato = Model.PAN_CENTER + Vector2(0.04, 0.14)
	model.potato_state = "pan"
	model.elevations.potato = Model.PAN_LIFT
	model.potato_orientation = Quaternion(Vector3(0.3, 0.0, 1.0).normalized(), 0.45)
	model._store_food("potato")
	model._load_food("sausage", 0)
	model.sausage = Vector2(0.55, 0.48)
	model.sausage_state = "table"
	model.elevations.sausage = Model.surface_at(model.sausage) - Model.BASE_Y
	model.sausage_angle = 0.0
	model._store_food("sausage")
	for i in [1, 2]:
		model.potatoes[i].potato_state = "eaten"
		model.sausages[i].sausage_state = "eaten"
	station.update_view(model, 0.0, false)
	camera.position = Vector3(-2.20, 1.75, 2.35)
	camera.look_at(Vector3(Model.PAN_CENTER.x, 1.18, Model.PAN_CENTER.y), Vector3.UP)
	await save("/tmp/surface_potato.png")
	camera.position = Vector3(2.35, 1.65, 2.35)
	camera.look_at(Vector3(0.55, 1.10, 0.48), Vector3.UP)
	await save("/tmp/surface_sausage.png")

func capture_sofa() -> void:
	Props.box(world, Vector3(5.6, 0.10, 4.0), Vector3(0, -0.05, 0), Color("776f60"))
	var sofa := preload("res://scenes/lounge/sofa.tscn").instantiate() as Node3D
	world.add_child(sofa)
	var actor := SceneRuntime.instantiate("res://scenes/actors/cook_avatar.tscn", CookAvatar) as Node3D
	world.add_child(actor)
	await process_frame
	var spot := {"id":"sofa_left", "pose":"chat", "position":Vector3(-0.55, 0.0, -0.25), "yaw":0.0}
	actor.lounge_pose(spot, 1.2, 0)
	camera.position = Vector3(2.65, 1.95, -3.15)
	camera.look_at(Vector3(-0.25, 0.82, -0.05), Vector3.UP)
	await save("/tmp/surface_sofa.png")
