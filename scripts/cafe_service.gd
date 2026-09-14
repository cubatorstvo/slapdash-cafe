extends Node3D
const Station = preload("res://scripts/work_station.gd")
const Definition = preload("res://scripts/station_definition.gd")
const Person = preload("res://scripts/customer_view.gd")
const STARTER_TYPES := ["counter", "counter", "counter", "kitchen"]
const SLOT_COUNT := 4
const SLOT_GAP := 0.6
const SLOT_ROW_CENTER_X := 3.0
const SLOT_Z := -1.4
var stations: Array = []
var customers: Array = []
var next_customer_id := 1
var served := 0
var missed := 0
var revenue := 0
var open_for_business := false
const Progression = preload("res://scripts/cafe_progression.gd")
var progress = Progression.new()
var autosave_clock := 0.0
var banquet_clock := 0.0
var spawn_clock := 3.0
var game: Node3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func slot_position(slot_index: int) -> Vector3:
	var row_width := Station.SLOT_WIDTH * SLOT_COUNT + SLOT_GAP * (SLOT_COUNT - 1)
	var first_center := SLOT_ROW_CENTER_X - row_width / 2.0 + Station.SLOT_WIDTH / 2.0
	return Vector3(first_center + slot_index * (Station.SLOT_WIDTH + SLOT_GAP), 0, SLOT_Z)

func starter_layout_positions() -> Array:
	var positions: Array = []
	for slot_index in range(SLOT_COUNT): positions.append(slot_position(slot_index))
	return positions

func initial_stations(sandbox := false) -> void:
	for slot_index in range(STARTER_TYPES.size() if sandbox else 1): add_station(STARTER_TYPES[slot_index], slot_index, not sandbox, not sandbox)

func add_station(type_id: String, slot_index: int, manual := false, bare := false) -> Node3D:
	var station := Station.new()
	station.manual_station = manual
	if bare: station.equipment = []; station.staffed = 0
	station.slot_index = slot_index
	station.station_id = slot_index + 1
	station.type_id = type_id
	station.position = slot_position(slot_index)
	station.rotation.y = PI
	add_child(station)
	stations.append(station)
	assign_clones()
	return station

func by_id(id: int) -> Node3D:
	for station in stations:
		if station.station_id == id: return station
	return null

func training_for(peer: int) -> Node3D:
	for station in stations:
		if station.training.active() and (station.training.lead == peer or station.training.role_for(peer) >= 0): return station
	return null

func any_training() -> bool:
	for station in stations:
		if station.training.active() or station.pending_teacher > 0: return true
	return false

func request_training(station: Node3D, dish: String, peer: int) -> bool:
	if station == null or not station.ready_crew() or station.manual_station or not dish in station.dishes() or progress.busy(): return false
	if station.training.active(): return station.training.lead == peer
	if training_for(peer) != null or station.pending_teacher > 0: return false
	if station.state in ["cooking","serving"]:
		station.pending_teacher = peer
		station.pending_dish = dish
		return true
	station.training.dish = dish
	_attach_customer(station)
	station.training.open(dish, peer)
	return true

func _attach_customer(station: Node3D) -> void:
	for customer in customers:
		if customer.id == station.customer_id and customer.dish == station.training.dish and customer.state not in ["queued","eating","leaving"]:
			station.taster = customer.view
			station.taster_real = true
			customer.state = "training"
			customer.path.clear()
			return
	if station.customer_id >= 0: finish_customer(station.customer_id, false)

func advance(delta: float) -> void:
	if game != null and is_instance_valid(game.shop): game.shop.advance(delta)
	if game != null and is_instance_valid(game.laboratory): game.laboratory.advance(delta)
	advance_shift(delta)
	advance_event(delta)
	autosave_clock += delta
	if autosave_clock >= 30.0 and not progress.busy() and not any_training():
		autosave_clock = 0.0
		if game != null: game.save_cafe()
	if open_for_business and not progress.busy():
		spawn_clock -= delta
		if spawn_clock <= 0:
			spawn_customer()
			spawn_clock = progress.arrival_interval()
	advance_queue()
	for station in stations:
		station.training.advance(delta)
		if station.state != "cooking": continue
		var record: Dictionary = station.recipes[station.order_dish]
		station.order_tick += delta * 60.0 * station.order_tempo
		station.show_tracks(record.tracks, mini(int(station.order_tick), station.Run.duration_ticks(record.tracks)-1))
		if station.type_id == "counter":
			for customer in customers:
				if customer.id == station.customer_id: customer.view.react(station.model.customer_reaction)
		if station.order_tick >= station.Run.duration_ticks(record.tracks):
			finish_customer(station.customer_id, true)
			if station.pending_teacher > 0 and station.state!="serving":
				var teacher: int = station.pending_teacher
				station.pending_teacher = 0
				station.training.open(station.pending_dish, teacher)
	for index in range(customers.size() - 1, -1, -1):
		var customer: Dictionary = customers[index]
		if customer.state=="eating":
			customer.eat_age+=delta
			customer.view.meal_age=customer.eat_age
			if customer.eat_age>=1.2:
				customer.state="leaving"; customer.path=[Vector3(17.4,0,1.65)]
				var table: Node3D=by_id(customer.station)
				if table!=null and table.customer_id==customer.id:
					table.customer_id=-1; table.state="idle"
					if table.pending_teacher>0:
						var teacher: int=table.pending_teacher; table.pending_teacher=0
						table.training.open(table.pending_dish,teacher)
			continue
		if not customer.path.is_empty():
			if customer.view.walk_to(customer.path[0], delta): customer.path.pop_front()
			continue
		if customer.state == "leaving":
			customer.view.queue_free()
			customers.remove_at(index)
		elif customer.state in ["walking", "waiting"]:
			customer.state = "waiting"
			var station: Node3D = by_id(customer.station)
			customer.view.rotation.y = station.global_rotation.y + PI
			if station.recipes.has(customer.dish) and not station.manual_station:
				station.state = "cooking"
				station.order_dish = customer.dish
				station.order_tick = 0
				station.order_tempo = station.crew_tempo()
				station.reset_model()
				customer.state = "cooking"
			elif station.manual_station:
				customer.view.caption.text = (preload("res://scripts/chef_orders.gd").special_request(station.customer_order) if not preload("res://scripts/chef_orders.gd").special_request(station.customer_order).is_empty() else Definition.DISHES[customer.dish]) + " · [E] у стойки"
			else:
				customer.wait += delta
				customer.view.caption.text = Definition.DISHES[customer.dish] + "\nПовара ждут твоего показа · [E]"
				if customer.wait >= 14:
					finish_customer(customer.id, false)

func spawn_customer(recipe := "", banquet := false, chef_guest := false) -> bool:
	if customers.size() >= 18: return false
	if recipe.is_empty():
		var pool: Array = progress.available_dishes()
		if progress.stars == 0 and by_id(1) != null and "jug" not in by_id(1).equipment: pool.erase("wine")
		recipe = pool[rng.randi_range(0, pool.size() - 1)]
		if progress.stars == 0 and progress.tutorial_served.size() < 3:
			for starter in ["sausage","potato","wine"]:
				if starter in pool and starter not in progress.tutorial_served: recipe = starter; break
	if not recipe in Definition.DISHES: return false
	var candidates: Array = []
	var untrained: Array = []
	var offered := false
	for station in stations:
		if not recipe in station.dishes(): continue
		if station.manual_station or not station.ready_crew(): continue
		if station.recipes.has(recipe): offered = true
		if station.state == "idle" and station.pending_teacher == 0:
			if station.recipes.has(recipe): candidates.append(station)
			else: untrained.append(station)
	if candidates.is_empty() and not banquet:
		var personal := by_id(1)
		if personal != null and personal.manual_station and chef_queue().size()<3 and recipe in personal.dishes(): candidates.append(personal)
		else: candidates = untrained
	# Some ordinary guests deliberately choose the chef even when automation is available.
	if not banquet and next_customer_id%3==0 and by_id(1)!=null and by_id(1).manual_station and recipe in by_id(1).dishes() and chef_queue().size()<3:
		candidates=[by_id(1)]
	if chef_guest:
		candidates = [by_id(1)] if by_id(1)!=null and chef_queue().size()<3 else []
	var station: Node3D = null if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]
	var person := Person.new()
	person.color = Color("d6b56b") if banquet else [Color("ae7381"), Color("839fbb"), Color("c6a66b"), Color("91aa78")][next_customer_id % 4]
	add_child(person)
	person.position = Vector3(-11.4, 0, 1.65)
	person.caption.text = Definition.DISHES[recipe]
	var data := {"id": next_customer_id, "view": person, "station": station.station_id if station != null else -1, "dish": recipe, "state": "walking", "wait": 0.0, "path": [], "banquet": banquet}
	if station == null:
		data.state = "leaving"
		data.path = [Vector3(-9.6, 0, 2.6), Vector3(17.4, 0, 1.65)]
		person.caption.text += "\nВсе заняты · зайду позже" if offered else "\nЕщё не готовят · загляну позже"
		missed += 1
		progress.record_demand(recipe, "busy" if offered else "untrained")
		if banquet: progress.banquet_finished += 1
	else:
		data.order = preload("res://scripts/chef_orders.gd").choose(recipe,station.equipment,maxi(3,progress.manual_served) if chef_guest else progress.manual_served,rng) if station.manual_station else {}
		if station.manual_station and (station.state!="idle" or station.customer_id>=0 or not chef_queue().is_empty()):
			data.state="queued"
			data.path=[queue_point(chef_queue().size())]
			person.caption.text=Definition.DISHES[recipe]+"\nОчередь к шефу"
		else: assign_customer(station,data)
	trace("customer_arrived",{"dish":recipe,"station":data.station,"order":station.customer_order if station != null else {}})
	customers.append(data)
	next_customer_id += 1
	return station != null

func finish_customer(id: int, accepted: bool) -> void:
	for customer in customers:
		if customer.id != id or customer.state in ["leaving","eating"]: continue
		if customer.state=="queued": dismiss_queue(customer); return
		var station: Node3D = by_id(customer.station)
		var report: Dictionary = station.model.quality()
		var paid := accepted and bool(report.get("present", false))
		var premium: float = float(station.customer_order.get("premium",1.0)) if station.manual_station else 1.0
		var payment := roundi((65 if customer.dish == "meal" else 25) * report.price_factor * report.style_multiplier * premium) if paid else 0
		trace("customer_finished",{"dish":customer.dish,"station":station.station_id,"grade":report.grade,"payment":payment,"accepted":paid})
		customer.state = "leaving"
		customer.view.playback_speed = 1.0
		customer.view.caption.text = "%s · +%d\nСпасибо!" % [report.grade, payment] if paid else "Загляну позже"
		if paid and report.get("style_count", 0) > 0: customer.view.caption.text += "\nЛовкая подача · +20%"
		customer.path = [Vector3(17.4, 0, 1.65)]
		station.customer_id = -1
		if not station.training.active(): station.state = "idle"
		if accepted:
			var payload: Array=station.model.take_serving()
			if not payload.is_empty():
				for item in payload: item.from=station.to_global(item.from)
				customer.state="eating"; customer.eat_age=0.0; customer.path=[]
				customer.view.begin_meal(payload)
				station.state="serving"; station.customer_id=customer.id
		if paid:
			served += 1
			if station.manual_station:
				progress.manual_served += 1
				if not progress.starter_reward: game.shop.reward_sauce()
				if not customer.dish in progress.tutorial_served: progress.tutorial_served.append(customer.dish)
			revenue += payment
			progress.cash += payment
			progress.record_demand(customer.dish, "served")
		else:
			missed += 1
			progress.record_demand(customer.dish, "untrained")
		if customer.get("banquet", false):
			progress.banquet_finished += 1
			if paid: progress.banquet_served += 1
			if paid and report.grade in ["B", "A", "S"]: progress.banquet_good += 1
		return

func purchase(kind: String, id: String, station_id := 0) -> String:
	if progress.busy(): return "Сначала заверши проверку."
	if kind == "expansion":
		if progress.stars < 2: return "Нужна вторая звезда."
		if progress.expanded: return "Зал уже расширен."
		if progress.cash < Progression.EXPANSION_PRICE: return "Не хватает денег."
		progress.cash -= Progression.EXPANSION_PRICE
		progress.expanded = true
		progress.revision += 1
		trace("expansion")
		return ""
	var item := "sauce_ramp" if kind == "upgrade" else kind if kind in ["counter","kitchen"] else id
	return game.shop.order(item, station_id)

func start_banquet(peer: int) -> String:
	if not progress.can_attempt(stations, served): return "Подготовь кафе по списку во вкладке «Звёзды»."
	if any_training(): return "Сначала закончи текущие показы."
	progress.return_open = open_for_business
	open_for_business = false
	# Do not wait forever for an unattended personal/untrained counter.
	for customer in customers:
		if customer.state in ["walking", "waiting"]: finish_customer(customer.id, false)
	progress.phase = "preparing"
	progress.event_peer = peer
	progress.result = ""
	progress.banquet_spawned = 0
	progress.banquet_finished = 0
	progress.banquet_served = 0
	progress.banquet_good = 0
	progress.showcase_grade = ""
	progress.orders = ["wine", "potato", "sausage", "sausage", "wine", "potato", "potato", "sausage", "wine"]
	progress.revision += 1
	return ""

func is_showcase(station: Node3D) -> bool:
	return progress.phase == "showcase" and station.station_id == 1

func finish_showcase(report: Dictionary) -> void:
	if progress.phase != "showcase": return
	progress.showcase_grade = report.grade
	if not report.present or not report.grade in ["B", "A", "S"]:
		finish_banquet(false, "Личный показ: %s. Инспектор ждёт картофель на B или лучше." % report.grade)
		return
	by_id(1).training.close()
	progress.phase = "service"
	progress.remaining = Progression.BANQUET_SECONDS
	banquet_clock = 2.0
	progress.revision += 1
	announce("Инспектор доволен! Теперь бригады обслуживают девять гостей.")

func advance_event(delta: float) -> void:
	if progress.phase == "tasting": return
	if progress.phase == "preparing":
		for station in stations:
			if station.state != "idle": return
		if progress.stars == 0:
			progress.phase = "tasting"
			progress.tasting_done.clear()
			start_tasting_dish()
			return
		progress.phase = "service"
		progress.remaining = Progression.BANQUET_SECONDS
		banquet_clock = 1
		progress.revision += 1
		announce("Делегация идёт! Трое гостей хотят личный заказ шефа.")
	elif progress.phase in ["showcase", "service"]:
		progress.remaining = maxf(0.0, progress.remaining - delta)
		if progress.phase == "service":
			banquet_clock -= delta
			if banquet_clock <= 0 and progress.banquet_spawned < progress.orders.size():
				# Delegation waits outside until a trained station is free. Service has a shared deadline.
				var dish: String = progress.orders[progress.banquet_spawned]
				var chef_guest: bool = progress.banquet_spawned in [0,3,6]
				var available: bool = chef_queue().size()<3 if chef_guest else false
				if not chef_guest:
					for station in stations:
						if station.ready_crew() and not station.manual_station and station.state=="idle" and station.recipes.has(dish): available=true
				if available and spawn_customer(dish,true,chef_guest):
					progress.banquet_spawned += 1
					banquet_clock = 8.0
			if progress.banquet_finished >= Progression.BANQUET_GUESTS:
				finish_banquet(progress.banquet_served >= Progression.BANQUET_SERVED and progress.banquet_good >= Progression.BANQUET_GOOD)
				return
		if progress.remaining <= 0:
			finish_banquet(progress.phase == "service" and progress.banquet_served >= Progression.BANQUET_SERVED and progress.banquet_good >= Progression.BANQUET_GOOD, "Время проверки вышло.")

func finish_banquet(won: bool, reason := "") -> void:
	if not progress.busy(): return
	# A timed-out order cannot pay or contribute after the result is frozen.
	for customer in customers:
		if customer.get("banquet", false) and customer.state != "leaving": finish_customer(customer.id, false)
	for station in stations:
		if station.training.active(): station.training.close()
	progress.phase = "won" if won else "lost"
	progress.result = "Вторая звезда! +200. Открыты расширение зала и кухня «Мясо и макароны»." if won else (reason + " Обслужено %d/8, довольны %d/6. Подготовься и попробуй снова бесплатно." % [progress.banquet_served, progress.banquet_good])
	if not won and progress.stars == 0: progress.result = reason + " Можно пригласить дегустатора снова бесплатно."
	if won:
		progress.stars = 2
		progress.cash += 200
	open_for_business = progress.return_open
	spawn_clock = progress.arrival_interval()
	progress.revision += 1
	announce(progress.result)
	if game != null: game.save_cafe()

func announce(message: String) -> void:
	if game == null or not is_instance_valid(game.session): return
	game.session.message_to(1, message)
	for id in game.session.members:
		if id != 1: game.session.message_to(id, message)

func refresh_views(delta := 0.016) -> void:
	for station in stations: station.refresh(game.session.local_id(), delta)
	for customer in customers:
		customer.view.watching = customer.state in ["waiting", "cooking", "training"]
		if customer.view.watching:
			var station: Node3D = by_id(customer.station)
			if is_instance_valid(station): station.direct_attention(customer.view)

func save_data() -> Dictionary:
	var entries: Array = []
	for station in stations:
		var entry: Dictionary = station.save_entry()
		entry.crew = entry.crew.duplicate(true)
		entry.equipment = entry.equipment.duplicate()
		entry.upgrades = entry.upgrades.duplicate()
		entry.recipes = entry.recipes.duplicate()
		entry.drafts = entry.drafts.duplicate()
		entries.append(entry)
	return {"format": "station-cafe", "version": 8, "progression": progress.snapshot(), "stations": entries, "served": served, "revenue": revenue, "missed": missed, "open": open_for_business}

func clear_world() -> void:
	for station in stations:
		remove_child(station)
		station.queue_free()
	for customer in customers:
		remove_child(customer.view)
		customer.view.queue_free()
	stations.clear()
	customers.clear()

func _saved_slot(entry: Dictionary, version: int) -> int:
	if version >= 4: return int(entry.get("slot", -1))
	return int(entry.get("id", 0)) - 1

func load_data(data: Dictionary) -> bool:
	var version: int = int(data.get("version", 0))
	if data.get("format") != "station-cafe" or not version in [2, 3, 4, 5, 6, 7, 8] or not data.get("stations") is Array: return false
	if version >= 5 and not data.get("progression") is Dictionary: return false
	var slots: Array = []
	for entry in data.stations:
		if not entry is Dictionary or not entry.get("type", "") in Definition.TYPES: return false
		var slot_index := _saved_slot(entry, version)
		if slot_index < 0 or slot_index >= SLOT_COUNT or slot_index in slots: return false
		slots.append(slot_index)
		if not entry.get("crew") is Array or entry.crew.size() != Definition.TYPES[entry.type].roles.size(): return false
		for member in entry.crew:
			if not member is Dictionary or not member.get("name") is String: return false
		if not entry.get("recipes") is Dictionary or not entry.get("drafts") is Dictionary or not entry.get("upgrades") is Array: return false
		for collection in [entry.recipes, entry.drafts]:
			for dish in collection:
				if not dish in Definition.TYPES[entry.type].dishes: return false
				if collection == entry.recipes and not collection[dish] is Dictionary: return false
				var tracks = collection[dish].get("tracks", []) if collection == entry.recipes else collection[dish]
				if not valid_tracks(tracks, entry.type): return false
				if collection == entry.recipes:
					if not Station.TeamModel.finite(collection[dish].get("duration")): return false
					for track in tracks:
						if track.is_empty() or track.frames.is_empty(): return false
	clear_world()
	for entry in data.stations:
		var slot_index := _saved_slot(entry, version)
		var station := add_station(entry.type, slot_index, entry.get("manual", false))
		station.staffed = int(entry.get("staffed",station.role_count()))
		station.equipment = entry.get("equipment",station.equipment).duplicate()
		station.apply_equipment()
		station.crew = entry.crew.duplicate(true)
		station.upgrades = entry.upgrades.duplicate(true)
		station.apply_upgrades()
		station.recipes = entry.recipes.duplicate(true)
		station.drafts = entry.drafts.duplicate(true)
		for role in range(station.role_count()): station.students[role].caption.text = station.crew[role].name
	served = int(data.get("served", 0))
	revenue = int(data.get("revenue", 0))
	missed = int(data.get("missed", 0))
	open_for_business = data.get("open", true)
	progress = Progression.new()
	if data.get("progression") is Dictionary:
		progress.restore(data.progression)
		if version<8: progress.starter_reward=progress.manual_served>0
		progress.recover_deliveries()
		if data.progression.get("phase", "none") in ["preparing", "showcase", "service", "tasting"]: open_for_business = progress.return_open
	# A rag now belongs to every counter. Refund outstanding old rag deliveries.
	for parcel in progress.deliveries.duplicate():
		var items: Array = parcel.get("items", [parcel.item]).duplicate()
		if "rag" not in items: continue
		items.erase("rag")
		progress.cash += 12
		if items.is_empty(): progress.deliveries.erase(parcel)
		else: parcel.item = items[0]; parcel.items = items
	if game != null and is_instance_valid(game.laboratory): game.laboratory.reset()
	normalize_workers()
	assign_clones()
	spawn_clock = progress.arrival_interval()
	return true

func valid_tracks(tracks: Variant, type_id: String) -> bool:
	if not tracks is Array or tracks.size() != Definition.TYPES[type_id].roles.size(): return false
	var sample = Station.Model.new() if type_id == "counter" else Station.TeamModel.new()
	for role in range(tracks.size()):
		var track = tracks[role]
		if not track is Dictionary: return false
		if track.is_empty(): continue
		if not track.get("group") is int or not track.get("frames") is Array: return false
		var schema: Dictionary = sample.snapshot() if type_id == "counter" else sample.zone_snapshot(role)
		for frame in track.frames:
			if not matches_schema(frame, schema): return false
			if type_id == "counter":
				if not frame.held in ["", "jug", "cup", "rag", "pan", "potato", "sausage", "tomato", "plate_0", "plate_1", "plate_2"]: return false
				for puddle in frame.puddles:
					if not Station.TeamModel.numbers(puddle, 3): return false
			else:
				if not frame.hand in Station.TeamModel.ITEMS + [""]: return false
				for item in frame.owners:
					if not frame.owners[item] in [-1, 0, 1]: return false
	return true

func matches_schema(value: Variant, schema: Variant) -> bool:
	if schema is Dictionary:
		if not value is Dictionary: return false
		for key in schema:
			if key in ["ramp_velocity","equipment","guest_serving","chef_order","guest_roles","guest_zone"]: continue
			if key in ["presentation", "sausage_launched", "sausage_high", "sausage_showy", "guest_serving", "chef_order", "guest_pour", "equipment", "guest_active", "guest_roles", "guest_zone"] and not value.has(key): continue
			if not value.has(key) or not matches_schema(value[key], schema[key]): return false
	elif schema is Array:
		if not value is Array: return false
		if not schema.is_empty():
			if value.size() != schema.size(): return false
			for i in range(schema.size()):
				if not matches_schema(value[i], schema[i]): return false
	elif schema is float or schema is int: return Station.TeamModel.finite(value)
	elif typeof(value) != typeof(schema): return false
	return true

func manual_order(station: Node3D) -> String:
	if game != null and game.session.is_guest() and station.customer_id >= 0: return station.order_dish
	for customer in customers:
		if customer.id == station.customer_id and customer.state not in ["leaving","eating","queued"]: return customer.dish
	return ""

func request_manual(station: Node3D, dish: String, peer: int) -> bool:
	if station == null or station.state=="serving" or not station.manual_station or station.training.active() or training_for(peer) != null or (progress.busy() and progress.phase!="service"): return false
	var ordered := manual_order(station)
	if progress.phase=="service" and ordered.is_empty(): return false
	if not ordered.is_empty(): dish = ordered
	else: station.customer_order = {}
	if not dish in station.dishes(): return false
	station.training.dish = dish
	_attach_customer(station)
	station.training.open(dish, peer, "manual")
	if dish not in progress.tutorial_served:
		announce("Требования блюда — в книге [B]. Готовое поставь на поднос и позвони в настольный звонок [E].")
	return station.training.start_pass([peer])

func finish_manual(station: Node3D, report: Dictionary) -> void:
	if station.training.purpose == "tasting":
		if not report.present or not report.grade in ["B", "A", "S"]:
			var inspector: Node3D = station.taster
			station.taster = null
			station.training.close()
			station.taster = inspector
			announce("Дегустатор: пока %s. Попробуй это блюдо ещё раз — бесплатно." % report.grade)
			start_tasting_dish()
			return
		progress.tasting_done.append(station.training.dish)
		var inspector: Node3D = station.taster
		station.taster = null
		station.training.close()
		station.taster = inspector
		if progress.tasting_done.size() < 3:
			start_tasting_dish()
		else:
			station.finish_taster(false)
			progress.stars = 1
			progress.cash += 120
			progress.phase = "won"
			progress.result = "Первая звезда! +120. Лаборатория готова: теперь можно покупать станции с клонами. Твоя стойка остаётся за тобой."
			progress.revision += 1
			open_for_business = progress.return_open
			announce(progress.result)
			if game != null: game.save_cafe()
		return
	station.finish_taster(true)
	station.training.close()
	if game != null: game.save_cafe()

func start_tasting_dish() -> void:
	var first: Node3D = by_id(1)
	var dish: String = Progression.DISHES[progress.tasting_done.size()]
	first.training.open(dish, progress.event_peer, "tasting")
	first.training.start_pass([progress.event_peer])
	first.taster.caption.text = "Дегустатор · %s\nB или лучше · %d/3" % [Definition.DISHES[dish], progress.tasting_done.size() + 1]
	progress.revision += 1

func toggle_business() -> void:
	if progress.busy(): return
	if progress.shift == "night":
		announce("Смена закончена. Ляг на свободную кровать в комнате отдыха.")
		return
	if progress.shift == "closing": return
	if open_for_business:
		end_shift()
	else:
		progress.shift = "open"
		open_for_business = true
		spawn_clock = 2.0
	progress.revision += 1

func end_shift() -> void:
	trace("shift_closed", {"day":progress.day,"elapsed":progress.shift_elapsed})
	open_for_business = false
	progress.shift = "closing"
	for customer in customers:
		if customer.state=="queued": dismiss_queue(customer); continue
		var station: Node3D = by_id(customer.station)
		if station != null and station.manual_station and not station.training.active() and customer.state != "leaving": finish_customer(customer.id, false)
	progress.revision += 1

func advance_shift(delta: float) -> void:
	if progress.shift=="night": progress.night_elapsed+=delta
	if progress.busy(): return
	if open_for_business and progress.shift == "open":
		progress.shift_elapsed += delta
		if progress.shift_elapsed >= Progression.SHIFT_SECONDS: end_shift()
	if progress.shift == "closing":
		for station in stations:
			if station.state != "idle" or station.pending_teacher > 0: return
		progress.shift = "night"
		progress.night_elapsed=0.0
		progress.revision += 1
		announce("Смена закончена. Клоны бегут в комнату отдыха. Новый день начнётся, когда все игроки лягут спать.")
		if game != null: game.save_cafe()

func next_day() -> String:
	if progress.shift != "night" or any_training(): return "Сначала заверши дела текущей смены."
	if game != null and is_instance_valid(game.evening): game.evening.apply_rest()
	trace("next_day", {"day":progress.day+1})
	progress.day += 1
	progress.shift = "open"
	open_for_business = true
	spawn_clock = 2.0
	progress.shift_elapsed = 0
	progress.revision += 1
	return ""

func night_action(action: String, _data: Dictionary, _peer: int) -> String:
	if action == "next_day": return next_day()
	return "Закажи детали у компьютера и установи их из коробки."

static func valid_wall_point(point: Vector3) -> bool:
	if point.y < 1.4 or point.y > 3.7: return false
	return (absf(point.z + 7.35) < 0.08 or absf(point.z - 10.35) < 0.08) and point.x >= -11.5 and point.x <= 17.5

func trace(kind: String, data := {}) -> void:
	if game != null and is_instance_valid(game.telemetry): game.telemetry.event(kind,data)

func normalize_workers() -> void:
	while progress.free_workers.size() < progress.free_clones:
		progress.free_workers.append({"id":progress.next_clone_id,"tempo":1.0,"rest":1.0})
		progress.next_clone_id+=1
	for worker in progress.free_workers:
		worker.tempo=clampf(float(worker.get("tempo",1.0)),0.7,10.0)
		worker.rest=clampf(float(worker.get("rest",1.0)),0.9,1.1)
	for station in stations:
		if station.manual_station: continue
		for role in range(station.role_count() if station.staffed<0 else station.staffed):
			var member: Dictionary = station.crew[role]
			if not member.has("clone_id"):
				member.clone_id=progress.next_clone_id; progress.next_clone_id+=1
			member.tempo=clampf(float(member.get("tempo",1.0)),0.7,10.0)
			member.rest=clampf(float(member.get("rest",1.0)),0.9,1.1)
	progress.free_clones=progress.free_workers.size()

func assign_clones() -> void:
	# Existing saves keep their workers at 100%; unassigned workers retain individual tempo.
	normalize_workers()
	for station in stations:
		if station.manual_station or station.staffed<0: continue
		while station.staffed<station.role_count():
			var available := -1
			for i in range(progress.free_workers.size()):
				if game==null or not is_instance_valid(game.laboratory) or int(game.laboratory.state.get("clone_id",0))!=int(progress.free_workers[i].id): available=i; break
			if available<0: break
			var worker: Dictionary=progress.free_workers.pop_at(available)
			station.crew[station.staffed].clone_id=worker.id
			station.crew[station.staffed].tempo=worker.tempo
			station.crew[station.staffed].rest=worker.get("rest",1.0)
			station.staffed+=1
			progress.revision+=1
	progress.free_clones=progress.free_workers.size()

func clone_options() -> Array:
	var options: Array=[]
	for station in stations:
		if station.manual_station: continue
		for role in range(station.role_count() if station.staffed<0 else station.staffed):
			var member: Dictionary=station.crew[role]
			if not member.has("clone_id"): continue
			options.append({"id":member.clone_id,"tempo":member.get("tempo",1.0),"station":station.station_id,"name":str(member.name)+" · станция %d"%station.station_id})
	for worker in progress.free_workers: options.append({"id":worker.id,"tempo":worker.tempo,"station":0,"name":"Свободный клон №%d"%worker.id})
	return options

func clone_data(id: int) -> Dictionary:
	for station in stations:
		for member in station.crew:
			if int(member.get("clone_id",0))==id and id>0: return member
	for worker in progress.free_workers:
		if int(worker.id)==id: return worker
	return {}

func create_clone(tempo := 1.0, prepaid := false) -> String:
	if progress.stars<1 or progress.lab_stage<3: return "Нужны готовая лаборатория и первая звезда."
	if not prepaid and progress.cash<60: return "Ингредиенты клона стоят 60."
	if not prepaid: progress.cash-=60
	progress.free_workers.append({"id":progress.next_clone_id,"tempo":clampf(tempo,0.7,10.0),"rest":1.0})
	progress.next_clone_id+=1
	progress.free_clones=progress.free_workers.size()
	assign_clones()
	progress.revision+=1
	trace("clone_created",{"free":progress.free_clones,"tempo":tempo})
	announce("Клон создан · темп %d%% · свободно %d"%[roundi(tempo*100),progress.free_clones])
	return ""

func chef_queue() -> Array:
	return customers.filter(func(c): return c.state=="queued")

func queue_point(index: int) -> Vector3:
	var first: Node3D=by_id(1)
	return first.to_global(Vector3(0,0,-3.0-index*0.95))

func assign_customer(station: Node3D, customer: Dictionary) -> void:
	customer.state="walking"
	customer.path=[station.to_global(Vector3(0,0,-1.85))]
	station.customer_order=customer.get("order",{}).duplicate(true)
	station.order_dish=customer.dish
	station.customer_id=customer.id
	station.state="waiting"

func advance_queue() -> void:
	var line:=chef_queue()
	var first: Node3D=by_id(1)
	if first==null: return
	if not line.is_empty() and first.state=="idle" and first.customer_id<0 and not first.training.active() and progress.shift not in ["closing","night"]:
		assign_customer(first,line.pop_front())
	for i in range(line.size()):
		var goal:=queue_point(i)
		if line[i].view.position.distance_to(goal)>0.05: line[i].path=[goal]
		line[i].view.caption.text=Definition.DISHES[line[i].dish]+"\nК шефу · %d в очереди"%(i+1)

func dismiss_queue(customer: Dictionary) -> void:
	customer.state="leaving"
	customer.path=[Vector3(-8.8,0,4.8),Vector3(17.4,0,1.65)]
	customer.view.caption.text="До завтра!"
	if customer.get("banquet",false): progress.banquet_finished+=1
