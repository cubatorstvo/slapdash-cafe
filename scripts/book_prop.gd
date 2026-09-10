extends Node3D
const P = preload("res://scripts/props.gd")
const Data = preload("res://scripts/cookbook_data.gd")
var page_sound: AudioStreamPlayer3D
var title: Label3D
var illustration: Sprite3D
var current_page := ""
var is_open := false
var turn := 0.0
var page_mesh: Node3D

func _ready() -> void:
	for side in [-1, 1]:
		P.box(self, Vector3(0.48, 0.035, 0.65), Vector3(side * 0.25, 0, 0), Color("934d42"))
		P.box(self, Vector3(0.45, 0.028, 0.61), Vector3(side * 0.245, 0.035, 0), Color("eee1bf"))
		for i in range(4): P.box(self, Vector3(0.45, 0.002, 0.60), Vector3(side * 0.245, 0.017 + i * 0.005, 0), Color("cbbd9b"))
	P.box(self, Vector3(0.028, 0.052, 0.65), Vector3.ZERO, Color("704039"))
	P.box(self, Vector3(0.038, 0.006, 0.2), Vector3(0.1, 0.057, 0.29), Color("bf6b57"))
	title = P.text(self, "", Vector3(-0.24, 0.055, -0.15), 24, Color("354a45"))
	title.rotation.x = -PI/2
	title.pixel_size = 0.0013
	title.outline_size = 0
	illustration = Sprite3D.new()
	add_child(illustration)
	illustration.position = Vector3(0.245, 0.057, 0)
	illustration.rotation.x = -PI/2
	illustration.pixel_size = 0.0028
	for i in range(5): P.box(self, Vector3(0.31 - (i%2)*0.05, 0.002, 0.007), Vector3(-0.24, 0.056, -0.02+i*0.045), Color("b5a889"))
	page_mesh = Node3D.new()
	add_child(page_mesh)
	P.box(page_mesh, Vector3(0.43, 0.004, 0.58), Vector3(0.22, 0.065, 0), Color("f6ebd1"))
	page_sound = AudioStreamPlayer3D.new()
	add_child(page_sound)
	page_sound.stream = preload("res://assets/audio/page.wav")
	page_sound.max_distance = 6
	page_sound.volume_db = -12
	hide()

func set_reading(open: bool, recipe := "index") -> void:
	visible = open
	if open != is_open or (open and current_page != recipe): if is_visible_in_tree(): page_sound.play()
	if open and (not is_open or current_page != recipe): turn = 0.3
	is_open = open
	if current_page == recipe: return
	current_page = recipe
	title.text = "ПОВАРСКАЯ\nКНИГА" if recipe == "index" else Data.Definition.DISHES.get(recipe, "РЕЦЕПТ")
	illustration.texture = Data.ICONS.get(recipe, Data.ICONS.meal)

func _process(delta: float) -> void:
	turn = maxf(0, turn-delta)
	page_mesh.visible = turn > 0
	page_mesh.rotation.z = sin((1-turn/0.3)*PI)*2.7
