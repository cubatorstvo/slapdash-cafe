extends SceneTree
const Orders = preload("res://scripts/chef_orders.gd")
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failed = true; printerr("FAIL: ",text)
func run() -> void:
	var game = preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game); await process_frame
	game.set_physics_process(false)
	for dish in ["wine","potato","sausage"]:
		check(Orders.special_request(Orders.standard(dish)).is_empty(),"Standard recipe has no wish")
	var wish := Orders.standard("wine"); wish.min_ml=80; wish.max_ml=120
	game.hud.show_chef_request(wish)
	check(game.hud.recipe_panel.visible and game.hud.recipe_panel_text().contains("80–120 мл"),"Only requested volume on slip")
	check(not game.hud.recipe_panel_text().contains("Бережливость"),"Standard criteria stay in book")
	var chef = game.service.by_id(1)
	chef.customer_order=wish
	game.service.spawn_customer("wine",false,1)
	chef.customer_order=wish
	game.service.request_manual(chef,"wine",1)
	game.bind_training(); game.menu.close(); game.refresh_hud()
	var before: String=game.hud.recipe_panel_text()
	chef.model.filled=97
	game.refresh_hud()
	check(game.hud.recipe_panel_text()==before,"Slip does not display progress")
	chef.training.close(); game.bind_training()
	var station=game.service.add_station("counter",1)
	station.state="cooking"; station.order_dish="wine"
	game.player.global_position=station.to_global(Vector3(0,0.02,1.8))
	game.player.rotation.y=station.global_rotation.y
	game.camera.rotation.x=-0.12
	game.refresh_hud()
	check(not game.hud.recipe_panel.visible,"Watching a clone does not expose recipe")
	station.state="idle"
	game.service.request_training(station,"wine",1)
	station.training.start_pass([1]); game.bind_training(); game.menu.close(); game.refresh_hud()
	check(not game.hud.recipe_panel.visible,"Teaching requires cookbook too")
	game._shutdown_tree(game); game.free()
	print("PASS: cookbook-only recipes and chef deviations" if not failed else "FAILED")
	quit(1 if failed else 0)
