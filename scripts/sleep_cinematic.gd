extends Node3D
## A shared camera shot; only the host decides when morning starts.
const Layout=preload("res://scripts/lounge_layout.gd")
const Avatar=preload("res://scripts/cook_avatar.gd")
const Rest=preload("res://scripts/lounge_progression.gd")
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
var game: Node3D
var shot: Camera3D
var overlay: CanvasLayer
var shade: ColorRect
var title: Label
var hint: Label
var self_avatar: Node3D
var always_skip_checkbox: CheckBox
var auto_vote_key := ""
var showing := false
const SETTINGS_PATH := "user://cinematic_settings.cfg"

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
	always_skip_checkbox=CheckBox.new()
	surface.add_child(always_skip_checkbox)
	always_skip_checkbox.text="Всегда пропускать"
	always_skip_checkbox.anchor_left=1.0
	always_skip_checkbox.anchor_right=1.0
	always_skip_checkbox.anchor_top=1.0
	always_skip_checkbox.anchor_bottom=1.0
	always_skip_checkbox.offset_left=-245
	always_skip_checkbox.offset_right=-22
	always_skip_checkbox.offset_top=-67
	always_skip_checkbox.offset_bottom=-25
	always_skip_checkbox.add_theme_font_size_override("font_size",18)
	always_skip_checkbox.z_index=5
	always_skip_checkbox.button_pressed=_load_always_skip()
	always_skip_checkbox.toggled.connect(_set_always_skip)
	overlay.hide()

func _load_always_skip() -> bool:
	var config:=ConfigFile.new()
	return config.load(SETTINGS_PATH)==OK and bool(config.get_value("cinematics","always_skip",false))

func _set_always_skip(value: bool) -> void:
	var config:=ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("cinematics","always_skip",value)
	config.save(SETTINGS_PATH)
	auto_vote_key=""

func _auto_skip_vote() -> bool:
	if not is_instance_valid(always_skip_checkbox) or not always_skip_checkbox.button_pressed or not game.session.sleep_scene_active(): return false
	var scene: Dictionary=game.session.sleep_scene
	var key: String="%s:%s"%[str(scene.get("serial",0)),game.session.sleep_scene_phase()]
	if key==auto_vote_key: return false
	auto_vote_key=key
	game.session.request_action({"action":"skip_sleep"})
	return true

func begin() -> void:
	showing=true
	game.menu.close()
	game.office.close()
	game.cookbook.close()
	game.session_paused=false
	game.hud.pause_panel.hide()
	game.hud.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var back: float=Layout.back_z(game.service.progress.lounge_tier)
	shot.global_position=Vector3(3.55,4.02,11.05)
	shot.look_at(Vector3(Layout.ENTRANCE.x,1.05,(Layout.FRONT_Z+back)*0.5),Vector3.UP)
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
		auto_vote_key=""
		return
	if _auto_skip_vote(): return
	var age: float=game.session.sleep_scene_age()
	var scene: Dictionary=game.session.sleep_scene
	var phase: String=game.session.sleep_scene_phase()
	var forecast:=Rest.report(game.service.progress,game.evening.workers().size())
	if phase=="sleep":
		title.text="СМЕНА ЗАКОНЧЕНА" if age<2.1 else "ТИХИЙ ЧАС ДЛЯ ОЧЕНЬ УСТАВШИХ"
		hint.text="Завтра: +%d%% к темпу команды\nПробел · пропустить вместе (%d/%d)"%[roundi(float(forecast.bonus)*100),scene.skips.size(),scene.participants.size()]
		shade.color=Color(0,0,0,maxf(clampf(1.0-age/0.4,0,1),clampf((age-6.45)/0.55,0,1)))
		if is_instance_valid(self_avatar):
			self_avatar.visible=game.session.local_sleeping()
			if self_avatar.visible:
				game.annex.settle_player_avatar(self_avatar,game.session.local_sleep_bed())
				self_avatar.caption.hide()
		return

	# The black frame at the end of the sleep shot becomes the first frame of morning.
	title.text="ДОБРОЕ УТРО · ДЕНЬ %d"%int(scene.get("morning_day",game.service.progress.day))
	hint.text="Клоны уже бегут на рабочие места\nПробел · пропустить вместе (%d/%d)"%[scene.skips.size(),scene.participants.size()]
	shade.color=Color(0,0,0,clampf(1.0-age/0.65,0,1))
	var daylight_blend: float=smoothstep(0.0,1.0,clampf(age/1.45,0,1))
	game.daylight.light_energy=lerpf(0.12,0.75,daylight_blend)
	game.room_environment.environment.ambient_light_energy=lerpf(0.26,0.35,daylight_blend)
	var travel: float=smoothstep(0.0,1.0,clampf((age-0.55)/4.3,0,1))
	var stage: int=Expansion.stage_for_progress(game.service.progress)
	var right: float=Layout.right_x(game.service.progress.lounge_tier)
	var bed: Vector3=game.annex.player_bed_center(0,game.service.progress.lounge_tier,stage)
	var camera_start: Vector3=bed+Vector3(-2.4,2.2,-1.5) if stage<2 else Vector3(right-0.8,4.15,Layout.back_z(game.service.progress.lounge_tier)-1.0)
	var camera_end: Vector3=Vector3(Layout.ENTRANCE.x,3.15,Layout.FRONT_Z+1.0)
	var look_start: Vector3=bed+Vector3(0,0.35,0) if stage<2 else bed+Vector3(0,0.5,-2.0)
	var look_end: Vector3=Vector3(0.0,1.05,5.1)
	shot.global_position=camera_start.lerp(camera_end,travel)
	shot.look_at(look_start.lerp(look_end,travel),Vector3.UP)
	if is_instance_valid(self_avatar):
		self_avatar.visible=game.session.local_sleeping()
		if self_avatar.visible:
			var layer: int=game.session.local_sleep_bed()
			var rise: float=smoothstep(0.0,1.0,clampf(age/1.15,0,1))
			self_avatar.morning_wake_pose(game.annex.player_bed_exit(layer,game.service.progress.lounge_tier,stage),0.0,rise,game.session.local_id())
			self_avatar.caption.hide()
