extends Node3D
## Three counters share a staff roster; each employee owns independent recipe recordings.
const Model = preload("res://scripts/cooking_model.gd")
const View = preload("res://scripts/station_view.gd")
const Person = preload("res://scripts/customer_view.gd")
const NAMES := ["Боря", "Жора", "Лёва", "Сёма", "Кеша", "Веня", "Федя", "Толя"]
const SHORT_NAMES := {"wine": "Вино", "potato": "Картошка", "sausage": "Сосиска"}
var clones: Array = []
var stations: Array = []
var customers: Array = []
var reserve_people: Array[Node3D] = []
var next_clone_id := 1
var next_customer_id := 1
var served := 0
var missed := 0
var revenue := 0
var open_for_business := true
var spawn_clock := 3.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for index in range(3):
		var view := View.new()
		add_child(view)
		view.position = Vector3((index - 1) * 5.1, 0, -1.4)
		view.rotation.y = PI
		view.build(true)
		view.station_label.text = "СТОЙКА %d" % (index + 1)
		view.station_label.position = Vector3(0, 1.2, -1.15)
		view.station_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		view.station_label.modulate = Color("f3cf8b")
		var model := Model.new()
		model.reset(Model.DISHES.keys()[index])
		stations.append({"view": view, "model": model, "clone_id": -1, "state": "idle", "customer_id": -1, "frames": [], "tick": 0})
	create_clone()
	refresh_views()

func create_clone() -> Dictionary:
	var clone := {"id": next_clone_id, "name": "%s №%d" % [NAMES[(next_clone_id - 1) % NAMES.size()], next_clone_id], "recipes": {}}
	next_clone_id += 1
	clones.append(clone)
	for slot in [1, 0, 2]:
		if stations[slot].clone_id < 0:
			stations[slot].clone_id = clone.id
			break
	refresh_reserve()
	return clone

func get_clone(id: int) -> Dictionary:
	for clone in clones:
		if clone.id == id: return clone
	return {}

func slot_of(id: int) -> int:
	for index in range(stations.size()):
		if stations[index].clone_id == id: return index
	return -1

func reserve_station(slot: int, clone_id: int) -> void:
	var previous := slot_of(clone_id)
	for index in range(stations.size()):
		if index != slot and index != previous: continue
		var station: Dictionary = stations[index]
		if station.customer_id >= 0: _leave_customer(station.customer_id, "Повар ушёл учиться")
		station.state = "idle"
		station.frames = []
		station.clone_id = -1
	stations[slot].clone_id = clone_id
	stations[slot].state = "training"
	refresh_reserve()

func release_station(slot: int) -> void:
	stations[slot].state = "idle"
	stations[slot].frames = []

func refresh_reserve() -> void:
	for person in reserve_people: person.queue_free()
	reserve_people.clear()
	var count := 0
	for clone in clones:
		if slot_of(clone.id) >= 0: continue
		# Staff count is unlimited; a few visible reserves keep the small room readable.
		if count >= 10: break
		var person := Person.new()
		person.chef = true
		person.color = Color("63aa98")
		add_child(person)
		person.position = Vector3(-6.5 + count * 1.35, 0, -6.6)
		person.rotation.y = PI
		person.caption.text = clone.name + "\nРезерв"
		reserve_people.append(person)
		count += 1

func advance(delta: float) -> void:
	if open_for_business:
		spawn_clock -= delta
		if spawn_clock <= 0:
			spawn_customer()
			spawn_clock = 6.0
	for station in stations:
		if station.state != "cooking": continue
		if station.tick < station.frames.size():
			station.model.restore(station.frames[station.tick])
			station.tick += 1
		if station.tick >= station.frames.size():
			served += 1
			var price := roundi(25 * Model.efficiency(station.frames.size() / 60.0))
			revenue += price
			_leave_customer(station.customer_id, "Спасибо! +%d" % price)
	for index in range(customers.size() - 1, -1, -1):
		var customer: Dictionary = customers[index]
		if not customer.path.is_empty():
			if customer.view.walk_to(customer.path[0], delta): customer.path.pop_front()
			continue
		if customer.state == "leaving":
			customer.view.queue_free()
			customers.remove_at(index)
		elif customer.state == "walking":
			customer.state = "waiting"
			customer.wait = 0.0
		elif customer.state == "waiting":
			var station: Dictionary = stations[customer.slot]
			var clone := get_clone(station.clone_id)
			if not clone.is_empty() and clone.recipes.has(customer.dish):
				station.frames = clone.recipes[customer.dish].frames
				station.tick = 0
				station.state = "cooking"
				customer.state = "cooking"
				customer.view.caption.text = SHORT_NAMES[customer.dish] + "\nЖду свой заказ…"
			else:
				customer.wait += delta
				customer.view.caption.text = SHORT_NAMES[customer.dish] + "\nПовар пока не умеет"
				if customer.wait >= 9:
					missed += 1
					_leave_customer(customer.id, "Зайду после обучения")

func spawn_customer(recipe := "") -> bool:
	if customers.size() >= 9: return false
	if recipe.is_empty(): recipe = Model.DISHES.keys()[rng.randi_range(0, 2)]
	var available: Array = []
	var trained: Array = []
	for index in range(stations.size()):
		var station: Dictionary = stations[index]
		if station.state != "idle": continue
		available.append(index)
		var clone := get_clone(station.clone_id)
		if not clone.is_empty() and clone.recipes.has(recipe): trained.append(index)
	if available.is_empty(): return false
	var candidates: Array = trained if not trained.is_empty() else available
	var slot: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	var station: Dictionary = stations[slot]
	var person := Person.new()
	person.color = [Color("ae7381"), Color("839fbb"), Color("c6a66b"), Color("91aa78")][next_customer_id % 4]
	add_child(person)
	person.position = Vector3(-9.4, 0, 1.65)
	person.caption.text = SHORT_NAMES[recipe]
	var x: float = station.view.position.x
	customers.append({"id": next_customer_id, "view": person, "dish": recipe, "slot": slot, "state": "walking", "wait": 0.0,
		"path": [Vector3(x, 0, 1.65), Vector3(x, 0, 0.22)]})
	station.customer_id = next_customer_id
	station.state = "waiting"
	station.model.reset(recipe)
	next_customer_id += 1
	return true

func _leave_customer(id: int, message: String) -> void:
	for customer in customers:
		if customer.id != id: continue
		customer.state = "leaving"
		customer.view.caption.text = message
		customer.view.caption.modulate = Color("a0ebbd")
		customer.path = [Vector3(customer.view.position.x, 0, 1.65), Vector3(9.4, 0, 1.65)]
		var station: Dictionary = stations[customer.slot]
		station.customer_id = -1
		station.state = "idle"
		station.frames = []
		return

func refresh_views() -> void:
	for station in stations:
		station.view.update_view(station.model, 0, station.state == "idle")
		var clone := get_clone(station.clone_id)
		var occupied := not clone.is_empty()
		for node in [station.view.worker, station.view.left_hand, station.view.right_hand, station.view.left_arm, station.view.right_arm]: node.visible = occupied
		if occupied:
			var state_text := "Учится" if station.state == "training" else ("Готовит" if station.state == "cooking" else "Ждёт заказ")
			station.view.name_label.text = clone.name + "\n" + state_text

func save_data() -> Dictionary:
	var assigned: Array = []
	for station in stations: assigned.append(station.clone_id)
	return {"format": "slapdash-cafe", "clones": clones, "assigned": assigned, "served": served, "revenue": revenue}

func load_data(data: Dictionary, validate_frame: Callable) -> bool:
	if data.get("format") != "slapdash-cafe" or not data.get("clones") is Array or data.clones.is_empty(): return false
	var checked: Array = []
	var ids: Array = []
	for entry in data.clones:
		if not entry is Dictionary or not entry.get("id") is float and not entry.get("id") is int: return false
		var id := int(entry.id)
		if id < 1 or id in ids or not entry.get("name") is String or not entry.get("recipes") is Dictionary: return false
		ids.append(id)
		var recipes := {}
		for recipe in entry.recipes:
			if not recipe in Model.DISHES: return false
			var record = entry.recipes[recipe]
			if not record is Dictionary or not record.get("frames") is Array or record.frames.is_empty(): return false
			for frame in record.frames:
				if not validate_frame.call(frame) or frame.get("dish", "wine") != recipe: return false
			var result := Model.new()
			result.restore(record.frames.back())
			if not result.success(): return false
			recipes[recipe] = {"frames": record.frames, "duration": record.frames.size() / 60.0}
		checked.append({"id": id, "name": entry.name, "recipes": recipes})
	var assigned = data.get("assigned")
	if not assigned is Array or assigned.size() != 3: return false
	var used: Array = []
	for id in assigned:
		if not id is float and not id is int: return false
		if id != -1 and (not int(id) in ids or int(id) in used): return false
		used.append(int(id))
	clones = checked
	next_clone_id = int(ids.max()) + 1
	for index in range(3): stations[index].clone_id = int(assigned[index])
	served = int(data.get("served", 0))
	revenue = int(data.get("revenue", 0))
	refresh_reserve()
	return true
