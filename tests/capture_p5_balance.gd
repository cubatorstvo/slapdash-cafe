extends SceneTree
## Render the actual paid traversal's current-format saves; pass their directory after --.
var game: Node

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Pass the directory containing p5_*.save from test_p5_balance.gd"); quit(1); return
	game = load("res://scenes/cafe.tscn").instantiate()
	root.add_child(game); current_scene = game
	await process_frame; game.set_physics_process(false)
	var output := "res://docs/progression/validation/p5_07"
	DirAccess.make_dir_recursive_absolute(output)
	for point in ["starter_dishes", "star1", "first_auto", "star2", "star5"]:
		if game.office.opened(): game.office.close()
		var file := FileAccess.open(args[0].path_join("p5_%s.save" % point), FileAccess.READ)
		if file == null or not game.service.load_data(file.get_var()):
			printerr("Cannot load paid checkpoint: ", point); quit(1); return
		file.close()
		game.hud.notice.text = ""
		if point in ["starter_dishes", "star5"]: game.office.open("star")
		else:
			var pacing := root.get_node("LearningPacing")
			pacing.cafe_id = ""; pacing._bind_cafe("capture-" + point, game.service.progress.feature_progress)
			pacing.cafe_id = str(game.service.progress.feature_progress.cafe_id)
		game.service.refresh_views(0.0)
		game.refresh_hud(1.0)
		load("res://scripts/cafe_ui_mode.gd").sync(game)
		for index in range(6): await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(output.path_join(point + ".png"))
		if error != OK: printerr("Screenshot save failed: ", error); quit(1); return
		print("CAPTURE ", point)
	game._shutdown_tree(game); game.free(); quit(0)
