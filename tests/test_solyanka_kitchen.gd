extends SceneTree
const Model = preload("res://scripts/solyanka_cooking_model.gd")
const View = preload("res://scripts/solyanka_station_view.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	run.call_deferred()

func use_tool(model, role: int, item: String, seconds: float) -> void:
	model.grab(role,item)
	model.positions[item] = model.POT
	model.heights[item] = 0.35
	for _i in range(ceili(seconds*20.0)):
		var commands := [{},{},{}]
		commands[role] = {"use":true}
		model.step(commands,0.05)
	model.drop(role)

func dump_items(model, items: Array) -> void:
	for item in items:
		var role: int = model.item_role(item)
		check(model.grab(role,item),"Can grab "+item)
		model.positions[item] = model.POT
		model.heights[item] = 0.35
		var commands := [{},{},{}]
		commands[role] = {"dump":true}
		model.step(commands,0.016)
		check(bool(model.dumped[item]),item+" splashes into the pot")

func run() -> void:
	print("1/7: three roles own independent kits")
	var model = Model.new()
	check(model.hands.size()==3 and model.poses.size()==3,"Solyanka has three simultaneous roles")
	check(model.item_role("lighter")==0 and model.item_role("paddle")==1 and model.item_role("salt")==2,"Fire, stir and salt tools belong to separate roles")
	check(model.item_available("boot") and model.item_available("mug") and model.item_available("bolt"),"Comedy objects are real throwable items")

	print("2/7: solo recording roles can all reach the shared cauldron")
	for role in range(3):
		var solo = Model.new()
		solo.live_roles = [role]
		var item: String = ["lighter","paddle","salt"][role]
		check(solo.grab(role,item),"Solo role %d can grab its shared-pot tool"%role)
		for _i in range(20):
			var commands := [{},{},{}]
			commands[role] = {"target":[solo.POT.x,solo.POT.y],"height":0.35}
			solo.step(commands,0.05)
		check(solo.positions[item].distance_to(solo.POT)<=0.92,"Solo role %d can carry its tool into the common cauldron zone"%role)

	print("3/7: fire, stir and salt are active cooking jobs")
	use_tool(model,0,"lighter",0.1)
	use_tool(model,1,"paddle",2.0)
	use_tool(model,2,"salt",0.7)
	check(model.fire_started,"Fire role lights the cauldron")
	check(model.stir_progress>=0.999,"Stir role can fully mix the soup")
	check(model.salt_amount>=1.0,"Salt role can season the soup")

	print("4/7: E-style dump accepts food and random objects")
	var thirteen_foods := ["potato","onion","tomato","carrot","garlic","cabbage","cucumber","beet","pepper","zucchini","pickle","lemon","sausage"]
	dump_items(model,thirteen_foods)
	check(model.pot_count()==13,"Thirteen normal food ingredients satisfy the shared pot count without comedy objects")
	check(model.strange_count()==0,"Comedy objects stay optional")
	check(model.quality().grade=="S","Thirteen food items plus three role jobs produce S")
	check(model.quality().components[3].lines[0]=="В котле: 13 / 13","Recipe progress exposes the live shared count")
	dump_items(model,["boot"])
	check(model.strange_count()==1 and model.quality().grade=="S","A random object can be thrown in for comedy without a quality penalty")

	print("5/7: sequential role snapshots compose into one cauldron")
	var source = Model.new()
	source.fire_started = true
	source.dumped.potato = true
	var fire_snapshot: Dictionary = source.zone_snapshot(0)
	source.reset()
	source.stir_progress = 0.8
	source.dumped.cabbage = true
	var stir_snapshot: Dictionary = source.zone_snapshot(1)
	source.reset()
	source.salt_amount = 1.2
	source.dumped.pickle = true
	var salt_snapshot: Dictionary = source.zone_snapshot(2)
	var restored = Model.new()
	restored.restore_zone(0,fire_snapshot)
	restored.restore_zone(1,stir_snapshot)
	restored.restore_zone(2,salt_snapshot)
	check(restored.fire_started and is_equal_approx(restored.stir_progress,0.8) and restored.salt_amount>=1.0,"Role-specific cooking state survives sequential recording")
	check(restored.pot_count()==3,"Thrown contents from all three role snapshots compose")

	print("6/7: serving is always available; recipe actions affect quality")
	var incomplete = Model.new()
	for item in thirteen_foods: incomplete.dumped[item] = true
	var incomplete_quality := incomplete.quality()
	check(incomplete_quality.grade != "S","Missing fire, salt and stirring lowers the final grade")
	check(incomplete.take_serving().size()==2,"Incomplete solyanka can still be served")
	check(incomplete.take_serving().is_empty(),"The same cauldron cannot be served twice")
	var awful = Model.new()
	for item in ["potato","onion","tomato"]: awful.dumped[item] = true
	check(awful.quality().grade in ["D","C"],"Breaking most recipe goals produces a low grade")
	check(awful.take_serving().size()==2,"Recipe violations never block serving, even below 13 items")
	var complete = Model.new()
	for item in thirteen_foods: complete.dumped[item] = true
	complete.fire_started = true
	complete.stir_progress = 1.0
	complete.salt_amount = 1.0
	check(complete.quality().grade=="S","Completing all four recipe goals earns S")
	check(complete.take_serving().size()==2,"Complete solyanka can be served")

	print("7/7: 3D view renders the cauldron without world progress HUD")
	var holder := Node3D.new()
	root.add_child(holder)
	var view = View.new()
	holder.add_child(view)
	view.build(true)
	await process_frame
	view.update_view(model,0.0,false)
	check(view.actors.size()==3,"Solyanka view has three simultaneous cooks")
	check(view.status.text.is_empty() and not view.status.visible,"Kitchen view never exposes recipe progress above the station")
	check(view.broth!=null and view.fire_root!=null,"Central cauldron and fire are rendered")
	holder.queue_free()
	await process_frame
	print("PASS: three-role solyanka kitchen" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
