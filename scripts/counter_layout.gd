extends RefCounted
## Shared coordinates for furniture, initial stock and support surfaces.
const SHELF_HOME := Vector2(-2.72, 0.55)
const SHELF_HALF := Vector2(0.55, 0.275)
const SHELF_YAW := PI / 4.0
const SHELF_PULL := 0.55 # preserve the cook-facing edge while removing the far half of the old 1.1 m depth
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

static func shelf_forward() -> Vector2:
	return Vector2(sin(SHELF_YAW), cos(SHELF_YAW))

static func shelf_center() -> Vector2:
	return SHELF_HOME + shelf_forward() * SHELF_PULL

static func shelf_point(local_point: Vector2) -> Vector2:
	var c := cos(SHELF_YAW)
	var s := sin(SHELF_YAW)
	return shelf_center() + Vector2(local_point.x * c + local_point.y * s, -local_point.x * s + local_point.y * c)

static func shelf_local(point: Vector2) -> Vector2:
	var offset := point - shelf_center()
	var c := cos(SHELF_YAW)
	var s := sin(SHELF_YAW)
	return Vector2(offset.x * c - offset.y * s, offset.x * s + offset.y * c)

static func shelf_contains(point: Vector2) -> bool:
	var local := shelf_local(point)
	return absf(local.x) <= SHELF_HALF.x and absf(local.y) <= SHELF_HALF.y

static func support(point: Vector2, height := 100.0) -> float:
	if shelf_contains(point):
		var level := 0.015
		for y in LEVELS:
			if y <= height + 0.06: level = y
		return level
	if point.x >= 0.85 and point.x <= 2.15 and point.y > 1.125 and point.y <= 1.68:
		return CROCKERY_Y
	if on_tray(point): return TRAY_Y
	if absf(point.x) <= 2.15 and absf(point.y) <= 1.125: return TABLE_Y
	return 0.015
