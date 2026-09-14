extends Node3D
## A shared camera shot; only the host decides when morning starts.
const Layout=preload("res://scripts/lounge_layout.gd")
const Avatar=preload("res://scripts/cook_avatar.gd")
const Rest=preload("res://scripts/lounge_progression.gd")
var game: Node3D
var shot: Camera3D
var overlay: CanvasLayer
var shade: ColorRect
var title: Label
var hint: Label
var self_avatar: Node3D
var showing := false

func setup(owner_game: Node3D) -> void:
	game=owner_game
	shot=Camera3D.new()
	add_child(shot)
	shot.fov=80
	shot.near=0.05
	overlay=CanvasLayer.new()
	overlay.layer=60
	add_child(overlay)
	var surface:=Control.new()
	overlay.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for top in [true,false]:
		var bar:=ColorRect.new()
		surface.add_child(bar)
		bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		bar.color=Color(0.025,0.035,0.035,0.95)
		bar.anchor_right=1
		if top: bar.offset_bottom=78
		else:
			bar.anchor_top=1
			bar.anchor_bottom=1
			bar.offset_top=-86
	title=Label.new()
	surface.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top=23
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",24)
	hint=Label.new()
	surface.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top=-72
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",19)
	shade=ColorRect.new()
	surface.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.hide()

func begin() -> void:
	showing=true
	game.menu.close()
	game.office.close()
	game.cookbook.close()
	game.session_paused=false
	game.hud.pause_panel.hide()
	game.hud.hide()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var back:=Layout.back_z(game.service.progress.lounge_tier)
	shot.global_position=Vector3(3.55,4.02,11.05)
	shot.look_at(Vector3(10.6,1.05,(10.6+back)*0.5+1.4),Vector3.UP)
	shot.make_current()
	overlay.show()
	self_avatar=Avatar.new()
	self_avatar.tint=Color("789fce")
	add_child(self_avatar)
	self_avatar.caption.hide()

func finish() -> void:
	showing=false
	overlay.hide()
	if is_instance_valid(self_avatar): self_avatar.queue_free()
	game.camera.make_current()
	game.hud.show()
	game.sync_mouse_mode()

func _process(_delta: float) -> void:
	if game==null: return
	var active: bool=game.session.sleep_scene_active()
	if active and not showing: begin()
	if not active:
		if showing: finish()
		return
	var age: float=game.session.sleep_scene_age()
	var scene: Dictionary=game.session.sleep_scene
	var forecast:=Rest.report(game.service.progress,game.evening.workers().size())
	title.text="СМЕНА ЗАКОНЧЕНА" if age<2.1 else "ТИХИЙ ЧАС ДЛЯ ОЧЕНЬ УСТАВШИХ"
	hint.text="Завтра: +%d%% к темпу команды\nПробел · пропустить вместе (%d/%d)"%[roundi(float(forecast.bonus)*100),scene.skips.size(),scene.participants.size()]
	shade.color=Color(0,0,0,maxf(clampf(1.0-age/0.4,0,1),clampf((age-6.45)/0.55,0,1)))
	if is_instance_valid(self_avatar):
		self_avatar.visible=game.session.local_sleeping()
		if self_avatar.visible:
			game.annex.settle_player_avatar(self_avatar,game.session.local_sleep_bed())
			self_avatar.caption.hide()
