from pathlib import Path

p=Path('scripts/cafe_service.gd')
s=p.read_text()
start=s.index('func normalize_workers() -> void:\n')
end=s.index('\nfunc assign_clones() -> void:', start)
new='''func normalize_workers() -> void:\n\t# Old prototype saves may carry clone_id=0, duplicate ids or a stale next_clone_id.\n\t# Stations render by staffed count, while evening actors are keyed by clone id, so make\n\t# every active worker identity positive and unique before assignment or animation.\n\tvar max_existing_id := 0\n\tfor station in stations:\n\t\tif station.manual_station: continue\n\t\tvar active_roles: int=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())\n\t\tfor role in range(active_roles): max_existing_id=maxi(max_existing_id,int(station.crew[role].get("clone_id",0)))\n\tfor worker in progress.free_workers: max_existing_id=maxi(max_existing_id,int(worker.get("id",0)))\n\tprogress.next_clone_id=maxi(1,progress.next_clone_id,max_existing_id+1)\n\n\tvar used_ids := {}\n\tfor station in stations:\n\t\tif station.manual_station: continue\n\t\tvar active_roles: int=station.role_count() if station.staffed<0 else mini(station.staffed,station.role_count())\n\t\tfor role in range(active_roles):\n\t\t\tvar member: Dictionary=station.crew[role]\n\t\t\tvar id:=int(member.get("clone_id",0))\n\t\t\tif id<=0 or used_ids.has(id):\n\t\t\t\tid=progress.next_clone_id\n\t\t\t\tprogress.next_clone_id+=1\n\t\t\t\tmember.clone_id=id\n\t\t\tused_ids[id]=true\n\t\t\tmember.tempo=clampf(float(member.get("tempo",1.0)),0.7,10.0)\n\t\t\tmember.rest=progress.rest_multiplier\n\n\tfor worker in progress.free_workers:\n\t\tvar id:=int(worker.get("id",0))\n\t\tif id<=0 or used_ids.has(id):\n\t\t\tid=progress.next_clone_id\n\t\t\tprogress.next_clone_id+=1\n\t\t\tworker.id=id\n\t\tused_ids[id]=true\n\t\tworker.tempo=clampf(float(worker.get("tempo",1.0)),0.7,10.0)\n\t\tworker.rest=1.0\n\n\twhile progress.free_workers.size()<progress.free_clones:\n\t\tvar id:=progress.next_clone_id\n\t\tprogress.next_clone_id+=1\n\t\tprogress.free_workers.append({"id":id,"tempo":1.0,"rest":1.0})\n\t\tused_ids[id]=true\n\tprogress.free_clones=progress.free_workers.size()\n'''
p.write_text(s[:start]+new+s[end:])

Path('tests/test_worker_identity.gd').write_text(r'''extends SceneTree
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
''')
