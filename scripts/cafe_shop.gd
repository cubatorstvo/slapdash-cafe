extends "res://scripts/cafe_shop_core.gd"

const STARTER_EQUIPMENT := ["sauce", "plates", "pan", "jug", "cup"]

func _feature_access():
	return game.service.feature_access if game != null and is_instance_valid(game.service) else null

func _request_is_host() -> bool:
	return multiplayer.get_remote_sender_id() <= 1

func target(camera: Camera3D, peer: int) -> Dictionary:
	if game != null and is_instance_valid(game.get("laboratory")):
		var lab_target: Dictionary = game.laboratory.target(camera, peer)
		if not lab_target.is_empty(): return lab_target
	return super(camera, peer)

func _access_error(state: Dictionary) -> String:
	var access = _feature_access()
	if access == null or bool(state.get("enabled", state.get("allowed", false))): return ""
	var reason: String = str(access.reason_text(state))
	return reason if not reason.is_empty() else "Эта покупка пока недоступна."

func reward_sauce() -> void:
	var p = game.service.progress
	if p.starter_reward: return
	p.starter_reward = true
	p.revision += 1

func type_available(type_id: String) -> bool:
	if not super(type_id): return false
	var access = _feature_access()
	if access == null or not ITEMS.has(type_id): return true
	return bool(access.item_access(type_id, ITEMS[type_id]).get("visible", false))

func order(item: String, station_id: int) -> String:
	if not ITEMS.has(item): return super(item, station_id)
	var access = _feature_access()
	if access != null:
		var state: Dictionary = access.item_access(item, ITEMS[item], {"host_required":true,"is_host":_request_is_host(),"pending_delivery":pending(item, station_id),"price":int(ITEMS[item].get("price", 0))})
		var error: String = _access_error(state)
		if not error.is_empty(): return error
	var result: String = super(item, station_id)
	if result.is_empty() and game.service.has_method("_refresh_progression"): game.service._refresh_progression()
	return result

func _install_parcel(parcel: Dictionary, by_workers := false) -> String:
	var station_id := int(parcel.get("station", 0))
	var items: Array = parcel.get("items", [parcel.get("item", "")]).duplicate()
	var result: String = super(parcel, by_workers)
	if not result.is_empty(): return result
	if station_id == 1:
		for raw_item in items:
			var item := str(raw_item)
			if item in STARTER_EQUIPMENT:
				game.service.progression_director.observe("starter_equipment_installed", {"item":item,"station_id":station_id})
				break
	game.service._refresh_progression()
	return ""

func order_bundle(items: Array, station_id: int) -> String:
	var access = _feature_access()
	if access != null:
		var total := 0
		for raw in items:
			var item := str(raw)
			if not ITEMS.has(item): return "Проверь состав заказа."
			var state: Dictionary = access.item_access(item, ITEMS[item], {"host_required":true,"is_host":_request_is_host(),"pending_delivery":pending(item, station_id)})
			var item_error: String = _access_error(state)
			if not item_error.is_empty(): return item_error
			total += int(ITEMS[item].get("price", 0))
		var command: Dictionary = access.check_action("buy_bundle", {"host_required":true,"is_host":_request_is_host(),"price":total})
		var command_error: String = _access_error(command)
		if not command_error.is_empty(): return command_error
	var result: String = super(items, station_id)
	if result.is_empty() and game.service.has_method("_refresh_progression"): game.service._refresh_progression()
	return result

func order_station_batch(type_id: String, station_ids: Array, equipment: Array, group_id: String) -> String:
	var access = _feature_access()
	if access != null:
		if not ITEMS.has(type_id): return "Этот тип кухни ещё не открыт."
		var item_checks: Array = [{"item_id":type_id,"spec":ITEMS[type_id]}]
		var unit_price := int(ITEMS[type_id].get("price", 0))
		for raw in equipment:
			var item := str(raw)
			if not ITEMS.has(item): return "Проверь состав заказа."
			item_checks.append({"item_id":item,"spec":ITEMS[item]})
			unit_price += int(ITEMS[item].get("price", 0))
		var unique_ids: Array = []
		for raw_id in station_ids:
			var station_id := int(raw_id)
			if station_id not in unique_ids: unique_ids.append(station_id)
		var state: Dictionary = access.check_action("buy_station_batch", {"host_required":true,"is_host":_request_is_host(),"items":item_checks,"station_ids":unique_ids,"price":unit_price*unique_ids.size()})
		var error: String = _access_error(state)
		if not error.is_empty(): return error
	var result: String = super(type_id, station_ids, equipment, group_id)
	if result.is_empty() and game.service.has_method("_refresh_progression"): game.service._refresh_progression()
	return result
