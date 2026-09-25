extends "res://scripts/cafe_service_core.gd"
const ShiftSummary = preload("res://scripts/cafe_shift_summary.gd")
const OverviewInsights = preload("res://scripts/cafe_insights.gd")
const FeatureAccess = preload("res://scripts/feature_access.gd")
const ProgressionDirector = preload("res://scripts/progression/progression_director.gd")
const LabProgress = preload("res://scripts/laboratory_progression.gd")
const LoungeProgress = preload("res://scripts/lounge_progression.gd")
const ProgressionPolicy = preload("res://scripts/cafe_progression.gd")
const SAVE_VERSION := 26
var shift_summary = ShiftSummary.new()
var progression_director = ProgressionDirector.new()
var feature_access = FeatureAccess.new()
var _feature_poll_clock := 0.0

func _ready() -> void:
	super()
	progress.world_epoch = _new_world_epoch()
	progression_director.setup(self)
	feature_access.setup(self, progression_director)

func _new_world_epoch() -> String:
	return Crypto.new().generate_random_bytes(12).hex_encode()

func _refresh_progression() -> void:
	if game != null and is_instance_valid(game.get("session")) and game.session.is_guest(): return
	progression_director.migrate_from_game_state()
	progression_director.reconcile()
	progress.feature_progress = progression_director.snapshot()

func _process(delta: float) -> void:
	_feature_poll_clock += delta
	if _feature_poll_clock >= 0.25:
		_feature_poll_clock = 0.0
		_refresh_progression()

func current_shift_summary() -> Dictionary:
	return shift_summary.current(progress.day,served,missed,revenue)

func previous_shift_summary() -> Dictionary:
	return shift_summary.previous_report()

func feature_state(feature_id: String, context: Dictionary = {}) -> Dictionary:
	return feature_access.feature_state(feature_id) if context.is_empty() else feature_access.access(feature_id, context)

func ui_state(entry_id: String, context: Dictionary = {}) -> Dictionary:
	return feature_access.ui_state(entry_id, context)

func check_feature_action(action_id: String, context: Dictionary = {}) -> Dictionary:
	return feature_access.check_action(action_id, context)

func visible_feature_entries(container_id: String, context: Dictionary = {}) -> Array:
	return feature_access.visible_entries(container_id, context)

func next_unlock_preview() -> Dictionary:
	return feature_access.next_unlock_preview()

func feature_reason(state: Dictionary) -> String:
	return feature_access.reason_text(state)

func _action_command_error(action_id: String, context: Dictionary = {}) -> String:
	var state: Dictionary = feature_access.check_action(action_id, context)
	if bool(state.get("allowed", false)): return ""
	var reason := feature_access.reason_text(state)
	return reason if not reason.is_empty() else "Эта возможность сейчас недоступна."

func _request_is_host() -> bool:
	var sender: int = multiplayer.get_remote_sender_id()
	return sender <= 1

func _purchase_access(kind: String, id: String, station_id: int) -> Dictionary:
	var context := {"host_required":true,"is_host":_request_is_host()}
	var item_id := "sauce_ramp" if kind == "upgrade" else kind if kind in ["counter","kitchen","grill_kitchen","solyanka_kitchen"] else id
	if game != null and game.get("shop") != null and game.shop.ITEMS.has(item_id):
		var spec: Dictionary = game.shop.ITEMS[item_id]
		context.item_id = item_id
		context.spec = spec
		context.price = int(spec.get("price", 0))
		if station_id > 0 and game.shop.has_method("pending"): context.pending_delivery = game.shop.pending(item_id, station_id)
		return feature_access.item_access(item_id, spec, context)
	var feature_id := "shop_basic"
	var price := 0
	match kind:
		"lab_expansion":
			var lab_tier := mini(progress.lab_tier + 1, LabProgress.STAGES.size() - 1)
			feature_id = "content.lab_expansion.%d" % lab_tier
			price = int(LabProgress.STAGES[lab_tier].price)
		"lounge_expansion":
			var lounge_tier := mini(progress.lounge_tier + 1, LoungeProgress.STAGES.size() - 1)
			feature_id = "content.lounge_expansion.%d" % lounge_tier
			price = int(LoungeProgress.STAGES[lounge_tier].price)
		"expansion":
			feature_id = "kitchen_pair"
			price = ProgressionPolicy.EXPANSION_PRICE
		"specialty_expansion":
			feature_id = "kitchen_specialty"
			price = ProgressionPolicy.SPECIALTY_EXPANSION_PRICE
		"orchestration_expansion":
			feature_id = "kitchen_orchestration"
			price = ProgressionPolicy.ORCHESTRATION_EXPANSION_PRICE
	context.price = price
	return feature_access.access(feature_id, context)

func purchase(kind: String, id: String, station_id := 0) -> String:
	var state := _purchase_access(kind, id, station_id)
	if not bool(state.get("enabled", false)):
		var reason := feature_access.reason_text(state)
		return reason if not reason.is_empty() else "Эта покупка пока недоступна."
	var result: String = super(kind, id, station_id)
	if result.is_empty(): _refresh_progression()
	return result

func request_masterclass(dish: String, peer: int, equipment: Variant = null) -> String:
	var error := _action_command_error("masterclass_start")
	if not error.is_empty(): return error
	return super(dish, peer, equipment)

func request_live_lesson(dish: String, clone_id: int, peer: int) -> String:
	var error := _action_command_error("live_lesson_start", {"actor_id":peer})
	if not error.is_empty(): return error
	return super(dish,clone_id,peer)

func begin_live_lesson(peer: int) -> String:
	var error := _action_command_error("live_lesson_begin", {"actor_id":peer})
	if not error.is_empty(): return error
	return super(peer)

func observe_auto_served(dish: String,station_id: int) -> void:
	progression_director.observe("auto_served", {"dish":dish,"station_id":station_id})
	_refresh_progression()

func complete_video_lesson(lesson_id: int, record: Dictionary, participants: Array) -> Array:
	var learned: Array=super(lesson_id,record,participants)
	if not learned.is_empty():
		var station_ids: Array=[]
		for participant in participants:
			if not participant is Dictionary: continue
			var station_id:=int(participant.get("station",0))
			if station_id>0 and station_id not in station_ids: station_ids.append(station_id)
		progression_director.observe("video_training_completed", {"station_count":station_ids.size()})
		_refresh_progression()
	return learned

func rename_masterclass(id: int, value: String) -> String:
	var error := _action_command_error("masterclass_rename")
	if not error.is_empty(): return error
	return super(id, value)

func delete_masterclass(id: int) -> String:
	var error := _action_command_error("masterclass_delete")
	if not error.is_empty(): return error
	return super(id)

func create_clone(tempo := 1.0, prepaid := false) -> String:
	var error := _action_command_error("clone_create")
	if not error.is_empty(): return error
	var result: String = super(tempo, prepaid)
	if result.is_empty():
		progression_director.observe("clone_created", {"clone_id":maxi(1, progress.next_clone_id - 1)})
		_refresh_progression()
	return result

func save_masterclass_from_run(stage: Node3D, dish: String, tracks: Array) -> bool:
	var saved: bool = super(stage, dish, tracks)
	if saved:
		progression_director.observe("masterclass_saved", {"dish":dish})
		_refresh_progression()
	return saved

func start_banquet(sender: int) -> String:
	var error := _action_command_error("banquet", {"actor_id":sender})
	if not error.is_empty(): return error
	return super(sender)

func start_group_training(record_id: int, ids: Array, peer := 1, command_id := "") -> String:
	var error := _action_command_error("group_train", {"actor_id":peer,"station_ids":ids})
	if not error.is_empty(): return error
	return super(record_id, ids, peer, command_id)

func queue_training_course(assignments: Array, mode := "together", command_id := "", peer := 1, group_order: Array = []) -> Dictionary:
	var station_ids: Array = []
	for assignment in assignments:
		if assignment is Dictionary:
			for raw_id in assignment.get("station_ids", assignment.get("stations", [])):
				var station_id := int(raw_id)
				if station_id not in station_ids: station_ids.append(station_id)
	var error := _action_command_error("training_course_confirm", {"actor_id":peer,"station_ids":station_ids})
	if not error.is_empty(): return {"error":error,"course_id":0}
	if station_ids.size()>1 and not bool(feature_access.feature_state("group_training").get("unlocked",false)):
		return {"error":"Сначала обучи одного клона по фильму. Массовое назначение откроется после его завершённого просмотра.","course_id":0}
	return super(assignments, mode, command_id, peer, group_order)

func edit_training_course(course_id: int, assignments: Array, mode := "together", peer := 1, group_order: Array = []) -> String:
	var station_ids: Array = []
	for assignment in assignments:
		if assignment is Dictionary:
			for raw_id in assignment.get("station_ids", assignment.get("stations", [])):
				var station_id := int(raw_id)
				if station_id not in station_ids: station_ids.append(station_id)
	var error := _action_command_error("training_course_edit", {"actor_id":peer,"station_ids":station_ids})
	if not error.is_empty(): return error
	if station_ids.size()>1 and not bool(feature_access.feature_state("group_training").get("unlocked",false)):
		return "Сначала обучи одного клона по фильму. Массовое назначение откроется после его завершённого просмотра."
	return super(course_id, assignments, mode, peer, group_order)

func create_table_group(ids: Array, name := "") -> String:
	var error := _action_command_error("group_create", {"station_ids":ids})
	if not error.is_empty(): return error
	return super(ids, name)

func rename_table_group(group_id: String, value: String) -> String:
	var error := _action_command_error("group_rename")
	if not error.is_empty(): return error
	return super(group_id, value)

func dissolve_table_groups(group_ids: Array) -> String:
	var error := _action_command_error("group_dissolve")
	if not error.is_empty(): return error
	return super(group_ids)

func set_group_dish_active(group_id: String, dish: String, enabled: bool) -> String:
	var error := _action_command_error("group_active")
	if not error.is_empty(): return error
	return super(group_id, dish, enabled)

func finish_customer(id: int, accepted: bool, failure_reason := "", portion_number := 0, expected_order_id := 0) -> void:
	super(id, accepted, failure_reason, portion_number, expected_order_id)
	_refresh_progression()

func save_data() -> Dictionary:
	_refresh_progression()
	progress.feature_progress = progression_director.snapshot()
	var data: Dictionary=super()
	data.version=SAVE_VERSION
	data.shift_summary=shift_summary.snapshot()
	return data

func load_data(data: Dictionary) -> bool:
	var source_version:=int(data.get("version",0))
	if source_version>22 and source_version not in [23,24,25,SAVE_VERSION]: return false
	if source_version>=23 and not data.get("shift_summary",{}) is Dictionary: return false
	if source_version==SAVE_VERSION:
		if not data.get("progression",{}) is Dictionary or not data.progression.get("feature_progress",{}) is Dictionary or not data.get("learning",{}) is Dictionary: return false
	var compatible: Dictionary=data.duplicate(true)
	if source_version>=23: compatible.version=22
	if not super(compatible): return false
	progress.world_epoch=_new_world_epoch()
	if source_version==SAVE_VERSION and data.progression.get("feature_progress",{}) is Dictionary:
		progress.feature_progress=data.progression.feature_progress.duplicate(true)
		progression_director.restore(progress.feature_progress)
	else:
		progress.feature_progress={}
		progression_director.migrate_from_game_state()
		progression_director.reconcile()
	progress.feature_progress=progression_director.snapshot()
	feature_access.setup(self, progression_director)
	if source_version>=23: shift_summary.restore(data.get("shift_summary",{}),progress.day,served,missed,revenue)
	else: shift_summary.reset(progress.day,served,missed,revenue)
	return true

func clear_world() -> void:
	super()
	shift_summary.reset(progress.day,0,0,0)
	shift_summary.previous={}
	progress.world_epoch=_new_world_epoch()
	progress.feature_progress={}
	progression_director.reset_new_cafe()
	feature_access.setup(self, progression_director)

func advance_shift(delta: float) -> void:
	var before:=str(progress.shift)
	super(delta)
	if before!="night" and progress.shift=="night": shift_summary.finalize(progress.day,served,missed,revenue)
	_refresh_progression()

func next_day() -> String:
	var old_day:=int(progress.day)
	var result: String=super()
	if result.is_empty() and progress.day!=old_day: shift_summary.reset(progress.day,served,missed,revenue)
	_refresh_progression()
	return result

func _analytics_loss(customer: Dictionary,reason: String) -> void:
	super(customer,reason)
	if analytics.get("feed",[]) is Array and not analytics.feed.is_empty():
		var entry: Dictionary=analytics.feed[0]
		if str(entry.get("kind","")) in ["loss","partial"]:
			entry.day=progress.day
			entry.order_id=int(customer.get("order_id",0))
			entry.customer_id=int(customer.get("id",0))

func overview_problem() -> Dictionary:
	if not analytics.get("feed",[]) is Array: return {}
	for raw_entry in analytics.feed:
		if not raw_entry is Dictionary: continue
		var entry: Dictionary=raw_entry
		if str(entry.get("kind","")) not in ["loss","partial"] or int(entry.get("day",-1))!=progress.day: continue
		var result:=entry.duplicate(true)
		var reason:=str(result.get("reason",""))
		result.label=OverviewInsights.reason_label(reason)
		result.suggestion=OverviewInsights.suggestion(reason)
		return result
	return {}

func production_overview() -> Dictionary:
	var clones: Array=clone_options()
	if clones.is_empty(): return {}
	var assigned_stations:=0
	var working_stations:=0
	var production_stations:=0
	for station in stations:
		if bool(station.get("manual_station")) or bool(station.get("masterclass_station")): continue
		production_stations+=1
		var has_clone:=false
		for member in station.get("crew"):
			if member is Dictionary and member.has("clone_id"):
				has_clone=true
				break
		if has_clone:
			assigned_stations+=1
			if str(station.get("state"))!="idle": working_stations+=1
	return {"clones":clones.size(),"assigned_stations":assigned_stations,"working_stations":working_stations,"production_stations":production_stations}
