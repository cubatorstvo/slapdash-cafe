extends "res://scripts/cafe_service_core.gd"
const ShiftSummary = preload("res://scripts/cafe_shift_summary.gd")
const OverviewInsights = preload("res://scripts/cafe_insights.gd")
const FeatureAccess = preload("res://scripts/feature_access.gd")
const SAVE_VERSION := 24
var shift_summary = ShiftSummary.new()
var feature_access = FeatureAccess.new()

func _ready() -> void:
	super()
	feature_access.setup(self)

func current_shift_summary() -> Dictionary:
	return shift_summary.current(progress.day,served,missed,revenue)

func previous_shift_summary() -> Dictionary:
	return shift_summary.previous_report()

func feature_state(feature_id: String, context: Dictionary = {}) -> Dictionary:
	return feature_access.access(feature_id, context)

func feature_reason(state: Dictionary) -> String:
	return feature_access.reason_text(state)

func _action_command_error(action_id: String, context: Dictionary = {}) -> String:
	var state: Dictionary = feature_access.action_access(action_id, context)
	if bool(state.get("enabled", false)): return ""
	var reason := feature_access.reason_text(state)
	return reason if not reason.is_empty() else "Эта возможность сейчас недоступна."

func _purchase_access(kind: String, id: String, station_id: int) -> Dictionary:
	var context := {"host_required":true,"is_host":true}
	if game != null and game.get("shop") != null and game.shop.ITEMS.has(id):
		var spec: Dictionary = game.shop.ITEMS[id]
		context.price = int(spec.get("price", 0))
		if station_id > 0 and game.shop.has_method("pending"): context.pending_delivery = game.shop.pending(id, station_id)
		return feature_access.item_access(id, spec, context)
	var feature_id := "shop_basic"
	match kind:
		"lab_expansion": feature_id = "clone_lab"
		"lounge_expansion": feature_id = "rest_basics"
		"expansion": feature_id = "stars"
	return feature_access.access(feature_id, context)

func purchase(kind: String, id: String, station_id := 0) -> String:
	var state := _purchase_access(kind, id, station_id)
	if not bool(state.get("enabled", false)):
		var reason := feature_access.reason_text(state)
		return reason if not reason.is_empty() else "Эта покупка пока недоступна."
	return super(kind, id, station_id)

func request_masterclass(dish: String, peer: int, equipment: Variant = null) -> String:
	var error := _action_command_error("masterclass")
	if not error.is_empty(): return error
	return super(dish, peer, equipment)

func create_clone(tempo := 1.0, prepaid := false) -> String:
	var error := _action_command_error("clone_create")
	if not error.is_empty(): return error
	var result: String = super(tempo, prepaid)
	if result.is_empty(): feature_access.mark_fact("first_clone_created")
	return result

func save_masterclass_from_run(stage: Node3D, dish: String, tracks: Array) -> bool:
	var saved: bool = super(stage, dish, tracks)
	if saved: feature_access.mark_fact("first_recording_saved")
	return saved

func start_banquet(sender: int) -> String:
	var error := _action_command_error("banquet")
	if not error.is_empty(): return error
	return super(sender)

func save_data() -> Dictionary:
	var data: Dictionary=super()
	data.version=SAVE_VERSION
	data.shift_summary=shift_summary.snapshot()
	data.feature_access=feature_access.export_state()
	return data

func load_data(data: Dictionary) -> bool:
	var source_version:=int(data.get("version",0))
	if source_version>22 and source_version not in [23,SAVE_VERSION]: return false
	if source_version>=23 and not data.get("shift_summary",{}) is Dictionary: return false
	if source_version==SAVE_VERSION and not data.get("feature_access",{}) is Dictionary: return false
	var compatible: Dictionary=data.duplicate(true)
	if source_version>=23: compatible.version=22
	if not super(compatible): return false
	if source_version>=23:
		shift_summary.restore(data.get("shift_summary",{}),progress.day,served,missed,revenue)
	else:
		shift_summary.reset(progress.day,served,missed,revenue)
	feature_access.import_state(data.get("feature_access",{}))
	return true

func clear_world() -> void:
	super()
	shift_summary.reset(progress.day,0,0,0)
	shift_summary.previous={}
	feature_access.reset()

func advance_shift(delta: float) -> void:
	var before:=str(progress.shift)
	super(delta)
	if before!="night" and progress.shift=="night": shift_summary.finalize(progress.day,served,missed,revenue)
	feature_access.refresh_facts()

func next_day() -> String:
	var old_day:=int(progress.day)
	var result: String=super()
	if result.is_empty() and progress.day!=old_day: shift_summary.reset(progress.day,served,missed,revenue)
	feature_access.refresh_facts()
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
