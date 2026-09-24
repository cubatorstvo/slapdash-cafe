extends RefCounted

var baseline: Dictionary = {"day":1,"served":0,"missed":0,"revenue":0}
var previous: Dictionary = {}
var finalized_day := -1

func reset(day: int, served: int, missed: int, revenue: int) -> void:
	baseline = {"day":day,"served":maxi(0,served),"missed":maxi(0,missed),"revenue":maxi(0,revenue)}
	finalized_day = -1

func current(day: int, served: int, missed: int, revenue: int) -> Dictionary:
	return {"day":day,"served":maxi(0,served-int(baseline.get("served",0))),"missed":maxi(0,missed-int(baseline.get("missed",0))),"revenue":maxi(0,revenue-int(baseline.get("revenue",0)))}

func finalize(day: int, served: int, missed: int, revenue: int) -> Dictionary:
	if finalized_day == day: return previous.duplicate(true)
	previous = current(day,served,missed,revenue)
	finalized_day = day
	return previous.duplicate(true)

func previous_report() -> Dictionary:
	return previous.duplicate(true)

func snapshot() -> Dictionary:
	return {"baseline":baseline.duplicate(true),"previous":previous.duplicate(true),"finalized_day":finalized_day}

func restore(value: Variant, day: int, served: int, missed: int, revenue: int) -> bool:
	if not value is Dictionary:
		reset(day,served,missed,revenue)
		previous = {}
		return false
	var saved_baseline: Variant=value.get("baseline",{})
	var saved_previous: Variant=value.get("previous",{})
	if not saved_baseline is Dictionary or not saved_previous is Dictionary:
		reset(day,served,missed,revenue)
		previous = {}
		return false
	baseline={"day":int(saved_baseline.get("day",day)),"served":maxi(0,int(saved_baseline.get("served",served))),"missed":maxi(0,int(saved_baseline.get("missed",missed))),"revenue":maxi(0,int(saved_baseline.get("revenue",revenue)))}
	previous=saved_previous.duplicate(true)
	finalized_day=int(value.get("finalized_day",-1))
	return true
