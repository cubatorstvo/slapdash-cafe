extends SceneTree
const Scene=preload("res://scenes/cafe.tscn")
const Annex=preload("res://scripts/cafe_annex.gd")
var failures:=0

func check(ok: bool,message: String)->void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func delivery(service: Node3D,id: int)->Dictionary:
	for parcel in service.progress.deliveries:
		if int(parcel.get("id",0))==id: return parcel
	return {}

func job(service: Node3D,id: int)->Dictionary:
	for value in service.progress.installer_jobs:
		if int(value.get("id",0))==id: return value
	return {}

func history_count(service: Node3D,id: int)->int:
	var count:=0
	for entry in service.progress.delivery_history:
		if int(entry.get("id",0))==id: count+=1
	return count

func pos(value: Dictionary)->Vector3:
	var raw: Array=value.get("position",[0.0,0.0,0.0])
	return Vector3(float(raw[0]),float(raw[1]),float(raw[2]))

func advance_shop(game: Node3D,seconds: float,step:=0.10)->void:
	var elapsed:=0.0
	while elapsed<seconds:
		var delta:=minf(step,seconds-elapsed)
		game.shop.advance(delta)
		game.shop._process(minf(delta,0.05))
		elapsed+=delta

func _initialize()->void:
	run.call_deferred()

func run()->void:
	print("1/7: five ordinary-price boxes create five persistent physical installers")
	var game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var service=game.service
	var p=service.progress
	p.stars=2
	p.cash=10000
	p.next_delivery_id=4
	var station=service.add_station("counter",1,false,false)
	station.equipment=["rag"]
	station.apply_equipment()
	station.state="cooking"
	station.customer_id=900
	var before_cash: int=p.cash
	var expected: int=int(game.shop.ITEMS.sauce.price)+int(game.shop.ITEMS.rest_television.price)+int(game.shop.ITEMS.rest_rocking_chair.price)+int(game.shop.ITEMS.plates.price)+int(game.shop.ITEMS.rest_beanbag.price)
	check(game.shop.order("sauce",2,true).is_empty(),"Busy station equipment order accepts an installer")
	check(game.shop.order("rest_television",0,true).is_empty(),"Lounge television order accepts an installer")
	check(game.shop.order("rest_rocking_chair",0,true).is_empty(),"Lounge rocker order accepts an installer")
	check(game.shop.order("plates",2,true).is_empty(),"Second busy equipment box gets its own installer")
	check(game.shop.order("rest_beanbag",0,true).is_empty(),"Third lounge box gets its own installer")
	check(p.cash==before_cash-expected,"Free installers do not add a surcharge to the ordinary goods price")
	check(p.deliveries.size()==5 and p.installer_jobs.size()==5,"Five boxes own five separate installer jobs")
	var ids: Array=[]
	for value in p.installer_jobs: ids.append(int(value.id))
	ids.sort()
	check(ids==[4,5,6,7,8],"Installer identity follows the persistent delivery ids")

	print("2/7: lounge installers use the real rest-room doorway and every pair of feet stays on the floor")
	var door_seen:=false
	var floor_ok:=true
	for _i in range(520):
		game.shop.advance(0.10)
		game.shop._process(0.02)
		for value in p.installer_jobs:
			var at:=pos(value)
			if absf(at.y)>0.001: floor_ok=false
			if int(value.id) in [5,6,8] and (at.distance_to(Annex.REST_DOOR_CAFE)<0.72 or at.distance_to(Annex.REST_DOOR_ROOM)<0.72): door_seen=true
		if history_count(service,5)==1 and history_count(service,6)==1 and history_count(service,8)==1: break
	check(floor_ok,"Authoritative installer positions keep feet at floor height")
	check(door_seen,"A lounge installer physically crosses the existing rest-room doorway")
	check("television" in p.lounge_items and "rocking_chair" in p.lounge_items and "beanbag" in p.lounge_items,"Lounge parcels reach their physical destinations")
	check(history_count(service,5)==1 and history_count(service,6)==1 and history_count(service,8)==1,"Each lounge box is installed exactly once")

	print("3/7: occupied station keeps two boxes with distinct waiting spots and visible body-language variants")
	var watch_job:=job(service,4)
	var angry_job:=job(service,7)
	check(not watch_job.is_empty() and str(watch_job.phase)=="waiting","Clock variant waits at the occupied station")
	check(not angry_job.is_empty() and str(angry_job.phase)=="waiting","Angry variant waits at the occupied station")
	check(pos(watch_job).distance_to(pos(angry_job))>0.35,"Separate installers have separate local waiting spots")
	check(int(watch_job.variant)==0 and int(angry_job.variant)==3,"Persistent ids select the clock and angry variants deterministically")
	watch_job.phase_age=1.15
	angry_job.phase_age=3.4
	game.shop._process(0.12)
	var watch_visual=game.shop.installers.get(4)
	var angry_visual=game.shop.installers.get(7)
	check(is_instance_valid(watch_visual) and "час" in str(watch_visual.actor.caption.text),"Hurry variant visibly looks at a wrist/watch")
	if is_instance_valid(watch_visual):
		check(absf(float(watch_visual.actor.legs[1].rotation.x))>0.02,"Hurry variant physically taps a foot")
	var angry_before:=0.0
	if is_instance_valid(angry_visual): angry_before=float(angry_visual.actor.head.rotation.y)
	if is_instance_valid(station.view.worker): station.view.worker.position.x+=1.2
	game.shop._process(0.12)
	if is_instance_valid(angry_visual):
		check("взгляд" in str(angry_visual.actor.caption.text),"Angry variant announces the matching visible action")
		check(absf(float(angry_visual.actor.head.rotation.y)-angry_before)>0.01 or absf(float(angry_visual.actor.rotation.y)-float(angry_job.yaw))>0.01,"Angry gaze follows the real moving cook target")

	print("4/7: installer-owned boxes refuse manual interaction while manual delivery remains unchanged")
	var blocked_parcel:=delivery(service,4)
	var blocked_at:=pos(watch_job)
	game.camera.global_position=blocked_at+Vector3(0,1.25,2.0)
	game.camera.look_at(blocked_at+Vector3.UP*0.7,Vector3.UP)
	var target: Dictionary=game.shop.target(game.camera,1)
	check(str(target.get("hint",""))=="Этой доставкой займется сборщик","Installer box shows the exact no-touch hint")
	check(game.shop.action(1,{"action":"installer_owned_parcel","id":4})=="Этой доставкой займется сборщик.","Host-side action rejects the same installer-owned parcel")
	var manual_cash: int=p.cash
	check(game.shop.order("cup",2,false).is_empty(),"Manual delivery can coexist beside waiting installers")
	check(p.cash==manual_cash-int(game.shop.ITEMS.cup.price),"Manual delivery keeps the same ordinary item price")
	advance_shop(game,8.1)
	var manual_id:=int(p.deliveries.back().id)
	var manual:=delivery(service,manual_id)
	game.player.global_position=Vector3(manual.position[0],manual.position[1],manual.position[2])
	check(game.shop.action(1,{"action":"take_parcel","id":manual_id}).is_empty(),"Player still picks up a manual box")
	station.state="idle"
	station.customer_id=-1
	game.player.global_position=game.shop.installation_position(manual)
	check(game.shop.action(1,{"action":"install_parcel","id":manual_id}).is_empty(),"Player still installs a manual box by hand")
	check("cup" in station.equipment and history_count(service,manual_id)==1,"Manual installation updates equipment exactly once")

	print("5/7: waiting installers install once, then remain as physical leaving workers after their deliveries disappear")
	for _i in range(200):
		game.shop.advance(0.10)
		game.shop._process(0.02)
		if delivery(service,4).is_empty() and delivery(service,7).is_empty(): break
	check(delivery(service,4).is_empty() and delivery(service,7).is_empty(),"Both released installer boxes leave the delivery queue after installation")
	check("sauce" in station.equipment and "plates" in station.equipment,"Both waiting equipment parcels were installed")
	check(history_count(service,4)==1 and history_count(service,7)==1,"Each waiting box installs exactly once")
	check(not job(service,4).is_empty() or not job(service,7).is_empty(),"At least one installer can still exist physically after its box has completed")
	for _i in range(200):
		game.shop.advance(0.10)
		if job(service,4).is_empty() and job(service,7).is_empty(): break
	check(job(service,4).is_empty() and job(service,7).is_empty(),"Installers are freed only after physically reaching the exit")

	print("6/7: save/load resumes carrying, installing and leaving without a duplicate installation")
	game._shutdown_tree(game)
	game.free()
	game=Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	service=game.service
	p=service.progress
	p.stars=2
	p.cash=5000
	station=service.add_station("counter",1,false,false)
	station.equipment=["rag"]
	station.apply_equipment()
	check(game.shop.order("pan",2,true).is_empty(),"Save-state installer order starts")
	var pan_id:=int(p.deliveries.back().id)
	advance_shop(game,8.1)
	for _i in range(160):
		game.shop.advance(0.05)
		if str(job(service,pan_id).get("phase",""))=="carrying": break
	var carrying:=job(service,pan_id)
	check(str(carrying.get("phase",""))=="carrying","Installer reaches the carrying phase")
	var carrying_pos:=pos(carrying)
	var saved: Dictionary=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(saved),"Save during carrying reloads")
	p=service.progress
	carrying=job(service,pan_id)
	check(str(carrying.get("phase",""))=="carrying" and pos(carrying).distance_to(carrying_pos)<0.02,"Carrying phase and floor position resume from save")
	for _i in range(260):
		game.shop.advance(0.05)
		if str(job(service,pan_id).get("phase",""))=="installing" and float(job(service,pan_id).get("phase_age",0.0))>0.30: break
	var installing:=job(service,pan_id)
	check(str(installing.get("phase",""))=="installing","Installer reaches installation")
	saved=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(saved),"Save during installation reloads")
	p=service.progress
	installing=job(service,pan_id)
	check(str(installing.get("phase",""))=="installing" and not bool(installing.get("installed",false)),"Unfinished installation resumes without pre-crediting the item")
	advance_shop(game,2.2)
	var leaving:=job(service,pan_id)
	check("pan" in service.by_id(2).equipment and history_count(service,pan_id)==1,"Reloaded installation commits exactly once")
	check(not leaving.is_empty() and str(leaving.get("phase",""))=="leaving" and bool(leaving.get("installed",false)),"Installed delivery becomes a separate leaving worker")
	check(delivery(service,pan_id).is_empty(),"Installed parcel is already absent while its worker leaves")
	saved=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(saved),"Save during leaving reloads")
	p=service.progress
	leaving=job(service,pan_id)
	check(not leaving.is_empty() and str(leaving.get("phase",""))=="leaving" and bool(leaving.get("installed",false)),"Leaving worker resumes as already installed")
	advance_shop(game,16.0)
	check(job(service,pan_id).is_empty(),"Reloaded leaving worker finishes the route")
	check(history_count(service,pan_id)==1 and "pan" in service.by_id(2).equipment,"Leaving reload never installs the item a second time")

	print("7/7: save/load resumes a blocked wait with its own box, then releases it once")
	station=service.by_id(2)
	station.state="cooking"
	station.customer_id=901
	check(game.shop.order("sauce",2,true).is_empty(),"Second save-state order starts against a busy station")
	var sauce_id:=int(p.deliveries.back().id)
	for _i in range(360):
		game.shop.advance(0.10)
		game.shop._process(0.02)
		if str(job(service,sauce_id).get("phase",""))=="waiting": break
	var waiting:=job(service,sauce_id)
	check(str(waiting.get("phase",""))=="waiting","Busy accepted work produces a persistent installer wait")
	var waiting_pos:=pos(waiting)
	saved=bytes_to_var(var_to_bytes(service.save_data()))
	check(service.load_data(saved),"Save during waiting reloads")
	p=service.progress
	waiting=job(service,sauce_id)
	check(str(waiting.get("phase",""))=="waiting" and pos(waiting).distance_to(waiting_pos)<0.02 and not delivery(service,sauce_id).is_empty(),"Waiting phase, box link and local waiting spot resume")
	service.by_id(2).state="idle"
	service.by_id(2).customer_id=-1
	advance_shop(game,18.0)
	check(delivery(service,sauce_id).is_empty() and history_count(service,sauce_id)==1 and "sauce" in service.by_id(2).equipment,"Released saved waiter installs once and completes")
	check(game.shop.ITEMS.sauce.price>0,"Installer path never changes the catalogue's ordinary price")

	game._shutdown_tree(game)
	game.free()
	print("PASS: T20/T21 physical installers, doorway routing, gestures, manual coexistence and save recovery" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
