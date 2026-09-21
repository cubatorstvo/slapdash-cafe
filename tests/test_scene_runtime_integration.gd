extends SceneTree

const CHECKLIST := "res://docs/SCENE_MIGRATION_CHECKLIST.md"
const EXPECTED_SCENES := 162
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	run.call_deferred()

func checklist_scenes() -> Array[String]:
	var file := FileAccess.open(CHECKLIST, FileAccess.READ)
	check(file != null, "Scene migration checklist opens")
	if file == null: return []
	var text := file.get_as_text()
	var regex := RegEx.new()
	regex.compile("`(scenes/[^`]+\\.tscn)`")
	var result: Array[String] = []
	for match in regex.search_all(text):
		var path := "res://" + match.get_string(1)
		if path not in result: result.append(path)
	return result

func collect_files(path: String, extensions: Array[String], out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty(): break
		if name.begins_with("."): continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			collect_files(full, extensions, out)
		else:
			for extension in extensions:
				if name.ends_with(extension):
					out.append(full)
					break
	dir.list_dir_end()

func source_blob() -> String:
	var files: Array[String] = []
	collect_files("res://scripts", [".gd"], files)
	collect_files("res://scenes", [".tscn"], files)
	var blob := ""
	for path in files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null: blob += file.get_as_text() + "\n"
	return blob

func production_script_blob() -> String:
	var files: Array[String] = []
	collect_files("res://scripts", [".gd"], files)
	var blob := ""
	for path in files:
		if path.begins_with("res://scripts/debug/"): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null: blob += file.get_as_text() + "\n"
	return blob

func check_office_shell(game: Node, page: String, expected_name: String) -> void:
	game.office.tab = page
	game.office.rebuild()
	check(game.office.content_root.get_child_count() > 0, "Office page %s mounts an authored shell" % page)
	if game.office.content_root.get_child_count() > 0:
		check(game.office.content_root.get_child(0).name == expected_name, "Office page %s uses %s" % [page, expected_name])

func run() -> void:
	var scene_paths := checklist_scenes()
	check(scene_paths.size() == EXPECTED_SCENES, "Checklist contains exactly %d unique authored scenes" % EXPECTED_SCENES)
	var references := source_blob()
	for path in scene_paths:
		check(ResourceLoader.exists(path), "Authored scene exists: " + path)
		var packed := load(path) as PackedScene
		check(packed != null, "Authored scene loads: " + path)
		if packed != null:
			var instance := packed.instantiate()
			check(instance != null, "Authored scene instantiates: " + path)
			if instance != null: instance.free()
		check(path in references, "Authored scene has a runtime scene/script reference: " + path)

	var production := production_script_blob()
	for constructor in ["MeshInstance3D.new()", "StaticBody3D.new()", "AnimatableBody3D.new()", "CollisionShape3D.new()", "OmniLight3D.new()", "DirectionalLight3D.new()"]:
		check(constructor not in production, "Production scripts do not directly construct persistent 3D node type: " + constructor)
	for obsolete in ["func _build_pan()", "func _build_potato()", "func _build_sausage()", "func _build_countertop_structure(", "func _build_storage_and_tray()"]:
		check(obsolete not in production, "Obsolete procedural builder removed: " + obsolete)

	var game := preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	check(game.hud.name == "CafeHUD", "HUD runtime root is cafe_hud.tscn")
	check(game.menu.name == "MainPauseMenu", "Station/network menu runtime root is main_pause_menu.tscn")
	check(game.office.name == "CafeOffice", "Office runtime root is cafe_office.tscn")
	check(game.cookbook.physical.pages.size() == 2, "Physical cookbook owns two authored cookbook_ui pages")
	check_office_shell(game, "overview", "DevelopmentPanels")
	check_office_shell(game, "groups", "TrainingCourseEditor")
	check_office_shell(game, "stations", "ShopPanels")
	check_office_shell(game, "stats", "StatisticsPanels")
	check_office_shell(game, "laboratory", "LaboratoryPanels")
	check_office_shell(game, "lounge", "StaffLoungePanels")
	game._shutdown_tree(game)
	game.free()
	print("PASS: all %d authored scenes are loadable and runtime-integrated" % EXPECTED_SCENES if failures == 0 else "FAILED: %d scene-runtime checks" % failures)
	quit(1 if failures > 0 else 0)
