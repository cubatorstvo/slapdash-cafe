extends CharacterBody3D
## Feet-origin FPS body. Station-local bounds match the recorded clone's workspace.

const EYE_HEIGHT := 1.70
const BODY_RADIUS := 0.25
const ZONE_MIN := Vector2(-2.6, -1.4)
const ZONE_MAX := Vector2(2.6, 2.85)
const LOOK_SENSITIVITY := 0.0022
var camera: Camera3D
var body_collider: CollisionShape3D
var station: Node3D
var constrained := false
var zone_min := ZONE_MIN
var zone_max := ZONE_MAX
var sleeping := false
var wake_pitch := -0.2

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	body_collider = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = 1.8
	body_collider.shape = capsule
	body_collider.position.y = 0.9
	add_child(body_collider)
	camera = Camera3D.new()
	add_child(camera)
	camera.position.y = EYE_HEIGHT
	camera.fov = 78.0
	camera.near = 0.04
	camera.current = true

func look(movement: Vector2) -> void:
	if sleeping: return
	rotation.y -= movement.x * LOOK_SENSITIVITY
	camera.rotation.x = clampf(camera.rotation.x - movement.y * LOOK_SENSITIVITY, deg_to_rad(-78), deg_to_rad(72))

func advance(delta: float, movement: Vector2) -> void:
	if sleeping:
		velocity = Vector3.ZERO
		return
	var desired := global_basis * Vector3(movement.x, 0, movement.y)
	var speed := 2.2 if constrained else 3.5
	velocity.x = desired.x * speed
	velocity.z = desired.z * speed
	if not is_on_floor(): velocity.y -= 18.0 * delta
	elif velocity.y <= 0: velocity.y = -0.5
	move_and_slide()
	# Clamp supplements physical barriers during their deferred enable/disable tick.
	if constrained and is_instance_valid(station):
		var local := station.to_local(global_position)
		local.x = clampf(local.x, zone_min.x + BODY_RADIUS, zone_max.x - BODY_RADIUS)
		local.z = clampf(local.z, zone_min.y + BODY_RADIUS, zone_max.y - BODY_RADIUS)
		global_position = station.to_global(local)

func enter_sleep(point: Vector3, yaw: float) -> void:
	if not sleeping: wake_pitch = camera.rotation.x
	sleeping = true
	velocity = Vector3.ZERO
	global_position = point
	rotation.y = yaw
	body_collider.set_deferred("disabled",true)
	camera.position = Vector3(1.5,0.18,0)
	camera.rotation = Vector3(-0.12,0,-PI/2)

func exit_sleep(point: Vector3) -> void:
	if not sleeping: return
	sleeping = false
	global_position = point
	velocity = Vector3.ZERO
	body_collider.set_deferred("disabled",false)
	camera.position = Vector3(0,EYE_HEIGHT,0)
	camera.rotation.z = 0.0
	camera.rotation.y = 0.0
	camera.rotation.x = clampf(wake_pitch,deg_to_rad(-78),deg_to_rad(72))

func pose_in(reference: Node3D) -> Dictionary:
	var local := reference.to_local(global_position)
	return {"position": local, "yaw": wrapf(global_rotation.y - reference.global_rotation.y, -PI, PI), "pitch": camera.rotation.x}
