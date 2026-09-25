extends "res://scripts/cafe_service_feature_core.gd"

const STARTER_DISH_SEQUENCE := ["sausage", "potato", "wine"]
const STANDARD_FORMULA_TEMPO := 1.0

func _ready() -> void:
	super()
	if progress.shift == "morning":
		progress.shift = "open"
		open_for_business = true
		spawn_clock = 2.0

func _ensure_standard_formula() -> void:
	if progress.stars < 1 or progress.lab_stage < 3 or progress.lab_formula_version > 0: return
	progress.lab_formula_tempo = STANDARD_FORMULA_TEMPO
	progress.lab_formula_version = 1
	progress.revision += 1
	progression_director.observe("standard_formula_available", {"tempo":STANDARD_FORMULA_TEMPO,"version":progress.lab_formula_version})

func _refresh_progression() -> void:
	_ensure_standard_formula()
	super()

func start_highlights(id: int, peer: int) -> String:
	var error := _action_command_error("masterclass_watch", {"actor_id":peer})
	if not error.is_empty(): return error
	return super(id, peer)

func create_clone(tempo := 1.0, prepaid := false) -> String:
	var clone_id := int(progress.next_clone_id)
	var manual_growth: bool = progress.stars == 1 and "lab_production" not in progress.lab_upgrades
	var result: String = super(tempo, prepaid)
	if result.is_empty() and manual_growth:
		progression_director.observe("manual_clone_growth_completed", {"clone_id":clone_id,"ordinal":clone_id,"tempo":tempo})
		_refresh_progression()
	return result

func _starter_equipped(station: Node3D, dish: String) -> bool:
	return Definition.missing_equipment(dish, station.equipment, station.upgrades).is_empty()

func chef_order_recipe() -> String:
	if progress.stars != 0: return super()
	var personal: Node3D = by_id(1)
	if personal == null or not personal.manual_station: return ""
	for dish in STARTER_DISH_SEQUENCE:
		if dish in progress.tutorial_served: continue
		if _starter_equipped(personal, dish): return dish
		break
	var fallback: Array = []
	for dish in STARTER_DISH_SEQUENCE:
		if dish in progress.tutorial_served and _starter_equipped(personal, dish): fallback.append(dish)
	return "" if fallback.is_empty() else str(fallback[rng.randi_range(0, fallback.size() - 1)])

func _count_completed_customer(customer: Dictionary, station: Node3D) -> void:
	super(customer, station)
	if not station.manual_station: return
	progression_director.observe("manual_served", {"dish":str(customer.get("dish", "")), "station_id":station.station_id})
	if str(customer.get("dish", "")) in STARTER_DISH_SEQUENCE:
		progression_director.observe("starter_dish_served", {"dish":str(customer.dish), "station_id":station.station_id})
	_refresh_progression()

func _learned_station_ids(participants: Array, learned_clone_ids: Array) -> Array:
	var result: Array = []
	for participant in participants:
		if not participant is Dictionary: continue
		var clone_id := int(participant.get("clone_id", 0))
		if clone_id > 0 and clone_id not in learned_clone_ids: continue
		var station_id := int(participant.get("station", 0))
		if station_id > 0 and station_id not in result: result.append(station_id)
	result.sort()
	return result

func _milestone_matches_service(milestone_id: String, station_id: int, dish: String) -> bool:
	if not progression_director.has_milestone(milestone_id): return false
	var milestone: Variant = progression_director.milestones.get(milestone_id, {})
	if not milestone is Dictionary: return false
	var station_ids: Variant = milestone.get("station_ids", [])
	if station_ids is Array and not station_ids.is_empty():
		if station_id not in station_ids: return false
		var taught_dish := str(milestone.get("dish", ""))
		return taught_dish.is_empty() or taught_dish == dish
	if milestone_id != "first_video_training_completed": return false
	var station = by_id(station_id)
	if station == null or not station.method_sources.has(dish): return false
	var source: Variant = station.method_sources.get(dish, {})
	return source is Dictionary and int(source.get("id", source.get("record_id", 0))) > 0

func observe_auto_served(dish: String, station_id: int) -> void:
	progression_director.observe("auto_served", {"dish":dish,"station_id":station_id})
	if _milestone_matches_service("first_video_training_completed", station_id, dish):
		progression_director.observe("video_trained_auto_served", {"dish":dish,"station_id":station_id})
	if _milestone_matches_service("first_group_training_completed", station_id, dish):
		progression_director.observe("group_trained_auto_served", {"dish":dish,"station_id":station_id})
	var station = by_id(station_id)
	if station != null:
		match str(station.type_id):
			"kitchen": progression_director.observe("pair_kitchen_auto_served", {"dish":dish,"station_id":station_id})
			"grill_kitchen": progression_director.observe("specialty_kitchen_auto_served", {"dish":dish,"station_id":station_id})
			"solyanka_kitchen": progression_director.observe("solyanka_auto_served", {"dish":dish,"station_id":station_id})
	_refresh_progression()

func complete_video_lesson(lesson_id: int, record: Dictionary, participants: Array) -> Array:
	var learned: Array = super(lesson_id, record, participants)
	if not learned.is_empty():
		var station_ids := _learned_station_ids(participants, learned)
		var payload := {"lesson_id":lesson_id,"record_id":int(record.get("id", 0)),"dish":str(record.get("dish", "")),"station_ids":station_ids.duplicate(),"station_count":station_ids.size(),"clone_ids":learned.duplicate()}
		progression_director.observe("video_training_completed", payload)
		if station_ids.size() >= 2: progression_director.observe("group_training_completed", payload)
		_refresh_progression()
	return learned

func load_data(data: Dictionary) -> bool:
	if not super(data): return false
	if progress.shift == "morning":
		progress.shift = "open"
		open_for_business = true
		spawn_clock = 2.0
	if int(data.get("version", 0)) == SAVE_VERSION and data.get("progression", {}) is Dictionary and data.progression.get("feature_progress", {}) is Dictionary:
		progress.feature_progress = data.progression.feature_progress.duplicate(true)
		progression_director.restore(progress.feature_progress, true)
		feature_access.setup(self, progression_director)
	return true
