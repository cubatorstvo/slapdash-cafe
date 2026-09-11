extends Node3D
const Station = preload("res://scripts/work_station.gd")
const Definition = preload("res://scripts/station_definition.gd")
const Person = preload("res://scripts/customer_view.gd")
var stations: Array = []
var customers: Array = []
var next_station_id := 1
var next_customer_id := 1
var served := 0
var missed := 0
var revenue := 0
var open_for_business := true
var spawn_clock := 3.0
var game: Node3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func initial_stations() -> void:
	const ROW_CENTER_X := 3.0
	var types := ["counter", "counter", "counter", "kitchen"]
	var zone_widths: Array[float] = []
	for type_id in types: zone_widths.append(float(Definition.TYPES[type_id].width) * Station.TRAINING_ZONE_SCALE)
	var zone_gaps: Array[float] = []
	for index in range(types.size() - 1):
		var left_width: float = Definition.TYPES[types[index]].width
		var right_width: float = Definition.TYPES[types[index + 1]].width
		zone_gaps.append((left_width + right_width) / 2.0 * (Station.TRAINING_ZONE_SCALE - 1.0))
	var row_width := 0.0
	for width in zone_widths: row_width += width
	for gap in zone_gaps: row_width += gap
	var x := ROW_CENTER_X - row_width / 2.0 + zone_widths[0] / 2.0
	for index in range(types.size()):
		if index > 0: x += (zone_widths[index - 1] + zone_widths[index]) / 2.0 + zone_gaps[index - 1]
		add_station(types[index], Vector3(x, 0, -1.4))

func add_station(type_id: String, point: Vector3, id := 0) -> Node3D:
	var station := Station.new()
	station.station_id = next_station_id if id == 0 else id
	next_station_id = maxi(next_station_id, station.station_id + 1)
	station.type_id = type_id
	station.position = point
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
	if station == null or not dish in station.dishes(): return false
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
	if open_for_business:
		spawn_clock -= delta
		if spawn_clock <= 0:
			spawn_customer()
			spawn_clock = 6.0
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
			if station.recipes.has(customer.dish):
				station.state = "cooking"
				station.order_dish = customer.dish
				station.order_tick = 0
				station.reset_model()
				customer.state = "cooking"
			else:
				customer.wait += delta
				customer.view.caption.text = Definition.DISHES[customer.dish] + "\nПовара ждут твоего показа · [E]"
				if customer.wait >= 35:
					missed += 1
					finish_customer(customer.id, false)

func spawn_customer(recipe := "") -> bool:
	if customers.size() >= 12: return false
	if recipe.is_empty(): recipe = Definition.DISHES.keys()[rng.randi_range(0, 3)]
	var candidates: Array = []
	for station in stations:
		if station.state == "idle" and station.pending_teacher == 0 and recipe in station.dishes(): candidates.append(station)
	if candidates.is_empty():
		missed += 1
		return false
	var station: Node3D = candidates[rng.randi_range(0, candidates.size() - 1)]
	var person := Person.new()
	person.color = [Color("ae7381"), Color("839fbb"), Color("c6a66b"), Color("91aa78")][next_customer_id % 4]
	add_child(person)
	person.position = Vector3(-11.4, 0, 1.65)
	person.caption.text = Definition.DISHES[recipe]
	var destination: Vector3 = station.to_global(Vector3(0, 0, -1.85))
	customers.append({"id": next_customer_id, "view": person, "station": station.station_id, "dish": recipe, "state": "walking", "wait": 0.0, "path": [destination]})
	station.customer_id = next_customer_id
	station.state = "waiting"
	next_customer_id += 1
	return true

func finish_customer(id: int, accepted: bool) -> void:
	for customer in customers:
		if customer.id != id or customer.state == "leaving": continue
		customer.state = "leaving"
		customer.view.caption.text = "Спасибо!" if accepted else "Загляну позже"
		customer.path = [Vector3(17.4, 0, 1.65)]
		var station: Node3D = by_id(customer.station)
		station.customer_id = -1
		if not station.training.active(): station.state = "idle"
		if accepted:
			served += 1
			var report: Dictionary = station.model.quality()
			revenue += roundi((65 if customer.dish == "meal" else 25) * report.price_factor * report.style_multiplier)
		return

func refresh_views(delta := 0.016) -> void:
	for station in stations: station.refresh(game.session.local_id(), delta)
	for customer in customers:
		customer.view.watching = customer.state in ["waiting", "cooking", "training"]
		if customer.view.watching:
			var station: Node3D = by_id(customer.station)
			if is_instance_valid(station): station.direct_attention(customer.view)

func save_data() -> Dictionary:
	var entries: Array = []
	for station in stations: entries.append(station.save_entry())
	return {"format": "station-cafe", "version": 2, "stations": entries, "served": served, "revenue": revenue, "missed": missed, "open": open_for_business}

func clear_world() -> void:
	for station in stations:
		remove_child(station)
		station.queue_free()
	for customer in customers:
		remove_child(customer.view)
		customer.view.queue_free()
	stations.clear()
	customers.clear()
	next_station_id = 1

func load_data(data: Dictionary) -> bool:
	if data.get("format") != "station-cafe" or data.get("version") != 2 or not data.get("stations") is Array: return false
	var ids: Array = []
	for entry in data.stations:
		if not entry is Dictionary or not entry.get("type", "") in Definition.TYPES or not entry.get("id") is int or entry.id <= 0 or entry.id in ids: return false
		ids.append(entry.id)
		if not Station.TeamModel.numbers(entry.get("position"), 3) or not Station.TeamModel.finite(entry.get("yaw")): return false
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
		var station := add_station(entry.type, Vector3(entry.position[0], entry.position[1], entry.position[2]), entry.id)
		station.rotation.y = entry.yaw
		station.crew = entry.crew.duplicate(true)
		station.upgrades = entry.upgrades.duplicate(true)
		station.recipes = entry.recipes.duplicate(true)
		station.drafts = entry.drafts.duplicate(true)
		for role in range(station.role_count()): station.students[role].caption.text = station.crew[role].name
	served = int(data.get("served", 0))
	revenue = int(data.get("revenue", 0))
	missed = int(data.get("missed", 0))
	open_for_business = data.get("open", true)
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
				if not frame.held in ["", "jug", "cup", "rag", "pan", "potato", "sausage", "tomato"]: return false
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
			if key == "presentation" and not value.has(key): continue
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
