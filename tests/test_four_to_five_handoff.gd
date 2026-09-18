extends SceneTree
const Progression = preload("res://scripts/cafe_progression.gd")
const SolyankaModel = preload("res://scripts/solyanka_cooking_model.gd")
const Journey = preload("res://scripts/cafe_journey.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	run.call_deferred()

func install_last_delivery(game) -> void:
	var parcel: Dictionary = game.service.progress.deliveries.back()
	parcel.remaining = 0.0
	parcel.owner = 1
	game.player.global_position = game.shop.installation_position(parcel)
	check(game.shop.action(1, {"action":"install_parcel", "id":parcel.id}).is_empty(), "Delivery installs successfully")

func run() -> void:
	print("1/5: winning Three Waves enters the 4→5 chapter")
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.new_cafe()
	var service = game.service
	var p = service.progress
	p.stars = 3
	p.phase = "service"
	p.cash = 3000
	p.return_open = false
	p.fifth_star_auto_served = 99
	p.fifth_star_solyanka_served = 99
	service.finish_banquet(true)
	check(p.stars == 4, "Fourth-star inspection grants star four")
	check(p.fifth_star_auto_served == 0 and p.fifth_star_solyanka_served == 0, "Fourth star resets fifth-star preparation counters")
	check("solyanka" in p.available_dishes(), "Solyanka demand unlocks immediately at four stars")

	print("2/5: unlocked sector builds and equips the three-role kitchen")
	check(service.purchase("orchestration_expansion", "").is_empty(), "Orchestration sector can be bought after the fourth star")
	check(service.purchase("solyanka_kitchen", "", 6).is_empty(), "Sixth slot accepts the solyanka kitchen")
	install_last_delivery(game)
	var station = service.by_id(6)
	check(station != null and station.type_id == "solyanka_kitchen" and station.role_count() == 3, "Installed sixth station is a real three-role kitchen")
	for kit in ["fire_kit", "stir_kit", "salt_kit"]:
		check(service.purchase("equipment", kit, 6).is_empty(), "Can order " + kit)
		install_last_delivery(game)
	station = service.by_id(6)
	station.staffed = -1
	check(["fire_kit", "stir_kit", "salt_kit"].all(func(kit): return kit in station.equipment), "All three role kits are installed")

	print("3/5: accepted B+ record satisfies the recipe gate")
	var finished := SolyankaModel.new()
	finished.equipment = ["fire_kit", "stir_kit", "salt_kit"]
	finished.fire_started = true
	finished.stir_progress = 1.0
	finished.salt_amount = 1.0
	for item in finished.ITEMS.slice(0, finished.MIN_CONTENTS): finished.dumped[item] = true
	var tracks: Array = []
	for role in range(3): tracks.append({"group":1, "frames":[finished.zone_snapshot(role)]})
	station.recipes.solyanka = {"tracks":tracks, "duration":1.0/60.0, "quality":finished.quality()}
	var initial_requirements: Array = p.star_requirements(service.stations, service.served)
	check(initial_requirements[0].done and initial_requirements[1].done, "Staffed kitchen and B+ recording satisfy the first two preparation requirements")
	check(not initial_requirements[2].done and not initial_requirements[3].done, "Real service counters still have to be earned")

	print("4/5: real automatic service earns the 6 / 16 counters")
	for index in range(Progression.FIFTH_STAR_AUTO_SERVED):
		check(service.spawn_customer("solyanka"), "Automatic solyanka customer %d can be assigned" % (index + 1))
		var customer: Dictionary = service.customers.back()
		customer.path.clear()
		service.advance(1.0/60.0)
		service.advance(0.10)
		service.advance(1.30)
		if index == Progression.FIFTH_STAR_SOLYANKA_SERVED - 1:
			check(p.fifth_star_solyanka_served == Progression.FIFTH_STAR_SOLYANKA_SERVED, "Six real solyanka servings satisfy the specialty counter")
	check(p.fifth_star_auto_served == Progression.FIFTH_STAR_AUTO_SERVED, "Sixteen real automatic servings satisfy the orchestration counter")
	check(p.fifth_star_solyanka_served == Progression.FIFTH_STAR_AUTO_SERVED, "Solyanka automatic servings count toward both applicable counters")

	print("5/5: chapter hands off cleanly to the final fifth-star step")
	var requirements: Array = p.star_requirements(service.stations, service.served)
	check(requirements.size() == 4 and requirements.all(func(requirement): return bool(requirement.done)), "All current 4→5 preparation requirements are complete")
	var goal: Dictionary = Journey.current(p, service.stations, service.served, true)
	check(goal.key == "fifth_star", "Journey reaches the explicit final-inspection launch")
	check(p.can_attempt(service.stations, service.served), "Completed orchestration preparation unlocks the fifth-star inspection")
	game._shutdown_tree(game)
	game.free()
	print("PASS: fourth-star to fifth-star preparation handoff" if failures == 0 else "FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
