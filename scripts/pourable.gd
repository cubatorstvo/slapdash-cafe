extends RefCounted
## Shared deterministic pouring geometry for jugs, cups and pots.
## Volumes/materials belong to the owner model; this class controls the vessel.
var angle := 0.0
var radius := 0.24
var rim_height := 0.5
var pivot_height := 0.25
var max_rate := 650.0

func _init(r := 0.24, rim := 0.5, rate := 650.0) -> void:
	radius = r
	rim_height = rim
	pivot_height = rim / 2
	max_rate = rate

func advance(delta: float, use_item: bool) -> void:
	angle = move_toward(angle, 110.0 if use_item else 0.0, delta * (52.0 if use_item else 140.0))

func rate() -> float:
	return max_rate * pow(clampf((angle - 28.0) / 72.0, 0, 1), 2)

func take(volume: float, delta: float) -> float:
	return minf(maxf(0, volume), rate() * delta)

func mouth(base: Vector3) -> Vector3:
	var a := deg_to_rad(angle)
	return base + Vector3(radius * cos(a) + (rim_height - pivot_height) * sin(a), pivot_height - radius * sin(a) + (rim_height - pivot_height) * cos(a), 0)

func landing(base: Vector3, surface_y: float) -> Vector2:
	var start := mouth(base)
	# A heavy pour travels a little farther before falling; never random.
	var travel := pow(clampf((angle - 65) / 45, 0, 1), 2) * minf(0.30, sqrt(maxf(0, start.y - surface_y)) * 0.24)
	return Vector2(start.x + travel, start.z)

static func accepted(amount: float, current: float, capacity: float) -> float:
	return minf(maxf(0, amount), maxf(0, capacity - current))
