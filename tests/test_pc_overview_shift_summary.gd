extends SceneTree
const Scene = preload("res://scenes/cafe.tscn")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,title: String) -> void:
	if value: return
	failures += 1
	printerr("FAIL: ",title)

func _labels(node: Node,result: Array[String]) -> void:
	if node is Label: result.append(node.text)
	for child in node.get_children(): _labels(child,result)

func run() -> void:
	var game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var service=game.service
	var p=service.progress

	print("[1/5] Current shift is separate from campaign totals")
	check(service.current_shift_summary()=={"day":p.day,"served":0,"missed":0,"revenue":0},"Fresh shift starts at zero")
	service.served=4
	service.missed=1
	service.revenue=160
	check(service.current_shift_summary()=={"day":p.day,"served":4,"missed":1,"revenue":160},"Shift summary follows cumulative deltas")

	print("[2/5] Night report finalizes once")
	p.shift="closing"
	service.open_for_business=false
	service.advance_shift(0.0)
	check(p.shift=="night","Closing idle cafe reaches night")
	var finished: Dictionary=service.previous_shift_summary()
	check(finished=={"day":p.day,"served":4,"missed":1,"revenue":160},"Night transition stores completed report")
	service.served=9
	service.missed=3
	service.revenue=500
	service.advance_shift(0.0)
	check(service.previous_shift_summary()==finished,"Night report cannot be overwritten by later calls")

	print("[3/5] New day resets only shift counters")
	var campaign_before: Array=[service.served,service.missed,service.revenue]
	check(service.next_day().is_empty(),"Next day starts from night")
	check(service.current_shift_summary()=={"day":p.day,"served":0,"missed":0,"revenue":0},"Morning starts a fresh shift")
	check([service.served,service.missed,service.revenue]==campaign_before,"Campaign totals remain cumulative")
	check(service.previous_shift_summary()==finished,"Previous report survives morning reset")

	print("[4/5] Save format preserves shift state")
	service.served+=2
	service.missed+=1
	service.revenue+=75
	var saved: Dictionary=service.save_data()
	check(int(saved.get("version",0))==23 and saved.get("shift_summary",{}) is Dictionary,"Save v23 contains shift summary")
	var restored_game=Scene.instantiate()
	root.add_child(restored_game)
	await process_frame
	restored_game.set_physics_process(false)
	check(restored_game.service.load_data(saved),"v23 save restores")
	check(restored_game.service.current_shift_summary()=={"day":p.day,"served":2,"missed":1,"revenue":75},"Mid-shift counters survive save/load")
	check(restored_game.service.previous_shift_summary()==finished,"Previous report survives save/load")

	print("[5/5] Office overview and HUD mode")
	game.office.open("overview")
	await process_frame
	var top: CanvasItem=game.hud.get_node("Root/Top")
	check(not top.visible,"Gameplay top HUD is hidden while office is open")
	var labels: Array[String]=[]
	_labels(game.office.content,labels)
	var text: String="\n".join(labels)
	check("ВЫРУЧКА" in text and "ОБСЛУЖЕНО" in text and "УШЛИ" in text,"Overview renders the three shift metrics")
	check("СЛЕДУЮЩИЙ ШАГ" not in text,"Journey card is not duplicated on overview")
	game.office.close()
	check(top.visible,"Gameplay top HUD returns after closing office")

	restored_game._shutdown_tree(restored_game)
	restored_game.free()
	game._shutdown_tree(game)
	game.free()
	print("PASS: PC overview shift summary" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
