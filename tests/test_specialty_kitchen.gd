extends SceneTree
const Model=preload("res://scripts/specialty_cooking_model.gd")
var failures:=0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func prepare(model, dish: String) -> void:
	model.reset(dish)
	model.patty_sides=[1.0,1.0]
	model.patty_season=1.0
	model.patty_state="assembly"
	model.positions.patty=model.ASSEMBLY
	model.positions.bun=model.ASSEMBLY
	model.bun_toast=1.0
	model.sauce_amount=1.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("1/3: shared griddle is a real bottleneck")
	var model=Model.new()
	model.reset("burger")
	model.positions.patty=model.GRIDDLE
	model.positions.bun=model.GRIDDLE
	model.step([{},{}],1.0)
	check(model.griddle_conflict,"Patty and bun collide on the shared griddle")
	check(is_zero_approx(model.patty_sides[0]) and is_zero_approx(model.bun_toast),"Conflict pauses both cooking jobs")
	model.positions.bun=Vector2(2.0,0.2)
	model.step([{},{}],1.0)
	check(model.patty_sides[0]>0.0 and not model.griddle_conflict,"Freeing the griddle resumes the patty")

	print("2/3: role snapshots remain separate while sharing timing")
	model.reset("burger")
	model.patty_sides=[0.7,0.2]
	model.patty_season=1.0
	var grill_snapshot:Dictionary=model.zone_snapshot(0)
	model.bun_toast=0.8
	model.sauce_amount=1.0
	var assembly_snapshot:Dictionary=model.zone_snapshot(1)
	var restored=Model.new()
	restored.reset("burger")
	restored.restore_zone(0,grill_snapshot)
	restored.restore_zone(1,assembly_snapshot)
	check(restored.patty_sides==[0.7,0.2],"Grill role snapshot restores its own work")
	check(is_equal_approx(restored.bun_toast,0.8) and is_equal_approx(restored.sauce_amount,1.0),"Assembly role snapshot restores independently")

	print("3/3: three recipes have distinct completion requirements")
	prepare(model,"burger")
	check(model.quality().grade=="S","Base burger can reach S")
	prepare(model,"cheeseburger")
	check(model.quality().grade!="S","Cheeseburger needs cheese")
	model.cheese_applied=true
	check(model.quality().grade=="S","Cheese completes cheeseburger")
	prepare(model,"spicy_burger")
	check(model.quality().grade!="S","Spicy burger needs chili")
	model.chili_amount=1.0
	check(model.quality().grade=="S","Chili completes spicy burger")
	print("PASS: specialty shared-griddle kitchen" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
