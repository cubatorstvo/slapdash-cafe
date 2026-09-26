extends SceneTree
const Core = preload("res://scripts/progression/learning_pacing_core.gd")
const Runtime = preload("res://scripts/progression/learning_pacing_runtime.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: ",message)

func snapshot(features: Array, milestones: Array) -> Dictionary:
	var facts := {}
	for id in milestones: facts[id] = {"day":1}
	return {"cafe_id":"p5-balance-coop","unlocked_features":features,"milestones":facts}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var before := snapshot(["clone_lab","production_tables"],["first_clone_created"])
	var lesson := snapshot(["clone_lab","production_tables"],["first_clone_created","first_live_lesson_accepted"])
	var working := snapshot(["clone_lab","production_tables"],["first_clone_created","first_live_lesson_accepted","first_auto_served"])
	var shared: Dictionary = working.duplicate(true)
	check(not Core.applicable(Core.explanation_by_id("p5.personal_learning"),Core.snapshot_sets(before)), "opening tables cannot announce an accepted lesson")
	check(Core.applicable(Core.explanation_by_id("p5.personal_learning"),Core.snapshot_sets(lesson)), "actual accepted lesson introduces work")
	var a = Runtime.new(); root.add_child(a); a.set_process(false); a.player_key = "balance-a"
	var b = Runtime.new(); root.add_child(b); b.set_process(false); b.player_key = "balance-b"
	a._bind_cafe("p5-balance-coop",before); b._bind_cafe("p5-balance-coop",before)
	a.current = Core.explanation_by_id("p5.clone_core")
	a._enqueue(Core.explanation_by_id("p5.personal_learning"))
	a._collect(working); b._collect(working)
	check(a.current.is_empty(), "a blocked old explanation is retired after facts advance")
	check(a.pending.size() == 1 and str(a.pending[0].id) == "p5.first_automation", "only the relevant explanation remains after delayed presentation")
	a.current = a.pending.pop_front(); a.queued.erase(str(a.current.id)); a.panel.show()
	var key := InputEventKey.new(); key.pressed = true; key.physical_keycode = KEY_F1
	a._unhandled_input(key)
	check(a.seen.has("p5.first_automation") and not b.seen.has("p5.first_automation"), "F1 is personal, another player keeps their explanation")
	check(working == shared, "local acknowledgement never mutates shared unlocks")
	check(not Core.can_present({"ui_mode":"world","holding_item":true}) and Core.can_present({"ui_mode":"world"}), "one busy player cannot gate a free player's presentation")
	a._bind_cafe("another-cafe",snapshot([],[])); a._bind_cafe("p5-balance-coop",working)
	check(a.seen.has("p5.first_automation") and a.pending.is_empty(), "personal seen survives return to this cafe")
	var game = load("res://scenes/cafe.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_physics_process(false); a.game = game
	game.service.progress.phase = "preparing"
	check(bool(a._state().inspection), "star inspection blocks explanations even before first customer")
	game.service.progress.phase = "none"
	game.service.live_training.active = true; game.service.live_training.teacher_peer = game.session.local_id()
	check(bool(a._state().teaching), "teacher waiting for the live student is already busy")
	game.service.live_training.active = false
	game._shutdown_tree(game); game.free(); a.free(); b.free()
	print("PASS: P5.07 explanation relevance and cooperative separation" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
