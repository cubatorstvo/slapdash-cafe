extends Node3D
const Props = preload("res://scripts/props.gd")
const P = preload("res://scripts/cafe_progression.gd")
var game: Node3D
var board: Node3D
var decor := {}
var slots: Array = []
var ribbon: Node3D
var star_label: Label3D

func build(root_game: Node3D) -> void:
	game = root_game
	board = Node3D.new()
	add_child(board)
	board.position = Vector3(-1.8, 0, 6.8)
	Props.solid_box(board, Vector3(1.6, 1.6, 0.12), Vector3(0, 1.2, 0), Color("b5875c"))
	Props.box(board, Vector3(1.42, 1.42, 0.03), Vector3(0, 1.2, 0.08), Color("213b3c"))
	var title := Props.text(board, "МОЁ КАФЕ\n[E] Управление", Vector3(0, 1.55, 0.12), 26, Color("efcf91"))
	title.pixel_size = 0.007
	star_label = Props.text(board, "☆ ☆ ☆ ☆ ☆", Vector3(0, 0.95, 0.12), 30, Color("efcf91"))
	star_label.pixel_size = 0.007
	Props.solid_box(board, Vector3(0.9, 0.12, 0.7), Vector3(0, 0.08, 0), Color("775e43"))
	for i in range(4):
		var marker := Node3D.new()
		add_child(marker)
		marker.position = game.service.slot_position(i)
		Props.box(marker, Vector3(5.5, 0.015, 3.6), Vector3(0, 0.015, 0), Color("61716a"))
		var label := Props.text(marker, "", Vector3(0, 1.3, 0), 27, Color("e7c591"))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.005
		slots.append({"node": marker, "label": label})
	ribbon = Node3D.new()
	add_child(ribbon)
	Props.box(ribbon, Vector3(12.9, 0.11, 0.04), Vector3(10.2, 1.0, 0.65), Color("bfa565"))
	var sign := Node3D.new()
	add_child(sign)
	decor.sign = sign
	Props.box(sign, Vector3(3.2, 1.0, 0.12), Vector3(-9.2, 2.8, -7.35), Color("d4a268"))
	Props.text(sign, "МЫ ПОЧТИ УМЕЕМ", Vector3(-9.2, 2.85, -7.25), 33, Color("243f40"))
	var lights := Node3D.new()
	add_child(lights)
	decor.lights = lights
	for i in range(15):
		var x := -10.0 + i * 1.8
		var y := 3.7 - sin(i * PI / 14) * 0.35
		Props.ball(lights, 0.085, Vector3(x, y, -5.7), Color("ffd78c")).material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if i > 0: Props.line(lights, Vector3(x - 1.8, 3.7 - sin((i-1)*PI/14)*0.35, -5.7), Vector3(x,y,-5.7), 0.018, Color("333e39"))
	var plants := Node3D.new()
	add_child(plants)
	decor.plants = plants
	for x in [-7.5, 8.0, 13.0]:
		Props.cylinder(plants, 0.38, 0.55, Vector3(x, 0.275, 8.8), Color("cd9167"), 0.45)
		for i in range(4):
			var leaf := Props.ball(plants, 0.3, Vector3(x + sin(i*1.7)*0.3, 0.95+i*0.20, 8.8), Color("84ad78"))
			leaf.scale = Vector3(0.7, 1.8, 0.65)
	refresh()

func board_hit(camera: Camera3D) -> bool:
	var origin := board.to_local(camera.global_position)
	var ray := board.global_basis.inverse() * -camera.global_basis.z
	var hit = AABB(Vector3(-0.85, 0.35, -0.1), Vector3(1.7, 1.7, 0.3)).intersects_ray(origin, ray)
	return hit != null and origin.distance_to(hit) < 3.5

func refresh() -> void:
	var progress = game.service.progress
	for id in decor: decor[id].visible = id in progress.decorations
	for i in range(slots.size()):
		slots[i].node.visible = game.service.by_id(i + 1) == null
		slots[i].label.text = "МЕСТО ДЛЯ СТОЙКИ\n[M] Купить · 120" if i < 2 or (i == 2 and progress.expanded) else "РАСШИРЕНИЕ ЗАЛА\nПервая звезда" if not progress.expanded else "КУХНЯ НА ДВОИХ\n[M] Купить · 250"
	ribbon.visible = not progress.expanded
	star_label.text = "★ ☆ ☆ ☆ ☆" if progress.stars > 0 else "☆ ☆ ☆ ☆ ☆"
