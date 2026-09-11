extends RefCounted
## Shared coordinates for furniture, initial stock and support surfaces.
const TABLE_HALF := Vector2(2.15, 1.125)
const TABLE_FAR_LEFT := Vector2(-TABLE_HALF.x, -TABLE_HALF.y)
const TABLE_FAR_RIGHT := Vector2(TABLE_HALF.x, -TABLE_HALF.y)
const TABLE_NEAR_LEFT := Vector2(-TABLE_HALF.x, TABLE_HALF.y)
const TABLE_NEAR_RIGHT := Vector2(TABLE_HALF.x, TABLE_HALF.y)
const TABLE_BREAK_NEAR := Vector2(-0.75, TABLE_HALF.y)
const TABLE_BREAK_DROP := 0.40
const SHELF_HALF := Vector2(0.55, 0.275)
const SHELF_YAW := PI / 4.0
const LEVELS := [0.35, 0.85, 1.40]
const TRAY := Vector2(1.35, -0.15)
const TRAY_HALF := Vector2(0.58, 0.77)
const TRAY_Y := 1.055
const CROCKERY_Y := 0.40
const CROCKERY_Z := 1.38
const TABLE_Y := 1.015

static func on_tray(point: Vector2, margin := 0.0) -> bool:
	var d := (point - TRAY).abs()
	return d.x <= TRAY_HALF.x - margin and d.y <= TRAY_HALF.y - margin

static func table_contains(point: Vector2) -> bool:
	return absf(point.x) <= TABLE_HALF.x and absf(point.y) <= TABLE_HALF.y

static func _triangle_weights(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var denominator := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(denominator) < 0.000001: return Vector3(-1, -1, -1)
	var wa := ((b.y - c.y) * (point.x - c.x) + (c.x - b.x) * (point.y - c.y)) / denominator
	var wb := ((c.y - a.y) * (point.x - c.x) + (a.x - c.x) * (point.y - c.y)) / denominator
	return Vector3(wa, wb, 1.0 - wa - wb)

static func broken_corner_weights(point: Vector2) -> Vector3:
	return _triangle_weights(point, TABLE_FAR_LEFT, TABLE_NEAR_LEFT, TABLE_BREAK_NEAR)

static func broken_corner_contains(point: Vector2) -> bool:
	if not table_contains(point): return false
	var weights := broken_corner_weights(point)
	return weights.x >= -0.0001 and weights.y >= -0.0001 and weights.z >= -0.0001

static func broken_corner_height(point: Vector2) -> float:
	var weights := broken_corner_weights(point)
	return TABLE_Y - TABLE_BREAK_DROP * weights.y

static func broken_corner_run() -> float:
	var seam := TABLE_BREAK_NEAR - TABLE_FAR_LEFT
	var t := clampf((TABLE_NEAR_LEFT - TABLE_FAR_LEFT).dot(seam) / maxf(seam.length_squared(), 0.000001), 0.0, 1.0)
	return TABLE_NEAR_LEFT.distance_to(TABLE_FAR_LEFT.lerp(TABLE_BREAK_NEAR, t))

static func broken_corner_downhill() -> Vector2:
	var seam := TABLE_BREAK_NEAR - TABLE_FAR_LEFT
	var t := clampf((TABLE_NEAR_LEFT - TABLE_FAR_LEFT).dot(seam) / maxf(seam.length_squared(), 0.000001), 0.0, 1.0)
	var closest := TABLE_FAR_LEFT.lerp(TABLE_BREAK_NEAR, t)
	return (TABLE_NEAR_LEFT - closest).normalized()

static func broken_corner_roll_acceleration() -> Vector2:
	var slope_angle := atan2(TABLE_BREAK_DROP, maxf(broken_corner_run(), 0.000001))
	return broken_corner_downhill() * 9.81 * sin(slope_angle)

static func shelf_offset(local_point: Vector2) -> Vector2:
	var c := cos(SHELF_YAW)
	var s := sin(SHELF_YAW)
	return Vector2(local_point.x * c + local_point.y * s, -local_point.x * s + local_point.y * c)

static func shelf_center() -> Vector2:
	# Join the cabinet to the table at one exact corner: cabinet right-near = table left-near.
	return TABLE_NEAR_LEFT - shelf_offset(Vector2(SHELF_HALF.x, SHELF_HALF.y))

static func shelf_point(local_point: Vector2) -> Vector2:
	return shelf_center() + shelf_offset(local_point)

static func shelf_local(point: Vector2) -> Vector2:
	var offset := point - shelf_center()
	var c := cos(SHELF_YAW)
	var s := sin(SHELF_YAW)
	return Vector2(offset.x * c - offset.y * s, offset.x * s + offset.y * c)

static func shelf_contains(point: Vector2) -> bool:
	var local := shelf_local(point)
	return absf(local.x) <= SHELF_HALF.x and absf(local.y) <= SHELF_HALF.y

static func table_height(point: Vector2) -> float:
	return broken_corner_height(point) if broken_corner_contains(point) else TABLE_Y

static func support(point: Vector2, height := 100.0) -> float:
	if shelf_contains(point):
		var level := 0.015
		for y in LEVELS:
			if y <= height + 0.06: level = y
		return level
	if point.x >= 0.85 and point.x <= 2.15 and point.y > 1.125 and point.y <= 1.68:
		return CROCKERY_Y
	if on_tray(point): return TRAY_Y
	if table_contains(point): return table_height(point)
	return 0.015
