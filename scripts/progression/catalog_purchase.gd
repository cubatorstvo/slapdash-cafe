extends RefCounted
## One purchase predicate for catalogue cards and host commands.
const Bindings = preload("res://scripts/progression/catalog_bindings.gd")
const Reasons = preload("res://scripts/progression/access_reasons.gd")

static func _laboratory():
	return load("res://scripts/laboratory_progression.gd")

static func _lounge():
	return load("res://scripts/lounge_progression.gd")

static func _base_catalogue():
	return load("res://scripts/cafe_catalogue.gd")

static func introduced(progress, item_id: String) -> bool:
	var row := Bindings.item(item_id)
	if row.is_empty() or progress == null: return true
	if str(row.context) == "base_lab_purchase":
		return int(progress.get("lab_stage")) >= int(row.stage)
	if bool(row.upgrade):
		var owned: Variant = progress.get("lounge_items")
		return owned is Array and str(row.internal) in owned
	return true

static func flags(progress, item_id: String, _spec: Dictionary = {}) -> Dictionary:
	var row := Bindings.item(item_id)
	if row.is_empty() or progress == null: return {}
	var result := {}
	if _delivery_pending(progress, item_id): result.pending_delivery = true
	if _busy(progress):
		result.station_busy = true
		result.busy_reason = "Сначала заверши проверку."
	var structural := _structural(progress, row)
	for key in structural: result[key] = structural[key]
	return result

static func structural_reason(progress, item_id: String) -> String:
	var row := Bindings.item(item_id)
	if row.is_empty(): return ""
	return _reason_from_flags(_structural(progress, row), 0, 0)

static func expansion_unlocked(progress, feature_id: String) -> bool:
	var raw: Variant = progress.get("feature_progress") if progress != null else {}
	if not raw is Dictionary: return false
	var unlocked: Variant = raw.get("unlocked_features", [])
	return unlocked is Array and feature_id in unlocked

static func title_for(item_id: String) -> String:
	if item_id.begins_with("rest_upgrade_"):
		var lounge_id := item_id.trim_prefix("rest_upgrade_")
		if _lounge().GOODS.has(lounge_id): return "Улучшение: " + str(_lounge().GOODS[lounge_id].name)
	if _laboratory().ITEMS.has(item_id): return str(_laboratory().ITEMS[item_id].name)
	if _base_catalogue().ITEMS.has(item_id): return str(_base_catalogue().ITEMS[item_id].name)
	if item_id.begins_with("rest_"):
		var lounge_id := item_id.trim_prefix("rest_")
		if _lounge().GOODS.has(lounge_id): return str(_lounge().GOODS[lounge_id].name)
	return item_id

static func _structural(progress, row: Dictionary) -> Dictionary:
	var result := {}
	var context := str(row.context)
	if context == "base_lab_purchase":
		var stage := int(progress.get("lab_stage"))
		var suffix := int(row.stage)
		if stage > suffix:
			result.already_owned = true
		elif stage < suffix:
			result.missing_upgrade = true
			result.upgrade_reason = "Сначала установи: %s." % title_for(str(row.requires[0])) if not (row.requires as Array).is_empty() else "Сначала установи предыдущую деталь лаборатории."
	elif context == "laboratory_purchase":
		var item_id := str(row.item_id)
		var installed: Variant = progress.get("lab_upgrades")
		if installed is Array and item_id in installed:
			result.already_owned = true
		elif int(progress.get("lab_stage")) < 3:
			result.room_too_small = true
			result.room_reason = "Сначала собери стол исследования."
		elif int(progress.get("lab_tier")) < int(row.lab_tier):
			result.room_too_small = true
			result.room_reason = "Сначала расширь лабораторию: %s." % str(_laboratory().STAGES[int(row.lab_tier)].name)
		else:
			for raw in row.requires:
				var prerequisite := str(raw)
				if not installed is Array or prerequisite not in installed:
					result.missing_upgrade = true
					result.upgrade_reason = "Сначала установи: %s." % title_for(prerequisite)
					break
	elif context == "lounge_purchase":
		var lounge_id := str(row.internal)
		var owned: Variant = progress.get("lounge_items")
		var upgrades: Variant = progress.get("lounge_upgrades")
		if bool(row.upgrade):
			if upgrades is Array and lounge_id in upgrades: result.already_owned = true
			elif not owned is Array or lounge_id not in owned:
				result.missing_upgrade = true
				result.upgrade_reason = "Сначала установи: %s." % title_for("rest_" + lounge_id)
		elif owned is Array and lounge_id in owned:
			result.already_owned = true
		if int(progress.get("lounge_tier")) < int(row.lounge_tier):
			result.room_too_small = true
			result.room_reason = "Сначала расширь комнату: %s." % str(_lounge().STAGES[int(row.lounge_tier)].name)
	return result

static func _reason_from_flags(flags: Dictionary, price: int, cash: int) -> String:
	if flags.is_empty() and price <= cash: return ""
	if bool(flags.get("already_owned", false)): return Reasons.text(Reasons.ALREADY_OWNED)
	if bool(flags.get("pending_delivery", false)): return Reasons.text(Reasons.DELIVERY_PENDING)
	if bool(flags.get("station_busy", false)): return Reasons.text(Reasons.STATION_BUSY, {"text":str(flags.get("busy_reason", ""))})
	if bool(flags.get("room_too_small", false)): return Reasons.text(Reasons.ROOM_TOO_SMALL, {"text":str(flags.get("room_reason", ""))})
	if bool(flags.get("missing_upgrade", false)): return Reasons.text(Reasons.MISSING_UPGRADE, {"text":str(flags.get("upgrade_reason", ""))})
	if price > cash: return Reasons.text(Reasons.INSUFFICIENT_FUNDS, {"missing":price - cash})
	return ""

static func _busy(progress) -> bool:
	return progress.has_method("busy") and bool(progress.busy())

static func _delivery_pending(progress, item_id: String) -> bool:
	var deliveries: Variant = progress.get("deliveries")
	if not deliveries is Array: return false
	for raw in deliveries:
		if not raw is Dictionary: continue
		var parcel: Dictionary = raw
		if str(parcel.get("item", "")) == item_id: return true
		var packed: Variant = parcel.get("items", [])
		if packed is Array and item_id in packed: return true
	return false
