extends SceneTree
const Model = preload("res://scripts/cooking_model.gd")
const Team = preload("res://scripts/team_cooking_model.gd")
const Orders = preload("res://scripts/chef_orders.gd")
const Scene = preload("res://scenes/cafe.tscn")
var failures := 0
var game
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",label)
func near_face(m, item: String) -> void:
	m.pick_up(item)
	m.move_item(m.held,Vector2(0,-1.61))
	m.elevations[m.held]=0.385 if m.held not in m.vessels else 0.135
func serve_sausage(m, index: int, coating: float, plate := true) -> void:
	m.pick_up("sausage_%d"%index)
	m.sausage_coating=coating
	m.sausage=m.Layout.TRAY
	m.sausage_state="plate_0" if plate else "tray"
	m.elevations.sausage=m.Layout.TRAY_Y-m.BASE_Y+0.035
	m.plates[0].point=m.Layout.TRAY
	m.elevations.plate_0=m.Layout.TRAY_Y-m.BASE_Y
	m.held=""
	m._store_food("sausage")
func delivery(item: String, station := 0) -> void:
	check(game.shop.order(item,station).is_empty(),"Purchase " + item)
	var parcel: Dictionary = game.service.progress.deliveries.back()
	check(not game.shop.order(item,station).is_empty(),"Reject duplicate pending purchase")
	game.shop.advance(8)
	game.player.position=Vector3(parcel.position[0],0,parcel.position[2])
	check(game.shop.action(1,{"action":"take_parcel","id":parcel.id}).is_empty(),"Take arrived box")
	check(game.shop.carried(1)==parcel.id,"Carry ownership")
	game.player.position=game.shop.installation_position(parcel)-Vector3.UP
	check(game.shop.action(1,{"action":"install_parcel","id":parcel.id}).is_empty(),"Install " + item)
func run() -> void:
	var m := Model.new()
	m.reset("sausage")
	m.guest_serving.active=true
	near_face(m,"sausage_0")
	check(m.mouth_opening()>0.9 and m.can_feed(),"Progressive mouth and close-range feeding")
	check(m.feed() and not m.item_available("sausage_0"),"Raw sausage consumed once")
	check(m.quality().grade=="D" and m.quality().present,"Raw hand delivery counts and pays D")
	serve_sausage(m,1,1)
	check(m.quality().grade=="S","Best plated portion beats raw swallowed one")
	near_face(m,"plate_0")
	check(m.feed() and not m.item_available("plate_0") and not m.item_available("sausage_1"),"Guest swallows plate and its food")
	check(m.quality().grade=="S" and m.serving_candidates("sausage").size()==2,"No duplicate of same eaten and plated sausage")
	serve_sausage(m,2,0,false)
	check(m.quality().grade=="S","Later worse delivery cannot spoil best portion")
	var copy := Model.new()
	copy.restore(JSON.parse_string(JSON.stringify(m.snapshot())))
	check(copy.quality()==m.quality() and not copy.item_available("plate_0"),"Feeding survives serialized replay")
	m.reset("sausage")
	m.chef_order=Orders.standard("sausage"); m.chef_order.portions=2
	serve_sausage(m,0,1)
	check(m.quality().grade!="S","Double order requires two distinct portions")
	serve_sausage(m,1,1)
	check(m.quality().grade=="S","Two perfect portions fulfill double order")
	m.reset("wine"); m.guest_serving.active=true
	m.source="jug"; m.held="jug"; m.elevations.jug=0.8
	m.vessels.jug.angle=100
	var hit: Vector2=m.vessels.jug.landing(m.vessel_base("jug"),m.GUEST_MOUTH.y)
	m.jug+=Vector2(0,-1.61)-hit
	m.wine-=225; m._deliver(Vector2.ZERO,225,2)
	check(m.guest_serving.drunk==225 and m.quality().grade=="S","Pour into mouth fulfills wine order")
	m.wine-=80; m._deliver(Vector2.ZERO,80,2)
	check(m.quality().grade!="S","Overdrinking affects that portion")
	m.held=""; m.cup=m.Layout.TRAY; m.elevations.cup=m.Layout.TRAY_Y-m.BASE_Y; m.filled=225; m.wine-=225
	check(m.quality().grade=="S","Better glass overrides overfilled guest")
	check(is_equal_approx(m.wine+m.filled+m.guest_serving.drunk,1000),"Feeding conserves liquid")
	m.chef_order=Orders.standard("wine"); m.chef_order.min_ml=80; m.chef_order.max_ml=120
	m.filled=100
	check(m.quality().grade=="S","Live personal volume range")
	m.equipment=[]; m.reset("potato"); m.pick_up("pan")
	check(m.held.is_empty() and not m.item_available("cup") and m.item_available("potato_0"),"Bare station has products but no equipment")
	var t:=Team.new(); t.guest_active=true
	t.grab(0,"steak"); t.positions.steak=Vector2(-0.12,-1.61); t.heights.steak=0.4; t.meat_sides=[1.0,1.0]; t.meat_salt=1
	check(t.feed(0) and t.meat_state=="eaten","Kitchen meat can be fed")
	t.pasta=100; t.cooked=1; t.stirred=1; t.pasta_salt=1; t.water=200
	t.grab(1,"pot"); t.positions.pot=Vector2(0.12,-1.61); t.heights.pot=0.2
	check(t.feed(1) and t.quality().grade=="S","Whole pot and steak count as meal")
	var fresh:=Team.new(); fresh.restore_zone(1,(Team.new()).zone_snapshot(1)); fresh.restore_zone(0,t.zone_snapshot(0))
	check(fresh.guest_active and fresh.guest_roles[0].steak.size()>0,"Role-specific feeding replay")
	fresh.restore_zone(1,(Team.new()).zone_snapshot(1))
	check(fresh.guest_active,"Empty inactive role cannot disable live guest")
	game=Scene.instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false)
	var first=game.service.by_id(1)
	check(first.equipment.is_empty() and first.manual_station and game.service.progress.stars==0,"New run starts bare and manual")
	check(not game.shop.order("counter",0).is_empty(),"No early clone")
	game.service.progress.cash=100
	delivery("sauce",1)
	check("sauce" in first.equipment and game.service.progress.cash==76,"Physical purchase updates station and cash")
	delivery("plates",1)
	check(game.service.progress.cash==46 and "plates" in first.model.equipment,"Second upgrade opens plating")
	game.service.progress.cash=500
	delivery("lab_0")
	check(game.service.progress.lab_stage==1,"Lab part physically installed")
	game.service.progress.stars=1
	delivery("lights")
	game.player.position=Vector3(1.48,0,8.15)
	check(game.shop.action(1,{"action":"garland_put"}).is_empty() and game.service.progress.garland_builder==0,"Put reel down to free hands")
	check(game.shop.action(1,{"action":"garland_take"}).is_empty(),"Pick up owned reel")
	var paid: int=game.service.progress.cash
	for point in [[-4,2,-7.35],[-2,2.8,-7.35],[0,2.2,-7.35],[2,3,-7.35]]:
		game.player.position=Vector3(point[0],0,point[2]+1)
		check(game.shop.action(1,{"action":"garland_anchor","point":point}).is_empty(),"Place anchor")
	check(game.service.progress.popularity==15,"Garland bonus once")
	check(game.shop.action(1,{"action":"garland_remove","index":3}).is_empty() and game.service.progress.popularity==0,"Remove old decoration bonus")
	for point in [[-4,2,-7.35],[-2,2.8,-7.35],[0,2.2,-7.35],[2,3,-7.35]]:
		game.player.position=Vector3(point[0],0,point[2]+1)
		game.shop.action(1,{"action":"garland_anchor","point":point})
	check(game.service.progress.popularity==15 and game.service.progress.cash==paid,"Rehanging cannot farm popularity or charge again")
	game.player.position=Vector3(15,0,0)
	var cash: int=game.service.progress.cash
	game.session.execute_action(1,{"action":"buy","kind":"item","item":"jug","station":1})
	check(game.service.progress.cash==cash,"Purchases require physical computer")
	game.telemetry.event("marker",{"kind":"boring"}); game.telemetry.save_summary()
	check(FileAccess.file_exists(game.telemetry.folder+"/summary.json"),"Separate playtest summary written")
	for tab in ["overview","stations","deliveries","star"]:
		game.office.open(tab); await process_frame
	game.office.close()
	game._shutdown_tree(game); game.free()
	print("PASS: physical shop, upgrades, personal requirements, feeding, best portions, garland and logs" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
