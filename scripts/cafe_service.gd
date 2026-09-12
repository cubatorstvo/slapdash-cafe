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
	for slot_index in range(STARTER_TYPES.size() if sandbox else 1): add_station(STARTER_TYPES[slot_index], slot_index, not sandbox)

func add_station(type_id: String, slot_index: int, manual := false) -> Node3D:
	var station := Station.new()
	station.manual_station = manual
	station.slot_index = slot_index
	station.station_id = slot_index + 1
	station.type_id = type_id
	station.position = slot_position(slot_index)
	station.rotation.y = PI
	add_child(station)
	stations.append(station)
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
	if station == null or station.manual_station or not dish in station.dishes() or progress.busy(): return false
	if station.training.active(): return station.training.lead == peer
	if training_for(peer) != null or station.pending_teacher > 0: return false
	if station.state == "cooking":
		station.pending_teacher = peer
		station.pending_dish = dish
		return true
	station.training.dish = dish
	_attach_customer(station)
	station.training.open(dish, peer)
	return true

func _attach_customer(station: Node3D) -> void:
	for customer in customers:
		if customer.id == station.customer_id and customer.dish == station.training.dish:
			station.taster = customer.view
			station.taster_real = true
			customer.state = "training"
			customer.path.clear()
			return
	if station.customer_id >= 0: finish_customer(station.customer_id, false)

func advance(delta: float) -> void:
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
	for station in stations:
		station.training.advance(delta)
		if station.state != "cooking": continue
		var record: Dictionary = station.recipes[station.order_dish]
		station.show_tracks(record.tracks, station.order_tick)
		station.order_tick += 1
		if station.type_id == "counter":
			for customer in customers:
				if customer.id == station.customer_id: customer.view.react(station.model.customer_reaction)
		if station.order_tick >= station.Run.duration_ticks(record.tracks):
			finish_customer(station.customer_id, true)
			if station.pending_teacher > 0:
				var teacher: int = station.pending_teacher
				station.pending_teacher = 0
				station.training.open(station.pending_dish, teacher)
	for index in range(customers.size() - 1, -1, -1):
		var customer: Dictionary = customers[index]
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
				station.reset_model()
				customer.state = "cooking"
			elif station.manual_station:
				customer.view.caption.text = Definition.DISHES[customer.dish] + "\nТвой заказ · [E] у стойки"
			else:
				customer.wait += delta
				customer.view.caption.text = Definition.DISHES[customer.dish] + "\nПовара ждут твоего показа · [E]"
				if customer.wait >= 14:
					finish_customer(customer.id, false)

func spawn_customer(recipe := "", banquet := false) -> bool:
	if customers.size() >= 18: return false
	if progress.stars == 0 and not banquet and by_id(1) != null and by_id(1).manual_station and by_id(1).state != "idle": return false
	if recipe.is_empty():
		var pool: Array = progress.available_dishes()
		recipe = pool[rng.randi_range(0, pool.size() - 1)]
		if progress.stars == 0 and progress.tutorial_served.size() < 3:
			for starter in Progression.DISHES:
				if starter not in progress.tutorial_served: recipe = starter; break
	if not recipe in Definition.DISHES: return false
	var candidates: Array = []
	var untrained: Array = []
	var offered := false
	for station in stations:
		if not recipe in station.dishes(): continue
		if station.manual_station: continue
		if station.recipes.has(recipe): offered = true
		if station.state == "idle" and station.pending_teacher == 0:
			if station.recipes.has(recipe): candidates.append(station)
			else: untrained.append(station)
	if candidates.is_empty() and not banquet:
		var personal := by_id(1)
		if personal != null and personal.manual_station and personal.state == "idle" and recipe in personal.dishes(): candidates.append(personal)
		else: candidates = untrained
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
		data.path = [station.to_global(Vector3(0, 0, -1.85))]
		station.order_dish = recipe
		station.customer_id = next_customer_id
		station.state = "waiting"
	customers.append(data)
	next_customer_id += 1
	return station != null

func finish_customer(id: int, accepted: bool) -> void:
	for customer in customers:
		if customer.id != id or customer.state == "leaving": continue
		var station: Node3D = by_id(customer.station)
		var report: Dictionary = station.model.quality()
		var paid := accepted and bool(report.get("present", false))
		var payment := roundi((65 if customer.dish == "meal" else 25) * report.price_factor * report.style_multiplier) if paid else 0
		customer.state = "leaving"
		customer.view.caption.text = "%s · +%d\nСпасибо!" % [report.grade, payment] if paid else "Загляну позже"
		if paid and report.get("style_count", 0) > 0: customer.view.caption.text += "\nЕда под потолком · +20%"
		customer.path = [Vector3(17.4, 0, 1.65)]
		station.customer_id = -1
		if not station.training.active(): station.state = "idle"
		if paid:
			served += 1
			if station.manual_station:
				progress.manual_served += 1
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
	if progress.busy(): return "Покупки доступны после банкета."
	var price := 0
	var slot := -1
	var station: Node3D = by_id(station_id)
	match kind:
		"decor":
			if progress.stars < 1: return "Обустройство зала откроется после первой звезды."
			if id == "lights": return "Развесь гирлянду вечером: катушка на верстаке."
			return progress.paid_decoration(id)
		"counter":
			if progress.stars < 1: return "Первую бригаду откроет звезда дегустатора."
			for index in range(1, 3):
				if by_id(index + 1) == null:
					slot = index
					break
			if slot < 0: return "Все места под стойки заняты. Следующие места — после расширения."
			price = Progression.COUNTER_PRICE
		"kitchen":
			if not progress.expanded or progress.stars < 2: return "Нужны вторая звезда и расширение зала."
			if by_id(4) != null: return "Кухня на двоих уже установлена."
			slot = 3
			price = Progression.KITCHEN_PRICE
		"expansion":
			if progress.stars < 2: return "Расширение откроется со второй звездой."
			if progress.expanded: return "Зал уже расширен."
			price = Progression.EXPANSION_PRICE
		"upgrade":
			if progress.stars < 1: return "Оборудование откроется после первой звезды."
			if station == null or station.type_id != "counter": return "Выбери тяп-ляп стойку."
			if station.state != "idle": return "Дождись свободной станции."
			if "sauce_ramp" in station.upgrades: return "Соусный жёлоб уже установлен."
			price = Progression.UPGRADE_PRICE
		_: return "Покупка не найдена."
	if progress.cash < price: return "Не хватает денег."
	progress.cash -= price
	match kind:
		"counter", "kitchen": add_station(kind, slot)
		"expansion": progress.expanded = true
		"upgrade":
			station.upgrades.append("sauce_ramp")
			station.apply_upgrades()
	progress.revision += 1
	return ""

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
		progress.phase = "showcase"
		progress.remaining = Progression.SHOWCASE_SECONDS
		var first: Node3D = by_id(1)
		first.training.open("potato", progress.event_peer)
		first.training.tracks = [{}]
		first.taster.caption.text = "Инспектор · картофель на B\nЗвонок завершает личный показ"
		progress.revision += 1
		announce("Приготовь картофель инспектору. На выбор роли и готовку — две минуты.")
	elif progress.phase in ["showcase", "service"]:
		progress.remaining = maxf(0.0, progress.remaining - delta)
		if progress.phase == "service":
			banquet_clock -= delta
			if banquet_clock <= 0 and progress.banquet_spawned < progress.orders.size():
				# Delegation waits outside until a trained station is free. Service has a shared deadline.
				var dish: String = progress.orders[progress.banquet_spawned]
				for station in stations:
					if station.state == "idle" and station.recipes.has(dish):
						if spawn_customer(dish, true):
							progress.banquet_spawned += 1
							banquet_clock = 8.0
						break
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
		entry.upgrades = entry.upgrades.duplicate()
		entry.recipes = entry.recipes.duplicate()
		entry.drafts = entry.drafts.duplicate()
		entries.append(entry)
	return {"format": "station-cafe", "version": 6, "progression": progress.snapshot(), "stations": entries, "served": served, "revenue": revenue, "missed": missed, "open": open_for_business}

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
	if data.get("format") != "station-cafe" or not version in [2, 3, 4, 5, 6] or not data.get("stations") is Array: return false
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
		if data.progression.get("phase", "none") in ["preparing", "showcase", "service", "tasting"]: open_for_business = progress.return_open
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
			if key in ["presentation", "sausage_launched", "sausage_high", "sausage_showy"] and not value.has(key): continue
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
		if customer.station == station.station_id and customer.state != "leaving": return customer.dish
	return ""

func request_manual(station: Node3D, dish: String, peer: int) -> bool:
	if station == null or not station.manual_station or station.training.active() or training_for(peer) != null or progress.busy(): return false
	var ordered := manual_order(station)
	if not ordered.is_empty(): dish = ordered
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
		announce("Смена закончена. Отдохни у двери, чтобы начать следующий день.")
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
	open_for_business = false
	progress.shift = "closing"
	for customer in customers:
		var station: Node3D = by_id(customer.station)
		if station != null and station.manual_station and not station.training.active() and customer.state != "leaving": finish_customer(customer.id, false)
	progress.revision += 1

func advance_shift(delta: float) -> void:
	if progress.busy(): return
	if open_for_business and progress.shift == "open":
		progress.shift_elapsed += delta
		if progress.shift_elapsed >= Progression.SHIFT_SECONDS: end_shift()
	if progress.shift == "closing":
		for station in stations:
			if station.state != "idle" or station.pending_teacher > 0: return
		progress.shift = "night"
		progress.revision += 1
		announce("Кафе закрыто до утра. Можно заняться лабораторией и обустройством или отдохнуть.")
		if game != null: game.save_cafe()

func next_day() -> String:
	if progress.shift != "night" or any_training(): return "Сначала заверши дела текущей смены."
	progress.day += 1
	progress.shift = "morning"
	progress.shift_elapsed = 0
	progress.revision += 1
	return ""

func night_action(action: String, data: Dictionary, peer: int) -> String:
	if progress.shift != "night" or progress.busy(): return "Этим можно заняться после закрытия кафе."
	match action:
		"next_day": return next_day()
		"lab_begin":
			if progress.lab_stage >= 3: return "Лаборатория готова."
			if progress.lab_step >= 0: return "Продолжи подключение на верстаке."
			var price: int = Progression.LAB_PRICES[progress.lab_stage]
			if progress.cash < price: return "На комплект нужно %d. Можно заработать в следующую смену." % price
			progress.cash -= price
			progress.lab_step = 0
		"lab_switch":
			if progress.lab_step < 0: return "Сначала возьми комплект на верстаке."
			var sequences := [[0, 1, 2], [2, 0, 1], [1, 2, 0]]
			if int(data.get("index", -1)) != sequences[progress.lab_stage][progress.lab_step]:
				progress.lab_step = 0
				progress.revision += 1
				return "Контакт не тот. Схема сброшена; комплект остаётся у тебя."
			progress.lab_step += 1
			if progress.lab_step == 3:
				progress.lab_stage += 1
				progress.lab_step = -1
		"garland_begin":
			if progress.stars < 1: return "Сначала закончи лабораторию и получи первую звезду."
			if progress.garland_complete: return "Гирлянда уже развешена."
			if progress.garland_builder > 0:
				if progress.garland_builder != peer and game.session.members.has(progress.garland_builder): return "Катушка у другого игрока."
			else:
				if progress.cash < 40: return "Катушка стоит 40."
				progress.cash -= 40
			progress.garland_builder = peer
		"garland_anchor":
			if progress.garland_builder != peer or progress.garland_complete: return "Возьми катушку на верстаке."
			var raw = data.get("point")
			if not Station.TeamModel.numbers(raw, 3): return "Выбери точку на стене."
			var point := Vector3(raw[0], raw[1], raw[2])
			if not valid_wall_point(point): return "Крепление должно быть на стене на доступной высоте."
			var previous: Array = progress.garland_points.back() if not progress.garland_points.is_empty() else raw
			var distance := point.distance_to(Vector3(previous[0], previous[1], previous[2]))
			if not progress.garland_points.is_empty() and (distance < 0.65 or distance > 4.0): return "Оставь между креплениями от 0.65 до 4 метров."
			progress.garland_points.append(raw.duplicate())
			if progress.garland_points.size() == 4:
				progress.garland_complete = true
				progress.popularity += 15
				progress.decorations.append("lights")
				progress.garland_builder = 0
	progress.revision += 1
	return ""

static func valid_wall_point(point: Vector3) -> bool:
	if point.y < 1.4 or point.y > 3.7: return false
	return (absf(point.z + 7.35) < 0.08 or absf(point.z - 10.35) < 0.08) and point.x >= -11.5 and point.x <= 17.5
