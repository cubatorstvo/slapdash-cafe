from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing block: {label}")
    return text.replace(old, new, 1)

# Progression owns the explicit star-by-star cadence and payout bonus.
p = Path('scripts/cafe_progression.gd')
s = p.read_text()
s = replace_once(s,
'''const SHIFT_SECONDS := 480.0
''',
'''const SHIFT_SECONDS := 480.0
const CHEF_ORDER_INTERVALS := [Vector2(25.0,35.0),Vector2(45.0,60.0),Vector2(75.0,95.0),Vector2(105.0,130.0),Vector2(140.0,175.0),Vector2(180.0,220.0)]
const CHEF_ORDER_PREMIUM := [1.0,1.5,2.2,3.0,3.8,4.8]
''', 'progression constants')
s = replace_once(s,
'''func arrival_interval() -> float: return maxf(8.0, 18.0 - popularity * 0.20)
''',
'''func arrival_interval() -> float: return maxf(8.0, 18.0 - popularity * 0.20)
func chef_order_stage() -> int: return clampi(stars,0,5)
func chef_order_delay(rng: RandomNumberGenerator) -> float:
	var window: Vector2=CHEF_ORDER_INTERVALS[chef_order_stage()]
	return rng.randf_range(window.x,window.y)
func chef_order_premium() -> float: return float(CHEF_ORDER_PREMIUM[chef_order_stage()])
''', 'progression functions')
p.write_text(s)

p = Path('scripts/cafe_service.gd')
s = p.read_text()
s = replace_once(s,
'''const STARTER_TYPES := ["counter", "counter", "counter", "kitchen"]
''',
'''const STARTER_TYPES := ["counter", "counter", "counter", "kitchen"]
const CHEF_QUEUE_LIMIT := 3
''', 'queue limit')
s = replace_once(s,
'''var spawn_clock := 3.0
''',
'''var spawn_clock := 3.0
var chef_order_clock := 3.0
''', 'chef clock')

s = replace_once(s,
'''\tif open_for_business and not progress.busy():
\t\tspawn_clock -= delta
\t\tif spawn_clock <= 0:
\t\t\tspawn_customer()
\t\t\tspawn_clock = progress.arrival_interval()
''',
'''\tif open_for_business and not progress.busy():
\t\tif has_automatic_station():
\t\t\tspawn_clock -= delta
\t\t\tif spawn_clock <= 0:
\t\t\t\tspawn_customer()
\t\t\t\tspawn_clock = progress.arrival_interval()
\t\tadvance_chef_orders(delta)
''', 'advance spawning')

marker = 'func spawn_customer(recipe := "", banquet := false, chef_guest := false) -> bool:\n'
if marker not in s:
    raise SystemExit('missing spawn_customer marker')
helpers = '''func has_automatic_station() -> bool:
	for station in stations:
		if not station.manual_station: return true
	return false

func chef_order_recipe() -> String:
	var personal: Node3D=by_id(1)
	if personal==null or not personal.manual_station: return ""
	var pool: Array=personal.dishes().duplicate()
	if progress.stars==0 and "jug" not in personal.equipment: pool.erase("wine")
	if pool.is_empty(): return ""
	if progress.stars==0 and progress.tutorial_served.size()<3:
		for starter in ["sausage","potato","wine"]:
			if starter in pool and starter not in progress.tutorial_served: return starter
	return str(pool[rng.randi_range(0,pool.size()-1)])

func spawn_chef_customer() -> bool:
	if chef_queue().size()>=CHEF_QUEUE_LIMIT: return false
	var recipe:=chef_order_recipe()
	if recipe.is_empty(): return false
	return spawn_customer(recipe,false,true)

func advance_chef_orders(delta: float) -> void:
	chef_order_clock-=delta
	if chef_order_clock>0: return
	if chef_queue().size()<CHEF_QUEUE_LIMIT: spawn_chef_customer()
	# A full queue deliberately consumes this opportunity too. A new interval starts now,
	# so serving one customer never causes an immediate replacement to appear.
	chef_order_clock=progress.chef_order_delay(rng)

'''
s = s.replace(marker, helpers + marker, 1)

old_routing = '''\tif candidates.is_empty() and not banquet:
\t\tvar personal := by_id(1)
\t\tif personal != null and personal.manual_station and chef_queue().size()<3 and recipe in personal.dishes(): candidates.append(personal)
\t\telse: candidates = untrained
\t# Some ordinary guests deliberately choose the chef even when automation is available.
\tif not banquet and next_customer_id%3==0 and by_id(1)!=null and by_id(1).manual_station and recipe in by_id(1).dishes() and chef_queue().size()<3:
\t\tcandidates=[by_id(1)]
\tif chef_guest:
\t\tcandidates = [by_id(1)] if by_id(1)!=null and chef_queue().size()<3 else []
'''
new_routing = '''\tif candidates.is_empty() and not banquet and not chef_guest: candidates=untrained
\tif chef_guest:
\t\tvar personal:=by_id(1)
\t\tcandidates=[personal] if personal!=null and personal.manual_station and recipe in personal.dishes() and chef_queue().size()<CHEF_QUEUE_LIMIT else []
'''
s = replace_once(s, old_routing, new_routing, 'customer routing')

s = replace_once(s,
'''\tvar data := {"id": next_customer_id, "view": person, "station": station.station_id if station != null else -1, "dish": recipe, "state": "walking", "wait": 0.0, "path": [], "banquet": banquet}
''',
'''\tvar data := {"id": next_customer_id, "view": person, "station": station.station_id if station != null else -1, "dish": recipe, "state": "walking", "wait": 0.0, "path": [], "banquet": banquet, "chef_order": chef_guest and not banquet}
''', 'customer payload')

s = replace_once(s,
'''\t\tdata.order = preload("res://scripts/chef_orders.gd").choose(recipe,station.equipment,maxi(3,progress.manual_served) if chef_guest else progress.manual_served,rng) if station.manual_station else {}
''',
'''\t\tif station.manual_station:
\t\t\tvar order_serial: int=maxi(3,progress.manual_served) if banquet and chef_guest else progress.manual_served
\t\t\tdata.order=preload("res://scripts/chef_orders.gd").choose(recipe,station.equipment,order_serial,rng)
\t\t\tif chef_guest and not banquet:
\t\t\t\tvar chef_bonus: float=progress.chef_order_premium()
\t\t\t\tdata.order.chef_bonus=chef_bonus
\t\t\t\tdata.order.premium=float(data.order.get("premium",1.0))*chef_bonus
\t\telse: data.order={}
''', 'chef order premium')

s = replace_once(s,
'''\t\t\telif station.manual_station:
\t\t\t\tcustomer.view.caption.text = (preload("res://scripts/chef_orders.gd").special_request(station.customer_order) if not preload("res://scripts/chef_orders.gd").special_request(station.customer_order).is_empty() else Definition.DISHES[customer.dish]) + " · [E] у стойки"
''',
'''\t\t\telif station.manual_station:
\t\t\t\tvar request_text: String=preload("res://scripts/chef_orders.gd").special_request(station.customer_order)
\t\t\t\tif request_text.is_empty(): request_text=Definition.DISHES[customer.dish]
\t\t\t\tif customer.get("chef_order",false): request_text+="\\nЗаказ шефу · ×%.1f"%float(station.customer_order.get("chef_bonus",1.0))
\t\t\t\tcustomer.view.caption.text=request_text+" · [E] у стойки"
''', 'active chef label')

s = replace_once(s,
'''\t\tline[i].view.caption.text=Definition.DISHES[line[i].dish]+"\\nК шефу · %d в очереди"%(i+1)
''',
'''\t\tvar bonus_text: String=" · ×%.1f"%float(line[i].get("order",{}).get("chef_bonus",1.0)) if line[i].get("chef_order",false) else ""
\t\tline[i].view.caption.text=Definition.DISHES[line[i].dish]+"\\nК шефу%s · %d в очереди"%[bonus_text,i+1]
''', 'queue label')

s = replace_once(s,
'''\tspawn_clock = progress.arrival_interval()
\tprogress.revision += 1
''',
'''\tspawn_clock = progress.arrival_interval()
\tchef_order_clock = progress.chef_order_delay(rng)
\tprogress.revision += 1
''', 'banquet reschedule')

s = replace_once(s,
'''\tspawn_clock = 2.0
\tprogress.shift_elapsed = 0
''',
'''\tspawn_clock = 2.0
\tchef_order_clock = progress.chef_order_delay(rng)
\tprogress.shift_elapsed = 0
''', 'next day reschedule')

s = replace_once(s,
'''\treturn {"format": "station-cafe", "version": 9, "progression": progress.snapshot(), "stations": entries, "served": served, "revenue": revenue, "missed": missed, "open": open_for_business}
''',
'''\treturn {"format": "station-cafe", "version": 9, "progression": progress.snapshot(), "stations": entries, "served": served, "revenue": revenue, "missed": missed, "open": open_for_business, "chef_order_clock": chef_order_clock}
''', 'save chef clock')

s = replace_once(s,
'''\tstations.clear()
\tcustomers.clear()
''',
'''\tstations.clear()
\tcustomers.clear()
\tchef_order_clock=3.0
''', 'clear chef clock')

s = replace_once(s,
'''\tspawn_clock = progress.arrival_interval()
\treturn true
''',
'''\tspawn_clock = progress.arrival_interval()
\tchef_order_clock=float(data.get("chef_order_clock",progress.chef_order_delay(rng)))
\treturn true
''', 'load chef clock')
p.write_text(s)

# Existing queue regression now requests explicit chef orders instead of relying on ordinary fallback.
p=Path('tests/test_cafe_life.gd')
s=p.read_text()
s=replace_once(s,'check(service.spawn_customer("sausage"),"First customer takes chef station")','check(service.spawn_customer("sausage",false,true),"First customer takes chef station")','life first chef')
s=replace_once(s,'for dish in ["potato","wine","sausage"]: check(service.spawn_customer(dish),"Guest joins chef queue")','for dish in ["potato","wine","sausage"]: check(service.spawn_customer(dish,false,true),"Guest joins chef queue")','life chef queue')
s=replace_once(s,'check(not service.spawn_customer("potato"),"Full queue declines additional arrivals")','check(not service.spawn_customer("potato",false,true),"Full queue declines additional arrivals")','life full queue')
p.write_text(s)

Path('tests/test_chef_orders.gd').write_text(r'''extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",text)

func run() -> void:
	var game=preload("res://scenes/cafe.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false)
	var service=game.service
	var p=service.progress
	service.rng.seed=12345
	var expected_premium: Array=[1.0,1.5,2.2,3.0,3.8,4.8]
	for star in range(6):
		p.stars=star
		var window: Vector2=p.CHEF_ORDER_INTERVALS[star]
		for sample in range(8):
			var delay: float=p.chef_order_delay(service.rng)
			check(delay>=window.x and delay<=window.y,"Chef interval stays inside %d-star window"%star)
		check(is_equal_approx(p.chef_order_premium(),expected_premium[star]),"Chef premium matches %d-star stage"%star)

	p.stars=0; p.manual_served=0; p.shift="open"; service.open_for_business=true
	service.chef_order_clock=0.0
	service.advance_chef_orders(0.01)
	var chef=service.by_id(1)
	check(chef.customer_id>=0,"Dedicated chef timer creates the active personal order")
	check(is_equal_approx(float(chef.customer_order.get("chef_bonus",0.0)),1.0),"Zero-star chef order keeps base payout")
	for i in range(3):
		service.chef_order_clock=0.0
		service.advance_chef_orders(0.01)
	check(service.chef_queue().size()==3,"Chef queue holds three waiting guests")
	var count_before: int=service.customers.size()
	service.chef_order_clock=0.0
	service.advance_chef_orders(0.01)
	check(service.customers.size()==count_before,"Full chef queue does not create a fourth waiting guest")
	check(service.chef_order_clock>=p.CHEF_ORDER_INTERVALS[0].x,"Full queue starts a fresh cooldown instead of banking an instant replacement")
	var queued: Dictionary=service.chef_queue()[0]
	service.dismiss_queue(queued)
	var remaining_before: float=service.chef_order_clock
	service.advance_chef_orders(0.1)
	check(service.chef_queue().size()==2 and service.chef_order_clock<remaining_before,"Opening a queue slot does not instantly refill it")

	# Ordinary traffic belongs to clone stations; it must no longer fall back to the chef.
	service.clear_world(); service.progress=p
	service.initial_stations(false)
	var automatic=service.add_station("counter",1,false,false)
	automatic.state="cooking"
	p.stars=2
	check(not service.spawn_customer("sausage"),"Busy automation does not redirect an ordinary guest to the chef")
	check(service.chef_queue().is_empty() and service.by_id(1).customer_id<0,"Ordinary overflow leaves the personal station untouched")

	# Late-game chef orders are rare but visibly more valuable.
	p.stars=5; p.manual_served=0
	service.chef_order_clock=0.0
	service.advance_chef_orders(0.01)
	chef=service.by_id(1)
	check(chef.customer_id>=0,"Five-star chef timer still creates a personal order")
	check(is_equal_approx(float(chef.customer_order.get("chef_bonus",0.0)),4.8),"Five-star chef order carries the 4.8x stage bonus")
	check(service.chef_order_clock>=180.0 and service.chef_order_clock<=220.0,"Five-star cooldown uses the 180-220 second range")

	game._shutdown_tree(game); game.free()
	print("PASS: chef traffic scales down by stars while queue capacity and payout scale correctly" if failures==0 else "FAILURES: %d"%failures)
	quit(0 if failures==0 else 1)
''')
