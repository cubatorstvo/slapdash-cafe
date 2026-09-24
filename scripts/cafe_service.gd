extends "res://scripts/cafe_service_core.gd"
const ShiftSummary = preload("res://scripts/cafe_shift_summary.gd")
const OverviewInsights = preload("res://scripts/cafe_insights.gd")
const SAVE_VERSION := 23
var shift_summary = ShiftSummary.new()

func current_shift_summary() -> Dictionary:
	return shift_summary.current(progress.day,served,missed,revenue)

func previous_shift_summary() -> Dictionary:
	return shift_summary.previous_report()

func save_data() -> Dictionary:
	var data: Dictionary=super()
	data.version=SAVE_VERSION
	data.shift_summary=shift_summary.snapshot()
	return data

func load_data(data: Dictionary) -> bool:
	var source_version:=int(data.get("version",0))
	if source_version>22 and source_version!=SAVE_VERSION: return false
	if source_version==SAVE_VERSION and not data.get("shift_summary",{}) is Dictionary: return false
	var compatible: Dictionary=data.duplicate(true)
	if source_version==SAVE_VERSION: compatible.version=22
	if not super(compatible): return false
	if source_version==SAVE_VERSION:
		shift_summary.restore(data.get("shift_summary",{}),progress.day,served,missed,revenue)
	else:
		shift_summary.reset(progress.day,served,missed,revenue)
	return true

func clear_world() -> void:
	super()
	shift_summary.reset(progress.day,0,0,0)
	shift_summary.previous={}

func advance_shift(delta: float) -> void:
	var before:=str(progress.shift)
	super(delta)
	if before!="night" and progress.shift=="night": shift_summary.finalize(progress.day,served,missed,revenue)

func next_day() -> String:
	var old_day:=int(progress.day)
	var result: String=super()
	if result.is_empty() and progress.day!=old_day: shift_summary.reset(progress.day,served,missed,revenue)
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
