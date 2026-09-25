extends Node3D
## One-time world interaction that opens a brand-new cafe before the first guest.
const INTRO_DISH := "sausage"
const INTERACTION_RADIUS := 4.5
const INTRO_ORDER_DELAY := 0.35
const HOLD_BACK_ORDERS := 3600.0
var retry_clock := 0.0
var migrated := false

func _ready() -> void:
	set_process_unhandled_input(true)

func _game() -> Node3D:
	var node: Node = self
	while node != null:
		if node.has_method("save_cafe") and node.has_method("new_cafe"): return node as Node3D
		node = node.get_parent()
	return null

func _interaction_point() -> Node3D:
	return get_node_or_null("Interaction") as Node3D

func _focused(game: Node3D) -> bool:
	var point := _interaction_point()
	if point == null or not is_instance_valid(game.camera) or not is_instance_valid(game.player): return false
	var offset: Vector3 = point.global_position - game.camera.global_position
	if offset.length() > INTERACTION_RADIUS or offset.length() < 0.01: return false
	var center: Vector2 = game.camera.get_viewport().get_visible_rect().size * 0.5
	return game.camera.project_ray_normal(center).dot(offset.normalized()) >= 0.78

func _ensure_intro_equipment(game: Node3D) -> void:
	var p = game.service.progress
	if p.cafe_inaugurated or p.day != 1 or game.service.served != 0 or p.manual_served != 0: return
	var station: Node3D = game.service.by_id(1)
	if station == null or not station.manual_station: return
	var changed := false
	for item in ["sauce", "plates", "rag"]:
		if item not in station.equipment:
			station.equipment.append(item)
			changed = true
	if changed:
		station.apply_equipment()
		station.reset_model()

func _migrate_legacy_if_needed(game: Node3D) -> void:
	if migrated: return
	migrated = true
	var p = game.service.progress
	if p.cafe_inaugurated: return
	var pristine_first_morning: bool = p.day <= 1 and game.service.served <= 0 and game.service.guests_arrived <= 0 and not game.service.open_for_business and p.shift == "morning"
	if pristine_first_morning: return
	p.cafe_inaugurated = true
	p.inauguration_first_service_pending = false
	p.revision += 1
	if not game.session.is_guest(): game.save_cafe()

func _intro_guest_present(game: Node3D) -> bool:
	for customer in game.service.customers:
		if str(customer.get("state", "")) != "leaving": return true
	return not game.service.customers.is_empty()

func _spawn_intro_guest(game: Node3D) -> bool:
	_ensure_intro_equipment(game)
	return game.service.spawn_customer(INTRO_DISH, false, true)

func _finish_intro_gate(game: Node3D) -> void:
	var p = game.service.progress
	if not p.inauguration_first_service_pending: return
	p.inauguration_first_service_pending = false
	game.service.spawn_clock = p.arrival_interval()
	game.service.chef_order_clock = p.chef_order_delay(game.service.rng)
	p.revision += 1
	game.save_cafe()

func _advance_host_intro(game: Node3D, delta: float) -> void:
	var p = game.service.progress
	if not p.inauguration_first_service_pending: return
	game.service.spawn_clock = maxf(game.service.spawn_clock, HOLD_BACK_ORDERS)
	game.service.chef_order_clock = maxf(game.service.chef_order_clock, HOLD_BACK_ORDERS)
	if p.starter_reward or p.manual_served > 0:
		_finish_intro_gate(game)
		return
	if _intro_guest_present(game):
		retry_clock = INTRO_ORDER_DELAY
		return
	retry_clock = maxf(0.0, retry_clock - delta)
	if retry_clock > 0.0: return
	if _spawn_intro_guest(game): retry_clock = INTRO_ORDER_DELAY
	else: retry_clock = 1.0

func _process(delta: float) -> void:
	var game := _game()
	if game == null or not is_instance_valid(game.service) or not is_instance_valid(game.session): return
	_migrate_legacy_if_needed(game)
	var p = game.service.progress
	visible = not p.cafe_inaugurated
	if visible: _ensure_intro_equipment(game)
	if not game.session.is_guest(): _advance_host_intro(game, delta)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo or event.physical_keycode != KEY_E: return
	var game := _game()
	if game == null or game.input_blocked() or not _focused(game): return
	get_viewport().set_input_as_handled()
	if game.session.is_guest(): _request_inauguration.rpc_id(1)
	else: _host_inaugurate(1)

@rpc("any_peer", "call_remote", "reliable", 0)
func _request_inauguration() -> void:
	var game := _game()
	if game == null or game.session.is_guest(): return
	_host_inaugurate(multiplayer.get_remote_sender_id())

func _host_inaugurate(peer: int) -> void:
	var game := _game()
	if game == null or game.session.is_guest(): return
	var p = game.service.progress
	if p.cafe_inaugurated: return
	if p.busy() or p.shift not in ["morning", "open"]: return
	if not game.session.near_peer(peer, self, INTERACTION_RADIUS):
		game.session.message_to(peer, "Подойди к ленточке у входа.")
		return
	_ensure_intro_equipment(game)
	p.cafe_inaugurated = true
	p.inauguration_first_service_pending = true
	p.shift = "open"
	p.shift_elapsed = 0.0
	game.service.open_for_business = true
	game.service.spawn_clock = HOLD_BACK_ORDERS
	game.service.chef_order_clock = HOLD_BACK_ORDERS
	p.revision += 1
	visible = false
	game.service.progression_director.observe("cafe_opened", {"day":p.day})
	game.service._refresh_progression()
	_spawn_intro_guest(game)
	retry_clock = INTRO_ORDER_DELAY
	game.service.trace("cafe_inaugurated", {"day": p.day, "peer": peer})
	game.service.announce("Ленточка перерезана! Первый гость уже идёт — к стойке №1.")
	if is_instance_valid(game.feedback): game.feedback.play_ui("ready")
	game.save_cafe()
