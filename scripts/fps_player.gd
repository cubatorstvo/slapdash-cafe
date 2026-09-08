extends CharacterBody3D
## Feet-origin FPS body. Station-local bounds match the recorded clone's workspace.

const EYE_HEIGHT := 1.70
const BODY_RADIUS := 0.25
const ZONE_MIN := Vector2(-2.6, -1.4)
const ZONE_MAX := Vector2(2.6, 2.85)
const LOOK_SENSITIVITY := 0.0022
var camera: Camera3D
var station: Node3D
var constrained := false
var zone_min := ZONE_MIN
var zone_max := ZONE_MAX

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	camera = Camera3D.new()
	add_child(camera)
	camera.position.y = EYE_HEIGHT
	camera.fov = 78.0
	camera.near = 0.04
	camera.current = true

func look(movement: Vector2) -> void:
	rotation.y -= movement.x * LOOK_SENSITIVITY
	camera.rotation.x = clampf(camera.rotation.x - movement.y * LOOK_SENSITIVITY, deg_to_rad(-78), deg_to_rad(72))

func advance(delta: float, movement: Vector2) -> void:
	var desired := global_basis * Vector3(movement.x, 0, movement.y)
	var speed := 2.2 if constrained else 3.5
	velocity.x = desired.x * speed
	velocity.z = desired.z * speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	# Clamp supplements physical barriers during their deferred enable/disable tick.
	if constrained and is_instance_valid(station):
		var local := station.to_local(global_position)
		local.x = clampf(local.x, zone_min.x + BODY_RADIUS, zone_max.x - BODY_RADIUS)
		local.z = clampf(local.z, zone_min.y + BODY_RADIUS, zone_max.y - BODY_RADIUS)
		global_position = station.to_global(local)

func pose_in(reference: Node3D) -> Dictionary:
	var local := reference.to_local(global_position)
	return {"position": local, "yaw": wrapf(global_rotation.y - reference.global_rotation.y, -PI, PI), "pitch": camera.rotation.x}
