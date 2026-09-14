extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",text)
func run() -> void:
	var game=preload("res://scenes/cafe.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false)
	game.service.clear_world()
	game.service.progress=game.service.Progression.new()
	var counter=game.service.add_station("counter",1,false,true)
	counter.staffed=1
	counter.crew[0].clone_id=0
	var kitchen=game.service.add_station("kitchen",2,false,true)
	kitchen.staffed=2
	kitchen.crew[0].clone_id=5
	kitchen.crew[1].clone_id=5
	game.service.progress.free_workers=[{"id":5,"tempo":1.0,"rest":1.0}]
	game.service.progress.free_clones=1
	game.service.progress.next_clone_id=1
	game.service.normalize_workers()
	var assigned: Array=[]
	for station in [counter,kitchen]:
		for role in range(station.staffed): assigned.append(int(station.crew[role].clone_id))
	check(assigned.size()==3,"Three staffed roles remain staffed")
	check(assigned.all(func(id): return id>0),"Every staffed role receives a positive clone id")
	var seen: Dictionary={}
	for id in assigned: seen[id]=true
	check(seen.size()==3,"Duplicate staffed clone ids are repaired")
	var free_id:=int(game.service.progress.free_workers[0].id)
	check(free_id>0 and free_id not in assigned,"Free clone id cannot collide with a staffed clone")
	game.service.progress.shift="night"
	game.service.progress.night_elapsed=0.0
	check(game.evening.workers().size()==3,"Every staffed clone participates in the evening")
	game.evening._process(0.0)
	check(game.evening.performers.size()==3,"Every staffed clone receives a distinct evening actor")
	game._shutdown_tree(game); game.free()
	print("PASS: worker identities stay unique through evening actors" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
