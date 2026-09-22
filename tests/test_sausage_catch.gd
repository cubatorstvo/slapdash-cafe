extends SceneTree

const Model = preload("res://scripts/cooking_model.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	run.call_deferred()

func held_model() -> Model:
	var model := Model.new()
	model.reset("sausage")
	model.pick_up("sausage_0")
	model.sausage_slip = 0.70
	return model

func run() -> void:
	var normal := held_model()
	var rmb := held_model()
	normal.step(0.1, false, true, false)
	rmb.step(0.1, true, false, true)
	check(absf(normal.sausage_slip - rmb.sausage_slip) < 0.00001, "RMB does not reduce or stabilize sausage slip")
	check(absf(normal.sausage_angle - rmb.sausage_angle) < 0.00001, "RMB does not rotate sausage into a stable carrying pose")

	var model := held_model()
	model.sausage_slip = 0.995
	var before_height := float(model.elevations.sausage)
	model.step(0.1, false, true, false)
	check(model.held.is_empty(), "Sausage leaves the hand after slip reaches the threshold")
	check(model.sausage_state == "slipped", "Hand slip uses the dedicated catchable state")
	check(model.sausage_fall_speed <= -Model.SAUSAGE_SLIP_UPWARD_SPEED + 0.0001, "Slipped sausage receives an upward impulse")
	var slipped_height := float(model.elevations.sausage)
	model.step(0.1, false, true, false)
	check(float(model.elevations.sausage) > slipped_height and slipped_height >= before_height - 0.001, "Slipped sausage pops upward before gravity pulls it down")

	model.pick_up("sausage_0")
	check(model.held == "sausage" and model.sausage_state == "held", "Player can catch a slipped sausage with the normal grab action")
	check(model.sausage_velocity.is_zero_approx() and absf(model.sausage_slip) < 0.0001, "Catching resets slip motion for the next carry")

	print("PASS: sausage slips upward, ignores RMB stabilization and can be caught" if failures == 0 else "FAILED: %d sausage catch checks" % failures)
	quit(1 if failures > 0 else 0)
