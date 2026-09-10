extends RefCounted
## Per-station rehearsal. Inactive zones replay baked state, independent of live time/physics.
var station: Node3D
var phase := "idle"
var dish := "wine"
var lead := 0
var participants: Array = []
var tracks: Array = []
var pending_tracks: Array = []
var live_roles: Array = []
var inputs := {}
var events := {}
var tick := 0
var revision := 0
var group_serial := 0
var info := ""

func setup(owner_station: Node3D) -> void:
	station = owner_station
	participants.resize(station.role_count())
	participants.fill(0)

func active() -> bool: return phase != "idle"
func role_for(peer: int) -> int: return participants.find(peer) if active() and peer > 0 else -1

func open(recipe: String, peer: int) -> void:
	dish = recipe
	lead = peer
	phase = "ready"
	tracks = station.drafts.get(dish, station.recipes.get(dish, {}).get("tracks", [])).duplicate(true)
	while tracks.size() < station.role_count(): tracks.append({})
	participants.fill(0)
	station.model.reset(dish) if station.type_id == "counter" else station.model.reset()
	station.state = "training"
	station.ensure_taster()
	info = "Выбери роль и напарника. Без напарника — последовательная запись."
	revision += 1

func start_pass(assignments: Array) -> bool:
	if phase not in ["ready", "review"] or assignments.size() != station.role_count() or assignments.count(lead) != 1: return false
	var used: Array = []
	for peer in assignments:
		if peer < 0 or (peer > 0 and peer in used): return false
		if peer > 0: used.append(peer)
	participants = assignments.duplicate()
	live_roles.clear()
	for role in range(participants.size()):
		if participants[role] > 0: live_roles.append(role)
	pending_tracks = tracks.duplicate(true)
	# Cross-zone cooperation is one take. Replacing a member opens its linked zones for a new take.
	var invalid_groups: Array = []
	for role in live_roles:
		if not tracks[role].is_empty(): invalid_groups.append(tracks[role].group)
	for role in range(tracks.size()):
		if not tracks[role].is_empty() and tracks[role].group in invalid_groups: pending_tracks[role] = {}
	group_serial = 1
	for track in tracks:
		if not track.is_empty(): group_serial = maxi(group_serial, int(track.group) + 1)
	for role in live_roles: pending_tracks[role] = {"group": group_serial, "frames": []}
	station.model.reset(dish) if station.type_id == "counter" else station.model.reset()
	if station.type_id == "kitchen": station.model.live_roles = live_roles.duplicate()
	phase = "recording"
	tick = 0
	inputs.clear()
	events.clear()
	station.reset_taster()
	revision += 1
	info = "Красные зоны принадлежат другим дублям. Enter — закончить проход."
	return true

func queue_event(role: int, event: Dictionary) -> void:
	if role not in live_roles or phase != "recording": return
	if not events.has(role): events[role] = []
	if events[role].size() < 16: events[role].append(event)

func advance(delta: float) -> void:
	if phase != "recording": return
	var commands: Array = []
	for role in range(station.role_count()):
		var command: Dictionary = inputs.get(role, {}).duplicate(true) if role in live_roles else {}
		if events.has(role) and not events[role].is_empty(): command.merge(events[role].pop_front(), true)
		commands.append(command)
	if station.type_id == "counter":
		station.apply_single(commands[0], delta)
	else:
		_restore_inactive(tick)
		station.model.step(commands, delta)
		_restore_inactive(tick)
	for role in live_roles:
		pending_tracks[role].frames.append(station.model.snapshot() if station.type_id == "counter" else station.model.zone_snapshot(role))
	tick += 1

func _restore_inactive(at_tick: int) -> void:
	for role in range(station.role_count()):
		if role in live_roles: continue
		var track: Dictionary = pending_tracks[role]
		if not track.is_empty() and not track.frames.is_empty():
			station.model.restore_zone(role, track.frames[mini(at_tick, track.frames.size() - 1)])
		else:
			var empty = station.TeamModel.new()
			station.model.restore_zone(role, empty.zone_snapshot(role))

func finish_pass() -> void:
	if phase != "recording" or tick == 0: return
	for role in live_roles:
		station.model.put_down() if station.type_id == "counter" else station.model.drop(role)
	for role in live_roles:
		pending_tracks[role].frames.append(station.model.snapshot() if station.type_id == "counter" else station.model.zone_snapshot(role))
	phase = "review"
	info = "Проход готов. Сохрани роли или повтори попытку; рабочий рецепт пока прежний."

func keep_pass() -> void:
	if phase != "review": return
	tracks = pending_tracks.duplicate(true)
	station.drafts[dish] = tracks.duplicate(true)
	phase = "ready"
	participants.fill(0)
	revision += 1
	station.show_tracks(tracks, duration_ticks(tracks) - 1)
	info = "Роли сохранены в черновик. Можно записать другую роль или принять всё блюдо."

func can_accept() -> bool:
	if phase != "ready" or tracks.is_empty(): return false
	for track in tracks:
		if track.is_empty() or track.frames.is_empty(): return false
	station.show_tracks(tracks, duration_ticks(tracks) - 1)
	return station.model.quality().present

func accept() -> bool:
	if not can_accept():
		info = "Запиши все роли и положи еду на подачу. Любое качество D–S можно сохранить."
		return false
	station.recipes[dish] = {"tracks": tracks.duplicate(true), "duration": duration_ticks(tracks) / 60.0, "quality": station.model.quality()}
	station.drafts.erase(dish)
	station.finish_taster(true)
	close()
	return true

func close() -> void:
	phase = "idle"
	participants.fill(0)
	live_roles.clear()
	inputs.clear()
	events.clear()
	lead = 0
	revision += 1
	station.state = "idle"
	station.finish_taster(false)
	station.reset_model()

static func duration_ticks(value: Array) -> int:
	var longest := 0
	for track in value:
		if not track.is_empty(): longest = maxi(longest, track.frames.size())
	return longest

func summary() -> Dictionary:
	var lengths: Array = []
	var groups: Array = []
	for track in tracks:
		lengths.append(track.get("frames", []).size())
		groups.append(track.get("group", -1))
	return {"phase": phase, "dish": dish, "lead": lead, "participants": participants, "live_roles": live_roles, "tick": tick, "revision": revision, "lengths": lengths, "groups": groups, "info": info}

func apply_summary(data: Dictionary) -> void:
	for key in ["phase", "dish", "lead", "participants", "live_roles", "tick", "revision", "info"]: set(key, data[key])
