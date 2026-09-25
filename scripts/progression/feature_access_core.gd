extends RefCounted

const FeatureCatalog = preload("res://scripts/progression/feature_catalog.gd")
const UiEntryCatalog = preload("res://scripts/progression/ui_entry_catalog.gd")
const AccessReasons = preload("res://scripts/progression/access_reasons.gd")

var service: Node
var progression_director
var _world_epoch_seen := ""
var _cafe_id_seen := ""
var _revision_seen := -1

func setup(owner_service: Node, director = null) -> void:
	service = owner_service
	progression_director = director if director != null else owner_service.get("progression_director")
	_capture_sync_stamp()

func revision() -> int:
	return int(progression_director.revision) if progression_director != null else 0

func feature_state(feature_id: StringName) -> Dictionary:
	_sync_from_progress_snapshot()
	var normalized := FeatureCatalog.normalize_feature_id(str(feature_id))
	if FeatureCatalog.definition(normalized).is_empty(): return {"feature_id":normalized,"unlocked":false,"revision":revision(),"reason_code":AccessReasons.UNKNOWN_FEATURE,"reason_args":{"feature_id":normalized}}
	var unlocked: bool = progression_director != null and bool(progression_director.is_unlocked(normalized))
	return {"feature_id":normalized,"unlocked":unlocked,"revision":revision(),"reason_code":AccessReasons.OK if unlocked else AccessReasons.FEATURE_LOCKED,"reason_args":{} if unlocked else {"feature_id":normalized}}

func ui_state(entry_id: StringName, context: Dictionary = {}) -> Dictionary:
	_sync_from_progress_snapshot()
	var requested := str(entry_id)
	var definition := UiEntryCatalog.entry(requested)
	if definition.is_empty(): return _ui_result(requested, "", false, false, false, "hidden", AccessReasons.UNKNOWN_ENTRY, {})
	var required: Array = definition.get("required_features", [])
	var any_features: Array = definition.get("any_features", [])
	var locked_feature := _first_locked(required)
	if locked_feature.is_empty() and not any_features.is_empty() and not _any_unlocked(any_features): locked_feature = str(any_features[0])
	var feature_id := str(required[0]) if not required.is_empty() else str(any_features[0]) if not any_features.is_empty() else ""
	if not locked_feature.is_empty(): return _ui_result(str(definition.id), feature_id, false, false, false, "hidden", AccessReasons.FEATURE_LOCKED, {"feature_id":locked_feature})
	var parent_id := str(definition.get("parent_id", ""))
	if not parent_id.is_empty() and not bool(ui_state(parent_id, context).get("visible", false)): return _ui_result(str(definition.id), feature_id, false, false, false, "hidden", AccessReasons.FEATURE_LOCKED, {"feature_id":feature_id})
	if not _context_applies(definition, context): return _ui_result(str(definition.id), feature_id, true, true, false, "hidden", AccessReasons.INCOMPATIBLE_TARGET, {})
	var action_id := str(definition.get("action_id", ""))
	if action_id.is_empty(): return _ui_result(str(definition.id), feature_id, true, true, true, "ready", AccessReasons.OK, {})
	var check := check_action(action_id, context)
	return _ui_result(str(definition.id), feature_id, true, true, bool(check.allowed), "ready" if bool(check.allowed) else "blocked", check.reason_code, check.reason_args)

func check_action(action_id: StringName, context: Dictionary) -> Dictionary:
	_sync_from_progress_snapshot()
	var id := str(action_id)
	if id == "buy": return _check_buy(context)
	if id == "buy_station_batch": return _check_station_batch(context)
	if not UiEntryCatalog.ACTION_FEATURES.has(id): return _check(false, AccessReasons.UNKNOWN_ACTION, {"action_id":id})
	var required := UiEntryCatalog.action_features(id)
	if id in ["group_train", "training_course_confirm", "training_course_edit"] and _normalized_station_count(context) >= 2 and "group_training" not in required: required.append("group_training")
	var locked := _first_locked(required)
	if not locked.is_empty(): return _check(false, AccessReasons.FEATURE_LOCKED, {"feature_id":locked})
	return _check_temporary(context)

func visible_entries(container_id: StringName, context: Dictionary = {}) -> Array:
	_sync_from_progress_snapshot()
	var result: Array = []
	for definition in UiEntryCatalog.children(str(container_id)):
		if bool(definition.get("auxiliary", false)) and not bool(context.get("include_auxiliary", false)): continue
		var state := ui_state(str(definition.id), context)
		if bool(state.visible): result.append(state)
	return result

func next_unlock_preview() -> Dictionary:
	_sync_from_progress_snapshot()
	if progression_director == null: return {}
	for feature_id in FeatureCatalog.ordered_ids():
		var definition := FeatureCatalog.definition(feature_id)
		if progression_director.is_unlocked(feature_id) or not bool(definition.get("announce", false)): continue
		var parents_ready := true
		for dependency in definition.get("requires_features", []):
			if not progression_director.is_unlocked(str(dependency)): parents_ready = false; break
		if not parents_ready: continue
		var condition := _next_condition(definition)
		if condition.is_empty(): continue
		return {"feature_id":feature_id,"title":str(definition.get("title_key", feature_id)),"condition":condition,"route":_route_for_feature(feature_id)}
	return {}

func item_access(item_id: String, spec: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_sync_from_progress_snapshot()
	var required := FeatureCatalog.item_features(item_id, spec)
	var locked := _first_locked(required)
	var primary := str(required[0]) if not required.is_empty() else "shop_basic"
	if not locked.is_empty(): return _item_result(item_id, primary, false, false, "hidden", AccessReasons.FEATURE_LOCKED, {"feature_id":locked})
	var merged := context.duplicate(true)
	if not merged.has("item_id"): merged.item_id = item_id
	if not merged.has("price"): merged.price = int(spec.get("price", 0))
	var temporary := _check_temporary(merged)
	var state := "ready" if bool(temporary.allowed) else "blocked"
	if bool(merged.get("already_owned", false)): state = "owned"
	elif bool(merged.get("pending_delivery", false)): state = "pending"
	return _item_result(item_id, primary, true, bool(temporary.allowed), state, temporary.reason_code, temporary.reason_args)

func recipe_access(dish_id: String, context: Dictionary = {}) -> Dictionary:
	_sync_from_progress_snapshot()
	var feature_id := FeatureCatalog.recipe_feature(dish_id)
	if feature_id.is_empty(): return _ui_result("recipe." + dish_id, "", false, false, false, "hidden", AccessReasons.UNKNOWN_ENTRY, {})
	var unlocked: bool = progression_director != null and bool(progression_director.is_unlocked(feature_id))
	if not unlocked and bool(context.get("known_recipe", false)): unlocked = true
	return _ui_result("recipe." + dish_id, feature_id, unlocked, unlocked, unlocked, "ready" if unlocked else "hidden", AccessReasons.OK if unlocked else AccessReasons.FEATURE_LOCKED, {})

func nearest_visible_route(route: String, context: Dictionary = {}) -> String:
	var candidate := UiEntryCatalog.route_id(route)
	var visited := {}
	while not candidate.is_empty() and not visited.has(candidate):
		visited[candidate] = true
		if bool(ui_state(candidate, context).visible): return candidate
		var definition := UiEntryCatalog.entry(candidate)
		candidate = str(definition.get("parent_id", "")) if not definition.is_empty() else ""
	return "office.cafe"

func nearest_visible_page(page: String, context: Dictionary = {}) -> String:
	return UiEntryCatalog.legacy_page(nearest_visible_route(page, context))

func first_visible_category(preferred := "equipment", context: Dictionary = {}) -> String:
	var ordered := [preferred, "equipment", "tables", "rooms", "lab", "lounge", "decor"]
	var seen := {}
	for raw in ordered:
		var category := str(raw)
		if seen.has(category): continue
		seen[category] = true
		if bool(ui_state("shop.category." + category, context).visible): return category
	return "equipment"

func access(feature_id: String, context: Dictionary = {}) -> Dictionary:
	var feature := feature_state(feature_id)
	var unlocked := bool(feature.unlocked)
	if not unlocked: return {"feature_id":str(feature.feature_id),"introduced":false,"unlocked":false,"visible":false,"enabled":false,"state":"hidden","reason_code":feature.reason_code,"reason_args":feature.reason_args,"revision":revision()}
	var temporary := _check_temporary(context) if not context.is_empty() and not bool(context.get("ignore_context", false)) else _check(true, AccessReasons.OK, {})
	return {"feature_id":str(feature.feature_id),"introduced":true,"unlocked":true,"visible":true,"enabled":bool(temporary.allowed),"state":"ready" if bool(temporary.allowed) else "blocked","reason_code":temporary.reason_code,"reason_args":temporary.reason_args,"revision":revision()}

func page_access(page: String, context: Dictionary = {}) -> Dictionary: return ui_state(UiEntryCatalog.route_id(page), context)
func category_access(category: String, context: Dictionary = {}) -> Dictionary: return ui_state("shop.category." + category, context)

func action_access(action: String, context: Dictionary = {}) -> Dictionary:
	var aliases := {"masterclass":"masterclass_start","video_manage":"masterclass_rename","staff_training":"video_watch","training_course":"training_course_confirm","group_manage":"group_create","group_training":"group_train","recalibration":"lab_recalibrate"}
	var action_id := str(aliases.get(action, action))
	var check := check_action(action_id, context)
	return {"feature_id":"","introduced":check.reason_code != AccessReasons.FEATURE_LOCKED,"unlocked":check.reason_code != AccessReasons.FEATURE_LOCKED,"visible":check.reason_code != AccessReasons.FEATURE_LOCKED,"enabled":bool(check.allowed),"state":"ready" if bool(check.allowed) else "blocked","reason_code":check.reason_code,"reason_args":check.reason_args,"revision":revision()}

func reason_text(result: Dictionary) -> String: return AccessReasons.text(StringName(str(result.get("reason_code", AccessReasons.OK))), result.get("reason_args", {}))

func mark_seen(feature_id: String) -> void:
	if progression_director == null or progression_director.cafe_id.is_empty(): return
	var config := ConfigFile.new(); config.load("user://ui_progress.cfg")
	var ids: Array = config.get_value(progression_director.cafe_id, "seen_feature_ids", [])
	if feature_id not in ids:
		ids.append(feature_id); ids.sort(); config.set_value(progression_director.cafe_id, "seen_feature_ids", ids); config.save("user://ui_progress.cfg")

func has_seen(feature_id: String) -> bool:
	if progression_director == null or progression_director.cafe_id.is_empty(): return false
	var config := ConfigFile.new(); config.load("user://ui_progress.cfg")
	return feature_id in config.get_value(progression_director.cafe_id, "seen_feature_ids", [])

func _check_buy(context: Dictionary) -> Dictionary:
	var item_id := str(context.get("item_id", ""))
	if item_id.is_empty(): return _check(false, AccessReasons.INVALID_CONTEXT, {"field":"item_id"})
	var spec: Dictionary = context.get("spec", {}) if context.get("spec", {}) is Dictionary else {}
	var required := FeatureCatalog.item_features(item_id, spec)
	var locked := _first_locked(required)
	if not locked.is_empty(): return _check(false, AccessReasons.FEATURE_LOCKED, {"feature_id":locked})
	return _check_temporary(context)

func _check_station_batch(context: Dictionary) -> Dictionary:
	var items: Variant = context.get("items", [])
	if not items is Array or items.is_empty(): return _check(false, AccessReasons.INVALID_CONTEXT, {"field":"items"})
	for raw in items:
		var item: Dictionary = raw if raw is Dictionary else {"item_id":str(raw)}
		var item_context := context.duplicate(true)
		item_context.erase("items")
		item_context.erase("price")
		item_context.merge(item, true)
		var result := _check_buy(item_context)
		if not bool(result.allowed): return result
	if _normalized_station_count(context) >= 2 and progression_director != null and not progression_director.is_unlocked("group_training"): return _check(false, AccessReasons.FEATURE_LOCKED, {"feature_id":"group_training"})
	return _check_temporary(context)

func _check_temporary(context: Dictionary) -> Dictionary:
	if bool(context.get("host_required", false)) and not bool(context.get("is_host", true)): return _check(false, AccessReasons.HOST_ONLY, {})
	if bool(context.get("session_owner_required", false)) and int(context.get("actor_id", 0)) != int(context.get("session_owner_id", 0)): return _check(false, AccessReasons.NOT_SESSION_OWNER, {})
	if bool(context.get("target_missing", false)): return _check(false, AccessReasons.TARGET_MISSING, {})
	if bool(context.get("incompatible_target", false)): return _check(false, AccessReasons.INCOMPATIBLE_TARGET, {})
	if bool(context.get("stale_session", false)): return _check(false, AccessReasons.STALE_SESSION, {})
	if bool(context.get("already_owned", false)): return _check(false, AccessReasons.ALREADY_OWNED, {})
	if bool(context.get("pending_delivery", false)): return _check(false, AccessReasons.DELIVERY_PENDING, {})
	if bool(context.get("phase_blocked", false)): return _check(false, AccessReasons.PHASE_BLOCKED, {"text":str(context.get("phase_reason", ""))})
	if bool(context.get("station_busy", context.get("busy", false))): return _check(false, AccessReasons.STATION_BUSY, {"text":str(context.get("busy_reason", ""))})
	if bool(context.get("actor_busy", false)): return _check(false, AccessReasons.ACTOR_BUSY, {"text":str(context.get("busy_reason", ""))})
	if bool(context.get("no_workers", false)): return _check(false, AccessReasons.NO_WORKERS, {})
	if bool(context.get("missing_equipment", false)): return _check(false, AccessReasons.MISSING_EQUIPMENT, {"text":str(context.get("equipment_reason", ""))})
	if bool(context.get("missing_upgrade", false)): return _check(false, AccessReasons.MISSING_UPGRADE, {"text":str(context.get("upgrade_reason", ""))})
	if bool(context.get("room_too_small", false)): return _check(false, AccessReasons.ROOM_TOO_SMALL, {"text":str(context.get("room_reason", ""))})
	if bool(context.get("no_capacity", false)): return _check(false, AccessReasons.NO_CAPACITY, {"text":str(context.get("capacity_reason", ""))})
	if bool(context.get("training_not_ready", false)): return _check(false, AccessReasons.TRAINING_NOT_READY, {"text":str(context.get("training_reason", ""))})
	if bool(context.get("too_far", false)): return _check(false, AccessReasons.TOO_FAR, {"text":str(context.get("distance_reason", ""))})
	if bool(context.get("hands_busy", false)): return _check(false, AccessReasons.HANDS_BUSY, {})
	var price := int(context.get("price", 0)); var available := _cash(context)
	if price > available: return _check(false, AccessReasons.INSUFFICIENT_FUNDS, {"required":price,"available":available,"missing":price-available})
	var domain_check: Variant = context.get("domain_check", {})
	if domain_check is Dictionary and not bool(domain_check.get("allowed", true)): return _check(false, StringName(str(domain_check.get("reason_code", AccessReasons.INVALID_CONTEXT))), domain_check.get("reason_args", {}))
	return _check(true, AccessReasons.OK, {})

func _cash(context: Dictionary) -> int:
	if context.has("available_funds"): return int(context.available_funds)
	if service != null and service.get("progress") != null: return int(service.progress.get("cash"))
	return 0

func _first_locked(features: Array) -> String:
	for raw in features:
		var id := FeatureCatalog.normalize_feature_id(str(raw))
		if progression_director == null or not progression_director.is_unlocked(id): return id
	return ""

func _any_unlocked(features: Array) -> bool:
	for raw in features:
		if progression_director != null and progression_director.is_unlocked(str(raw)): return true
	return false

func _context_applies(definition: Dictionary, context: Dictionary) -> bool:
	var rule := str(definition.get("context_rule_id", "always"))
	match rule:
		"always", "": return true
		"station_type": return str(context.get("station_type", "")) == str(definition.get("station_type", ""))
		_: return false

func _normalized_station_count(context: Dictionary) -> int:
	var unique := {}
	for raw in context.get("station_ids", []): unique[int(raw)] = true
	return unique.size()

func _next_condition(definition: Dictionary) -> String:
	var stars_required := int(definition.get("min_stars", 0)); var current_stars := 0
	if service != null and service.get("progress") != null: current_stars = int(service.progress.get("stars"))
	if current_stars < stars_required: return "Получить %d★" % stars_required
	for milestone_id in definition.get("requires_milestones", []):
		if progression_director != null and not progression_director.has_milestone(str(milestone_id)): return _milestone_hint(str(milestone_id))
	return ""

func _milestone_hint(milestone_id: String) -> String:
	return {"basic_dishes_served":"Обслужить три базовых блюда","lab_assembled":"Собрать лабораторию","first_formula_obtained":"Получить первую формулу","first_clone_created":"Создать первого клона","first_masterclass_saved":"Сохранить первый мастер-класс","first_video_training_completed":"Завершить первое видеообучение","two_compatible_stations_seen":"Установить два совместимых стола","first_auto_served":"Выполнить первую автоподачу","first_staff_rest_completed":"Завершить отдых сотрудников","formula_improvement_relevant":"Получить формулу быстрее текущего клона"}.get(milestone_id, "Продолжить развитие кафе")

func _route_for_feature(feature_id: String) -> String:
	for definition in UiEntryCatalog.ENTRIES.values():
		if feature_id in definition.get("required_features", []) or feature_id in definition.get("any_features", []): return str(definition.id)
	return "office.development"

func _check(allowed: bool, reason_code: StringName, reason_args: Dictionary) -> Dictionary: return {"allowed":allowed,"reason_code":reason_code,"reason_args":reason_args.duplicate(true)}
func _ui_result(entry_id: String, feature_id: String, introduced: bool, unlocked: bool, enabled: bool, state: String, reason_code: StringName, reason_args: Dictionary) -> Dictionary: return {"entry_id":entry_id,"feature_id":feature_id,"introduced":introduced,"unlocked":unlocked,"visible":state != "hidden","enabled":enabled,"state":state,"reason_code":reason_code,"reason_args":reason_args.duplicate(true),"revision":revision()}
func _item_result(item_id: String, feature_id: String, visible: bool, enabled: bool, state: String, reason_code: StringName, reason_args: Dictionary) -> Dictionary: return {"entry_id":"item." + item_id,"item_id":item_id,"feature_id":feature_id,"introduced":visible,"unlocked":visible,"visible":visible,"enabled":enabled,"state":state,"reason_code":reason_code,"reason_args":reason_args.duplicate(true),"revision":revision()}

func _sync_from_progress_snapshot() -> void:
	if service == null or service.get("progress") == null or progression_director == null: return
	var progress = service.progress
	var raw: Variant = progress.get("feature_progress")
	if not raw is Dictionary or raw.is_empty(): return
	var epoch := str(progress.get("world_epoch")); var incoming_cafe := str(raw.get("cafe_id", "")); var incoming_revision := int(raw.get("revision", 0))
	var generation_changed := epoch != _world_epoch_seen or incoming_cafe != _cafe_id_seen
	if generation_changed or incoming_revision > _revision_seen:
		progression_director.restore(raw); _capture_sync_stamp()

func _capture_sync_stamp() -> void:
	if service == null or service.get("progress") == null or progression_director == null: return
	_world_epoch_seen = str(service.progress.get("world_epoch")); _cafe_id_seen = str(progression_director.cafe_id); _revision_seen = int(progression_director.revision)
