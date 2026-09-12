extends Node
## Small semantic events; no input replay or per-frame disk writes.
var file: FileAccess
var folder := ""
var started := 0
var clock := 0.0
var activity := ""
var activity_started := 0
var totals := {}
var counts := {}
var version := "shop-feeding-1"
var game: Node
var summary_clock := 0.0
var closed := false

func begin(owner_game: Node) -> void:
	game = owner_game
	started = Time.get_ticks_msec()
	activity_started = started
	var stamp := Time.get_datetime_string_from_system().replace(":","-") + "-" + str(OS.get_process_id())
	folder = "user://playtests/" + stamp
	DirAccess.make_dir_recursive_absolute(folder)
	file = FileAccess.open(folder + "/events.jsonl",FileAccess.WRITE)
	event("session_start",{"build":version,"engine":Engine.get_version_info().string})

func event(kind: String, data := {}) -> void:
	if file == null or closed: return
	counts[kind] = int(counts.get(kind,0))+1
	file.store_line(JSON.stringify({"seconds":(Time.get_ticks_msec()-started)/1000.0,"event":kind,"data":data}))

func change_activity(next: String) -> void:
	if next == activity: return
	var now := Time.get_ticks_msec()
	if not activity.is_empty():
		var seconds := (now-activity_started)/1000.0
		totals[activity] = float(totals.get(activity,0))+seconds
		event("activity_end",{"activity":activity,"seconds":seconds})
	activity = next
	activity_started = now
	event("activity_start",{"activity":next})

func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game.service): return
	if delta > 0.12: event("long_frame",{"ms":roundi(delta*1000)})
	clock += delta
	if clock < 1: return
	clock = 0
	var station = game.local_station()
	var next := "moving" if game.player.velocity.length() > 0.1 else "observing_or_idle"
	if game.session_paused: next = "pause"
	elif game.office.opened(): next = "computer"
	elif game.cookbook.opened: next = "cookbook"
	elif station != null: next = "teaching" if station.training.purpose == "lesson" else "personal_order"
	elif is_instance_valid(game.shop) and game.shop.carried(game.session.local_id()) >= 0: next = "delivery"
	change_activity(next)
	summary_clock += 1
	if summary_clock >= 15: summary_clock = 0; save_summary()

func save_summary() -> void:
	if file == null: return
	file.flush()
	var current := totals.duplicate()
	current[activity] = float(current.get(activity,0)) + (Time.get_ticks_msec()-activity_started)/1000.0
	var out := FileAccess.open(folder + "/summary.json",FileAccess.WRITE)
	if out: out.store_string(JSON.stringify({"build":version,"duration_seconds":(Time.get_ticks_msec()-started)/1000.0,"activities_seconds":current,"events":counts},"\t")); out.close()

func shutdown() -> void:
	if closed: return
	event("session_end")
	save_summary()
	closed = true
	if file: file.close(); file = null
func _exit_tree() -> void: shutdown()
