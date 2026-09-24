extends RefCounted
## Single source of truth for progression visibility and temporary command availability.
const FeatureDefinition = preload("res://scripts/feature_definition.gd")

var service: Node
var cafe_facts: Dictionary = {}
var player_facts: Dictionary = {}
var _revision := 0

func setup(owner_service: Node) -> void:
	service = owner_service
	refresh_facts()

func reset() -> void:
	cafe_facts.clear()
	player_facts.clear()
	_revision += 1
	refresh_facts()

func revision() -> int:
	return _revision

func chapter() -> int:
	if service == null or service.get("progress") == null: return 0
	return maxi(0, int(service.progress.stars))

func _set_fact(id: String, value := true) -> bool:
	if not value or bool(cafe_facts.get(id, false)): return false
	cafe_facts[id] = true
	_revision += 1
	return true

func mark_fact(id: String) -> void:
	_set_fact(id)

func has_fact(id: String) -> bool:
	refresh_facts()
	return bool(cafe_facts.get(id, false))

func mark_player_fact(peer_id: int, id: String) -> void:
	var key := str(peer_id)
	var facts: Dictionary = player_facts.get(key, {}).duplicate(true)
	if bool(facts.get(id, false)): return
	facts[id] = true
	player_facts[key] = facts
	_revision += 1

func has_player_fact(peer_id: int, id: String) -> bool:
	return bool(player_facts.get(str(peer_id), {}).get(id, false))

func refresh_facts() -> void:
	_set_fact("new_game")
	if service == null or service.get("progress") == null: return
	var p = service.progress
	if int(service.get("guests_arrived")) > 0 or int(service.get("served")) > 0: _set_fact("first_guest_seen")
	if int(p.stars) >= 1: _set_fact("first_guest_seen"); _set_fact("first_star")
	if int(p.stars) >= 2: _set_fact("second_star")
	if int(p.stars) >= 3: _set_fact("third_star")
	if int(p.stars) >= 4: _set_fact("fourth_star")
	if int(p.stars) >= 5: _set_fact("fifth_star")
	if int(p.next_clone_id) > 1 or not p.free_workers.is_empty(): _set_fact("first_clone_created")
	if service.get("masterclasses") != null and not service.masterclasses.is_empty(): _set_fact("first_recording_saved")
	if bool(p.get("training_intro_mass_seen")): _set_fact("personal_lesson_accepted")
	if int(p.get("journey_auto_served")) > 0 or int(p.get("third_star_auto_served")) > 0: _set_fact("auto_feed_completed")

func export_state() -> Dictionary:
	refresh_facts()
	return {"cafe_facts":cafe_facts.duplicate(true),"player_facts":player_facts.duplicate(true)}

func import_state(data: Variant) -> void:
	cafe_facts.clear()
	player_facts.clear()
	if data is Dictionary:
		var saved_cafe: Variant = data.get("cafe_facts", {})
		var saved_players: Variant = data.get("player_facts", {})
		if saved_cafe is Dictionary:
			for key in saved_cafe:
				if bool(saved_cafe[key]): cafe_facts[str(key)] = true
		if saved_players is Dictionary:
			for peer in saved_players:
				if saved_players[peer] is Dictionary: player_facts[str(peer)] = saved_players[peer].duplicate(true)
	_revision += 1
	refresh_facts()

func _introduced(definition: Dictionary) -> bool:
	var events: Array = definition.get("introduction_events", [])
	if events.is_empty(): return true
	for event in events:
		if bool(cafe_facts.get(str(event), false)): return true
	return false

func _dependencies_unlocked(definition: Dictionary) -> Dictionary:
	for dependency in definition.get("dependencies", []):
		var dependency_state := access(str(dependency), {"ignore_context":true})
		if not bool(dependency_state.get("unlocked", false)):
			return {"ok":false,"id":str(dependency)}
	return {"ok":true,"id":""}

func access(feature_id: String, context: Dictionary = {}) -> Dictionary:
	refresh_facts()
	if feature_id.is_empty(): return _result(feature_id, true, true, true, true, "", {})
	var definition := FeatureDefinition.definition(feature_id)
	if definition.is_empty(): return _result(feature_id, false, false, false, false, "unknown_feature", {"feature":feature_id})
	var introduced := _introduced(definition)
	var dependencies := _dependencies_unlocked(definition) if introduced else {"ok":false,"id":""}
	var chapter_ready := chapter() >= int(definition.get("min_chapter", 0))
	var unlocked := introduced and bool(dependencies.ok) and chapter_ready
	var visible := introduced
	var enabled := unlocked
	var reason_code := ""
	var reason_args: Dictionary = {}
	if not introduced:
		reason_code = "not_introduced"
	elif not bool(dependencies.ok):
		reason_code = "dependency_locked"
		reason_args = {"feature":str(dependencies.id)}
	elif not chapter_ready:
		reason_code = "chapter_locked"
		reason_args = {"chapter":int(definition.get("min_chapter", 0))}
	if not bool(context.get("ignore_context", false)) and unlocked:
		var temporary := _temporary_block(context)
		if not temporary.is_empty():
			enabled = false
			reason_code = str(temporary.code)
			reason_args = temporary.get("args", {})
	return _result(feature_id, introduced, unlocked, visible, enabled, reason_code, reason_args)

func page_access(page: String, context: Dictionary = {}) -> Dictionary:
	return access(FeatureDefinition.feature_for_page(page), context)

func category_access(category: String, context: Dictionary = {}) -> Dictionary:
	return access(FeatureDefinition.feature_for_category(category), context)

func action_access(action: String, context: Dictionary = {}) -> Dictionary:
	return access(FeatureDefinition.feature_for_action(action), context)

func item_access(item_id: String, spec: Dictionary, context: Dictionary = {}) -> Dictionary:
	var feature_id := str(spec.get("feature", "shop_basic"))
	var merged := context.duplicate(true)
	if not merged.has("price"): merged.price = int(spec.get("price", 0))
	var result := access(feature_id, merged)
	result.item = item_id
	return result

func nearest_visible_page(page: String, context: Dictionary = {}) -> String:
	var candidate := page
	var visited: Dictionary = {}
	while not candidate.is_empty() and not visited.has(candidate):
		visited[candidate] = true
		if bool(page_access(candidate, context).visible): return candidate
		candidate = str(FeatureDefinition.PAGE_PARENTS.get(candidate, "overview"))
	return "overview"

func first_visible_category(preferred := "equipment", context: Dictionary = {}) -> String:
	var ordered := [preferred, "equipment", "tables", "rooms", "lab", "lounge", "decor"]
	var seen: Dictionary = {}
	for category in ordered:
		var key := str(category)
		if seen.has(key): continue
		seen[key] = true
		if bool(category_access(key, context).visible): return key
	return "equipment"

func reason_text(result: Dictionary) -> String:
	var code := str(result.get("reason_code", ""))
	var args: Dictionary = result.get("reason_args", {})
	match code:
		"": return ""
		"not_introduced": return "Эта возможность ещё не введена."
		"unknown_feature": return "Неизвестная игровая возможность."
		"dependency_locked": return "Сначала освой предыдущую возможность."
		"chapter_locked": return "Откроется позже по развитию кафе."
		"host_only": return "Покупку и общие изменения подтверждает хозяин кафе."
		"insufficient_funds": return "Не хватает денег."
		"pending_delivery": return "Этот товар уже едет."
		"already_owned": return "Уже установлено."
		"busy": return str(args.get("text", "Сейчас действие занято другим процессом."))
		"shift": return str(args.get("text", "Сейчас действие недоступно в этой части смены."))
		"no_clone": return "Сначала создай клона."
		_: return str(args.get("text", "Сейчас действие недоступно."))

func _temporary_block(context: Dictionary) -> Dictionary:
	if bool(context.get("host_required", false)) and not bool(context.get("is_host", true)):
		return {"code":"host_only","args":{}}
	if bool(context.get("already_owned", false)):
		return {"code":"already_owned","args":{}}
	if bool(context.get("pending_delivery", false)):
		return {"code":"pending_delivery","args":{}}
	if bool(context.get("busy", false)):
		return {"code":"busy","args":{"text":str(context.get("busy_reason", "Сейчас действие занято другим процессом."))}}
	if bool(context.get("requires_clone", false)) and not has_fact("first_clone_created"):
		return {"code":"no_clone","args":{}}
	var price := int(context.get("price", 0))
	if price > 0 and service != null and service.get("progress") != null and int(service.progress.cash) < price:
		return {"code":"insufficient_funds","args":{"price":price,"cash":int(service.progress.cash)}}
	return {}

func _result(feature_id: String, introduced: bool, unlocked: bool, visible: bool, enabled: bool, reason_code: String, reason_args: Dictionary) -> Dictionary:
	return {"feature_id":feature_id,"introduced":introduced,"unlocked":unlocked,"visible":visible,"enabled":enabled,"reason_code":reason_code,"reason_args":reason_args.duplicate(true)}
