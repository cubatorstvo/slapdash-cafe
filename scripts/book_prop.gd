extends Node3D
const P = preload("res://scripts/props.gd")
const Data = preload("res://scripts/cookbook_data.gd")
var page_sound: AudioStreamPlayer3D
var title: Label3D
var notes: Label3D
var illustration: Sprite3D
var current_page := ""
var is_open := false
var turn := 0.0
var page_mesh: Node3D
var first_person := false

func _ready() -> void:
	for side in [-1, 1]:
		P.box(self, Vector3(0.50, 0.038, 0.68), Vector3(side * 0.255, -0.004, 0), Color("7a3d38"))
		P.box(self, Vector3(0.46, 0.030, 0.63), Vector3(side * 0.248, 0.034, 0), Color("f3e6c8") if side < 0 else Color("f8efd6"))
		for i in range(5): P.box(self, Vector3(0.455, 0.002, 0.61), Vector3(side * 0.248, 0.012 + i * 0.004, 0), Color("d8c9a4"))
	P.box(self, Vector3(0.032, 0.058, 0.68), Vector3.ZERO, Color("5e322f"))
	P.box(self, Vector3(0.046, 0.007, 0.22), Vector3(0.12, 0.062, 0.30), Color("e0b15a"))
	P.box(self, Vector3(0.08, 0.004, 0.08), Vector3(-0.42, 0.058, -0.28), Color("d7a45a"))
	title = P.text(self, "", Vector3(-0.25, 0.056, -0.18), 22, Color("213b3c"))
	title.rotation = Vector3(-PI / 2, PI, 0)
	title.pixel_size = 0.00115
	title.outline_size = 0
	title.modulate = Color("213b3c")
	notes = P.text(self, "", Vector3(0.25, 0.056, 0.16), 14, Color("35514c"))
	notes.rotation = Vector3(-PI / 2, PI, 0)
	notes.pixel_size = 0.00105
	notes.outline_size = 0
	notes.modulate = Color("35514c")
	illustration = Sprite3D.new()
	add_child(illustration)
	illustration.position = Vector3(-0.25, 0.058, 0.12)
	illustration.rotation = Vector3(-PI / 2, PI, 0)
	illustration.pixel_size = 0.0024
	for i in range(5): P.box(self, Vector3(0.34 - (i % 2) * 0.04, 0.002, 0.006), Vector3(-0.25, 0.057, -0.02 + i * 0.04), Color("c4b48d"))
	page_mesh = Node3D.new()
	add_child(page_mesh)
	P.box(page_mesh, Vector3(0.44, 0.004, 0.60), Vector3(0.22, 0.068, 0), Color("f7eed8"))
	page_sound = AudioStreamPlayer3D.new()
	add_child(page_sound)
	page_sound.stream = preload("res://assets/audio/page.wav")
	page_sound.max_distance = 6
	page_sound.unit_size = 2
	page_sound.volume_db = -12
	hide()

func pose_in_hands(first_person_held: bool) -> void:
	first_person = first_person_held
	if first_person:
		position = Vector3(0.0, -0.34, -0.70)
		rotation = Vector3(1.12, 0.04, 0)
		scale = Vector3(0.95, 0.95, 0.95)
	else:
		position = Vector3(0, 1.08, -0.40)
		rotation = Vector3(-0.58, 0, 0)
		scale = Vector3(0.72, 0.72, 0.72)
	title.visible = not first_person
	notes.visible = not first_person

func shown() -> bool:
	if not is_inside_tree() or not visible: return false
	var node: Node = self
	while node != null:
		if node is CanvasItem and not (node as CanvasItem).visible: return false
		if node is Node3D and not (node as Node3D).visible: return false
		node = node.get_parent()
	return true

func set_reading(open: bool, recipe := "index") -> void:
	visible = open
	var page := Data.page(recipe) if open else current_page
	var turned: bool = open != is_open or (open and current_page != page)
	if turned and shown(): page_sound.play()
	if open and turned: turn = 0.28
	is_open = open
	if not open or current_page == page: return
	current_page = page
	title.text = "ПОВАРСКАЯ\nКНИГА" if page == "index" else Data.Definition.DISHES.get(page, "РЕЦЕПТ")
	title.visible = not first_person
	illustration.texture = Data.ICONS.get(page, Data.ICONS.meal)
	illustration.visible = page != "index" and not first_person
	notes.visible = not first_person
	if page == "index":
		notes.text = "Выбери блюдо.\nКнига говорит,\nчто должно\nполучиться."
	else:
		var lines := PackedStringArray()
		for note in Data.NOTES.get(page, []):
			lines.append("• " + str(note[0]))
		notes.text = "\n".join(lines)

func _process(delta: float) -> void:
	turn = maxf(0, turn - delta)
	page_mesh.visible = turn > 0 and visible
	page_mesh.rotation.z = sin((1 - turn / 0.28) * PI) * 2.7
